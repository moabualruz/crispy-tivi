//! Playlist entry deduplication.
//!
//! Remove duplicate entries from a playlist based on configurable
//! key strategies: URL, name, tvg_id, or a custom key function.

use std::collections::HashSet;

use crispy_iptv_types::PlaylistEntry;

/// Strategy for determining duplicate entries.
pub enum DeduplicateStrategy {
    /// Same URL = duplicate.
    ByUrl,
    /// Same name = duplicate.
    ByName,
    /// Same tvg_id = duplicate.
    ByTvgId,
    /// Custom key function — entries with the same key are duplicates.
    Custom(fn(&PlaylistEntry) -> String),
}

/// Deduplicate entries using the given strategy.
///
/// Preserves the first occurrence of each unique key. Order is preserved.
pub fn deduplicate(
    entries: &[PlaylistEntry],
    strategy: &DeduplicateStrategy,
) -> Vec<PlaylistEntry> {
    let mut seen = HashSet::new();
    entries
        .iter()
        .filter(|entry| {
            let key = extract_key(entry, strategy);
            // Skip entries with empty keys (no URL, no name, etc.).
            if key.is_empty() {
                return true;
            }
            seen.insert(key)
        })
        .cloned()
        .collect()
}

/// Extract the deduplication key from an entry based on the strategy.
fn extract_key(entry: &PlaylistEntry, strategy: &DeduplicateStrategy) -> String {
    match strategy {
        DeduplicateStrategy::ByUrl => entry.url.as_deref().unwrap_or("").to_lowercase(),
        DeduplicateStrategy::ByName => entry.name.as_deref().unwrap_or("").to_lowercase(),
        DeduplicateStrategy::ByTvgId => entry.tvg_id.as_deref().unwrap_or("").to_lowercase(),
        DeduplicateStrategy::Custom(f) => f(entry),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_entry(name: &str, url: &str, tvg_id: &str) -> PlaylistEntry {
        PlaylistEntry {
            name: Some(name.to_string()),
            url: Some(url.to_string()),
            tvg_id: if tvg_id.is_empty() {
                None
            } else {
                Some(tvg_id.to_string())
            },
            ..Default::default()
        }
    }

    #[test]
    fn dedup_by_url_removes_exact_dupes() {
        let entries = vec![
            make_entry("BBC One", "http://a.com/1", ""),
            make_entry("BBC One (copy)", "http://a.com/1", ""),
            make_entry("CNN", "http://a.com/2", ""),
        ];
        let result = deduplicate(&entries, &DeduplicateStrategy::ByUrl);
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].name.as_deref().unwrap(), "BBC One");
        assert_eq!(result[1].name.as_deref().unwrap(), "CNN");
    }

    #[test]
    fn dedup_by_url_case_insensitive() {
        let entries = vec![
            make_entry("A", "HTTP://A.COM/1", ""),
            make_entry("B", "http://a.com/1", ""),
        ];
        let result = deduplicate(&entries, &DeduplicateStrategy::ByUrl);
        assert_eq!(result.len(), 1);
    }

    #[test]
    fn dedup_by_name_removes_same_name() {
        let entries = vec![
            make_entry("BBC One", "http://a.com/1", ""),
            make_entry("BBC One", "http://a.com/2", ""),
            make_entry("CNN", "http://a.com/3", ""),
        ];
        let result = deduplicate(&entries, &DeduplicateStrategy::ByName);
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].url.as_deref().unwrap(), "http://a.com/1");
    }

    #[test]
    fn dedup_by_tvg_id() {
        let entries = vec![
            make_entry("A", "http://a.com/1", "bbc.uk"),
            make_entry("B", "http://a.com/2", "bbc.uk"),
            make_entry("C", "http://a.com/3", "cnn.us"),
        ];
        let result = deduplicate(&entries, &DeduplicateStrategy::ByTvgId);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn dedup_custom_key() {
        let entries = vec![
            make_entry("A", "http://a.com/1", ""),
            make_entry("B", "http://a.com/2", ""),
            make_entry("C", "http://b.com/3", ""),
        ];
        // Custom key: extract host from URL.
        let result = deduplicate(
            &entries,
            &DeduplicateStrategy::Custom(|e| {
                let url = e.url.as_deref().unwrap_or("");
                url::Url::parse(url)
                    .ok()
                    .and_then(|u| u.host_str().map(|h| h.to_string()))
                    .unwrap_or_default()
            }),
        );
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn dedup_preserves_entries_with_empty_keys() {
        let entries = vec![make_entry("A", "", ""), make_entry("B", "", "")];
        // Both have empty URLs — both should be kept.
        let result = deduplicate(&entries, &DeduplicateStrategy::ByUrl);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn dedup_empty_input() {
        let result = deduplicate(&[], &DeduplicateStrategy::ByUrl);
        assert!(result.is_empty());
    }
}
