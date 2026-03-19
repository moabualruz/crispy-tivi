//! Card-deck Z-depth provider — stacked cards perspective effect.

use crate::core::config::{ZTransform, ZTransformParams, ZTransformProvider};

/// Card-deck provider: items behind the focused item appear as stacked cards
/// with decreasing scale and offset.
pub struct CardDeckProvider {
    /// Scale reduction per card behind focus.
    pub scale_step: f32,
    /// Y offset per card behind focus (positive = shift down).
    pub y_offset_step: f32,
    /// Maximum number of cards visible in the stack.
    pub max_visible: u32,
}

impl Default for CardDeckProvider {
    fn default() -> Self {
        Self {
            scale_step: 0.04,
            y_offset_step: 8.0,
            max_visible: 3,
        }
    }
}

impl ZTransformProvider for CardDeckProvider {
    fn compute(&self, params: ZTransformParams) -> ZTransform {
        if params.is_focused {
            return ZTransform {
                scale: 1.0,
                opacity: 1.0,
                z_offset: 10.0,
                shadow_radius: 20.0,
                shadow_opacity: 0.5,
                ..ZTransform::default()
            };
        }

        let depth = params.normalized_distance as u32;
        if depth > self.max_visible {
            return ZTransform {
                opacity: 0.0,
                ..ZTransform::default()
            };
        }

        let scale = (1.0 - self.scale_step * depth as f32).max(0.0);
        let translate_y = -(self.y_offset_step * depth as f32);
        let opacity = 1.0 - 0.2 * depth as f32;

        ZTransform {
            scale,
            opacity: opacity.max(0.0),
            translate_y,
            z_offset: -(depth as f32 * 2.0),
            ..ZTransform::default()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::ZTransformParams;

    fn params(distance: f32, focused: bool) -> ZTransformParams {
        ZTransformParams {
            index: distance as i32,
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
    fn test_card_deck_focused_is_full_scale() {
        let p = CardDeckProvider::default();
        let t = p.compute(params(0.0, true));
        assert!((t.scale - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_card_deck_stacked_item_is_smaller() {
        let p = CardDeckProvider::default();
        let t = p.compute(params(1.0, false));
        assert!(t.scale < 1.0);
    }

    #[test]
    fn test_card_deck_beyond_max_visible_is_hidden() {
        let p = CardDeckProvider::default();
        let t = p.compute(params(5.0, false));
        assert!((t.opacity).abs() < 0.001);
    }
}
