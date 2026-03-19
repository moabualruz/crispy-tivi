/// Property-based tests — slot recycler invariants.
use proptest::prelude::*;

proptest! {
    #[test]
    fn prop_recycle_diff_balanced_for_same_size_ranges(
        start1 in 0usize..1000,
        len    in 1usize..50,
        offset in 1usize..50,
    ) {
        let old = start1..(start1 + len);
        let new = (start1 + offset)..(start1 + offset + len);
        let diff = slint_crispy_vscroll::slots::recycler::compute_recycle(old, new);
        prop_assert_eq!(
            diff.to_free.len(),
            diff.to_assign.len(),
            "to_free.len()={} != to_assign.len()={}",
            diff.to_free.len(),
            diff.to_assign.len()
        );
    }

    #[test]
    fn prop_recycle_no_overlap_between_free_and_assign(
        start1 in 0usize..500,
        len    in 1usize..50,
        offset in 1usize..50,
    ) {
        let old = start1..(start1 + len);
        let new = (start1 + offset)..(start1 + offset + len);
        let diff = slint_crispy_vscroll::slots::recycler::compute_recycle(old, new);
        for idx in &diff.to_free {
            prop_assert!(
                !diff.to_assign.contains(idx),
                "idx={idx} appears in both to_free and to_assign"
            );
        }
    }

    #[test]
    fn prop_recycle_identical_ranges_empty_diff(
        start in 0usize..1000,
        len   in 0usize..100,
    ) {
        let range = start..(start + len);
        let diff =
            slint_crispy_vscroll::slots::recycler::compute_recycle(range.clone(), range);
        prop_assert!(diff.to_free.is_empty());
        prop_assert!(diff.to_assign.is_empty());
    }

    #[test]
    fn prop_recycle_to_free_not_in_new(
        start1 in 0usize..500,
        len    in 1usize..50,
        offset in 0usize..100,
    ) {
        let old = start1..(start1 + len);
        let start2 = start1 + offset;
        let new = start2..(start2 + len);
        let diff = slint_crispy_vscroll::slots::recycler::compute_recycle(old, new.clone());
        for idx in &diff.to_free {
            prop_assert!(
                !new.contains(idx),
                "freed idx={idx} is still in new range"
            );
        }
    }

    #[test]
    fn prop_recycle_to_assign_not_in_old(
        start1 in 0usize..500,
        len    in 1usize..50,
        offset in 0usize..100,
    ) {
        let old = start1..(start1 + len);
        let start2 = start1 + offset;
        let new = start2..(start2 + len);
        let diff = slint_crispy_vscroll::slots::recycler::compute_recycle(old.clone(), new);
        for idx in &diff.to_assign {
            prop_assert!(
                !old.contains(idx),
                "assigned idx={idx} was already in old range"
            );
        }
    }
}
