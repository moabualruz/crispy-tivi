//! EventEmitter with guaranteed callback ordering (Task 14).
//!
//! Callbacks are fired in the order they were registered.
//! All callbacks receive a clone of the event — no shared mutable state.

use crate::core::events::ScrollEvent;

// ---------------------------------------------------------------------------
// EventEmitter
// ---------------------------------------------------------------------------

type BoxedScrollCb = Box<dyn FnMut(&ScrollEvent) + Send + 'static>;

pub struct EventEmitter {
    callbacks: Vec<BoxedScrollCb>,
}

impl EventEmitter {
    pub fn new() -> Self {
        Self {
            callbacks: Vec::new(),
        }
    }

    /// Register a callback. Callbacks fire in registration order.
    pub fn on_scroll(&mut self, cb: impl FnMut(&ScrollEvent) + Send + 'static) {
        self.callbacks.push(Box::new(cb));
    }

    /// Emit a scroll event to all registered callbacks in order.
    ///
    /// Ordering guarantee: callbacks fire strictly in FIFO registration order.
    pub fn emit(&mut self, event: &ScrollEvent) {
        for cb in self.callbacks.iter_mut() {
            cb(event);
        }
    }

    /// Remove all registered callbacks.
    pub fn clear(&mut self) {
        self.callbacks.clear();
    }

    /// Number of registered callbacks.
    pub fn len(&self) -> usize {
        self.callbacks.len()
    }

    pub fn is_empty(&self) -> bool {
        self.callbacks.is_empty()
    }
}

impl Default for EventEmitter {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::events::ScrollEvent;
    use std::sync::{Arc, Mutex};

    fn default_event() -> ScrollEvent {
        ScrollEvent::default()
    }

    #[test]
    fn test_emitter_starts_empty() {
        let e = EventEmitter::new();
        assert!(e.is_empty());
        assert_eq!(e.len(), 0);
    }

    #[test]
    fn test_register_callback_increases_len() {
        let mut e = EventEmitter::new();
        e.on_scroll(|_| {});
        assert_eq!(e.len(), 1);
    }

    #[test]
    fn test_emit_calls_callback() {
        let mut e = EventEmitter::new();
        let called = Arc::new(Mutex::new(false));
        let called_clone = called.clone();
        e.on_scroll(move |_| {
            *called_clone.lock().unwrap() = true;
        });
        e.emit(&default_event());
        assert!(*called.lock().unwrap());
    }

    #[test]
    fn test_callbacks_fire_in_registration_order() {
        let mut e = EventEmitter::new();
        let order = Arc::new(Mutex::new(Vec::<u32>::new()));

        let o1 = order.clone();
        e.on_scroll(move |_| o1.lock().unwrap().push(1));

        let o2 = order.clone();
        e.on_scroll(move |_| o2.lock().unwrap().push(2));

        let o3 = order.clone();
        e.on_scroll(move |_| o3.lock().unwrap().push(3));

        e.emit(&default_event());

        let result = order.lock().unwrap().clone();
        assert_eq!(result, vec![1, 2, 3]);
    }

    #[test]
    fn test_emit_multiple_events() {
        let mut e = EventEmitter::new();
        let count = Arc::new(Mutex::new(0u32));
        let c = count.clone();
        e.on_scroll(move |_| *c.lock().unwrap() += 1);
        e.emit(&default_event());
        e.emit(&default_event());
        e.emit(&default_event());
        assert_eq!(*count.lock().unwrap(), 3);
    }

    #[test]
    fn test_clear_removes_all_callbacks() {
        let mut e = EventEmitter::new();
        e.on_scroll(|_| {});
        e.on_scroll(|_| {});
        e.clear();
        assert!(e.is_empty());
    }

    #[test]
    fn test_emit_after_clear_does_nothing() {
        let mut e = EventEmitter::new();
        let called = Arc::new(Mutex::new(false));
        let called_clone = called.clone();
        e.on_scroll(move |_| {
            *called_clone.lock().unwrap() = true;
        });
        e.clear();
        e.emit(&default_event());
        assert!(!*called.lock().unwrap());
    }

    #[test]
    fn test_event_data_passed_correctly() {
        use crate::core::types::{ScrollPhase, ScrollSource, Vec2};
        let mut e = EventEmitter::new();
        let received_delta = Arc::new(Mutex::new(Vec2::ZERO));
        let rd = received_delta.clone();
        e.on_scroll(move |ev| {
            *rd.lock().unwrap() = ev.original_delta;
        });

        let event = ScrollEvent {
            original_delta: Vec2::new(0.0, 42.0),
            phase: ScrollPhase::Moved,
            source: ScrollSource::DPad,
            ..ScrollEvent::default()
        };
        e.emit(&event);

        let delta = *received_delta.lock().unwrap();
        assert!((delta.y - 42.0).abs() < 0.001);
    }

    #[test]
    fn test_default_creates_empty_emitter() {
        let e = EventEmitter::default();
        assert!(e.is_empty());
        assert_eq!(e.len(), 0);
    }
}
