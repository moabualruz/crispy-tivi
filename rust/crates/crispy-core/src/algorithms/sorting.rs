//! Channel sorting by number and name.
//!
//! Ports `_channelSort()` from Dart
//! `channel_repository_impl.dart`.

use crate::models::Channel;

/// Sort channels by number (ascending, nulls last) then
/// by name (ascending, case-insensitive).
///
/// Pre-computes lowercase name keys to avoid O(N log N)
/// allocations in sort comparisons.
pub fn sort_channels(channels: &mut [Channel]) {
    // Pre-compute lowercase keys once — O(N) allocations
    // instead of O(N log N).
    let keys: Vec<String> = channels.iter().map(|c| c.name.to_lowercase()).collect();

    // Sort indices using number + cached key.
    let mut indices: Vec<usize> = (0..channels.len()).collect();
    indices.sort_by(|&i, &j| {
        let a = &channels[i];
        let b = &channels[j];
        match (&a.number, &b.number) {
            (Some(na), Some(nb)) => {
                let cmp = na.cmp(nb);
                if cmp != std::cmp::Ordering::Equal {
                    return cmp;
                }
            }
            (Some(_), None) => return std::cmp::Ordering::Less,
            (None, Some(_)) => return std::cmp::Ordering::Greater,
            (None, None) => {}
        }
        keys[i].cmp(&keys[j])
    });

    // Reorder channels according to the sorted indices.
    let sorted: Vec<Channel> = indices.into_iter().map(|i| channels[i].clone()).collect();
    channels.clone_from_slice(&sorted);
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn ch(id: &str, name: &str, num: Option<i32>) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: String::new(),
            number: num,
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
    fn channels_with_numbers_sort_ascending() {
        let mut channels = vec![
            ch("c", "CNN", Some(3)),
            ch("a", "ABC", Some(1)),
            ch("b", "BBC", Some(2)),
        ];
        sort_channels(&mut channels);
        let ids: Vec<&str> = channels.iter().map(|c| c.id.as_str()).collect();
        assert_eq!(ids, vec!["a", "b", "c"]);
    }

    #[test]
    fn null_numbers_go_last() {
        let mut channels = vec![
            ch("x", "No Num", None),
            ch("a", "ABC", Some(1)),
            ch("y", "Also None", None),
        ];
        sort_channels(&mut channels);
        let ids: Vec<&str> = channels.iter().map(|c| c.id.as_str()).collect();
        assert_eq!(ids, vec!["a", "y", "x"]);
    }

    #[test]
    fn same_number_sorts_by_name() {
        let mut channels = vec![
            ch("z", "Zebra", Some(5)),
            ch("a", "Alpha", Some(5)),
            ch("m", "Mike", Some(5)),
        ];
        sort_channels(&mut channels);
        let names: Vec<&str> = channels.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, vec!["Alpha", "Mike", "Zebra"]);
    }

    #[test]
    fn all_nulls_sort_by_name_case_insensitive() {
        let mut channels = vec![
            ch("c", "charlie", None),
            ch("a", "Alpha", None),
            ch("b", "BRAVO", None),
        ];
        sort_channels(&mut channels);
        let names: Vec<&str> = channels.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, vec!["Alpha", "BRAVO", "charlie"]);
    }

    // ── Additional sorting tests ────────────────────

    #[test]
    fn sort_by_number_ascending() {
        let mut channels = vec![
            ch("d", "Delta", Some(10)),
            ch("a", "Alpha", Some(1)),
            ch("c", "Charlie", Some(7)),
            ch("b", "Bravo", Some(3)),
        ];
        sort_channels(&mut channels);
        let nums: Vec<Option<i32>> = channels.iter().map(|c| c.number).collect();
        assert_eq!(nums, vec![Some(1), Some(3), Some(7), Some(10)]);
    }

    #[test]
    fn sort_nulls_last() {
        // Channels without number come after all numbered ones.
        let mut channels = vec![
            ch("x", "Xray", None),
            ch("a", "Alpha", Some(5)),
            ch("y", "Yankee", None),
            ch("b", "Bravo", Some(2)),
        ];
        sort_channels(&mut channels);
        let ids: Vec<&str> = channels.iter().map(|c| c.id.as_str()).collect();
        assert_eq!(ids, vec!["b", "a", "x", "y"]);
    }

    #[test]
    fn sort_tiebreak_by_name() {
        // Same number → alphabetical by name.
        let mut channels = vec![
            ch("c", "Charlie", Some(3)),
            ch("a", "Alpha", Some(3)),
            ch("b", "Bravo", Some(3)),
        ];
        sort_channels(&mut channels);
        let names: Vec<&str> = channels.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, vec!["Alpha", "Bravo", "Charlie"]);
    }

    #[test]
    fn sort_case_insensitive_name() {
        // "abc" and "ABC" treated equivalently for ordering.
        let mut channels = vec![
            ch("c", "charlie", Some(1)),
            ch("a", "ALPHA", Some(1)),
            ch("b", "Bravo", Some(1)),
        ];
        sort_channels(&mut channels);
        let names: Vec<&str> = channels.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(names, vec!["ALPHA", "Bravo", "charlie"]);
    }

    #[test]
    fn sort_empty_list() {
        let mut channels: Vec<Channel> = vec![];
        sort_channels(&mut channels);
        assert!(channels.is_empty());
    }

    #[test]
    fn sort_single_item() {
        let mut channels = vec![ch("a", "Alpha", Some(1))];
        sort_channels(&mut channels);
        assert_eq!(channels.len(), 1);
        assert_eq!(channels[0].id, "a");
        assert_eq!(channels[0].name, "Alpha");
    }
}
