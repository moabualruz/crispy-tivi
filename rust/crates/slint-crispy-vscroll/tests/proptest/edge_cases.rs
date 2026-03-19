/// Edge case tests: zero items, single item, NaN/Inf, extreme velocities,
/// ring buffer at capacity, focus at boundaries.
use slint_crispy_vscroll::{
    core::types::{Direction, NavDirection},
    focus::tracker::{FocusTracker, NavResult},
    layout::vertical::{content_size_uniform, max_scroll_offset, visible_range_uniform},
    physics::{
        momentum::{apply_friction_decay, apply_velocity_cap, should_stop_momentum},
        rubber_band::rubber_band_displacement,
        snap::snap_nearest,
        spring::spring_step,
    },
    slots::{recycler::compute_recycle, ring_buffer::RingBuffer},
};

// ---------------------------------------------------------------------------
// Layout — zero / single item
// ---------------------------------------------------------------------------

#[test]
fn edge_visible_range_zero_items() {
    let r = visible_range_uniform(0.0, 80.0, 600.0, 0, 2);
    assert_eq!(r, 0..0, "zero items must return empty range");
}

#[test]
fn edge_visible_range_single_item_buffer_zero() {
    let r = visible_range_uniform(0.0, 80.0, 600.0, 1, 0);
    assert_eq!(r, 0..1);
}

#[test]
fn edge_visible_range_single_item_large_buffer() {
    let r = visible_range_uniform(0.0, 80.0, 600.0, 1, 5);
    // buffer cannot push end past item_count=1
    assert_eq!(r, 0..1);
}

#[test]
fn edge_content_size_zero_items() {
    assert_eq!(content_size_uniform(0, 80.0), 0.0);
}

#[test]
fn edge_content_size_zero_item_size() {
    assert_eq!(content_size_uniform(1000, 0.0), 0.0);
}

#[test]
fn edge_max_scroll_offset_content_smaller_than_viewport() {
    assert_eq!(max_scroll_offset(200.0, 600.0), 0.0);
}

#[test]
fn edge_max_scroll_offset_content_equal_to_viewport() {
    assert_eq!(max_scroll_offset(600.0, 600.0), 0.0);
}

// ---------------------------------------------------------------------------
// Layout — NaN / Inf scroll positions (must not panic)
// ---------------------------------------------------------------------------

#[test]
fn edge_visible_range_nan_scroll_does_not_panic() {
    let _ = visible_range_uniform(f32::NAN, 80.0, 600.0, 100, 1);
}

#[test]
fn edge_visible_range_inf_scroll_end_clamped() {
    let r = visible_range_uniform(f32::INFINITY, 80.0, 600.0, 100, 1);
    assert!(r.end <= 100, "end={} should be <= 100", r.end);
}

#[test]
fn edge_visible_range_neg_inf_scroll_does_not_panic() {
    let r = visible_range_uniform(f32::NEG_INFINITY, 80.0, 600.0, 100, 1);
    assert!(r.start <= r.end);
    assert!(r.end <= 100);
}

// ---------------------------------------------------------------------------
// Physics — extreme velocity values
// ---------------------------------------------------------------------------

#[test]
fn edge_velocity_cap_extremely_large_positive() {
    let capped = apply_velocity_cap(1_000_000.0, 3000.0);
    assert_eq!(capped, 3000.0);
}

#[test]
fn edge_velocity_cap_extremely_large_negative() {
    let capped = apply_velocity_cap(-1_000_000.0, 3000.0);
    assert_eq!(capped, -3000.0);
}

#[test]
fn edge_velocity_cap_zero_velocity() {
    assert_eq!(apply_velocity_cap(0.0, 3000.0), 0.0);
}

#[test]
fn edge_friction_decay_zero_velocity() {
    assert_eq!(apply_friction_decay(0.0, 0.97, 1.0 / 60.0), 0.0);
}

#[test]
fn edge_friction_decay_friction_at_one_does_not_panic() {
    // friction=1.0 → velocity unchanged; must not panic
    let _ = apply_friction_decay(100.0, 1.0, 1.0 / 60.0);
}

#[test]
fn edge_should_stop_zero_velocity_positive_threshold() {
    assert!(should_stop_momentum(0.0, 0.001));
}

// ---------------------------------------------------------------------------
// Physics — rubber band edge cases
// ---------------------------------------------------------------------------

#[test]
fn edge_rubber_band_zero_overscroll() {
    assert_eq!(rubber_band_displacement(0.0, 600.0, 0.55), 0.0);
}

#[test]
fn edge_rubber_band_zero_dimension() {
    assert_eq!(rubber_band_displacement(100.0, 0.0, 0.55), 0.0);
}

#[test]
fn edge_rubber_band_negative_overscroll() {
    assert_eq!(rubber_band_displacement(-50.0, 600.0, 0.55), 0.0);
}

// ---------------------------------------------------------------------------
// Physics — spring
// ---------------------------------------------------------------------------

#[test]
fn edge_spring_step_at_rest_no_movement() {
    let (new_pos, new_vel) = spring_step(100.0, 0.0, 100.0, 300.0, 28.0, 1.0 / 60.0);
    assert_eq!(new_pos, 100.0);
    assert_eq!(new_vel, 0.0);
}

#[test]
fn edge_spring_step_zero_dt_no_position_change() {
    let (new_pos, new_vel) = spring_step(0.0, 500.0, 100.0, 300.0, 28.0, 0.0);
    // dt=0 → new_vel = vel + acc*0 = vel; new_pos = pos + new_vel*0 = pos
    assert_eq!(new_pos, 0.0);
    assert_eq!(new_vel, 500.0);
}

// ---------------------------------------------------------------------------
// Physics — snap
// ---------------------------------------------------------------------------

#[test]
fn edge_snap_nearest_empty_targets() {
    assert_eq!(snap_nearest(&[], 100.0), 0.0);
}

#[test]
fn edge_snap_nearest_single_target() {
    assert_eq!(snap_nearest(&[250.0], 999.0), 250.0);
}

// ---------------------------------------------------------------------------
// RingBuffer — at exact capacity
// ---------------------------------------------------------------------------

#[test]
fn edge_ring_buffer_push_to_exact_capacity() {
    let mut rb = RingBuffer::<u32>::new(3);
    rb.push(1);
    rb.push(2);
    rb.push(3);
    assert!(rb.is_full());
    assert_eq!(rb.len(), 3);
}

#[test]
#[should_panic(expected = "RingBuffer is full")]
fn edge_ring_buffer_push_beyond_capacity_panics() {
    let mut rb = RingBuffer::<u32>::new(2);
    rb.push(1);
    rb.push(2);
    rb.push(3); // must panic
}

#[test]
fn edge_ring_buffer_empty_pop_returns_none() {
    let mut rb = RingBuffer::<u32>::new(4);
    assert_eq!(rb.pop_head(), None);
}

#[test]
fn edge_ring_buffer_capacity_one_push_pop() {
    let mut rb = RingBuffer::<u32>::new(1);
    rb.push(42_u32);
    assert!(rb.is_full());
    assert_eq!(rb.pop_head(), Some(42));
    assert!(rb.is_empty());
}

#[test]
fn edge_ring_buffer_get_out_of_bounds_returns_none() {
    let rb = RingBuffer::<u32>::new(4);
    assert_eq!(rb.get(0), None);
}

// ---------------------------------------------------------------------------
// RecycleDiff — edge cases
// ---------------------------------------------------------------------------

#[test]
fn edge_recycle_empty_ranges() {
    let diff = compute_recycle(0..0, 0..0);
    assert!(diff.to_free.is_empty());
    assert!(diff.to_assign.is_empty());
}

#[test]
fn edge_recycle_fully_disjoint_large_jump() {
    let diff = compute_recycle(0..5, 1000..1005);
    assert_eq!(diff.to_free, vec![0, 1, 2, 3, 4]);
    assert_eq!(diff.to_assign, vec![1000, 1001, 1002, 1003, 1004]);
}

#[test]
fn edge_recycle_new_range_shrinks_to_empty() {
    let diff = compute_recycle(5..10, 5..5);
    assert_eq!(diff.to_free, vec![5, 6, 7, 8, 9]);
    assert!(diff.to_assign.is_empty());
}

// ---------------------------------------------------------------------------
// FocusTracker — boundary focus
// ---------------------------------------------------------------------------

#[test]
fn edge_focus_navigate_up_at_zero_returns_edge() {
    let mut ft = FocusTracker::new(5, Direction::Vertical);
    let r = ft.navigate(NavDirection::Up);
    assert_eq!(r, NavResult::EdgeReached(NavDirection::Up));
    assert_eq!(ft.focused_index(), 0);
}

#[test]
fn edge_focus_navigate_down_at_max_returns_edge() {
    let mut ft = FocusTracker::new(5, Direction::Vertical);
    ft.set_focus(4);
    let r = ft.navigate(NavDirection::Down);
    assert_eq!(r, NavResult::EdgeReached(NavDirection::Down));
    assert_eq!(ft.focused_index(), 4);
}

#[test]
fn edge_focus_single_item_any_direction_is_edge() {
    let mut ft = FocusTracker::new(1, Direction::Vertical);
    assert_eq!(
        ft.navigate(NavDirection::Down),
        NavResult::EdgeReached(NavDirection::Down)
    );
    assert_eq!(
        ft.navigate(NavDirection::Up),
        NavResult::EdgeReached(NavDirection::Up)
    );
    assert_eq!(ft.focused_index(), 0);
}

#[test]
fn edge_focus_set_focus_beyond_count_clamped() {
    let mut ft = FocusTracker::new(3, Direction::Vertical);
    ft.set_focus(999);
    assert_eq!(ft.focused_index(), 2, "must clamp to item_count-1");
}

#[test]
fn edge_focus_navigate_down_traverses_all_items() {
    let count = 5;
    let mut ft = FocusTracker::new(count, Direction::Vertical);
    for expected in 1..count {
        let r = ft.navigate(NavDirection::Down);
        assert_eq!(r, NavResult::Moved(expected));
    }
    assert_eq!(
        ft.navigate(NavDirection::Down),
        NavResult::EdgeReached(NavDirection::Down)
    );
}
