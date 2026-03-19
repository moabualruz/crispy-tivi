/// Property-based tests — focus tracker invariants.
use proptest::prelude::*;

proptest! {
    #[test]
    fn prop_focus_stays_in_bounds(
        item_count in 2usize..1000,
        nav_steps  in 0usize..200,
    ) {
        use slint_crispy_vscroll::core::types::{Direction, NavDirection};
        use slint_crispy_vscroll::focus::tracker::FocusTracker;

        let mut ft = FocusTracker::new(item_count, Direction::Vertical);
        let dirs = [NavDirection::Up, NavDirection::Down];
        for i in 0..nav_steps {
            ft.navigate(dirs[i % 2]);
        }
        let idx = ft.focused_index();
        prop_assert!(
            idx < item_count,
            "focused_index={idx} >= item_count={item_count}"
        );
    }

    #[test]
    fn prop_focus_grid_stays_in_bounds(
        item_count in 2usize..500,
        columns    in 1usize..10,
        nav_steps  in 0usize..200,
    ) {
        use slint_crispy_vscroll::core::types::NavDirection;
        use slint_crispy_vscroll::focus::tracker::FocusTracker;

        let mut ft = FocusTracker::new_grid(item_count, columns);
        let dirs = [
            NavDirection::Up,
            NavDirection::Down,
            NavDirection::Left,
            NavDirection::Right,
        ];
        for i in 0..nav_steps {
            ft.navigate(dirs[i % 4]);
        }
        let idx = ft.focused_index();
        prop_assert!(
            idx < item_count,
            "focused_index={idx} >= item_count={item_count}"
        );
    }

    #[test]
    fn prop_set_focus_then_query_consistent(
        item_count in 1usize..1000,
        target_idx in 0usize..1000,
    ) {
        use slint_crispy_vscroll::core::types::Direction;
        use slint_crispy_vscroll::focus::tracker::FocusTracker;

        let mut ft = FocusTracker::new(item_count, Direction::Vertical);
        ft.set_focus(target_idx);
        let reported = ft.focused_index();
        let clamped = target_idx.min(item_count.saturating_sub(1));
        prop_assert_eq!(
            reported,
            clamped,
            "reported={} expected clamped={}",
            reported,
            clamped
        );
    }
}
