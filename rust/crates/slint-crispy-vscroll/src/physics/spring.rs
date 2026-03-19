/// Hooke's law: restoring force proportional to displacement.
/// `displacement` = current_position - rest_position (positive = stretched).
pub fn hooke_force(displacement: f32, stiffness: f32) -> f32 {
    -stiffness * displacement
}

/// Velocity-proportional damping force.
pub fn damping_force(velocity: f32, damping: f32) -> f32 {
    -damping * velocity
}

/// Semi-implicit Euler spring step.
/// Returns (new_position, new_velocity).
///
/// Steps:
/// 1. Compute acceleration = (hooke + damping) / mass  (mass=1 assumed)
/// 2. Update velocity first (semi-implicit)
/// 3. Update position using new velocity
pub fn spring_step(
    pos: f32,
    vel: f32,
    target: f32,
    stiffness: f32,
    damping: f32,
    dt: f32,
) -> (f32, f32) {
    let displacement = pos - target;
    let force = hooke_force(displacement, stiffness) + damping_force(vel, damping);
    let acceleration = force; // mass = 1.0
    let new_vel = vel + acceleration * dt;
    let new_pos = pos + new_vel * dt;
    (new_pos, new_vel)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hooke_force_proportional_to_displacement() {
        assert_eq!(hooke_force(10.0, 300.0), -3000.0);
        assert_eq!(hooke_force(-10.0, 300.0), 3000.0);
        assert_eq!(hooke_force(0.0, 300.0), 0.0);
    }

    #[test]
    fn test_damping_force_opposes_velocity() {
        assert_eq!(damping_force(5.0, 28.0), -140.0);
        assert_eq!(damping_force(-5.0, 28.0), 140.0);
        assert_eq!(damping_force(0.0, 28.0), 0.0);
    }

    #[test]
    fn test_spring_step_zero_at_rest() {
        // At rest: pos=target, vel=0 => no force, no movement
        let (new_pos, new_vel) = spring_step(100.0, 0.0, 100.0, 300.0, 28.0, 1.0 / 60.0);
        assert_eq!(new_pos, 100.0);
        assert_eq!(new_vel, 0.0);
    }

    #[test]
    fn test_spring_step_converges_to_target() {
        let mut pos = 0.0_f32;
        let mut vel = 0.0_f32;
        let target = 100.0;
        let dt = 1.0 / 60.0;
        for _ in 0..600 {
            (pos, vel) = spring_step(pos, vel, target, 300.0, 28.0, dt);
        }
        assert!((pos - target).abs() < 0.1, "pos={pos} vel={vel}");
    }

    #[test]
    fn test_spring_step_moves_toward_target() {
        // Starting at 0, target at 100, zero initial velocity
        let (new_pos, new_vel) = spring_step(0.0, 0.0, 100.0, 300.0, 28.0, 1.0 / 60.0);
        assert!(new_pos > 0.0, "new_pos={new_pos}");
        assert!(new_vel > 0.0, "new_vel={new_vel}");
    }

    #[test]
    fn test_spring_step_critically_damped_no_overshoot() {
        // Overdamped spring: stiffness=100, damping=30 (well above critical 2*sqrt(100)=20)
        let mut pos = 200.0_f32;
        let mut vel = 0.0_f32;
        let target = 0.0;
        let dt = 1.0 / 60.0;
        let mut overshot = false;
        for _ in 0..600 {
            (pos, vel) = spring_step(pos, vel, target, 100.0, 30.0, dt);
            if pos < -0.5 {
                overshot = true;
                break;
            }
        }
        assert!(!overshot, "Spring overshot target (pos={pos})");
    }
}
