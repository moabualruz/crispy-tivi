//! Runtime performance monitoring.
//!
//! Provides CPU timing via `tracing` spans and memory usage
//! via `memory-stats`. Designed for production use with minimal
//! overhead when disabled.

use std::time::Instant;

/// Log current process memory usage (RSS) in MB.
pub fn log_memory_usage(label: &str) {
    if let Some(usage) = memory_stats::memory_stats() {
        let rss_mb = usage.physical_mem as f64 / (1024.0 * 1024.0);
        let vms_mb = usage.virtual_mem as f64 / (1024.0 * 1024.0);
        eprintln!("[PERF] {label}: RSS={rss_mb:.1}MB VMS={vms_mb:.1}MB");
    }
}

/// Simple scope timer — prints elapsed on drop.
pub struct ScopeTimer {
    label: &'static str,
    start: Instant,
}

impl ScopeTimer {
    pub fn new(label: &'static str) -> Self {
        Self {
            label,
            start: Instant::now(),
        }
    }
}

impl Drop for ScopeTimer {
    fn drop(&mut self) {
        let elapsed = self.start.elapsed();
        eprintln!(
            "[PERF] {}: {:.1}ms",
            self.label,
            elapsed.as_secs_f64() * 1000.0
        );
    }
}

/// Macro for quick scope timing.
#[macro_export]
macro_rules! perf_scope {
    ($label:expr) => {
        let _timer = $crate::profiling::ScopeTimer::new($label);
    };
}
