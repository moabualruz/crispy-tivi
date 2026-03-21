//! EPG multi-source merge logic.
//!
//! Merges programme guides from multiple sources with priority ordering:
//! - Higher-priority source wins for overlapping time slots.
//! - Gaps in higher-priority sources are filled from lower-priority ones.

use serde::{Deserialize, Serialize};

use crate::models::EpgEntry;

// ── Input types ───────────────────────────────────────────

/// A single EPG source with an ordered list of programmes for one channel.
///
/// Lower `priority` value = higher importance (0 = highest priority).
#[derive(Debug, Clone)]
pub struct EpgSource {
    /// Source identifier (e.g. URL or name).
    pub source_id: String,
    /// Priority: 0 is highest. Higher number = lower priority.
    pub priority: u32,
    /// All EPG entries from this source for a given channel.
    /// Need not be sorted — this function will sort them.
    pub entries: Vec<EpgEntry>,
}

// ── Output types ─────────────────────────────────────────

/// A merged EPG entry with provenance metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MergedEpgEntry {
    /// Underlying programme data.
    pub entry: EpgEntry,
    /// Which source this entry came from.
    pub source_id: String,
    /// Priority of the source (lower = higher priority).
    pub source_priority: u32,
}

// ── Merge logic ───────────────────────────────────────────

/// Merge EPG entries from multiple sources into a single, gap-free timeline.
///
/// Algorithm:
/// 1. Sort sources by priority ascending (0 = first to be considered).
/// 2. For each source (highest priority first), add entries that do not
///    overlap any already-committed entry.
/// 3. Return all committed entries sorted by `start_time`.
///
/// Overlap definition: an entry from a lower-priority source is skipped
/// if its `[start_time, end_time)` interval overlaps any committed entry.
/// Partial overlap is treated as a full overlap (entry is skipped entirely).
pub fn merge_epg(sources: &[EpgSource]) -> Vec<MergedEpgEntry> {
    // Sort sources: lowest priority number first (highest importance).
    let mut ordered: Vec<&EpgSource> = sources.iter().collect();
    ordered.sort_by_key(|s| s.priority);

    let mut committed: Vec<MergedEpgEntry> = Vec::new();

    for source in ordered {
        // Sort this source's entries by start time.
        let mut entries = source.entries.clone();
        entries.sort_by_key(|e| e.start_time);

        for entry in entries {
            if !overlaps_any(&entry, &committed) {
                committed.push(MergedEpgEntry {
                    entry,
                    source_id: source.source_id.clone(),
                    source_priority: source.priority,
                });
            }
        }
    }

    // Final sort by start time.
    committed.sort_by_key(|e| e.entry.start_time);
    committed
}

/// Returns `true` if `entry` overlaps any entry in `committed`.
fn overlaps_any(entry: &EpgEntry, committed: &[MergedEpgEntry]) -> bool {
    let start = entry.start_time;
    let end = entry.end_time;

    committed.iter().any(|c| {
        let cs = c.entry.start_time;
        let ce = c.entry.end_time;
        // Two intervals [a_start, a_end) and [b_start, b_end) overlap iff
        // a_start < b_end && b_start < a_end.
        start < ce && cs < end
    })
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::normalize::EPG_FORMAT;
    use chrono::NaiveDateTime;

    fn dt(s: &str) -> NaiveDateTime {
        NaiveDateTime::parse_from_str(s, EPG_FORMAT).unwrap()
    }

    fn entry(channel_id: &str, title: &str, start: &str, end: &str) -> EpgEntry {
        EpgEntry {
            channel_id: channel_id.to_string(),
            title: title.to_string(),
            start_time: dt(start),
            end_time: dt(end),
            ..EpgEntry::default()
        }
    }

    fn source(id: &str, priority: u32, entries: Vec<EpgEntry>) -> EpgSource {
        EpgSource {
            source_id: id.to_string(),
            priority,
            entries,
        }
    }

    // ── Basic merge ───────────────────────────────────────

    #[test]
    fn test_merge_single_source_returns_all_entries() {
        let src = source(
            "s1",
            0,
            vec![
                entry("ch1", "News", "2024-02-16 08:00:00", "2024-02-16 09:00:00"),
                entry("ch1", "Sport", "2024-02-16 09:00:00", "2024-02-16 10:00:00"),
            ],
        );
        let merged = merge_epg(&[src]);
        assert_eq!(merged.len(), 2);
        assert_eq!(merged[0].entry.title, "News");
        assert_eq!(merged[1].entry.title, "Sport");
    }

    #[test]
    fn test_merge_empty_sources() {
        let merged = merge_epg(&[]);
        assert!(merged.is_empty());
    }

    #[test]
    fn test_merge_empty_entries_in_source() {
        let src = source("s1", 0, vec![]);
        assert!(merge_epg(&[src]).is_empty());
    }

    // ── Priority: higher-priority wins overlapping slot ───

    #[test]
    fn test_high_priority_wins_overlap() {
        let high = source(
            "high",
            0,
            vec![entry(
                "ch1",
                "HD Show",
                "2024-02-16 20:00:00",
                "2024-02-16 21:00:00",
            )],
        );
        let low = source(
            "low",
            1,
            vec![entry(
                "ch1",
                "SD Show",
                "2024-02-16 20:00:00",
                "2024-02-16 21:00:00",
            )],
        );
        let merged = merge_epg(&[high, low]);
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].entry.title, "HD Show");
        assert_eq!(merged[0].source_id, "high");
    }

    #[test]
    fn test_low_priority_fills_gaps() {
        let high = source(
            "high",
            0,
            vec![
                entry("ch1", "Main", "2024-02-16 20:00:00", "2024-02-16 21:00:00"),
                // Gap: 21:00–22:00 missing in high-priority source
                entry("ch1", "Late", "2024-02-16 22:00:00", "2024-02-16 23:00:00"),
            ],
        );
        let low = source(
            "low",
            1,
            vec![
                entry(
                    "ch1",
                    "Filler",
                    "2024-02-16 21:00:00",
                    "2024-02-16 22:00:00",
                ),
                entry(
                    "ch1",
                    "Overlap",
                    "2024-02-16 20:00:00",
                    "2024-02-16 21:00:00",
                ), // should be skipped
            ],
        );
        let merged = merge_epg(&[high, low]);
        assert_eq!(merged.len(), 3);
        let titles: Vec<&str> = merged.iter().map(|e| e.entry.title.as_str()).collect();
        assert!(titles.contains(&"Main"));
        assert!(titles.contains(&"Filler"));
        assert!(titles.contains(&"Late"));
        assert!(!titles.contains(&"Overlap"));
    }

    // ── Ordering ──────────────────────────────────────────

    #[test]
    fn test_output_sorted_by_start_time() {
        let s1 = source(
            "s1",
            0,
            vec![
                entry("ch1", "C", "2024-02-16 22:00:00", "2024-02-16 23:00:00"),
                entry("ch1", "A", "2024-02-16 08:00:00", "2024-02-16 09:00:00"),
            ],
        );
        let s2 = source(
            "s2",
            1,
            vec![entry(
                "ch1",
                "B",
                "2024-02-16 10:00:00",
                "2024-02-16 11:00:00",
            )],
        );
        let merged = merge_epg(&[s1, s2]);
        assert_eq!(merged[0].entry.title, "A");
        assert_eq!(merged[1].entry.title, "B");
        assert_eq!(merged[2].entry.title, "C");
    }

    // ── Partial overlap skipped ───────────────────────────

    #[test]
    fn test_partial_overlap_entry_skipped() {
        // high-priority: 20:00–21:00
        // low-priority:  20:30–21:30  (partial overlap → skipped entirely)
        let high = source(
            "high",
            0,
            vec![entry(
                "ch1",
                "Prime",
                "2024-02-16 20:00:00",
                "2024-02-16 21:00:00",
            )],
        );
        let low = source(
            "low",
            1,
            vec![entry(
                "ch1",
                "Partial",
                "2024-02-16 20:30:00",
                "2024-02-16 21:30:00",
            )],
        );
        let merged = merge_epg(&[high, low]);
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].entry.title, "Prime");
    }

    // ── Provenance ────────────────────────────────────────

    #[test]
    fn test_provenance_source_id_preserved() {
        let src = source(
            "xmltv-main",
            0,
            vec![entry(
                "ch1",
                "Show",
                "2024-02-16 20:00:00",
                "2024-02-16 21:00:00",
            )],
        );
        let merged = merge_epg(&[src]);
        assert_eq!(merged[0].source_id, "xmltv-main");
        assert_eq!(merged[0].source_priority, 0);
    }

    #[test]
    fn test_source_order_does_not_matter_priority_does() {
        // Pass low-priority source first in slice — priority field should still win.
        let low = source(
            "low",
            1,
            vec![entry(
                "ch1",
                "Low Show",
                "2024-02-16 20:00:00",
                "2024-02-16 21:00:00",
            )],
        );
        let high = source(
            "high",
            0,
            vec![entry(
                "ch1",
                "High Show",
                "2024-02-16 20:00:00",
                "2024-02-16 21:00:00",
            )],
        );
        // Low source is passed first in the slice.
        let merged = merge_epg(&[low, high]);
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].source_id, "high");
    }
}
