//! Cover flow Z-depth provider — carousel with rotation and depth perspective.
//!
//! The focused item is front-and-center at full scale.  Flanking items rotate
//! outward on the Y-axis (like album art in macOS Finder cover flow) and recede
//! into the background with reduced scale and opacity.

use crate::core::config::{ZTransform, ZTransformParams, ZTransformProvider};

// ---------------------------------------------------------------------------
// CoverFlowProvider
// ---------------------------------------------------------------------------

/// Cover flow: items flanking the focused item rotate and recede.
///
/// # Visual model
/// ```text
///   [  -2  ]  [ -1 ]  [ FOCUSED ]  [ +1 ]  [  +2  ]
///   rotated   tilted   flat/full    tilted   rotated
///   far back  behind    center     behind   far back
/// ```
pub struct CoverFlowProvider {
    /// Maximum rotation angle (degrees) applied to items farthest from focus.
    pub max_rotation_deg: f32,
    /// Scale of the focused item (should be 1.0 or slightly above for a "pop").
    pub focus_scale: f32,
    /// Scale applied to the item at `max_visible_distance` positions away.
    pub side_scale: f32,
    /// Opacity of the focused item.
    pub focus_opacity: f32,
    /// Opacity of items at `max_visible_distance` positions away.
    pub side_opacity: f32,
    /// Number of positions from focus at which items become fully hidden.
    pub max_visible_distance: f32,
    /// Z-depth offset for the focused item (pushes it toward the viewer).
    pub focus_z_offset: f32,
}

impl Default for CoverFlowProvider {
    fn default() -> Self {
        Self {
            max_rotation_deg: 70.0,
            focus_scale: 1.0,
            side_scale: 0.65,
            focus_opacity: 1.0,
            side_opacity: 0.5,
            max_visible_distance: 4.0,
            focus_z_offset: 20.0,
        }
    }
}

impl ZTransformProvider for CoverFlowProvider {
    fn compute(&self, params: ZTransformParams) -> ZTransform {
        let dist = params.distance_from_focus;
        let abs_dist = dist.abs();

        // Items beyond max_visible_distance are fully hidden
        if abs_dist >= self.max_visible_distance {
            return ZTransform {
                scale: self.side_scale,
                opacity: 0.0,
                z_offset: 0.0,
                rotation_y: dist.signum() * self.max_rotation_deg,
                shadow_radius: 0.0,
                ..ZTransform::default()
            };
        }

        // Normalised distance [0..1]
        let t = (abs_dist / self.max_visible_distance).clamp(0.0, 1.0);

        let scale = lerp(self.focus_scale, self.side_scale, t);
        let opacity = lerp(self.focus_opacity, self.side_opacity, t);
        let rotation_y = dist.signum() * lerp(0.0, self.max_rotation_deg, t);
        let z_offset = lerp(self.focus_z_offset, 0.0, t);
        let shadow_radius = if params.is_focused { 24.0 } else { 0.0 };

        ZTransform {
            scale,
            opacity,
            z_offset,
            rotation_y,
            shadow_radius,
            ..ZTransform::default()
        }
    }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

#[inline]
fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::ZTransformParams;

    fn params(distance: f32, focused: bool) -> ZTransformParams {
        ZTransformParams {
            index: 0,
            focused_index: 0,
            distance_from_focus: distance,
            normalized_distance: distance.abs(),
            scroll_progress: 0.0,
            viewport_position: 0.0,
            is_focused: focused,
            pointer_position: None,
            velocity: 0.0,
        }
    }

    #[test]
    fn test_cover_flow_focused_is_full_scale_no_rotation() {
        let p = CoverFlowProvider::default();
        let t = p.compute(params(0.0, true));
        assert!((t.scale - 1.0).abs() < 0.001);
        assert!((t.rotation_y).abs() < 0.001);
        assert!((t.opacity - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_cover_flow_adjacent_item_rotates_right() {
        let p = CoverFlowProvider::default();
        let t = p.compute(params(1.0, false));
        assert!(
            t.rotation_y > 0.0,
            "item to the right should rotate positive"
        );
        assert!(t.scale < 1.0, "adjacent item should be smaller");
    }

    #[test]
    fn test_cover_flow_adjacent_item_rotates_left_when_negative_distance() {
        let p = CoverFlowProvider::default();
        let t = p.compute(params(-1.0, false));
        assert!(
            t.rotation_y < 0.0,
            "item to the left should rotate negative"
        );
    }

    #[test]
    fn test_cover_flow_beyond_max_visible_is_hidden() {
        let p = CoverFlowProvider::default();
        let t = p.compute(params(5.0, false));
        assert!(
            (t.opacity).abs() < 0.001,
            "item beyond max_visible_distance should be hidden"
        );
    }

    #[test]
    fn test_cover_flow_opacity_decreases_with_distance() {
        let p = CoverFlowProvider::default();
        let t1 = p.compute(params(1.0, false));
        let t2 = p.compute(params(2.0, false));
        assert!(t1.opacity > t2.opacity);
    }

    #[test]
    fn test_cover_flow_scale_decreases_with_distance() {
        let p = CoverFlowProvider::default();
        let t1 = p.compute(params(1.0, false));
        let t2 = p.compute(params(3.0, false));
        assert!(t1.scale > t2.scale);
    }

    #[test]
    fn test_cover_flow_focused_has_z_offset() {
        let p = CoverFlowProvider::default();
        let t = p.compute(params(0.0, true));
        assert!(t.z_offset > 0.0);
    }
}
