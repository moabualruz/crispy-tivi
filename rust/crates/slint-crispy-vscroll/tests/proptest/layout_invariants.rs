/// Property-based tests — layout invariants.
use proptest::prelude::*;

proptest! {
    #[test]
    fn prop_visible_range_end_within_bounds(
        scroll    in 0.0f32..10000.0,
        item_size in 10.0f32..200.0,
        viewport  in 100.0f32..2000.0,
        count     in 1usize..10000,
        buffer    in 0usize..5,
    ) {
        let range = slint_crispy_vscroll::layout::vertical::visible_range_uniform(
            scroll, item_size, viewport, count, buffer,
        );
        prop_assert!(range.end <= count, "end={} > count={}", range.end, count);
    }

    #[test]
    fn prop_visible_range_start_le_end(
        scroll    in 0.0f32..10000.0,
        item_size in 10.0f32..200.0,
        viewport  in 100.0f32..2000.0,
        count     in 1usize..10000,
        buffer    in 0usize..5,
    ) {
        let range = slint_crispy_vscroll::layout::vertical::visible_range_uniform(
            scroll, item_size, viewport, count, buffer,
        );
        prop_assert!(
            range.start <= range.end,
            "start={} > end={}",
            range.start,
            range.end
        );
    }

    #[test]
    fn prop_content_size_non_negative(
        count in 0usize..100000,
        size  in 0.0f32..1000.0,
    ) {
        let cs = slint_crispy_vscroll::layout::vertical::content_size_uniform(count, size);
        prop_assert!(cs >= 0.0, "cs={cs}");
    }

    #[test]
    fn prop_max_scroll_offset_non_negative(
        content_size  in 0.0f32..1_000_000.0,
        viewport_size in 0.0f32..10_000.0,
    ) {
        let ms = slint_crispy_vscroll::layout::vertical::max_scroll_offset(
            content_size,
            viewport_size,
        );
        prop_assert!(ms >= 0.0, "max_scroll={ms}");
    }

    #[test]
    fn prop_content_size_equals_count_times_size(
        count in 0usize..10000,
        size  in 0.0f32..1000.0,
    ) {
        let cs = slint_crispy_vscroll::layout::vertical::content_size_uniform(count, size);
        let expected = count as f32 * size;
        prop_assert!((cs - expected).abs() < 0.001, "cs={cs} expected={expected}");
    }
}
