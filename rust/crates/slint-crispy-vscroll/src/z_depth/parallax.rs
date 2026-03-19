//! Z-depth parallax provider — depth-based positional offset.

use crate::core::config::{ZTransform, ZTransformParams, ZTransformProvider};

/// Parallax provider: items further from the focused index shift on their
/// secondary axis proportionally to their z-depth, creating a parallax effect.
pub struct ParallaxProvider {
    /// Maximum horizontal/vertical offset at maximum distance.
    pub max_offset: f32,
    /// How many items to consider as the "full range" for normalization.
    pub depth_range: f32,
}

impl Default for ParallaxProvider {
    fn default() -> Self {
        Self {
            max_offset: 30.0,
            depth_range: 5.0,
        }
    }
}

impl ZTransformProvider for ParallaxProvider {
    fn compute(&self, params: ZTransformParams) -> ZTransform {
        let nd = params.normalized_distance / self.depth_range;
        let offset = nd.clamp(0.0, 1.0) * self.max_offset;
        let sign = if params.distance_from_focus >= 0.0 {
            1.0_f32
        } else {
            -1.0_f32
        };
        ZTransform {
            translate_x: sign * offset,
            ..ZTransform::default()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::ZTransformParams;

    fn params(distance: f32) -> ZTransformParams {
        ZTransformParams {
            index: distance as i32,
            focused_index: 0,
            distance_from_focus: distance,
            normalized_distance: distance.abs(),
            scroll_progress: 0.0,
            viewport_position: 0.0,
            is_focused: distance == 0.0,
            pointer_position: None,
            velocity: 0.0,
        }
    }

    #[test]
    fn test_parallax_at_focus_has_zero_offset() {
        let p = ParallaxProvider::default();
        let t = p.compute(params(0.0));
        assert!((t.translate_x).abs() < 0.001);
    }

    #[test]
    fn test_parallax_offset_increases_with_distance() {
        let p = ParallaxProvider::default();
        let near = p.compute(params(1.0));
        let far = p.compute(params(4.0));
        assert!(far.translate_x.abs() >= near.translate_x.abs());
    }

    #[test]
    fn test_parallax_opposite_sign_for_negative_distance() {
        let p = ParallaxProvider::default();
        let right = p.compute(params(2.0));
        let left = p.compute(params(-2.0));
        assert!(right.translate_x >= 0.0);
        assert!(left.translate_x <= 0.0);
    }
}
