//! URL deduplication with async result sharing.
//!
//! Translated from IPTVChecker-Python `UrlDeduplicator` class:
//!
//! ```python
//! class UrlDeduplicator:
//!     def __init__(self):
//!         self._lock = threading.Lock()
//!         self._results = {}
//!         self._pending = {}
//!
//!     def get_or_start(self, url):
//!         with self._lock:
//!             if url in self._results:
//!                 return 'cached', self._results[url]
//!             if url in self._pending:
//!                 return 'waiting', self._pending[url]
//!             event = threading.Event()
//!             self._pending[url] = event
//!             return 'check', None
//!
//!     def set_result(self, url, result):
//!         with self._lock:
//!             self._results[url] = result
//!             event = self._pending.pop(url, None)
//!         if event:
//!             event.set()
//!
//!     def get_result(self, url):
//!         with self._lock:
//!             return self._results.get(url)
//! ```
//!
//! The Rust version uses `tokio::sync::watch` channels instead of
//! `threading.Event` for async notification.

use std::collections::HashMap;
use std::sync::Mutex;

use tokio::sync::watch;

use crate::types::CheckResult;

/// Outcome of attempting to check or retrieve a URL result.
pub enum DeduplicateAction {
    /// Result already cached — use it directly.
    Cached(Box<CheckResult>),
    /// Another task is already checking this URL — wait on the receiver.
    Waiting(watch::Receiver<Option<CheckResult>>),
    /// This task should perform the check — call `set_result` when done.
    Check,
}

/// Thread-safe URL deduplicator that prevents redundant checks for the
/// same URL across concurrent tasks.
pub struct UrlDeduplicator {
    inner: Mutex<DeduplicatorInner>,
}

struct DeduplicatorInner {
    results: HashMap<String, CheckResult>,
    pending: HashMap<String, watch::Sender<Option<CheckResult>>>,
}

impl UrlDeduplicator {
    /// Create a new empty deduplicator.
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(DeduplicatorInner {
                results: HashMap::new(),
                pending: HashMap::new(),
            }),
        }
    }

    /// Try to get an existing result or claim responsibility for checking.
    ///
    /// Returns:
    /// - `Cached(result)` — if the URL was already checked.
    /// - `Waiting(rx)` — if another task is checking; await the receiver.
    /// - `Check` — this task should perform the check and call `set_result`.
    pub fn get_or_start(&self, url: &str) -> DeduplicateAction {
        let mut inner = self.inner.lock().expect("deduplicator lock poisoned");

        if let Some(result) = inner.results.get(url) {
            return DeduplicateAction::Cached(Box::new(result.clone()));
        }

        if let Some(tx) = inner.pending.get(url) {
            return DeduplicateAction::Waiting(tx.subscribe());
        }

        let (tx, _rx) = watch::channel(None);
        inner.pending.insert(url.to_string(), tx);
        DeduplicateAction::Check
    }

    /// Store the check result and notify any waiting tasks.
    pub fn set_result(&self, url: &str, result: CheckResult) {
        let mut inner = self.inner.lock().expect("deduplicator lock poisoned");

        // Move from pending to results and notify waiters.
        if let Some(tx) = inner.pending.remove(url) {
            let _ = tx.send(Some(result.clone()));
        }
        inner.results.insert(url.to_string(), result);
    }

    /// Get a cached result without modifying state.
    pub fn get_result(&self, url: &str) -> Option<CheckResult> {
        let inner = self.inner.lock().expect("deduplicator lock poisoned");
        inner.results.get(url).cloned()
    }
}

impl Default for UrlDeduplicator {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    fn dummy_result(url: &str) -> CheckResult {
        use crate::types::{StreamCategory, StreamInfo};
        CheckResult {
            url: url.to_string(),
            info: StreamInfo {
                available: true,
                status_code: Some(200),
                response_time_ms: 42,
                content_type: None,
                content_length: None,
                error: None,
            },
            checked_at: Utc::now(),
            media_info: None,
            category: StreamCategory::Alive,
            error_reason: None,
            mismatch_warnings: Vec::new(),
        }
    }

    #[test]
    fn first_access_returns_check() {
        let dedup = UrlDeduplicator::new();
        assert!(matches!(
            dedup.get_or_start("http://example.com"),
            DeduplicateAction::Check
        ));
    }

    #[test]
    fn second_access_returns_waiting() {
        let dedup = UrlDeduplicator::new();
        let _ = dedup.get_or_start("http://example.com");
        assert!(matches!(
            dedup.get_or_start("http://example.com"),
            DeduplicateAction::Waiting(_)
        ));
    }

    #[test]
    fn after_set_result_returns_cached() {
        let dedup = UrlDeduplicator::new();
        let _ = dedup.get_or_start("http://example.com");
        dedup.set_result("http://example.com", dummy_result("http://example.com"));
        assert!(matches!(
            dedup.get_or_start("http://example.com"),
            DeduplicateAction::Cached(_)
        ));
    }

    #[test]
    fn get_result_returns_none_before_set() {
        let dedup = UrlDeduplicator::new();
        assert!(dedup.get_result("http://example.com").is_none());
    }

    #[test]
    fn get_result_returns_some_after_set() {
        let dedup = UrlDeduplicator::new();
        let _ = dedup.get_or_start("http://example.com");
        dedup.set_result("http://example.com", dummy_result("http://example.com"));
        assert!(dedup.get_result("http://example.com").is_some());
    }
}
