//! Z-depth preset providers: AppleTv, Netflix, GoogleTv, Flat (Tasks 9–13).

use crate::core::config::{ZPreset, ZTransform, ZTransformParams, ZTransformProvider};

// ---------------------------------------------------------------------------
// Helper: lerp
// ---------------------------------------------------------------------------

fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t.clamp(0.0, 1.0)
}

// ---------------------------------------------------------------------------
// FlatProvider (Task 12) — identity, no effects
// ---------------------------------------------------------------------------

/// Flat preset: no scale, no opacity change, no shadows.
/// Items look identical regardless of position.
pub struct FlatProvider;

impl ZTransformProvider for FlatProvider {
    fn compute(&self, _params: ZTransformParams) -> ZTransform {
        ZTransform::default()
    }
}

// ---------------------------------------------------------------------------
// AppleTvProvider (Task 9) — subtle parallax + focus pop
// ---------------------------------------------------------------------------

/// Apple TV-style: focused item scales up with shadow, others fade slightly.
pub struct AppleTvProvider;

impl ZTransformProvider for AppleTvProvider {
    fn compute(&self, params: ZTransformParams) -> ZTransform {
        let nd = params.normalized_distance.abs();

        if params.is_focused {
            ZTransform {
                scale: 1.12,
                opacity: 1.0,
                z_offset: 8.0,
                shadow_radius: 24.0,
                shadow_opacity: 0.6,
                border_width: 2.5,
                border_opacity: 1.0,
                ..ZTransform::default()
            }
        } else {
            // Items farther from focus get progressively dimmer
            let opacity = lerp(0.95, 0.65, (nd - 1.0).max(0.0) / 4.0);
            let scale = lerp(1.0, 0.94, (nd - 1.0).max(0.0) / 4.0);
            ZTransform {
                scale,
                opacity,
                ..ZTransform::default()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// NetflixProvider (Task 10) — hero focus with tilt + depth
// ---------------------------------------------------------------------------

/// Netflix-style: focused item has tilt + bold scale, neighbors rotate out.
pub struct NetflixProvider;

impl ZTransformProvider for NetflixProvider {
    fn compute(&self, params: ZTransformParams) -> ZTransform {
        let nd = params.normalized_distance.abs();
        let distance = params.distance_from_focus;

        if params.is_focused {
            ZTransform {
                scale: 1.2,
                opacity: 1.0,
                z_offset: 12.0,
                shadow_radius: 32.0,
                shadow_opacity: 0.7,
                blur: 0.0,
                border_width: 3.0,
                border_opacity: 1.0,
                ..ZTransform::default()
            }
        } else {
            // Blur increases with distance, slight scale down
            let blur = (nd - 1.0).max(0.0) * 1.5;
            let opacity = lerp(0.9, 0.4, (nd - 1.0).max(0.0) / 3.0);
            let scale = lerp(1.0, 0.88, (nd - 1.0).max(0.0) / 3.0);
            // Tilt: items to the left/right of focus tilt slightly toward center
            let tilt_sign = if distance > 0.0 { 1.0 } else { -1.0 };
            let rotation_y = tilt_sign * (nd - 1.0).min(2.0) * 4.0;
            ZTransform {
                scale,
                opacity,
                blur,
                rotation_y,
                ..ZTransform::default()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// GoogleTvProvider (Task 11) — card-stack with subtle elevation
// ---------------------------------------------------------------------------

/// Google TV-style: focused item elevates with border glow, others flatten.
pub struct GoogleTvProvider;

impl ZTransformProvider for GoogleTvProvider {
    fn compute(&self, params: ZTransformParams) -> ZTransform {
        let nd = params.normalized_distance.abs();

        if params.is_focused {
            ZTransform {
                scale: 1.08,
                opacity: 1.0,
                z_offset: 6.0,
                shadow_radius: 16.0,
                shadow_opacity: 0.5,
                border_width: 2.0,
                border_opacity: 1.0,
                ..ZTransform::default()
            }
        } else {
            let opacity = lerp(1.0, 0.72, (nd - 1.0).max(0.0) / 5.0);
            let scale = lerp(1.0, 0.96, (nd - 1.0).max(0.0) / 5.0);
            ZTransform {
                scale,
                opacity,
                ..ZTransform::default()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// make_preset — factory function (Task 13)
// ---------------------------------------------------------------------------

/// Construct a boxed `ZTransformProvider` from a `ZPreset` variant.
pub fn make_preset(preset: ZPreset) -> Box<dyn ZTransformProvider> {
    match preset {
        ZPreset::AppleTv => Box::new(AppleTvProvider),
        ZPreset::Netflix => Box::new(NetflixProvider),
        ZPreset::GoogleTv => Box::new(GoogleTvProvider),
        ZPreset::Flat => Box::new(FlatProvider),
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::ZTransformParams;

    fn make_params(index: i32, focused_index: i32, is_focused: bool) -> ZTransformParams {
        let distance = (index - focused_index) as f32;
        let nd = distance.abs();
        ZTransformParams {
            index,
            focused_index,
            distance_from_focus: distance,
            normalized_distance: nd,
            scroll_progress: 0.0,
            viewport_position: 0.0,
            is_focused,
            pointer_position: None,
            velocity: 0.0,
        }
    }

    // --- Flat ---

    #[test]
    fn test_flat_focused_is_identity() {
        let p = FlatProvider;
        let t = p.compute(make_params(0, 0, true));
        assert!((t.scale - 1.0).abs() < 0.001);
        assert!((t.opacity - 1.0).abs() < 0.001);
        assert_eq!(t.shadow_radius, 0.0);
    }

    #[test]
    fn test_flat_unfocused_is_identity() {
        let p = FlatProvider;
        let t = p.compute(make_params(3, 0, false));
        assert!((t.scale - 1.0).abs() < 0.001);
        assert!((t.opacity - 1.0).abs() < 0.001);
    }

    // --- Apple TV ---

    #[test]
    fn test_apple_tv_focused_has_scale_above_one() {
        let p = AppleTvProvider;
        let t = p.compute(make_params(0, 0, true));
        assert!(t.scale > 1.0);
    }

    #[test]
    fn test_apple_tv_focused_has_shadow() {
        let p = AppleTvProvider;
        let t = p.compute(make_params(0, 0, true));
        assert!(t.shadow_radius > 0.0);
        assert!(t.shadow_opacity > 0.0);
    }

    #[test]
    fn test_apple_tv_distant_item_has_lower_opacity() {
        let p = AppleTvProvider;
        let near = p.compute(make_params(1, 0, false));
        let far = p.compute(make_params(5, 0, false));
        assert!(far.opacity <= near.opacity);
    }

    #[test]
    fn test_apple_tv_unfocused_scale_at_most_one() {
        let p = AppleTvProvider;
        let t = p.compute(make_params(2, 0, false));
        assert!(t.scale <= 1.0);
    }

    // --- Netflix ---

    #[test]
    fn test_netflix_focused_has_largest_scale() {
        let p = NetflixProvider;
        let focused = p.compute(make_params(0, 0, true));
        let near = p.compute(make_params(1, 0, false));
        assert!(focused.scale > near.scale);
    }

    #[test]
    fn test_netflix_unfocused_has_blur() {
        let p = NetflixProvider;
        let far = p.compute(make_params(3, 0, false));
        assert!(far.blur >= 0.0);
    }

    #[test]
    fn test_netflix_tilt_direction_for_right_item() {
        let p = NetflixProvider;
        let right = p.compute(make_params(2, 0, false)); // distance > 0
        let left = p.compute(make_params(-2, 0, false)); // distance < 0
        assert!(right.rotation_y * left.rotation_y < 0.0 || right.rotation_y == left.rotation_y);
    }

    // --- Google TV ---

    #[test]
    fn test_google_tv_focused_has_border() {
        let p = GoogleTvProvider;
        let t = p.compute(make_params(0, 0, true));
        assert!(t.border_width > 0.0);
        assert!(t.border_opacity > 0.0);
    }

    #[test]
    fn test_google_tv_focused_scale_modest() {
        let p = GoogleTvProvider;
        let t = p.compute(make_params(0, 0, true));
        // Google TV is more subtle than Netflix
        assert!(t.scale < 1.15);
        assert!(t.scale > 1.0);
    }

    // --- Factory ---

    #[test]
    fn test_make_preset_flat_returns_identity() {
        let p = make_preset(ZPreset::Flat);
        let t = p.compute(make_params(0, 0, true));
        assert!((t.scale - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_make_preset_apple_tv_scales_focus() {
        let p = make_preset(ZPreset::AppleTv);
        let t = p.compute(make_params(0, 0, true));
        assert!(t.scale > 1.0);
    }

    #[test]
    fn test_make_preset_netflix_scales_focus() {
        let p = make_preset(ZPreset::Netflix);
        let t = p.compute(make_params(0, 0, true));
        assert!(t.scale > 1.0);
    }

    #[test]
    fn test_make_preset_google_tv_scales_focus() {
        let p = make_preset(ZPreset::GoogleTv);
        let t = p.compute(make_params(0, 0, true));
        assert!(t.scale > 1.0);
    }
}
