//! Playlist entry sorting.
//!
//! Sort entries by name, number, group, or resolution.
//! Supports multi-criteria sorting (primary, secondary, etc.).

use std::cmp::Ordering;

use crispy_iptv_types::PlaylistEntry;

use crate::resolution::detect_resolution;

/// Criteria for sorting playlist entries.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SortCriteria {
    /// Alphabetical by display name.
    Name,
    /// Numeric by channel number (`tvg_chno`).
    Number,
    /// Alphabetical by group title.
    Group,
    /// By resolution tier (Unknown < SD < HD < FHD < UHD).
    Resolution,
    /// By `tvg_id` — numeric when parseable, string fallback.
    ///
    /// Faithfully ported from `iptvtools/models.py::__custom_sort` which
    /// strips non-digit characters and parses as integer, falling back to
    /// `sys.maxsize` for non-numeric IDs.
    TvgId,
}

/// Sort direction for a single criterion.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SortDirection {
    /// Ascending order (A→Z, 0→9, low→high).
    Ascending,
    /// Descending order (Z→A, 9→0, high→low).
    Descending,
}

/// A sort key combining a criterion with a direction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SortKey {
    /// Which field to sort by.
    pub criteria: SortCriteria,
    /// Ascending or descending.
    pub direction: SortDirection,
}

/// Sort entries in place by the given criteria chain.
///
/// The first criterion is primary, the second is the tiebreaker, and so on.
/// All criteria use ascending direction.
pub fn sort_entries(entries: &mut [PlaylistEntry], criteria: &[SortCriteria]) {
    if criteria.is_empty() {
        return;
    }
    entries.sort_by(|a, b| compare_entries(a, b, criteria));
}

/// Sort entries in place with multiple keys, each having an independent direction.
///
/// The first key is primary, the second is the tiebreaker, and so on.
pub fn sort_entries_multi(entries: &mut [PlaylistEntry], keys: &[SortKey]) {
    if keys.is_empty() {
        return;
    }
    entries.sort_by(|a, b| {
        for key in keys {
            let ord = compare_by(a, b, key.criteria);
            let ord = match key.direction {
                SortDirection::Ascending => ord,
                SortDirection::Descending => ord.reverse(),
            };
            if ord != Ordering::Equal {
                return ord;
            }
        }
        Ordering::Equal
    });
}

/// Compare two entries by a chain of criteria.
fn compare_entries(a: &PlaylistEntry, b: &PlaylistEntry, criteria: &[SortCriteria]) -> Ordering {
    for criterion in criteria {
        let ord = compare_by(a, b, *criterion);
        if ord != Ordering::Equal {
            return ord;
        }
    }
    Ordering::Equal
}

/// Compare two entries by a single criterion.
fn compare_by(a: &PlaylistEntry, b: &PlaylistEntry, criterion: SortCriteria) -> Ordering {
    match criterion {
        SortCriteria::Name => {
            let a_name = a.name.as_deref().unwrap_or("");
            let b_name = b.name.as_deref().unwrap_or("");
            a_name.to_lowercase().cmp(&b_name.to_lowercase())
        }
        SortCriteria::Number => {
            let a_num = parse_chno(a.tvg_chno.as_deref());
            let b_num = parse_chno(b.tvg_chno.as_deref());
            a_num.cmp(&b_num)
        }
        SortCriteria::Group => {
            let a_group = a.group_title.as_deref().unwrap_or("");
            let b_group = b.group_title.as_deref().unwrap_or("");
            a_group.to_lowercase().cmp(&b_group.to_lowercase())
        }
        SortCriteria::Resolution => {
            let a_res = detect_resolution(
                a.name.as_deref().unwrap_or(""),
                a.url.as_deref().unwrap_or(""),
                &a.extras,
            );
            let b_res = detect_resolution(
                b.name.as_deref().unwrap_or(""),
                b.url.as_deref().unwrap_or(""),
                &b.extras,
            );
            a_res.cmp(&b_res)
        }
        SortCriteria::TvgId => {
            let a_id = parse_tvg_id_numeric(a.tvg_id.as_deref());
            let b_id = parse_tvg_id_numeric(b.tvg_id.as_deref());
            match (a_id, b_id) {
                (Some(an), Some(bn)) => an.cmp(&bn),
                (Some(_), None) => Ordering::Less,
                (None, Some(_)) => Ordering::Greater,
                (None, None) => {
                    let a_str = a.tvg_id.as_deref().unwrap_or("");
                    let b_str = b.tvg_id.as_deref().unwrap_or("");
                    a_str.to_lowercase().cmp(&b_str.to_lowercase())
                }
            }
        }
    }
}

/// Parse a channel number string to a sortable integer.
/// Non-numeric values sort to `u64::MAX` (end of list).
fn parse_chno(chno: Option<&str>) -> u64 {
    chno.and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(u64::MAX)
}

/// Parse a `tvg_id` as a numeric value for sorting.
///
/// Strips all non-digit characters and parses the remainder as `u64`.
/// Returns `None` if no digits are present, mirroring the Python logic
/// from `iptvtools/models.py::__custom_sort` which uses `re.sub(r"\D", "")`.
fn parse_tvg_id_numeric(id: Option<&str>) -> Option<u64> {
    let id = id?;
    let digits: String = id.chars().filter(char::is_ascii_digit).collect();
    if digits.is_empty() {
        return None;
    }
    digits.parse::<u64>().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_entry_with_chno(name: &str, chno: &str, group: &str) -> PlaylistEntry {
        PlaylistEntry {
            name: Some(name.to_string()),
            tvg_chno: if chno.is_empty() {
                None
            } else {
                Some(chno.to_string())
            },
            group_title: Some(group.to_string()),
            ..Default::default()
        }
    }

    #[test]
    fn sort_by_name_alphabetical() {
        let mut entries = vec![
            make_entry_with_chno("CNN", "", ""),
            make_entry_with_chno("ABC", "", ""),
            make_entry_with_chno("BBC", "", ""),
        ];
        sort_entries(&mut entries, &[SortCriteria::Name]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "ABC");
        assert_eq!(entries[1].name.as_deref().unwrap(), "BBC");
        assert_eq!(entries[2].name.as_deref().unwrap(), "CNN");
    }

    #[test]
    fn sort_by_name_case_insensitive() {
        let mut entries = vec![
            make_entry_with_chno("cnn", "", ""),
            make_entry_with_chno("ABC", "", ""),
            make_entry_with_chno("bbc", "", ""),
        ];
        sort_entries(&mut entries, &[SortCriteria::Name]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "ABC");
        assert_eq!(entries[1].name.as_deref().unwrap(), "bbc");
        assert_eq!(entries[2].name.as_deref().unwrap(), "cnn");
    }

    #[test]
    fn sort_by_number_numeric() {
        let mut entries = vec![
            make_entry_with_chno("C", "10", ""),
            make_entry_with_chno("A", "1", ""),
            make_entry_with_chno("B", "3", ""),
        ];
        sort_entries(&mut entries, &[SortCriteria::Number]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "A");
        assert_eq!(entries[1].name.as_deref().unwrap(), "B");
        assert_eq!(entries[2].name.as_deref().unwrap(), "C");
    }

    #[test]
    fn sort_by_number_missing_goes_last() {
        let mut entries = vec![
            make_entry_with_chno("NoNum", "", ""),
            make_entry_with_chno("First", "1", ""),
        ];
        sort_entries(&mut entries, &[SortCriteria::Number]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "First");
        assert_eq!(entries[1].name.as_deref().unwrap(), "NoNum");
    }

    #[test]
    fn sort_by_group() {
        let mut entries = vec![
            make_entry_with_chno("A", "", "Sports"),
            make_entry_with_chno("B", "", "Movies"),
            make_entry_with_chno("C", "", "News"),
        ];
        sort_entries(&mut entries, &[SortCriteria::Group]);
        assert_eq!(entries[0].group_title.as_deref().unwrap(), "Movies");
        assert_eq!(entries[1].group_title.as_deref().unwrap(), "News");
        assert_eq!(entries[2].group_title.as_deref().unwrap(), "Sports");
    }

    #[test]
    fn sort_by_resolution() {
        let mut entries = vec![
            PlaylistEntry {
                name: Some("HD Channel".into()),
                ..Default::default()
            },
            PlaylistEntry {
                name: Some("4K Channel".into()),
                ..Default::default()
            },
            PlaylistEntry {
                name: Some("SD Channel".into()),
                ..Default::default()
            },
        ];
        sort_entries(&mut entries, &[SortCriteria::Resolution]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "SD Channel");
        assert_eq!(entries[1].name.as_deref().unwrap(), "HD Channel");
        assert_eq!(entries[2].name.as_deref().unwrap(), "4K Channel");
    }

    #[test]
    fn sort_multi_criteria() {
        let mut entries = vec![
            make_entry_with_chno("B", "", "Sports"),
            make_entry_with_chno("A", "", "Sports"),
            make_entry_with_chno("C", "", "News"),
        ];
        sort_entries(&mut entries, &[SortCriteria::Group, SortCriteria::Name]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "C"); // News first
        assert_eq!(entries[1].name.as_deref().unwrap(), "A"); // Sports, A before B
        assert_eq!(entries[2].name.as_deref().unwrap(), "B");
    }

    #[test]
    fn sort_empty_criteria_is_noop() {
        let mut entries = vec![
            make_entry_with_chno("B", "", ""),
            make_entry_with_chno("A", "", ""),
        ];
        sort_entries(&mut entries, &[]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "B");
    }

    fn make_entry_with_tvg_id(name: &str, tvg_id: &str, group: &str) -> PlaylistEntry {
        PlaylistEntry {
            name: Some(name.to_string()),
            tvg_id: if tvg_id.is_empty() {
                None
            } else {
                Some(tvg_id.to_string())
            },
            group_title: Some(group.to_string()),
            ..Default::default()
        }
    }

    #[test]
    fn sort_by_tvg_id_numeric() {
        let mut entries = vec![
            make_entry_with_tvg_id("C", "ch100", ""),
            make_entry_with_tvg_id("A", "ch3", ""),
            make_entry_with_tvg_id("B", "ch20", ""),
        ];
        sort_entries(&mut entries, &[SortCriteria::TvgId]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "A"); // ch3 → 3
        assert_eq!(entries[1].name.as_deref().unwrap(), "B"); // ch20 → 20
        assert_eq!(entries[2].name.as_deref().unwrap(), "C"); // ch100 → 100
    }

    #[test]
    fn sort_by_tvg_id_string_fallback() {
        let mut entries = vec![
            make_entry_with_tvg_id("B", "bbc.uk", ""),
            make_entry_with_tvg_id("A", "abc.us", ""),
        ];
        sort_entries(&mut entries, &[SortCriteria::TvgId]);
        assert_eq!(entries[0].name.as_deref().unwrap(), "A"); // abc < bbc
        assert_eq!(entries[1].name.as_deref().unwrap(), "B");
    }

    #[test]
    fn sort_with_descending_direction() {
        let mut entries = vec![
            make_entry_with_chno("A", "", ""),
            make_entry_with_chno("C", "", ""),
            make_entry_with_chno("B", "", ""),
        ];
        sort_entries_multi(
            &mut entries,
            &[SortKey {
                criteria: SortCriteria::Name,
                direction: SortDirection::Descending,
            }],
        );
        assert_eq!(entries[0].name.as_deref().unwrap(), "C");
        assert_eq!(entries[1].name.as_deref().unwrap(), "B");
        assert_eq!(entries[2].name.as_deref().unwrap(), "A");
    }

    #[test]
    fn sort_with_mixed_directions() {
        let mut entries = vec![
            PlaylistEntry {
                name: Some("CNN HD".into()),
                group_title: Some("News".into()),
                ..Default::default()
            },
            PlaylistEntry {
                name: Some("BBC 4K".into()),
                group_title: Some("News".into()),
                ..Default::default()
            },
            PlaylistEntry {
                name: Some("Sky SD".into()),
                group_title: Some("Sports".into()),
                ..Default::default()
            },
        ];
        sort_entries_multi(
            &mut entries,
            &[
                SortKey {
                    criteria: SortCriteria::Group,
                    direction: SortDirection::Ascending,
                },
                SortKey {
                    criteria: SortCriteria::Resolution,
                    direction: SortDirection::Descending,
                },
            ],
        );
        // News group first (ascending), then within News: UHD (4K) before HD (descending).
        assert_eq!(entries[0].name.as_deref().unwrap(), "BBC 4K");
        assert_eq!(entries[1].name.as_deref().unwrap(), "CNN HD");
        assert_eq!(entries[2].name.as_deref().unwrap(), "Sky SD");
    }
}
