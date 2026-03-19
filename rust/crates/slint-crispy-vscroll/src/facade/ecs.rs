//! ECS wrapper — VScrollWorld, VScrollComponent, VScrollSystem.
//!
//! Wraps [`VirtualScroller`] in an entity-component-system model where the
//! pipeline layers are exposed as composable systems.
//!
//! Enabled behind the `ecs` feature flag.

use super::scroller::VirtualScroller;

// ---------------------------------------------------------------------------
// VScrollComponent marker trait
// ---------------------------------------------------------------------------

/// Marker trait for data components attached to a [`VScrollWorld`].
///
/// Implementors can carry arbitrary per-world state that systems read or write.
pub trait VScrollComponent: 'static {}

// ---------------------------------------------------------------------------
// VScrollSystem trait
// ---------------------------------------------------------------------------

/// A composable system that runs every tick with mutable access to the world.
///
/// Systems are called in registration order by [`VScrollWorld::tick`].
pub trait VScrollSystem: 'static {
    /// Called each frame.  `dt` is the elapsed time in seconds since the last tick.
    fn tick(&mut self, world: &mut VScrollWorld, dt: f32);
}

// ---------------------------------------------------------------------------
// VScrollWorld
// ---------------------------------------------------------------------------

/// ECS world that owns a [`VirtualScroller`] and a stack of composable systems.
///
/// ```rust,ignore
/// use slint_crispy_vscroll::facade::ecs::{VScrollWorld, VScrollSystem};
///
/// struct LogSystem;
/// impl VScrollSystem for LogSystem {
///     fn tick(&mut self, world: &mut VScrollWorld, _dt: f32) {
///         println!("scroll_pos={}", world.scroller().scroll_position());
///     }
/// }
///
/// let mut world = VScrollWorld::new(scroller);
/// world.add_system(LogSystem);
/// world.tick(1.0 / 60.0); // one 60 fps frame
/// ```
pub struct VScrollWorld {
    scroller: VirtualScroller,
    systems: Vec<Box<dyn VScrollSystem>>,
}

impl VScrollWorld {
    /// Create a new world wrapping the given scroller.
    pub fn new(scroller: VirtualScroller) -> Self {
        Self {
            scroller,
            systems: Vec::new(),
        }
    }

    /// Register a system to run every tick (in registration order).
    pub fn add_system<S: VScrollSystem>(&mut self, system: S) {
        self.systems.push(Box::new(system));
    }

    /// Advance all registered systems then advance the underlying scroller.
    ///
    /// `dt` is elapsed time in **seconds** (e.g. `1.0 / 60.0` for 60 fps).
    pub fn tick(&mut self, dt: f32) {
        // Temporarily take the systems vec to avoid a double-borrow while
        // systems hold `&mut VScrollWorld`.
        let mut systems = std::mem::take(&mut self.systems);
        for system in &mut systems {
            system.tick(self, dt);
        }
        self.systems = systems;

        // Advance the underlying scroller (dt is seconds → convert to ms).
        self.scroller.tick(dt * 1000.0);
    }

    /// Immutable access to the underlying scroller.
    pub fn scroller(&self) -> &VirtualScroller {
        &self.scroller
    }

    /// Mutable access to the underlying scroller.
    pub fn scroller_mut(&mut self) -> &mut VirtualScroller {
        &mut self.scroller
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::{
        AnimationConfig, IntegrityMode, ItemSizing, PhysicsConfig, ResizeStrategy, ScrollerConfig,
        ViewportFollow,
    };
    use crate::core::types::{Direction, SnapMode};
    use crate::facade::scroller::VirtualScrollerBuilder;

    fn make_scroller() -> VirtualScroller {
        VirtualScrollerBuilder::new(ScrollerConfig {
            direction: Direction::Vertical,
            item_count: 20,
            item_sizing: ItemSizing::Uniform {
                width: 200.0,
                height: 60.0,
            },
            snap_mode: SnapMode::None,
            resize_strategy: ResizeStrategy::Reflow,
            breakpoints: vec![],
            viewport_follow: ViewportFollow::ScrollAhead,
            integrity_mode: IntegrityMode::Sync,
            physics: PhysicsConfig::default(),
            z_preset: None,
            z_custom: None,
            animation: AnimationConfig::default(),
            pool_buffer_ratio: 1.5,
            async_ack_timeout_ms: 500,
            scrollbar_visible: false,
            scrollbar_fade_ms: 1000,
        })
        .build()
    }

    #[test]
    fn test_world_tick_calls_system() {
        use std::sync::{Arc, Mutex};

        struct FlagSystem(Arc<Mutex<bool>>);
        impl VScrollSystem for FlagSystem {
            fn tick(&mut self, _world: &mut VScrollWorld, _dt: f32) {
                *self.0.lock().unwrap() = true;
            }
        }

        let called = Arc::new(Mutex::new(false));
        let mut world = VScrollWorld::new(make_scroller());
        world.add_system(FlagSystem(called.clone()));
        world.tick(1.0 / 60.0);
        assert!(*called.lock().unwrap(), "system should have been called");
    }

    #[test]
    fn test_world_systems_run_in_registration_order() {
        use std::sync::{Arc, Mutex};

        struct OrderSystem(u32, Arc<Mutex<Vec<u32>>>);
        impl VScrollSystem for OrderSystem {
            fn tick(&mut self, _world: &mut VScrollWorld, _dt: f32) {
                self.1.lock().unwrap().push(self.0);
            }
        }

        let order: Arc<Mutex<Vec<u32>>> = Arc::new(Mutex::new(Vec::new()));
        let mut world = VScrollWorld::new(make_scroller());
        world.add_system(OrderSystem(1, order.clone()));
        world.add_system(OrderSystem(2, order.clone()));
        world.add_system(OrderSystem(3, order.clone()));
        world.tick(1.0 / 60.0);

        assert_eq!(*order.lock().unwrap(), vec![1, 2, 3]);
    }

    #[test]
    fn test_world_system_can_mutate_scroller() {
        struct ScrollBySystem(f32);
        impl VScrollSystem for ScrollBySystem {
            fn tick(&mut self, world: &mut VScrollWorld, _dt: f32) {
                world.scroller_mut().scroll_by(self.0);
            }
        }

        let mut world = VScrollWorld::new(make_scroller());
        world.add_system(ScrollBySystem(100.0));
        // Should not panic — system mutates scroller successfully
        world.tick(1.0 / 60.0);
    }

    #[test]
    fn test_world_no_systems_tick_does_not_panic() {
        let mut world = VScrollWorld::new(make_scroller());
        world.tick(1.0 / 60.0);
        // Just verifying no panic
    }

    #[test]
    fn test_world_multiple_ticks_accumulate() {
        use std::sync::{Arc, Mutex};

        struct CountSystem(Arc<Mutex<u32>>);
        impl VScrollSystem for CountSystem {
            fn tick(&mut self, _world: &mut VScrollWorld, _dt: f32) {
                *self.0.lock().unwrap() += 1;
            }
        }

        let count = Arc::new(Mutex::new(0u32));
        let mut world = VScrollWorld::new(make_scroller());
        world.add_system(CountSystem(count.clone()));
        for _ in 0..5 {
            world.tick(1.0 / 60.0);
        }
        assert_eq!(*count.lock().unwrap(), 5);
    }
}
