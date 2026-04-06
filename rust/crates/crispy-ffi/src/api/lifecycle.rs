use super::CTX;
use crate::frb_generated::StreamSink;
use anyhow::{Result, anyhow};
use crispy_core::services::ServiceContext;

/// Initialize the Rust backend with a database path.
/// Must be called once before any other API function.
///
/// Installs a custom panic hook that logs instead of aborting,
/// keeping the app alive when a Rust thread panics.
pub fn init_backend(db_path: String) -> Result<()> {
    // Install graceful panic hook — log the panic and continue
    // instead of aborting the process. This prevents Rust panics
    // from crashing the entire Flutter app.
    std::panic::set_hook(Box::new(|info| {
        let location = info
            .location()
            .map(|l| format!("{}:{}:{}", l.file(), l.line(), l.column()))
            .unwrap_or_else(|| "unknown".to_string());
        let payload = if let Some(s) = info.payload().downcast_ref::<&str>() {
            s.to_string()
        } else if let Some(s) = info.payload().downcast_ref::<String>() {
            s.clone()
        } else {
            "Box<dyn Any>".to_string()
        };
        eprintln!(
            "╔══════════════════════════════════════════\n\
             ║ RUST PANIC (thread kept alive)\n\
             ║ {payload}\n\
             ║ at {location}\n\
             ╚══════════════════════════════════════════"
        );
    }));

    let service = ServiceContext::open(&db_path)?;

    CTX.set(service)
        .map_err(|_| anyhow!("Already initialized"))?;

    // Run startup cleanup on a background thread so it never blocks app startup.
    // Uses super::ctx() to get a reference to the already-initialized CTX.
    std::thread::spawn(|| {
        if let Err(e) =
            super::ctx().and_then(|s| crispy_core::services::cleanup::run_startup_cleanup(&s))
        {
            eprintln!("[lifecycle] startup cleanup warning (non-fatal): {e}");
        }
    });

    Ok(())
}

/// Subscribe to data-change events from the Rust
/// backend. Returns a `Stream<String>` of
/// JSON-encoded `DataChangeEvent` objects on the
/// Dart side. Call once at app startup.
pub fn subscribe_data_events(sink: StreamSink<String>) {
    let sink = std::sync::Arc::new(sink);
    if let Some(svc) = CTX.get() {
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
