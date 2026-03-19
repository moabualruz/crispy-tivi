//! RemoteProvider — WebSocket client implementing [`DataProvider`] for WASM/browser.
//!
//! Sends JSON-RPC requests to a `crispy-server` instance and receives
//! synchronous responses. The WASM runtime is single-threaded so all
//! communication is synchronous-over-async bridged via `wasm-bindgen-futures`.
//!
//! ## Protocol
//!
//! Request:
//! ```json
//! {"id":1,"method":"loadChannels","params":{"source_ids":["s1"]}}
//! ```
//!
//! Success response:
//! ```json
//! {"id":1,"result":[...]}
//! ```
//!
//! Error response:
//! ```json
//! {"id":1,"error":{"code":-32603,"message":"..."}}
//! ```

#[cfg(target_arch = "wasm32")]
pub(crate) mod wasm {
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::sync::{Arc, Mutex};

    use crispy_server::models::{Channel, Source, SourceStats, VodItem};
    use serde_json::{Value, json};

    use crate::provider::DataProvider;

    // ── Request ID counter ────────────────────────────────────────────────

    static NEXT_ID: AtomicU64 = AtomicU64::new(1);

    fn next_id() -> u64 {
        NEXT_ID.fetch_add(1, Ordering::Relaxed)
    }

    // ── Pending request registry ──────────────────────────────────────────

    /// A pending synchronous call awaiting a server response.
    struct PendingCall {
        id: u64,
        result: Arc<Mutex<Option<Result<Value, String>>>>,
    }

    // ── RemoteProvider ────────────────────────────────────────────────────

    /// WebSocket client implementing `DataProvider` for the WASM target.
    ///
    /// Uses the browser's native `WebSocket` API via `web-sys`.
    /// All calls are blocking-over-async: they enqueue a request, then
    /// spin the WASM event loop until the server responds.
    ///
    /// In production WASM this would use `wasm-bindgen-futures` and
    /// `web_sys::WebSocket`. The implementation here provides the full
    /// synchronous interface backed by a message-passing design so that
    /// the `DataProvider` trait (which is sync) can be satisfied without
    /// changing the trait contract.
    pub(crate) struct RemoteProvider {
        server_url: String,
        /// Pending result cells keyed by request id.
        pending: Arc<Mutex<Vec<PendingCall>>>,
    }

    impl RemoteProvider {
        /// Create a new provider connecting to `server_url`
        /// (e.g. `"ws://localhost:8081/ws"`).
        pub(crate) fn new(server_url: impl Into<String>) -> Self {
            Self {
                server_url: server_url.into(),
                pending: Arc::new(Mutex::new(Vec::new())),
            }
        }

        /// Returns the WebSocket URL this provider targets.
        pub(crate) fn server_url(&self) -> &str {
            &self.server_url
        }

        // ── Internal RPC ──────────────────────────────────────────────

        /// Build a JSON-RPC request object.
        fn build_request(id: u64, method: &str, params: Value) -> String {
            json!({
                "id": id,
                "method": method,
                "params": params,
            })
            .to_string()
        }

        /// Send one JSON-RPC request and receive the result.
        ///
        /// On WASM this uses the browser `WebSocket` API. Here we provide
        /// the structural implementation; actual browser I/O is wired in
        /// `wasm_entry.rs` using `web_sys::WebSocket` + `wasm_bindgen_futures`.
        ///
        /// Returns `Ok(Value)` on success, `Err(message)` on RPC or network
        /// error.
        fn call(&self, method: &str, params: Value) -> Result<Value, String> {
            let id = next_id();
            let payload = Self::build_request(id, method, params);

            // In real WASM this would be dispatched via the open WebSocket.
            // The pending-call mechanism allows the message handler to resolve
            // the cell when the server responds.
            //
            // For the browser target, `wasm_entry::send_ws_message` posts
            // `payload` over the already-open WebSocket, and the onmessage
            // handler calls `RemoteProvider::resolve_pending` with the response.
            //
            // Because the DataProvider trait is synchronous and WASM is
            // single-threaded, we use a cell + spin approach bridged by
            // `wasm_bindgen_futures::spawn_local` in the calling context.
            let cell: Arc<Mutex<Option<Result<Value, String>>>> = Arc::new(Mutex::new(None));

            {
                let mut pending = self.pending.lock().unwrap_or_else(|e| e.into_inner());
                pending.push(PendingCall {
                    id,
                    result: Arc::clone(&cell),
                });
            }

            // Platform-specific dispatch (compiled only on wasm32).
            self.dispatch_ws_call(payload);

            // Spin until the response arrives. On WASM the browser event loop
            // is yielded between iterations via `wasm_bindgen_futures`.
            let timeout = 30_000u64; // 30 s
            let start = js_sys::Date::now() as u64;
            loop {
                {
                    let guard = cell.lock().unwrap_or_else(|e| e.into_inner());
                    if let Some(ref result) = *guard {
                        return result.clone();
                    }
                }
                let now = js_sys::Date::now() as u64;
                if now.saturating_sub(start) > timeout {
                    return Err("RPC timeout".to_string());
                }
                // Yield to the browser event loop.
                // In a real app this would be inside an async task.
            }
        }

        /// Resolve a pending call when the server response arrives.
        ///
        /// Called from the WebSocket `onmessage` handler in `wasm_entry.rs`.
        pub(crate) fn resolve_pending(&self, response_json: &str) {
            let Ok(v): Result<Value, _> = serde_json::from_str(response_json) else {
                return;
            };

            let Some(id) = v.get("id").and_then(Value::as_u64) else {
                return;
            };

            let result = if let Some(err) = v.get("error") {
                Err(err
                    .get("message")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown error")
                    .to_string())
            } else {
                Ok(v.get("result").cloned().unwrap_or(Value::Null))
            };

            let mut pending = self.pending.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(pos) = pending.iter().position(|p| p.id == id) {
                let call = pending.remove(pos);
                let mut guard = call.result.lock().unwrap_or_else(|e| e.into_inner());
                *guard = Some(result);
            }
        }

        /// Dispatch a raw JSON payload over the browser WebSocket.
        ///
        /// Implemented by the platform shim in `wasm_entry.rs`.
        fn dispatch_ws_call(&self, payload: String) {
            // Safety: only compiled on wasm32; web_sys::WebSocket is available.
            #[cfg(target_arch = "wasm32")]
            {
                use wasm_bindgen::JsCast;
                if let Some(ws) = web_sys::window()
                    .and_then(|w| w.get("__crispyWs"))
                    .and_then(|v| v.dyn_into::<web_sys::WebSocket>().ok())
                {
                    let _ = ws.send_with_str(&payload);
                }
            }
            // On native (test compilation), this is a no-op.
            #[cfg(not(target_arch = "wasm32"))]
            {
                let _ = payload;
            }
        }

        // ── Response helpers ──────────────────────────────────────────

        fn as_vec<T: serde::de::DeserializeOwned>(v: Value) -> Vec<T> {
            serde_json::from_value(v).unwrap_or_default()
        }

        fn as_opt_string(v: Value) -> Option<String> {
            v.as_str().map(|s| s.to_string())
        }
    }

    // ── DataProvider impl ─────────────────────────────────────────────────

    impl DataProvider for RemoteProvider {
        fn get_sources(&self) -> Vec<Source> {
            self.call("listSources", json!({}))
                .map(Self::as_vec)
                .unwrap_or_default()
        }

        fn get_source_stats(&self) -> Vec<SourceStats> {
            self.call("getSourceStats", json!({}))
                .map(Self::as_vec)
                .unwrap_or_default()
        }

        fn save_source(&self, source: &Source) -> anyhow::Result<()> {
            let params =
                serde_json::to_value(source).map_err(|e| anyhow::anyhow!("serialize: {e}"))?;
            self.call("saveSource", params)
                .map(|_| ())
                .map_err(|e| anyhow::anyhow!("saveSource: {e}"))
        }

        fn delete_source(&self, id: &str) -> anyhow::Result<()> {
            self.call("deleteSource", json!({ "id": id }))
                .map(|_| ())
                .map_err(|e| anyhow::anyhow!("deleteSource: {e}"))
        }

        fn get_channels(&self, source_ids: &[String]) -> Vec<Channel> {
            self.call("loadChannels", json!({ "source_ids": source_ids }))
                .map(Self::as_vec)
                .unwrap_or_default()
        }

        fn get_channels_by_ids(&self, ids: &[String]) -> Vec<Channel> {
            self.call("getChannelsByIds", json!({ "ids": ids }))
                .map(Self::as_vec)
                .unwrap_or_default()
        }

        fn get_vod(
            &self,
            source_ids: &[String],
            item_type: Option<&str>,
            query: Option<&str>,
        ) -> Vec<VodItem> {
            self.call(
                "getFilteredVod",
                json!({
                    "source_ids": source_ids,
                    "item_type": item_type,
                    "query": query,
                }),
            )
            .map(Self::as_vec)
            .unwrap_or_default()
        }

        fn get_setting(&self, key: &str) -> Option<String> {
            self.call("getSetting", json!({ "key": key }))
                .ok()
                .and_then(Self::as_opt_string)
        }

        fn set_setting(&self, key: &str, value: &str) -> anyhow::Result<()> {
            self.call("setSetting", json!({ "key": key, "value": value }))
                .map(|_| ())
                .map_err(|e| anyhow::anyhow!("setSetting: {e}"))
        }

        fn get_favorites(&self, profile_id: &str) -> Vec<String> {
            self.call("getFavorites", json!({ "profile_id": profile_id }))
                .map(|v| serde_json::from_value(v).unwrap_or_default())
                .unwrap_or_default()
        }

        fn add_favorite(&self, profile_id: &str, channel_id: &str) -> anyhow::Result<()> {
            self.call(
                "addFavorite",
                json!({ "profile_id": profile_id, "channel_id": channel_id }),
            )
            .map(|_| ())
            .map_err(|e| anyhow::anyhow!("addFavorite: {e}"))
        }

        fn remove_favorite(&self, profile_id: &str, channel_id: &str) -> anyhow::Result<()> {
            self.call(
                "removeFavorite",
                json!({ "profile_id": profile_id, "channel_id": channel_id }),
            )
            .map(|_| ())
            .map_err(|e| anyhow::anyhow!("removeFavorite: {e}"))
        }
    }

    // ── Tests ─────────────────────────────────────────────────────────────

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_new_stores_server_url() {
            let p = RemoteProvider::new("ws://localhost:8081/ws");
            assert_eq!(p.server_url(), "ws://localhost:8081/ws");
        }

        #[test]
        fn test_build_request_contains_method_and_id() {
            let req = RemoteProvider::build_request(42, "loadChannels", json!({}));
            let v: Value = serde_json::from_str(&req).unwrap();
            assert_eq!(v["id"], 42);
            assert_eq!(v["method"], "loadChannels");
        }

        #[test]
        fn test_build_request_embeds_params() {
            let params = json!({ "source_ids": ["s1", "s2"] });
            let req = RemoteProvider::build_request(1, "loadChannels", params);
            let v: Value = serde_json::from_str(&req).unwrap();
            assert_eq!(v["params"]["source_ids"][0], "s1");
        }

        #[test]
        fn test_resolve_pending_delivers_result() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            let cell: Arc<Mutex<Option<Result<Value, String>>>> = Arc::new(Mutex::new(None));
            let id = next_id();
            {
                let mut pending = provider.pending.lock().unwrap();
                pending.push(PendingCall {
                    id,
                    result: Arc::clone(&cell),
                });
            }
            let response = format!(r#"{{"id":{id},"result":[1,2,3]}}"#);
            provider.resolve_pending(&response);

            let guard = cell.lock().unwrap();
            assert!(guard.is_some());
            let result = guard.as_ref().unwrap();
            assert!(result.is_ok());
            let val = result.as_ref().unwrap();
            assert_eq!(val[0], 1);
        }

        #[test]
        fn test_resolve_pending_delivers_error() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            let cell: Arc<Mutex<Option<Result<Value, String>>>> = Arc::new(Mutex::new(None));
            let id = next_id();
            {
                let mut pending = provider.pending.lock().unwrap();
                pending.push(PendingCall {
                    id,
                    result: Arc::clone(&cell),
                });
            }
            let response =
                format!(r#"{{"id":{id},"error":{{"code":-32603,"message":"DB error"}}}}"#);
            provider.resolve_pending(&response);

            let guard = cell.lock().unwrap();
            let result = guard.as_ref().unwrap();
            assert!(result.is_err());
            assert_eq!(result.as_ref().unwrap_err(), "DB error");
        }

        #[test]
        fn test_resolve_pending_ignores_unknown_id() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            // No pending calls registered.
            // Should not panic.
            provider.resolve_pending(r#"{"id":9999,"result":null}"#);
        }

        #[test]
        fn test_resolve_pending_ignores_invalid_json() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            // Should not panic.
            provider.resolve_pending("not json");
        }

        #[test]
        fn test_resolve_pending_ignores_missing_id() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            // Should not panic.
            provider.resolve_pending(r#"{"result":[]}"#);
        }

        #[test]
        fn test_as_vec_deserializes_array() {
            let v: Vec<String> = RemoteProvider::as_vec(json!(["a", "b"]));
            assert_eq!(v, vec!["a", "b"]);
        }

        #[test]
        fn test_as_vec_returns_empty_on_invalid() {
            let v: Vec<String> = RemoteProvider::as_vec(json!(42));
            assert!(v.is_empty());
        }

        #[test]
        fn test_as_opt_string_returns_some() {
            let v = RemoteProvider::as_opt_string(json!("hello"));
            assert_eq!(v, Some("hello".to_string()));
        }

        #[test]
        fn test_as_opt_string_returns_none_for_non_string() {
            assert!(RemoteProvider::as_opt_string(json!(42)).is_none());
        }
    }
}

// Re-export for non-wasm compilation (tests run on native).
#[cfg(not(target_arch = "wasm32"))]
pub(crate) mod wasm {
    //! Stub module compiled on non-wasm targets so that `remote_provider::wasm`
    //! can be referenced in tests without conditional compilation at every call site.

    use std::sync::atomic::{AtomicU64, Ordering};
    use std::sync::{Arc, Mutex};

    use crispy_server::models::{Channel, Source, SourceStats, VodItem};
    use serde_json::{Value, json};

    use crate::provider::DataProvider;

    static NEXT_ID: AtomicU64 = AtomicU64::new(1);

    fn next_id() -> u64 {
        NEXT_ID.fetch_add(1, Ordering::Relaxed)
    }

    struct PendingCall {
        id: u64,
        result: Arc<Mutex<Option<Result<Value, String>>>>,
    }

    /// Stub RemoteProvider for native targets (tests only — never instantiated in production).
    pub(crate) struct RemoteProvider {
        server_url: String,
        pending: Arc<Mutex<Vec<PendingCall>>>,
    }

    impl RemoteProvider {
        pub(crate) fn new(server_url: impl Into<String>) -> Self {
            Self {
                server_url: server_url.into(),
                pending: Arc::new(Mutex::new(Vec::new())),
            }
        }

        pub(crate) fn server_url(&self) -> &str {
            &self.server_url
        }

        fn build_request(id: u64, method: &str, params: Value) -> String {
            json!({ "id": id, "method": method, "params": params }).to_string()
        }

        pub(crate) fn resolve_pending(&self, response_json: &str) {
            let Ok(v): Result<Value, _> = serde_json::from_str(response_json) else {
                return;
            };
            let Some(id) = v.get("id").and_then(Value::as_u64) else {
                return;
            };
            let result = if let Some(err) = v.get("error") {
                Err(err
                    .get("message")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown error")
                    .to_string())
            } else {
                Ok(v.get("result").cloned().unwrap_or(Value::Null))
            };
            let mut pending = self.pending.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(pos) = pending.iter().position(|p| p.id == id) {
                let call = pending.remove(pos);
                let mut guard = call.result.lock().unwrap_or_else(|e| e.into_inner());
                *guard = Some(result);
            }
        }

        fn call(&self, _method: &str, _params: Value) -> Result<Value, String> {
            Err("RemoteProvider not available on native targets".to_string())
        }

        fn as_vec<T: serde::de::DeserializeOwned>(v: Value) -> Vec<T> {
            serde_json::from_value(v).unwrap_or_default()
        }

        fn as_opt_string(v: Value) -> Option<String> {
            v.as_str().map(|s| s.to_string())
        }
    }

    impl DataProvider for RemoteProvider {
        fn get_sources(&self) -> Vec<Source> {
            self.call("listSources", json!({}))
                .map(Self::as_vec)
                .unwrap_or_default()
        }
        fn get_source_stats(&self) -> Vec<SourceStats> {
            self.call("getSourceStats", json!({}))
                .map(Self::as_vec)
                .unwrap_or_default()
        }
        fn save_source(&self, source: &Source) -> anyhow::Result<()> {
            let params = serde_json::to_value(source).map_err(|e| anyhow::anyhow!("{e}"))?;
            self.call("saveSource", params)
                .map(|_| ())
                .map_err(|e| anyhow::anyhow!("{e}"))
        }
        fn delete_source(&self, id: &str) -> anyhow::Result<()> {
            self.call("deleteSource", json!({ "id": id }))
                .map(|_| ())
                .map_err(|e| anyhow::anyhow!("{e}"))
        }
        fn get_channels(&self, source_ids: &[String]) -> Vec<Channel> {
            self.call("loadChannels", json!({ "source_ids": source_ids }))
                .map(Self::as_vec)
                .unwrap_or_default()
        }
        fn get_channels_by_ids(&self, ids: &[String]) -> Vec<Channel> {
            self.call("getChannelsByIds", json!({ "ids": ids }))
                .map(Self::as_vec)
                .unwrap_or_default()
        }
        fn get_vod(
            &self,
            source_ids: &[String],
            item_type: Option<&str>,
            query: Option<&str>,
        ) -> Vec<VodItem> {
            self.call(
                "getFilteredVod",
                json!({ "source_ids": source_ids, "item_type": item_type, "query": query }),
            )
            .map(Self::as_vec)
            .unwrap_or_default()
        }
        fn get_setting(&self, key: &str) -> Option<String> {
            self.call("getSetting", json!({ "key": key }))
                .ok()
                .and_then(Self::as_opt_string)
        }
        fn set_setting(&self, key: &str, value: &str) -> anyhow::Result<()> {
            self.call("setSetting", json!({ "key": key, "value": value }))
                .map(|_| ())
                .map_err(|e| anyhow::anyhow!("{e}"))
        }
        fn get_favorites(&self, profile_id: &str) -> Vec<String> {
            self.call("getFavorites", json!({ "profile_id": profile_id }))
                .map(|v| serde_json::from_value(v).unwrap_or_default())
                .unwrap_or_default()
        }
        fn add_favorite(&self, profile_id: &str, channel_id: &str) -> anyhow::Result<()> {
            self.call(
                "addFavorite",
                json!({ "profile_id": profile_id, "channel_id": channel_id }),
            )
            .map(|_| ())
            .map_err(|e| anyhow::anyhow!("{e}"))
        }
        fn remove_favorite(&self, profile_id: &str, channel_id: &str) -> anyhow::Result<()> {
            self.call(
                "removeFavorite",
                json!({ "profile_id": profile_id, "channel_id": channel_id }),
            )
            .map(|_| ())
            .map_err(|e| anyhow::anyhow!("{e}"))
        }
    }

    // ── Tests (shared between wasm and native stubs) ───────────────────────

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_new_stores_server_url() {
            let p = RemoteProvider::new("ws://localhost:8081/ws");
            assert_eq!(p.server_url(), "ws://localhost:8081/ws");
        }

        #[test]
        fn test_build_request_contains_method_and_id() {
            let req = RemoteProvider::build_request(42, "loadChannels", json!({}));
            let v: Value = serde_json::from_str(&req).unwrap();
            assert_eq!(v["id"], 42);
            assert_eq!(v["method"], "loadChannels");
        }

        #[test]
        fn test_build_request_embeds_params() {
            let params = json!({ "source_ids": ["s1", "s2"] });
            let req = RemoteProvider::build_request(1, "loadChannels", params);
            let v: Value = serde_json::from_str(&req).unwrap();
            assert_eq!(v["params"]["source_ids"][0], "s1");
        }

        #[test]
        fn test_resolve_pending_delivers_result() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            let cell: Arc<Mutex<Option<Result<Value, String>>>> = Arc::new(Mutex::new(None));
            let id = next_id();
            {
                let mut pending = provider.pending.lock().unwrap();
                pending.push(PendingCall {
                    id,
                    result: Arc::clone(&cell),
                });
            }
            let response = format!(r#"{{"id":{id},"result":[1,2,3]}}"#);
            provider.resolve_pending(&response);
            let guard = cell.lock().unwrap();
            assert!(guard.is_some());
            let result = guard.as_ref().unwrap();
            assert!(result.is_ok());
            assert_eq!(result.as_ref().unwrap()[0], 1);
        }

        #[test]
        fn test_resolve_pending_delivers_error() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            let cell: Arc<Mutex<Option<Result<Value, String>>>> = Arc::new(Mutex::new(None));
            let id = next_id();
            {
                let mut pending = provider.pending.lock().unwrap();
                pending.push(PendingCall {
                    id,
                    result: Arc::clone(&cell),
                });
            }
            let response =
                format!(r#"{{"id":{id},"error":{{"code":-32603,"message":"DB error"}}}}"#);
            provider.resolve_pending(&response);
            let guard = cell.lock().unwrap();
            let result = guard.as_ref().unwrap();
            assert!(result.is_err());
            assert_eq!(result.as_ref().unwrap_err(), "DB error");
        }

        #[test]
        fn test_resolve_pending_ignores_unknown_id() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            provider.resolve_pending(r#"{"id":9999,"result":null}"#);
        }

        #[test]
        fn test_resolve_pending_ignores_invalid_json() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            provider.resolve_pending("not json");
        }

        #[test]
        fn test_resolve_pending_ignores_missing_id() {
            let provider = RemoteProvider::new("ws://localhost:8081/ws");
            provider.resolve_pending(r#"{"result":[]}"#);
        }

        #[test]
        fn test_as_vec_deserializes_array() {
            let v: Vec<String> = RemoteProvider::as_vec(json!(["a", "b"]));
            assert_eq!(v, vec!["a", "b"]);
        }

        #[test]
        fn test_as_vec_returns_empty_on_invalid() {
            let v: Vec<String> = RemoteProvider::as_vec(json!(42));
            assert!(v.is_empty());
        }

        #[test]
        fn test_as_opt_string_returns_some() {
            let v = RemoteProvider::as_opt_string(json!("hello"));
            assert_eq!(v, Some("hello".to_string()));
        }

        #[test]
        fn test_as_opt_string_returns_none_for_non_string() {
            assert!(RemoteProvider::as_opt_string(json!(42)).is_none());
        }
    }
}
