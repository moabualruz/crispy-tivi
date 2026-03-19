//! Recycling algorithm: computes which slots to free and reassign on scroll.

use std::ops::Range;

/// Result of a recycle computation.
///
/// Invariant: `to_free.len() == to_assign.len()` when both ranges have equal size.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecycleDiff {
    /// Data indices that are no longer visible — their slots should be freed.
    pub to_free: Vec<usize>,
    /// Data indices that became visible — they need a slot assigned.
    pub to_assign: Vec<usize>,
}

/// Compute which indices to free and assign when the visible range changes.
///
/// Items in `old` but not in `new` → freed.
/// Items in `new` but not in `old` → assigned.
/// Items in both ranges → no-op (slot keeps serving the same item).
pub fn compute_recycle(old: Range<usize>, new: Range<usize>) -> RecycleDiff {
    let to_free: Vec<usize> = old.clone().filter(|i| !new.contains(i)).collect();
    let to_assign: Vec<usize> = new.clone().filter(|i| !old.contains(i)).collect();
    RecycleDiff { to_free, to_assign }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_change_when_identical_ranges() {
        let diff = compute_recycle(0..5, 0..5);
        assert!(diff.to_free.is_empty());
        assert!(diff.to_assign.is_empty());
    }

    #[test]
    fn test_forward_scroll_frees_head_assigns_tail() {
        // old: 0..5, new: 1..6 — free 0, assign 5
        let diff = compute_recycle(0..5, 1..6);
        assert_eq!(diff.to_free, vec![0]);
        assert_eq!(diff.to_assign, vec![5]);
    }

    #[test]
    fn test_backward_scroll_frees_tail_assigns_head() {
        // old: 2..7, new: 1..6 — free 6, assign 1
        let diff = compute_recycle(2..7, 1..6);
        assert_eq!(diff.to_free, vec![6]);
        assert_eq!(diff.to_assign, vec![1]);
    }

    #[test]
    fn test_disjoint_ranges_free_all_old_assign_all_new() {
        let diff = compute_recycle(0..3, 10..13);
        assert_eq!(diff.to_free, vec![0, 1, 2]);
        assert_eq!(diff.to_assign, vec![10, 11, 12]);
    }

    #[test]
    fn test_free_count_equals_assign_count_for_same_size_ranges() {
        let diff = compute_recycle(5..10, 7..12);
        assert_eq!(diff.to_free.len(), diff.to_assign.len());
    }

    #[test]
    fn test_growing_range_only_assigns() {
        let diff = compute_recycle(0..3, 0..5);
        assert!(diff.to_free.is_empty());
        assert_eq!(diff.to_assign, vec![3, 4]);
    }

    #[test]
    fn test_shrinking_range_only_frees() {
        let diff = compute_recycle(0..5, 0..3);
        assert_eq!(diff.to_free, vec![3, 4]);
        assert!(diff.to_assign.is_empty());
    }
}
