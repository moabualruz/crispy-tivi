pub use crate::core::config::PhysicsState;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_physics_state_idle_is_not_animating() {
        assert!(!PhysicsState::Idle.is_animating());
    }

    #[test]
    fn test_physics_state_all_non_idle_are_animating() {
        assert!(PhysicsState::Dragging.is_animating());
        assert!(PhysicsState::Momentum.is_animating());
        assert!(PhysicsState::Snapping.is_animating());
        assert!(PhysicsState::RubberBand.is_animating());
        assert!(PhysicsState::DPadStep.is_animating());
        assert!(PhysicsState::Programmatic.is_animating());
    }

    #[test]
    fn test_physics_state_can_accept_touch_start_during_cancellable_states() {
        assert!(PhysicsState::Momentum.can_accept_touch_start());
        assert!(PhysicsState::DPadStep.can_accept_touch_start());
        assert!(PhysicsState::Programmatic.can_accept_touch_start());
    }

    #[test]
    fn test_physics_state_cannot_accept_touch_start_when_idle_or_dragging() {
        assert!(!PhysicsState::Idle.can_accept_touch_start());
        assert!(!PhysicsState::Dragging.can_accept_touch_start());
        assert!(!PhysicsState::Snapping.can_accept_touch_start());
        assert!(!PhysicsState::RubberBand.can_accept_touch_start());
    }
}
