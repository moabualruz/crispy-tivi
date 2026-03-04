//! Channel source-access filtering algorithm.
//!
//! Ports `filterBySourceAccess` from Dart
//! `playlist_sync_helpers.dart`. Accepts JSON arrays
//! for interop via the FFI JSON bridge.

use serde_json::Value;
use std::collections::HashSet;

/// Filter channels to those accessible by the current
/// profile.
///
/// - If `is_admin` is `true`, returns all channels
///   unchanged (admins have full access).
/// - Otherwise, keeps only channels whose `source_id`
///   is in `accessible_source_ids_json`. Channels with
///   a null/missing `source_id` are **excluded** (no
///   legacy pass-through — Dart had it, Rust is
///   stricter; callers must ensure source_id is set).
///
/// Both inputs are JSON arrays. Returns a JSON array.
pub fn filter_channels_by_source(
    channels_json: &str,
    accessible_source_ids_json: &str,
    is_admin: bool,
) -> String {
    // Admin short-circuit — return input unchanged.
    if is_admin {
        return channels_json.to_string();
    }

    // Parse accessible source IDs into a set.
    let accessible: HashSet<String> =
        match serde_json::from_str::<Vec<String>>(accessible_source_ids_json) {
            Ok(ids) => ids.into_iter().collect(),
            Err(_) => return "[]".to_string(),
        };

    // Parse channels array.
    let channels: Vec<Value> = match serde_json::from_str(channels_json) {
        Ok(v) => v,
        Err(_) => return "[]".to_string(),
    };

    // Filter.
    let filtered: Vec<&Value> = channels
        .iter()
        .filter(|ch| {
            ch.get("source_id")
                .and_then(|v| v.as_str())
                .is_some_and(|sid| accessible.contains(sid))
        })
        .collect();

    serde_json::to_string(&filtered).unwrap_or_else(|_| "[]".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn make_channel(id: &str, source_id: Option<&str>) -> Value {
        let mut ch = json!({
            "id": id,
            "name": format!("Channel {id}"),
            "stream_url": format!("http://x/{id}"),
        });
        if let Some(sid) = source_id {
            ch["source_id"] = json!(sid);
        }
        ch
    }

    // ── admin bypass ───────────────────────────────

    #[test]
    fn admin_gets_all_channels() {
        let channels = json!([make_channel("a", Some("s1"))]);
        let sources = json!(["s2"]);
        let result = filter_channels_by_source(&channels.to_string(), &sources.to_string(), true);
        let parsed: Vec<Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 1);
    }

    // ── non-admin filtering ────────────────────────

    #[test]
    fn non_admin_with_matching_sources() {
        let channels = json!([
            make_channel("a", Some("s1")),
            make_channel("b", Some("s2")),
            make_channel("c", Some("s1")),
        ]);
        let sources = json!(["s1"]);
        let result = filter_channels_by_source(&channels.to_string(), &sources.to_string(), false);
        let parsed: Vec<Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0]["id"], "a");
        assert_eq!(parsed[1]["id"], "c");
    }

    #[test]
    fn non_admin_with_no_matching_sources() {
        let channels = json!([make_channel("a", Some("s1")), make_channel("b", Some("s2")),]);
        let sources = json!(["s3"]);
        let result = filter_channels_by_source(&channels.to_string(), &sources.to_string(), false);
        let parsed: Vec<Value> = serde_json::from_str(&result).unwrap();
        assert!(parsed.is_empty());
    }

    // ── empty inputs ───────────────────────────────

    #[test]
    fn empty_channel_list() {
        let result = filter_channels_by_source("[]", r#"["s1"]"#, false);
        let parsed: Vec<Value> = serde_json::from_str(&result).unwrap();
        assert!(parsed.is_empty());
    }

    #[test]
    fn empty_source_list_non_admin_gets_nothing() {
        let channels = json!([make_channel("a", Some("s1")),]);
        let result = filter_channels_by_source(&channels.to_string(), "[]", false);
        let parsed: Vec<Value> = serde_json::from_str(&result).unwrap();
        assert!(parsed.is_empty());
    }

    // ── null / missing source_id ───────────────────

    #[test]
    fn channel_with_null_source_id_excluded() {
        let channels = json!([make_channel("a", None), make_channel("b", Some("s1")),]);
        let sources = json!(["s1"]);
        let result = filter_channels_by_source(&channels.to_string(), &sources.to_string(), false);
        let parsed: Vec<Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 1);
        assert_eq!(parsed[0]["id"], "b");
    }

    // ── multiple sources, partial match ────────────

    #[test]
    fn multiple_sources_partial_match() {
        let channels = json!([
            make_channel("a", Some("s1")),
            make_channel("b", Some("s2")),
            make_channel("c", Some("s3")),
            make_channel("d", Some("s4")),
        ]);
        let sources = json!(["s2", "s4"]);
        let result = filter_channels_by_source(&channels.to_string(), &sources.to_string(), false);
        let parsed: Vec<Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0]["id"], "b");
        assert_eq!(parsed[1]["id"], "d");
    }

    // ── malformed JSON ─────────────────────────────

    #[test]
    fn malformed_json_returns_empty() {
        let result = filter_channels_by_source("not json", "[]", false);
        assert_eq!(result, "[]");

        let result = filter_channels_by_source("[]", "not json", false);
        assert_eq!(result, "[]");
    }
}
