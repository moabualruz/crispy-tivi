/// Property-based tests — physics invariants.
use proptest::prelude::*;

proptest! {
    #[test]
    fn prop_velocity_cap_always_respected(
        v   in -10000.0f32..10000.0,
        cap in 0.1f32..5000.0,
    ) {
        let capped = slint_crispy_vscroll::physics::momentum::apply_velocity_cap(v, cap);
        prop_assert!(capped.abs() <= cap + 0.001, "capped={capped} should be <= cap={cap}");
    }

    #[test]
    fn prop_velocity_cap_sign_preserved(
        v   in -10000.0f32..10000.0,
        cap in 0.1f32..5000.0,
    ) {
        let capped = slint_crispy_vscroll::physics::momentum::apply_velocity_cap(v, cap);
        if v > 0.001  { prop_assert!(capped >= 0.0); }
        if v < -0.001 { prop_assert!(capped <= 0.0); }
    }

    #[test]
    fn prop_friction_decay_never_exceeds_initial(
        v0      in 1.0f32..1000.0,
        friction in 0.80f32..0.9999,
        dt      in 0.001f32..0.05,
    ) {
        let decayed = slint_crispy_vscroll::physics::momentum::apply_friction_decay(v0, friction, dt);
        prop_assert!(decayed.abs() <= v0.abs() + 0.001, "decayed={decayed} > v0={v0}");
    }

    #[test]
    fn prop_friction_decay_positive_stays_positive(
        v0      in 0.001f32..1000.0,
        friction in 0.80f32..0.9999,
        dt      in 0.001f32..0.05,
    ) {
        let decayed = slint_crispy_vscroll::physics::momentum::apply_friction_decay(v0, friction, dt);
        prop_assert!(decayed >= 0.0, "decayed={decayed}");
    }

    #[test]
    fn prop_rubber_band_displacement_non_negative(
        overscroll in 0.0f32..500.0,
        dim        in 100.0f32..2000.0,
        coeff      in 0.1f32..1.0,
    ) {
        let d = slint_crispy_vscroll::physics::rubber_band::rubber_band_displacement(
            overscroll, dim, coeff,
        );
        prop_assert!(d >= 0.0, "d={d}");
    }

    #[test]
    fn prop_rubber_band_less_than_dimension(
        overscroll in 0.0f32..10000.0,
        dim        in 100.0f32..2000.0,
        coeff      in 0.1f32..1.0,
    ) {
        let d = slint_crispy_vscroll::physics::rubber_band::rubber_band_displacement(
            overscroll, dim, coeff,
        );
        prop_assert!(d < dim + 0.001, "d={d} >= dim={dim}");
    }

    #[test]
    fn prop_rubber_band_monotone_in_overscroll(
        base  in 0.0f32..4999.0,
        extra in 0.001f32..1.0,
        dim   in 100.0f32..2000.0,
        coeff in 0.1f32..1.0,
    ) {
        let d1 = slint_crispy_vscroll::physics::rubber_band::rubber_band_displacement(base, dim, coeff);
        let d2 = slint_crispy_vscroll::physics::rubber_band::rubber_band_displacement(base + extra, dim, coeff);
        prop_assert!(d2 >= d1 - 0.001, "d2={d2} < d1={d1}");
    }
}
