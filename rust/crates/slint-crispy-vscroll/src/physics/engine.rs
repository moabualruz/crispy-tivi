use crate::core::config::PhysicsState;
use crate::core::types::Vec2;

/// Object-safe trait for the scroll physics engine.
/// All implementations must be Send + Sync (no raw pointers, no Rc).
pub trait PhysicsEngine: Send + Sync {
    /// Advance the simulation by `dt` seconds. Returns the new scroll position.
    fn tick(&mut self, dt: f32) -> Vec2;

    /// Apply an instantaneous positional delta (drag move).
    fn apply_delta(&mut self, delta: Vec2);

    /// Current scroll position.
    fn position(&self) -> Vec2;

    /// Current velocity in px/s.
    fn velocity(&self) -> Vec2;

    /// Current physics state.
    fn state(&self) -> PhysicsState;

    /// Teleport to position without animation.
    fn set_position(&mut self, pos: Vec2);

    /// Update the total content size (height for vertical, width for horizontal).
    fn set_content_size(&mut self, size: f32);

    /// Update the viewport size.
    fn set_viewport_size(&mut self, size: f32);

    /// True when the engine is not Idle.
    fn is_animating(&self) -> bool;

    /// Stop all motion and return to Idle.
    fn cancel(&mut self);
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Verify the trait is object-safe (can be used as Box<dyn PhysicsEngine>).
    #[test]
    fn test_physics_engine_trait_is_object_safe() {
        let _: Option<Box<dyn PhysicsEngine>> = None;
    }
}
