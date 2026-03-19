//! Custom Z-depth provider wrapper (Task 13).
//!
//! Allows users to supply an arbitrary closure as a `ZTransformProvider`.

use crate::core::config::{ZTransform, ZTransformParams, ZTransformProvider};

// ---------------------------------------------------------------------------
// ClosureProvider
// ---------------------------------------------------------------------------

/// Wraps a `Fn(ZTransformParams) -> ZTransform` closure as a `ZTransformProvider`.
pub struct ClosureProvider {
    func: Box<dyn Fn(ZTransformParams) -> ZTransform + Send + Sync>,
}

impl ClosureProvider {
    pub fn new(f: impl Fn(ZTransformParams) -> ZTransform + Send + Sync + 'static) -> Self {
        Self { func: Box::new(f) }
    }
}

impl ZTransformProvider for ClosureProvider {
    fn compute(&self, params: ZTransformParams) -> ZTransform {
        (self.func)(params)
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::ZTransformParams;

    fn default_params() -> ZTransformParams {
        ZTransformParams {
            index: 0,
            focused_index: 0,
            distance_from_focus: 0.0,
            normalized_distance: 0.0,
            scroll_progress: 0.0,
            viewport_position: 0.0,
            is_focused: true,
            pointer_position: None,
            velocity: 0.0,
        }
    }

    #[test]
    fn test_closure_provider_calls_closure() {
        let p = ClosureProvider::new(|params| ZTransform {
            scale: if params.is_focused { 1.5 } else { 0.9 },
            ..ZTransform::default()
        });
        let t = p.compute(default_params());
        assert!((t.scale - 1.5).abs() < 0.001);
    }

    #[test]
    fn test_closure_provider_unfocused() {
        let p = ClosureProvider::new(|params| ZTransform {
            scale: if params.is_focused { 1.5 } else { 0.9 },
            ..ZTransform::default()
        });
        let mut params = default_params();
        params.is_focused = false;
        params.normalized_distance = 1.0;
        let t = p.compute(params);
        assert!((t.scale - 0.9).abs() < 0.001);
    }

    #[test]
    fn test_closure_provider_as_trait_object() {
        let p: Box<dyn ZTransformProvider> = Box::new(ClosureProvider::new(|_| ZTransform {
            opacity: 0.5,
            ..ZTransform::default()
        }));
        let t = p.compute(default_params());
        assert!((t.opacity - 0.5).abs() < 0.001);
    }
}
