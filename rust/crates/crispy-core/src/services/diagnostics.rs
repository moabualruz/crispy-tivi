//! Diagnostics data service.
//!
//! Collects system info, per-source health, and recent app events,
//! then serialises them to a redacted JSON log. Passwords are
//! replaced with `[REDACTED]`; email addresses are SHA-256 hashed.

use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
};

use chrono::{DateTime, Utc};
use sha2::{Digest, Sha256};

fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

// ── Source status ─────────────────────────────────────────────────────────────

/// Aggregated health status for a single source.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceStatus {
    Healthy,
    Degraded,
    Offline,
}

impl SourceStatus {
    /// Compute status from recent error rate.
    ///
    /// - 0 errors → Healthy
    /// - 1–50 % → Degraded
    /// - > 50 % (or all syncs failed) → Offline
    fn from_error_rate(errors: u32, total: u32) -> Self {
        if total == 0 || errors == 0 {
            return Self::Healthy;
        }
        let rate = errors as f64 / total as f64;
        if rate >= 0.5 {
            Self::Offline
        } else {
            Self::Degraded
        }
    }
}

// ── Source health ─────────────────────────────────────────────────────────────

/// Per-source health snapshot.
#[derive(Debug, Clone, serde::Serialize)]
pub struct SourceHealth {
    pub source_id: String,
    pub status: SourceStatus,
    pub last_sync: Option<DateTime<Utc>>,
    pub next_sync: Option<DateTime<Utc>>,
    pub channel_count: u32,
    pub epg_coverage_pct: f32,
    pub recent_errors: Vec<String>,
}

// ── App event ─────────────────────────────────────────────────────────────────

/// A single diagnostic app event (logged in-memory for the last 24 h).
#[derive(Debug, Clone, serde::Serialize)]
pub struct DiagEvent {
    pub timestamp: DateTime<Utc>,
    pub level: String,
    pub message: String,
}

// ── System info ───────────────────────────────────────────────────────────────

/// Static system snapshot gathered at startup.
#[derive(Debug, Clone, serde::Serialize)]
pub struct SystemInfo {
    pub app_version: String,
    pub platform: String,
    pub os: String,
    pub available_storage_bytes: Option<u64>,
    pub network_type: String,
}

// ── DiagnosticsService ────────────────────────────────────────────────────────

/// Collects system info, source health snapshots, and recent events,
/// then exports a redacted JSON diagnostic log.
#[derive(Clone)]
pub struct DiagnosticsService {
    inner: Arc<Mutex<DiagnosticsInner>>,
}

struct DiagnosticsInner {
    system_info: SystemInfo,
    source_health: Vec<SourceHealth>,
    /// Rolling last-24 h event ring buffer (max 1 000 entries).
    events: VecDeque<DiagEvent>,
}

const MAX_EVENTS: usize = 1_000;

impl DiagnosticsService {
    /// Create a new service with the given static system information.
    pub fn new(system_info: SystemInfo) -> Self {
        Self {
            inner: Arc::new(Mutex::new(DiagnosticsInner {
                system_info,
                source_health: Vec::new(),
                events: VecDeque::with_capacity(MAX_EVENTS),
            })),
        }
    }

    // ── System info ──────────────────────────────────────────────────────────

    /// Return a clone of the current system info snapshot.
    pub fn system_info(&self) -> SystemInfo {
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .system_info
            .clone()
    }

    // ── Source health ────────────────────────────────────────────────────────

    /// Register or replace the health snapshot for a source.
    pub fn update_source_health(&self, health: SourceHealth) {
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(pos) = guard
            .source_health
            .iter()
            .position(|h| h.source_id == health.source_id)
        {
            guard.source_health[pos] = health;
        } else {
            guard.source_health.push(health);
        }
    }

    /// Compute and record health for a source from raw sync statistics.
    ///
    /// `errors` / `total_syncs` drive the `SourceStatus` heuristic.
    pub fn record_source_stats(
        &self,
        source_id: impl Into<String>,
        total_syncs: u32,
        errors: u32,
        channel_count: u32,
        epg_coverage_pct: f32,
        last_sync: Option<DateTime<Utc>>,
        next_sync: Option<DateTime<Utc>>,
        recent_errors: Vec<String>,
    ) {
        let status = SourceStatus::from_error_rate(errors, total_syncs);
        self.update_source_health(SourceHealth {
            source_id: source_id.into(),
            status,
            last_sync,
            next_sync,
            channel_count,
            epg_coverage_pct,
            recent_errors,
        });
    }

    /// Return all registered source health snapshots.
    pub fn source_health_all(&self) -> Vec<SourceHealth> {
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .source_health
            .clone()
    }

    /// Return health for a specific source, if registered.
    pub fn source_health(&self, source_id: &str) -> Option<SourceHealth> {
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .source_health
            .iter()
            .find(|h| h.source_id == source_id)
            .cloned()
    }

    // ── Event logging ────────────────────────────────────────────────────────

    /// Log a diagnostic event (rolling 1 000-entry ring buffer).
    pub fn log_event(&self, level: impl Into<String>, message: impl Into<String>) {
        let event = DiagEvent {
            timestamp: Utc::now(),
            level: level.into(),
            message: message.into(),
        };
        let mut guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        if guard.events.len() >= MAX_EVENTS {
            guard.events.pop_front();
        }
        guard.events.push_back(event);
    }

    /// Return recent events (up to last 24 h window).
    pub fn recent_events(&self) -> Vec<DiagEvent> {
        let guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        let cutoff = Utc::now() - chrono::Duration::hours(24);
        guard
            .events
            .iter()
            .filter(|e| e.timestamp >= cutoff)
            .cloned()
            .collect()
    }

    // ── Export ───────────────────────────────────────────────────────────────

    /// Export a redacted JSON diagnostic log.
    ///
    /// - Passwords (keys containing `password`, `pass`, `secret`, `token`,
    ///   `key`, `credential`) → `[REDACTED]`
    /// - Email addresses in string values → SHA-256 hex hash
    pub fn export_diagnostic_log(&self) -> String {
        let guard = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        let cutoff = Utc::now() - chrono::Duration::hours(24);

        let events: Vec<&DiagEvent> = guard
            .events
            .iter()
            .filter(|e| e.timestamp >= cutoff)
            .collect();

        let payload = serde_json::json!({
            "exported_at": Utc::now().to_rfc3339(),
            "system": guard.system_info,
            "sources": guard.source_health,
            "events": events,
        });

        let raw = serde_json::to_string_pretty(&payload).unwrap_or_default();
        redact(raw)
    }
}

// ── Redaction helpers ─────────────────────────────────────────────────────────

static SENSITIVE_KEYS: &[&str] = &["password", "pass", "secret", "token", "key", "credential"];

static EMAIL_RE: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();

fn email_regex() -> &'static regex::Regex {
    EMAIL_RE.get_or_init(|| {
        regex::Regex::new(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}").unwrap()
    })
}

fn hash_email(email: &str) -> String {
    let mut h = Sha256::new();
    h.update(email.as_bytes());
    format!("[email:{}]", hex_encode(&h.finalize()))
}

/// Walk JSON text and redact sensitive keys / email values.
///
/// This operates on the serialised string rather than the value tree
/// to avoid a second serde round-trip and keep the function cheap.
fn redact(mut json: String) -> String {
    // Redact values for sensitive keys: "key": "value" → "key": "[REDACTED]"
    for sensitive in SENSITIVE_KEYS {
        // Match: "key": "any-value"  (non-greedy)
        let pattern = format!(r#""[^"]*{}[^"]*"\s*:\s*"[^"]*""#, sensitive);
        if let Ok(re) = regex::Regex::new(&pattern) {
            json = re
                .replace_all(&json, |caps: &regex::Captures| {
                    let full = &caps[0];
                    // Keep the key part, replace value.
                    if let Some(colon_pos) = full.find(':') {
                        let key_part = &full[..colon_pos + 1];
                        format!(r#"{} "[REDACTED]""#, key_part)
                    } else {
                        full.to_string()
                    }
                })
                .to_string();
        }
    }

    // Hash email addresses in string values.
    let re = email_regex();
    json = re
        .replace_all(&json, |caps: &regex::Captures| hash_email(&caps[0]))
        .to_string();

    json
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn make_service() -> DiagnosticsService {
        DiagnosticsService::new(SystemInfo {
            app_version: "0.1.0".into(),
            platform: "desktop".into(),
            os: "linux".into(),
            available_storage_bytes: Some(10_000_000),
            network_type: "ethernet".into(),
        })
    }

    #[test]
    fn test_system_info_roundtrip() {
        let svc = make_service();
        let info = svc.system_info();
        assert_eq!(info.app_version, "0.1.0");
        assert_eq!(info.platform, "desktop");
    }

    #[test]
    fn test_source_health_added_and_retrieved() {
        let svc = make_service();
        svc.record_source_stats("src-1", 10, 0, 500, 0.9, None, None, vec![]);
        let h = svc.source_health("src-1").unwrap();
        assert_eq!(h.status, SourceStatus::Healthy);
        assert_eq!(h.channel_count, 500);
    }

    #[test]
    fn test_source_status_degraded() {
        let svc = make_service();
        svc.record_source_stats("src-2", 10, 3, 100, 0.5, None, None, vec![]);
        let h = svc.source_health("src-2").unwrap();
        assert_eq!(h.status, SourceStatus::Degraded);
    }

    #[test]
    fn test_source_status_offline() {
        let svc = make_service();
        svc.record_source_stats("src-3", 4, 4, 0, 0.0, None, None, vec![]);
        let h = svc.source_health("src-3").unwrap();
        assert_eq!(h.status, SourceStatus::Offline);
    }

    #[test]
    fn test_source_health_updated_in_place() {
        let svc = make_service();
        svc.record_source_stats("src-1", 10, 0, 200, 0.8, None, None, vec![]);
        svc.record_source_stats("src-1", 10, 6, 180, 0.7, None, None, vec![]);
        let all = svc.source_health_all();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].status, SourceStatus::Offline);
    }

    #[test]
    fn test_log_event_and_retrieve() {
        let svc = make_service();
        svc.log_event("INFO", "sync started");
        let events = svc.recent_events();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].message, "sync started");
    }

    #[test]
    fn test_ring_buffer_caps_at_max() {
        let svc = make_service();
        for i in 0..=MAX_EVENTS + 10 {
            svc.log_event("DEBUG", format!("event {i}"));
        }
        let guard = svc.inner.lock().unwrap();
        assert_eq!(guard.events.len(), MAX_EVENTS);
    }

    #[test]
    fn test_export_log_is_valid_json() {
        let svc = make_service();
        svc.log_event("INFO", "test");
        let log = svc.export_diagnostic_log();
        assert!(serde_json::from_str::<serde_json::Value>(&log).is_ok());
    }

    #[test]
    fn test_export_redacts_password_field() {
        let json = r#"{"password": "s3cr3t", "user": "alice"}"#;
        let redacted = redact(json.to_string());
        assert!(!redacted.contains("s3cr3t"));
        assert!(redacted.contains("[REDACTED]"));
    }

    #[test]
    fn test_export_hashes_email() {
        let json = r#"{"contact": "user@example.com"}"#;
        let redacted = redact(json.to_string());
        assert!(!redacted.contains("user@example.com"));
        assert!(redacted.contains("[email:"));
    }

    #[test]
    fn test_source_status_healthy_zero_syncs() {
        assert_eq!(SourceStatus::from_error_rate(0, 0), SourceStatus::Healthy);
    }

    #[test]
    fn test_source_status_healthy_no_errors() {
        assert_eq!(SourceStatus::from_error_rate(0, 10), SourceStatus::Healthy);
    }
}
