//! Global sync progress emitter.
//!
//! Holds an optional callback that sync functions use to
//! report progress. The FFI layer sets the callback once
//! via `set_progress_callback`, wiring it to a FRB
//! `StreamSink`.

use std::sync::{Arc, Mutex, OnceLock};

use crate::models::SyncProgress;

/// Callback type for sync progress events.
pub type ProgressCallback = Arc<dyn Fn(&SyncProgress) + Send + Sync>;

/// Global progress callback singleton.
static PROGRESS_CB: OnceLock<Mutex<Option<ProgressCallback>>> = OnceLock::new();

fn cb_slot() -> &'static Mutex<Option<ProgressCallback>> {
    PROGRESS_CB.get_or_init(|| Mutex::new(None))
}

/// Register a progress callback. Replaces any previous one.
pub fn set_progress_callback(cb: ProgressCallback) {
    *cb_slot().lock().unwrap_or_else(|e| e.into_inner()) = Some(cb);
}

/// Emit a sync progress event. No-op if no callback registered.
pub fn emit_progress(source_id: &str, phase: &str, progress: f64, message: &str) {
    if let Some(cb) = cb_slot().lock().unwrap_or_else(|e| e.into_inner()).as_ref() {
        cb(&SyncProgress {
            source_id: source_id.to_owned(),
            phase: phase.to_owned(),
            progress,
            message: message.to_owned(),
        });
    }
}
