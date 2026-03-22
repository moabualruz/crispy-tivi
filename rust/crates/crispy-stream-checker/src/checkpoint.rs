//! Resume checkpoint writer with buffered writes.
//!
//! Translated from IPTVChecker-Python `CheckpointWriter` class:
//!
//! ```python
//! class CheckpointWriter:
//!     def __init__(self, log_file, flush_interval=0.25, flush_threshold=128):
//!         self._log_file = log_file
//!         self._flush_interval = flush_interval
//!         self._flush_threshold = flush_threshold
//!         self._buffer = []
//!         self._lock = threading.Lock()
//!         self._last_flush = time.monotonic()
//!
//!     def write(self, entry):
//!         with self._lock:
//!             self._buffer.append(entry)
//!             now = time.monotonic()
//!             if len(self._buffer) >= self._flush_threshold or \
//!                (now - self._last_flush) >= self._flush_interval:
//!                 self._flush_locked()
//!
//!     def _flush_locked(self):
//!         if not self._buffer:
//!             return
//!         try:
//!             with open(self._log_file, 'a', encoding='utf-8', errors='replace') as f:
//!                 for entry in self._buffer:
//!                     f.write(entry + "\n")
//!         except OSError as exc:
//!             logging.error(...)
//!         self._buffer.clear()
//!         self._last_flush = time.monotonic()
//!
//!     def flush(self):
//!         with self._lock:
//!             self._flush_locked()
//!
//!     def close(self):
//!         self.flush()
//! ```

use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::Instant;

use tracing::error;

/// Buffered checkpoint writer for resume logging.
///
/// Entries are buffered in memory and flushed to disk when either:
/// - The buffer reaches `flush_threshold` entries, or
/// - `flush_interval` has elapsed since the last flush.
pub struct CheckpointWriter {
    inner: Mutex<CheckpointInner>,
}

struct CheckpointInner {
    log_file: PathBuf,
    buffer: Vec<String>,
    flush_threshold: usize,
    flush_interval: std::time::Duration,
    last_flush: Instant,
}

impl CheckpointWriter {
    /// Create a new checkpoint writer.
    ///
    /// - `log_file`: Path to the checkpoint log file (appended to).
    /// - `flush_threshold`: Maximum entries before auto-flush (default: 128).
    /// - `flush_interval`: Maximum time between flushes (default: 250ms).
    pub fn new(
        log_file: impl AsRef<Path>,
        flush_threshold: usize,
        flush_interval: std::time::Duration,
    ) -> Self {
        Self {
            inner: Mutex::new(CheckpointInner {
                log_file: log_file.as_ref().to_path_buf(),
                buffer: Vec::new(),
                flush_threshold,
                flush_interval,
                last_flush: Instant::now(),
            }),
        }
    }

    /// Create with default settings (threshold=128, interval=250ms).
    pub fn with_defaults(log_file: impl AsRef<Path>) -> Self {
        Self::new(log_file, 128, std::time::Duration::from_millis(250))
    }

    /// Buffer a checkpoint entry, flushing if thresholds are reached.
    pub fn write(&self, entry: impl Into<String>) {
        let mut inner = self.inner.lock().expect("checkpoint lock poisoned");
        inner.buffer.push(entry.into());

        let now = Instant::now();
        if inner.buffer.len() >= inner.flush_threshold
            || now.duration_since(inner.last_flush) >= inner.flush_interval
        {
            flush_locked(&mut inner);
        }
    }

    /// Force-flush all buffered entries to disk.
    pub fn flush(&self) {
        let mut inner = self.inner.lock().expect("checkpoint lock poisoned");
        flush_locked(&mut inner);
    }

    /// Flush and close (consumes the writer).
    pub fn close(self) {
        self.flush();
    }

    /// Return the number of currently buffered (unflushed) entries.
    #[cfg(test)]
    fn buffered_count(&self) -> usize {
        let inner = self.inner.lock().expect("checkpoint lock poisoned");
        inner.buffer.len()
    }
}

/// Flush the internal buffer to disk (called with lock held).
fn flush_locked(inner: &mut CheckpointInner) {
    if inner.buffer.is_empty() {
        return;
    }

    match std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&inner.log_file)
    {
        Ok(mut f) => {
            for entry in &inner.buffer {
                if let Err(e) = writeln!(f, "{entry}") {
                    error!(
                        file = inner.log_file.display().to_string(),
                        error = %e,
                        "failed to write checkpoint entry"
                    );
                    break;
                }
            }
        }
        Err(e) => {
            error!(
                file = inner.log_file.display().to_string(),
                error = %e,
                "failed to open checkpoint log"
            );
        }
    }

    inner.buffer.clear();
    inner.last_flush = Instant::now();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn buffers_entries_below_threshold() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("checkpoint.log");

        // High threshold so entries stay buffered.
        let writer = CheckpointWriter::new(&path, 1000, std::time::Duration::from_secs(3600));

        writer.write("entry1");
        writer.write("entry2");

        assert_eq!(writer.buffered_count(), 2);
        assert!(!path.exists() || std::fs::read_to_string(&path).unwrap().is_empty());
    }

    #[test]
    fn flushes_on_threshold() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("checkpoint.log");

        let writer = CheckpointWriter::new(&path, 2, std::time::Duration::from_secs(3600));

        writer.write("entry1");
        writer.write("entry2"); // triggers flush

        assert_eq!(writer.buffered_count(), 0);
        let content = std::fs::read_to_string(&path).unwrap();
        assert!(content.contains("entry1"));
        assert!(content.contains("entry2"));
    }

    #[test]
    fn manual_flush_writes_all() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("checkpoint.log");

        let writer = CheckpointWriter::new(&path, 1000, std::time::Duration::from_secs(3600));

        writer.write("a");
        writer.write("b");
        writer.write("c");
        writer.flush();

        let content = std::fs::read_to_string(&path).unwrap();
        let lines: Vec<&str> = content.lines().collect();
        assert_eq!(lines, vec!["a", "b", "c"]);
    }

    #[test]
    fn close_flushes() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("checkpoint.log");

        let writer = CheckpointWriter::new(&path, 1000, std::time::Duration::from_secs(3600));
        writer.write("final");
        writer.close();

        let content = std::fs::read_to_string(&path).unwrap();
        assert!(content.contains("final"));
    }
}
