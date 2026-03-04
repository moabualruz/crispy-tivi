use super::SERVICE;
use crate::frb_generated::StreamSink;
use anyhow::{Result, anyhow};
use crispy_core::services::CrispyService;

/// Initialize the Rust backend with a database path.
/// Must be called once before any other API function.
pub fn init_backend(db_path: String) -> Result<()> {
    let service = CrispyService::open(&db_path)?;
    SERVICE
        .set(service)
        .map_err(|_| anyhow!("Already initialized"))
}

/// Subscribe to data-change events from the Rust
/// backend. Returns a `Stream<String>` of
/// JSON-encoded `DataChangeEvent` objects on the
/// Dart side. Call once at app startup.
pub fn subscribe_data_events(sink: StreamSink<String>) {
    let sink = std::sync::Arc::new(sink);
    if let Some(svc) = SERVICE.get() {
        svc.set_event_callback(std::sync::Arc::new(
            move |event: &crispy_core::events::DataChangeEvent| {
                let json = crispy_core::events::serialize_event(event);
                let _ = sink.add(json);
            },
        ));
    }
}

/// Returns the crispy-core version string.
#[flutter_rust_bridge::frb(sync)]
pub fn crispy_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
