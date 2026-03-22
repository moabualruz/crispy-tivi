//! Playlist merging.
//!
//! Combine multiple entry lists into one, with optional deduplication.

use crispy_iptv_types::PlaylistEntry;

use crate::dedup::{DeduplicateStrategy, deduplicate};

/// Merge multiple entry lists into a single list.
///
/// Concatenates all sources in order. Duplicates (by URL) are removed,
/// keeping the first occurrence.
pub fn merge_entries(sources: &[Vec<PlaylistEntry>]) -> Vec<PlaylistEntry> {
    let combined: Vec<PlaylistEntry> = sources.iter().flat_map(|s| s.iter().cloned()).collect();
    deduplicate(&combined, &DeduplicateStrategy::ByUrl)
}

/// Merge multiple entry lists without deduplication.
///
/// Simply concatenates all sources in order.
pub fn merge_entries_raw(sources: &[Vec<PlaylistEntry>]) -> Vec<PlaylistEntry> {
    sources.iter().flat_map(|s| s.iter().cloned()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_entry(name: &str, url: &str) -> PlaylistEntry {
        PlaylistEntry {
            name: Some(name.to_string()),
            url: Some(url.to_string()),
            ..Default::default()
        }
    }

    #[test]
    fn merge_no_overlap() {
        let a = vec![make_entry("A", "http://a.com/1")];
        let b = vec![make_entry("B", "http://b.com/1")];
        let result = merge_entries(&[a, b]);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn merge_with_duplicates() {
        let a = vec![
            make_entry("A", "http://a.com/1"),
            make_entry("B", "http://a.com/2"),
        ];
        let b = vec![
            make_entry("A copy", "http://a.com/1"), // same URL as first
            make_entry("C", "http://c.com/1"),
        ];
        let result = merge_entries(&[a, b]);
        assert_eq!(result.len(), 3);
        // First occurrence kept.
        assert_eq!(result[0].name.as_deref().unwrap(), "A");
    }

    #[test]
    fn merge_empty_sources() {
        let result = merge_entries(&[]);
        assert!(result.is_empty());
    }

    #[test]
    fn merge_single_source() {
        let a = vec![make_entry("A", "http://a.com/1")];
        let result = merge_entries(&[a]);
        assert_eq!(result.len(), 1);
    }

    #[test]
    fn merge_raw_keeps_duplicates() {
        let a = vec![make_entry("A", "http://a.com/1")];
        let b = vec![make_entry("A copy", "http://a.com/1")];
        let result = merge_entries_raw(&[a, b]);
        assert_eq!(result.len(), 2);
    }
}
