/// Uniform sizing: all items have the same width and height.
pub struct UniformSizing {
    pub width: f32,
    pub height: f32,
}

impl UniformSizing {
    pub fn new(width: f32, height: f32) -> Self {
        Self { width, height }
    }

    /// Returns (width, height) — same for every index.
    pub fn item_size(&self, _index: usize) -> (f32, f32) {
        (self.width, self.height)
    }
}

/// Aspect-ratio sizing: all items share a width; height is computed from aspect ratio.
pub struct AspectRatioSizing {
    pub width: f32,
    /// aspect_ratio = width / height
    pub aspect_ratio: f32,
}

impl AspectRatioSizing {
    pub fn new(width: f32, aspect_ratio: f32) -> Self {
        Self {
            width,
            aspect_ratio,
        }
    }

    /// Returns (width, height) where height = width / aspect_ratio.
    pub fn item_size(&self, _index: usize) -> (f32, f32) {
        let height = if self.aspect_ratio > 0.0 {
            self.width / self.aspect_ratio
        } else {
            0.0
        };
        (self.width, height)
    }
}

/// Variable sizing: each item can have a different size provided by a callback.
pub struct VariableSizing {
    get_size: Box<dyn Fn(usize) -> (f32, f32) + Send + Sync>,
}

impl VariableSizing {
    pub fn new<F>(get_size: F) -> Self
    where
        F: Fn(usize) -> (f32, f32) + Send + Sync + 'static,
    {
        Self {
            get_size: Box::new(get_size),
        }
    }

    /// Returns (width, height) from the callback for this index.
    pub fn item_size(&self, index: usize) -> (f32, f32) {
        (self.get_size)(index)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_uniform_sizing_same_for_all_indices() {
        let s = UniformSizing::new(200.0, 150.0);
        assert_eq!(s.item_size(0), (200.0, 150.0));
        assert_eq!(s.item_size(99), (200.0, 150.0));
        assert_eq!(s.item_size(1000), (200.0, 150.0));
    }

    #[test]
    fn test_aspect_ratio_sizing_computes_height() {
        // 16:9 ratio: width=160, height=90
        let s = AspectRatioSizing::new(160.0, 16.0 / 9.0);
        let (w, h) = s.item_size(0);
        assert_eq!(w, 160.0);
        assert!((h - 90.0).abs() < 0.1, "h={h}");
    }

    #[test]
    fn test_aspect_ratio_sizing_zero_ratio_returns_zero_height() {
        let s = AspectRatioSizing::new(200.0, 0.0);
        let (_, h) = s.item_size(0);
        assert_eq!(h, 0.0);
    }

    #[test]
    fn test_aspect_ratio_sizing_same_for_all_indices() {
        let s = AspectRatioSizing::new(200.0, 2.0);
        assert_eq!(s.item_size(0), s.item_size(50));
    }

    #[test]
    fn test_variable_sizing_returns_callback_result() {
        let s = VariableSizing::new(|i| ((i as f32 + 1.0) * 10.0, 50.0));
        assert_eq!(s.item_size(0), (10.0, 50.0));
        assert_eq!(s.item_size(4), (50.0, 50.0));
        assert_eq!(s.item_size(9), (100.0, 50.0));
    }

    #[test]
    fn test_variable_sizing_different_per_index() {
        let s = VariableSizing::new(|i| (i as f32 * 20.0, 100.0));
        assert_ne!(s.item_size(1), s.item_size(2));
    }
}
