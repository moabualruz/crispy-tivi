//! Duplicate channel detection by normalized stream URL.
//!
//! Ports logic from Dart `duplicate_detection_service.dart`.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::models::Channel;

use super::normalize::normalize_url;

/// A group of channels that share the same normalized
/// stream URL.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DuplicateGroup {
    /// Normalized stream URL shared by all channels.
    pub stream_url: String,
    /// All channel IDs in this group.
    pub channel_ids: Vec<String>,
    /// First channel is considered preferred.
    pub preferred_id: String,
    /// Remaining channels (duplicates).
    pub duplicate_ids: Vec<String>,
}

/// Detect duplicate channels by normalized stream URL.
///
/// Returns groups of 2+ channels sharing the same URL.
/// The first channel encountered in `channels` order is
/// treated as the preferred one.
pub fn detect_duplicates(channels: &[Channel]) -> Vec<DuplicateGroup> {
    // Group channel IDs by normalized URL.
    // Preserve insertion order with Vec of pairs.
    let mut url_groups: HashMap<String, Vec<String>> = HashMap::new();
    let mut order: Vec<String> = Vec::new();

    for ch in channels {
        let norm = normalize_url(&ch.stream_url);
        let entry = url_groups.entry(norm.clone());
        if matches!(entry, std::collections::hash_map::Entry::Vacant(_)) {
            order.push(norm.clone());
        }
        entry.or_default().push(ch.id.clone());
    }

    // Build groups for URLs with 2+ channels.
    let mut groups = Vec::new();
    for url in &order {
        if let Some(ids) = url_groups.get(url)
            && ids.len() >= 2
        {
            groups.push(DuplicateGroup {
                stream_url: url.clone(),
                channel_ids: ids.clone(),
                preferred_id: ids[0].clone(),
                duplicate_ids: ids[1..].to_vec(),
            });
        }
    }

    groups
}

/// Collect all duplicate channel IDs (excluding preferred)
/// from a list of duplicate groups.
pub fn get_duplicate_ids(groups: &[DuplicateGroup]) -> Vec<String> {
    groups
        .iter()
        .flat_map(|g| g.duplicate_ids.iter().cloned())
        .collect()
}

/// Find the duplicate group containing a given channel ID.
///
/// Searches all `channel_ids` in every group. Returns
/// `None` if the channel is not in any group.
pub fn find_group_for_channel<'a>(
    groups: &'a [DuplicateGroup],
    channel_id: &str,
) -> Option<&'a DuplicateGroup> {
    groups
        .iter()
        .find(|g| g.channel_ids.iter().any(|id| id == channel_id))
}

/// Check if a channel ID appears as a duplicate in any
/// group (i.e., is in `duplicate_ids`, not `preferred_id`).
pub fn is_duplicate(groups: &[DuplicateGroup], channel_id: &str) -> bool {
    groups
        .iter()
        .any(|g| g.duplicate_ids.iter().any(|id| id == channel_id))
}

/// Get all duplicate IDs across all groups.
///
/// This is an alias for [`get_duplicate_ids`] but named
/// to match the task spec for discoverability.
pub fn get_all_duplicate_ids(groups: &[DuplicateGroup]) -> Vec<String> {
    get_duplicate_ids(groups)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_channel(id: &str, url: &str) -> Channel {
        Channel {
            id: id.to_string(),
            name: format!("Channel {id}"),
            stream_url: url.to_string(),
            number: None,
            channel_group: None,
            logo_url: None,
            tvg_id: None,
            tvg_name: None,
            is_favorite: false,
            user_agent: None,
            has_catchup: false,
            catchup_days: 0,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
        }
    }

    #[test]
    fn detects_exact_url_duplicates() {
        let channels = vec![
            make_channel("a", "http://example.com/stream1"),
            make_channel("b", "http://example.com/stream1"),
            make_channel("c", "http://example.com/stream2"),
        ];

        let groups = detect_duplicates(&channels);

        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].preferred_id, "a");
        assert_eq!(groups[0].duplicate_ids, vec!["b"]);
    }

    #[test]
    fn detects_normalized_url_duplicates() {
        let channels = vec![
            make_channel("a", "http://example.com/stream/"),
            make_channel("b", "http://example.com/stream?token=x"),
        ];

        let groups = detect_duplicates(&channels);

        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].channel_ids.len(), 2);
    }

    #[test]
    fn no_duplicates_returns_empty() {
        let channels = vec![
            make_channel("a", "http://example.com/s1"),
            make_channel("b", "http://example.com/s2"),
        ];

        let groups = detect_duplicates(&channels);

        assert!(groups.is_empty());
    }

    #[test]
    fn three_way_duplicate() {
        let channels = vec![
            make_channel("a", "http://ex.com/live"),
            make_channel("b", "http://ex.com/live/"),
            make_channel("c", "http://ex.com/live?k=v"),
        ];

        let groups = detect_duplicates(&channels);

        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].preferred_id, "a");
        assert_eq!(groups[0].duplicate_ids, vec!["b", "c"],);
    }

    #[test]
    fn get_duplicate_ids_collects_all() {
        let channels = vec![
            make_channel("a", "http://ex.com/1"),
            make_channel("b", "http://ex.com/1"),
            make_channel("c", "http://ex.com/2"),
            make_channel("d", "http://ex.com/2"),
        ];

        let groups = detect_duplicates(&channels);
        let ids = get_duplicate_ids(&groups);

        assert_eq!(ids.len(), 2);
        assert!(ids.contains(&"b".to_string()));
        assert!(ids.contains(&"d".to_string()));
    }

    // ── find_group_for_channel ───────────────────

    #[test]
    fn find_group_for_channel_found() {
        let channels = vec![
            make_channel("a", "http://ex.com/s1"),
            make_channel("b", "http://ex.com/s1"),
            make_channel("c", "http://ex.com/s2"),
        ];
        let groups = detect_duplicates(&channels);

        let group = find_group_for_channel(&groups, "b");
        assert!(group.is_some());
        assert_eq!(group.unwrap().preferred_id, "a");
    }

    #[test]
    fn find_group_for_channel_not_found() {
        let channels = vec![
            make_channel("a", "http://ex.com/s1"),
            make_channel("b", "http://ex.com/s1"),
        ];
        let groups = detect_duplicates(&channels);

        let group = find_group_for_channel(&groups, "zzz");
        assert!(group.is_none());
    }

    // ── is_duplicate ─────────────────────────────

    #[test]
    fn is_duplicate_true_for_duplicate() {
        let channels = vec![
            make_channel("a", "http://ex.com/s1"),
            make_channel("b", "http://ex.com/s1"),
        ];
        let groups = detect_duplicates(&channels);

        assert!(is_duplicate(&groups, "b"));
    }

    #[test]
    fn is_duplicate_false_for_preferred() {
        let channels = vec![
            make_channel("a", "http://ex.com/s1"),
            make_channel("b", "http://ex.com/s1"),
        ];
        let groups = detect_duplicates(&channels);

        assert!(!is_duplicate(&groups, "a"));
    }

    // ── get_all_duplicate_ids ────────────────────

    #[test]
    fn get_all_duplicate_ids_multiple_groups() {
        let channels = vec![
            make_channel("a", "http://ex.com/1"),
            make_channel("b", "http://ex.com/1"),
            make_channel("c", "http://ex.com/2"),
            make_channel("d", "http://ex.com/2"),
            make_channel("e", "http://ex.com/2"),
        ];
        let groups = detect_duplicates(&channels);
        let ids = get_all_duplicate_ids(&groups);

        assert_eq!(ids.len(), 3);
        assert!(ids.contains(&"b".to_string()));
        assert!(ids.contains(&"d".to_string()));
        assert!(ids.contains(&"e".to_string()));
    }

    // ── Edge cases ─────────────────────────────────

    #[test]
    fn empty_input_returns_no_groups() {
        let channels: Vec<Channel> = vec![];
        let groups = detect_duplicates(&channels);

        assert!(groups.is_empty());
        assert!(get_duplicate_ids(&groups).is_empty());
    }

    #[test]
    fn all_unique_urls_returns_no_groups() {
        let channels = vec![
            make_channel("a", "http://ex.com/stream1"),
            make_channel("b", "http://ex.com/stream2"),
            make_channel("c", "http://ex.com/stream3"),
            make_channel("d", "http://ex.com/stream4"),
            make_channel("e", "http://ex.com/stream5"),
        ];
        let groups = detect_duplicates(&channels);

        assert!(groups.is_empty());
        assert!(!is_duplicate(&groups, "a"));
        assert!(find_group_for_channel(&groups, "a").is_none());
    }

    #[test]
    fn very_long_urls_still_detect_duplicates() {
        let long_path = "a".repeat(2000);
        let url = format!("http://example.com/{long_path}");
        let channels = vec![
            make_channel("a", &url),
            make_channel("b", &format!("{url}?token=xyz")),
        ];
        let groups = detect_duplicates(&channels);

        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].preferred_id, "a");
        assert_eq!(groups[0].duplicate_ids, vec!["b"]);
    }

    #[test]
    fn identical_urls_different_names_are_duplicates() {
        let channels = vec![
            Channel {
                id: "a".to_string(),
                name: "BBC One HD".to_string(),
                stream_url: "http://ex.com/bbc1".to_string(),
                number: None,
                channel_group: Some("UK".to_string()),
                logo_url: None,
                tvg_id: None,
                tvg_name: None,
                is_favorite: false,
                user_agent: None,
                has_catchup: false,
                catchup_days: 0,
                catchup_type: None,
                catchup_source: None,
                resolution: Some("HD".to_string()),
                source_id: None,
                added_at: None,
                updated_at: None,
            },
            Channel {
                id: "b".to_string(),
                name: "BBC 1".to_string(),
                stream_url: "http://ex.com/bbc1".to_string(),
                number: None,
                channel_group: Some("Entertainment".to_string()),
                logo_url: None,
                tvg_id: None,
                tvg_name: None,
                is_favorite: true,
                user_agent: None,
                has_catchup: false,
                catchup_days: 0,
                catchup_type: None,
                catchup_source: None,
                resolution: Some("SD".to_string()),
                source_id: None,
                added_at: None,
                updated_at: None,
            },
        ];

        let groups = detect_duplicates(&channels);

        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].preferred_id, "a");
        assert!(is_duplicate(&groups, "b"));
        assert!(!is_duplicate(&groups, "a"));
    }

    #[test]
    fn single_channel_returns_no_duplicates() {
        let channels = vec![make_channel("only", "http://ex.com/solo")];
        let groups = detect_duplicates(&channels);

        assert!(groups.is_empty());
        assert!(!is_duplicate(&groups, "only"));
        assert!(get_duplicate_ids(&groups).is_empty());
        assert!(find_group_for_channel(&groups, "only").is_none());
    }
}
