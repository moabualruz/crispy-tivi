//! Structured JSON-lines test logger.
//!
//! Writes per-category `.log` files and a combined `test.log` under the run's
//! `logs/` subdirectory. Also prints to stderr for `--nocapture` visibility.
//! Only used in test/debug builds — zero overhead in release.

use std::cell::RefCell;
use std::collections::HashMap;
use std::fs::{File, create_dir_all};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};

use chrono::Utc;

pub struct TestLogger {
    log_dir: PathBuf,
    writers: RefCell<HashMap<String, BufWriter<File>>>,
}

impl TestLogger {
    pub fn new(run_dir: &Path) -> Self {
        let log_dir = run_dir.join("logs");
        create_dir_all(&log_dir).expect("create log dir");
        Self {
            log_dir,
            writers: RefCell::new(HashMap::new()),
        }
    }

    /// Write a structured JSON-line event to a named log file.
    ///
    /// Writes to `{category}.log` and (when `category != "test"`) also to the
    /// combined `test.log`. Mirrors every event to stderr for `--nocapture`.
    pub fn event(&self, category: &str, event: &str, fields: &[(&str, &str)]) {
        let ts = Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true);
        let mut obj = serde_json::Map::new();
        obj.insert("ts".into(), serde_json::Value::String(ts));
        obj.insert("cat".into(), serde_json::Value::String(category.into()));
        obj.insert("event".into(), serde_json::Value::String(event.into()));
        for (k, v) in fields {
            obj.insert((*k).into(), serde_json::Value::String((*v).into()));
        }
        let line = serde_json::to_string(&serde_json::Value::Object(obj)).unwrap();

        // Write to category-specific log file.
        let log_name = format!("{category}.log");
        self.write_to(&log_name, &line);

        // Also write to combined test.log (unless this IS the test log).
        if category != "test" {
            self.write_to("test.log", &line);
        }

        // Mirror to stderr for `cargo test -- --nocapture`.
        let kv = fields
            .iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect::<Vec<_>>()
            .join(" ");
        eprintln!("[{category}] {event} {kv}");
    }

    /// Flush all open log writers.
    pub fn flush(&self) {
        for writer in self.writers.borrow_mut().values_mut() {
            writer.flush().ok();
        }
    }

    // ── Private ───────────────────────────────────────────────────────────────

    fn write_to(&self, log_name: &str, line: &str) {
        let mut writers = self.writers.borrow_mut();
        let writer = writers.entry(log_name.to_owned()).or_insert_with(|| {
            let path = self.log_dir.join(log_name);
            BufWriter::new(File::create(path).expect("create log file"))
        });
        writeln!(writer, "{}", line).ok();
        writer.flush().ok();
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_logger_writes_category_and_combined_log() {
        let tmp = std::env::temp_dir().join(format!("crispy_logger_test_{}", uuid::Uuid::new_v4()));
        fs::create_dir_all(&tmp).unwrap();

        let logger = TestLogger::new(&tmp);
        logger.event("journey", "step_start", &[("step", "home"), ("idx", "0")]);
        logger.event("render", "screenshot", &[("file", "home.png")]);
        logger.flush();

        // journey.log must exist and contain the event.
        let journey_log = tmp.join("logs/journey.log");
        assert!(journey_log.exists(), "journey.log missing");
        let content = fs::read_to_string(&journey_log).unwrap();
        assert!(content.contains("\"cat\":\"journey\""));
        assert!(content.contains("\"event\":\"step_start\""));
        assert!(content.contains("\"step\":\"home\""));

        // test.log must exist and aggregate both events.
        let test_log = tmp.join("logs/test.log");
        assert!(test_log.exists(), "test.log missing");
        let combined = fs::read_to_string(&test_log).unwrap();
        assert!(combined.contains("step_start"));
        assert!(combined.contains("screenshot"));

        // render.log must exist too.
        assert!(tmp.join("logs/render.log").exists(), "render.log missing");
    }

    #[test]
    fn test_logger_test_category_not_duplicated_in_combined() {
        let tmp =
            std::env::temp_dir().join(format!("crispy_logger_nodup_{}", uuid::Uuid::new_v4()));
        fs::create_dir_all(&tmp).unwrap();

        let logger = TestLogger::new(&tmp);
        logger.event("test", "suite_start", &[("name", "screenshots")]);
        logger.flush();

        // test.log must exist (written as the category file).
        let test_log = tmp.join("logs/test.log");
        let content = fs::read_to_string(&test_log).unwrap();
        // Exactly one line (not duplicated).
        let lines: Vec<&str> = content.lines().filter(|l| !l.is_empty()).collect();
        assert_eq!(lines.len(), 1, "test.log should have exactly one line");
    }
}
