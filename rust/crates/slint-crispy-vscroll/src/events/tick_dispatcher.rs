//! Tick dispatcher — fires events in spec-mandated order each frame (Task 15).
//!
//! Per-tick order:
//!   1. InputConsumed  — input events that were classified and consumed
//!   2. PhysicsStep    — physics engine result (position, velocity)
//!   3. SlotAssigned   — slot pool changes
//!   4. FocusChanged   — focus index changed
//!   5. ScrollUpdated  — final scroll position after physics + snap
//!   6. FrameEnd       — all work for this tick is done

use crate::core::events::ScrollEvent;

// ---------------------------------------------------------------------------
// TickEvent
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq)]
pub enum TickEventKind {
    /// An input event was consumed and classified.
    InputConsumed,
    /// Physics engine produced a new position/velocity.
    PhysicsStep,
    /// Slot pool assigned new indices to slots.
    SlotAssigned,
    /// Focus index changed to a new index.
    FocusChanged { new_index: usize },
    /// Final scroll position for this tick.
    ScrollUpdated,
    /// All work for this tick is done.
    FrameEnd,
}

#[derive(Debug, Clone)]
pub struct TickEvent {
    pub kind: TickEventKind,
    pub scroll_event: ScrollEvent,
    pub frame_number: u64,
}

// ---------------------------------------------------------------------------
// TickDispatcher (Task 15)
// ---------------------------------------------------------------------------

type BoxedTickCb = Box<dyn FnMut(&TickEvent) + Send + 'static>;

pub struct TickDispatcher {
    callbacks: Vec<(TickEventKind, BoxedTickCb)>,
    frame_number: u64,
}

impl TickDispatcher {
    pub fn new() -> Self {
        Self {
            callbacks: Vec::new(),
            frame_number: 0,
        }
    }

    /// Register a callback for a specific tick-event kind.
    pub fn on(&mut self, kind: TickEventKind, cb: impl FnMut(&TickEvent) + Send + 'static) {
        self.callbacks.push((kind, Box::new(cb)));
    }

    /// Dispatch all tick events for this frame in spec-mandated order.
    ///
    /// Callers build a `Vec<TickEventKind>` of events that occurred this tick.
    /// The dispatcher fires them in canonical order, not arrival order.
    pub fn dispatch(&mut self, events: Vec<(TickEventKind, ScrollEvent)>) {
        self.frame_number += 1;
        let frame = self.frame_number;

        // Sort events by canonical order before firing
        let mut ordered = events;
        ordered.sort_by_key(|(k, _)| canonical_order(k));

        for (kind, scroll_event) in ordered {
            let tick_event = TickEvent {
                kind: kind.clone(),
                scroll_event,
                frame_number: frame,
            };
            for (registered_kind, cb) in self.callbacks.iter_mut() {
                if kinds_match(registered_kind, &tick_event.kind) {
                    cb(&tick_event);
                }
            }
        }
    }

    pub fn frame_number(&self) -> u64 {
        self.frame_number
    }
}

impl Default for TickDispatcher {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// Canonical ordering
// ---------------------------------------------------------------------------

fn canonical_order(kind: &TickEventKind) -> u8 {
    match kind {
        TickEventKind::InputConsumed => 0,
        TickEventKind::PhysicsStep => 1,
        TickEventKind::SlotAssigned => 2,
        TickEventKind::FocusChanged { .. } => 3,
        TickEventKind::ScrollUpdated => 4,
        TickEventKind::FrameEnd => 5,
    }
}

fn kinds_match(registered: &TickEventKind, event: &TickEventKind) -> bool {
    std::mem::discriminant(registered) == std::mem::discriminant(event)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::events::ScrollEvent;
    use std::sync::{Arc, Mutex};

    fn ev() -> ScrollEvent {
        ScrollEvent::default()
    }

    #[test]
    fn test_dispatcher_fires_registered_callback() {
        let mut d = TickDispatcher::new();
        let called = Arc::new(Mutex::new(false));
        let c = called.clone();
        d.on(TickEventKind::ScrollUpdated, move |_| {
            *c.lock().unwrap() = true;
        });
        d.dispatch(vec![(TickEventKind::ScrollUpdated, ev())]);
        assert!(*called.lock().unwrap());
    }

    #[test]
    fn test_dispatcher_does_not_fire_unregistered_kind() {
        let mut d = TickDispatcher::new();
        let called = Arc::new(Mutex::new(false));
        let c = called.clone();
        d.on(TickEventKind::FocusChanged { new_index: 0 }, move |_| {
            *c.lock().unwrap() = true;
        });
        // Only dispatch PhysicsStep — not FocusChanged
        d.dispatch(vec![(TickEventKind::PhysicsStep, ev())]);
        assert!(!*called.lock().unwrap());
    }

    #[test]
    fn test_dispatch_order_is_canonical_not_insertion_order() {
        let mut d = TickDispatcher::new();
        let order = Arc::new(Mutex::new(Vec::<u8>::new()));

        let o1 = order.clone();
        d.on(TickEventKind::ScrollUpdated, move |_| {
            o1.lock().unwrap().push(4)
        });
        let o2 = order.clone();
        d.on(TickEventKind::InputConsumed, move |_| {
            o2.lock().unwrap().push(0)
        });

        // Insert in reverse order — dispatcher must reorder
        d.dispatch(vec![
            (TickEventKind::ScrollUpdated, ev()),
            (TickEventKind::InputConsumed, ev()),
        ]);

        let result = order.lock().unwrap().clone();
        assert_eq!(result, vec![0, 4]); // InputConsumed fires before ScrollUpdated
    }

    #[test]
    fn test_frame_number_increments_each_dispatch() {
        let mut d = TickDispatcher::new();
        assert_eq!(d.frame_number(), 0);
        d.dispatch(vec![]);
        assert_eq!(d.frame_number(), 1);
        d.dispatch(vec![]);
        assert_eq!(d.frame_number(), 2);
    }

    #[test]
    fn test_frame_number_passed_to_callback() {
        let mut d = TickDispatcher::new();
        let received_frame = Arc::new(Mutex::new(0u64));
        let rf = received_frame.clone();
        d.on(TickEventKind::FrameEnd, move |te| {
            *rf.lock().unwrap() = te.frame_number;
        });
        d.dispatch(vec![(TickEventKind::FrameEnd, ev())]);
        assert_eq!(*received_frame.lock().unwrap(), 1);
    }

    #[test]
    fn test_default_creates_dispatcher_at_frame_zero() {
        let d = TickDispatcher::default();
        assert_eq!(d.frame_number(), 0);
    }

    #[test]
    fn test_slot_assigned_fires_before_focus_changed() {
        let mut d = TickDispatcher::new();
        let order = Arc::new(Mutex::new(Vec::<u8>::new()));

        let o1 = order.clone();
        d.on(TickEventKind::FocusChanged { new_index: 0 }, move |_| {
            o1.lock().unwrap().push(3);
        });
        let o2 = order.clone();
        d.on(TickEventKind::SlotAssigned, move |_| {
            o2.lock().unwrap().push(2);
        });

        d.dispatch(vec![
            (TickEventKind::FocusChanged { new_index: 5 }, ev()),
            (TickEventKind::SlotAssigned, ev()),
        ]);

        let result = order.lock().unwrap().clone();
        assert_eq!(result, vec![2, 3]); // SlotAssigned(2) before FocusChanged(3)
    }

    #[test]
    fn test_focus_changed_different_index_still_matches() {
        // kinds_match uses discriminant — FocusChanged{0} registered should fire for FocusChanged{5}
        let mut d = TickDispatcher::new();
        let called = Arc::new(Mutex::new(false));
        let c = called.clone();
        d.on(TickEventKind::FocusChanged { new_index: 0 }, move |_| {
            *c.lock().unwrap() = true;
        });
        d.dispatch(vec![(TickEventKind::FocusChanged { new_index: 42 }, ev())]);
        assert!(*called.lock().unwrap());
    }

    #[test]
    fn test_multiple_callbacks_same_kind_all_fire() {
        // Covers the inner callback loop with multiple registrations for same kind
        // This ensures kinds_match false path is hit when only some match
        let mut d = TickDispatcher::new();
        let count = Arc::new(Mutex::new(0u32));

        let c1 = count.clone();
        d.on(TickEventKind::ScrollUpdated, move |_| {
            *c1.lock().unwrap() += 1;
        });
        let c2 = count.clone();
        d.on(TickEventKind::PhysicsStep, move |_| {
            *c2.lock().unwrap() += 10;
        });

        // Dispatch only ScrollUpdated — PhysicsStep callback must NOT fire
        d.dispatch(vec![(TickEventKind::ScrollUpdated, ev())]);
        assert_eq!(*count.lock().unwrap(), 1); // only scroll fired
    }

    #[test]
    fn test_physics_step_fires_before_scroll_updated() {
        let mut d = TickDispatcher::new();
        let order = Arc::new(Mutex::new(Vec::<u8>::new()));

        let o1 = order.clone();
        d.on(TickEventKind::ScrollUpdated, move |_| {
            o1.lock().unwrap().push(4);
        });
        let o2 = order.clone();
        d.on(TickEventKind::PhysicsStep, move |_| {
            o2.lock().unwrap().push(1);
        });

        d.dispatch(vec![
            (TickEventKind::ScrollUpdated, ev()),
            (TickEventKind::PhysicsStep, ev()),
        ]);

        let result = order.lock().unwrap().clone();
        assert_eq!(result, vec![1, 4]);
    }

    #[test]
    fn test_all_six_event_kinds_canonical_order() {
        // Covers canonical_order() for ALL six arms including FrameEnd (line 112)
        let mut d = TickDispatcher::new();
        let order = Arc::new(Mutex::new(Vec::<u8>::new()));

        let o = order.clone();
        d.on(TickEventKind::InputConsumed, move |_| {
            o.lock().unwrap().push(0);
        });
        let o = order.clone();
        d.on(TickEventKind::PhysicsStep, move |_| {
            o.lock().unwrap().push(1);
        });
        let o = order.clone();
        d.on(TickEventKind::SlotAssigned, move |_| {
            o.lock().unwrap().push(2);
        });
        let o = order.clone();
        d.on(TickEventKind::FocusChanged { new_index: 0 }, move |_| {
            o.lock().unwrap().push(3);
        });
        let o = order.clone();
        d.on(TickEventKind::ScrollUpdated, move |_| {
            o.lock().unwrap().push(4);
        });
        let o = order.clone();
        d.on(TickEventKind::FrameEnd, move |_| {
            o.lock().unwrap().push(5);
        });

        // Dispatch in reverse canonical order — dispatcher must reorder
        d.dispatch(vec![
            (TickEventKind::FrameEnd, ev()),
            (TickEventKind::ScrollUpdated, ev()),
            (TickEventKind::FocusChanged { new_index: 1 }, ev()),
            (TickEventKind::SlotAssigned, ev()),
            (TickEventKind::PhysicsStep, ev()),
            (TickEventKind::InputConsumed, ev()),
        ]);

        let result = order.lock().unwrap().clone();
        assert_eq!(result, vec![0, 1, 2, 3, 4, 5]);
    }
}
