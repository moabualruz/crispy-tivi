//! Core spatial focus types: FocusNode, FocusZone, Rect, Direction.

/// Axis-aligned bounding rectangle for a focusable UI element.
#[derive(Debug, Clone, PartialEq)]
pub struct Rect {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

impl Rect {
    pub fn new(x: f32, y: f32, width: f32, height: f32) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }

    /// Centre point on the horizontal axis.
    pub fn center_x(&self) -> f32 {
        self.x + self.width * 0.5
    }

    /// Centre point on the vertical axis.
    pub fn center_y(&self) -> f32 {
        self.y + self.height * 0.5
    }
}

/// A single focusable element within a zone.
#[derive(Debug, Clone)]
pub struct FocusNode {
    /// Unique identifier for this node (unique across the whole app).
    pub id: String,
    /// The zone this node belongs to.
    pub zone_id: String,
    /// Screen-space bounding rect.
    pub rect: Rect,
}

impl FocusNode {
    pub fn new(id: impl Into<String>, zone_id: impl Into<String>, rect: Rect) -> Self {
        Self {
            id: id.into(),
            zone_id: zone_id.into(),
            rect,
        }
    }
}

/// A named group of focusable nodes (e.g., "nav-bar", "content-list", "modal").
#[derive(Debug, Default)]
pub struct FocusZone {
    /// Unique identifier for this zone.
    pub id: String,
    /// All nodes registered in this zone.
    pub nodes: Vec<FocusNode>,
    /// Index into `nodes` of the most recently focused node.
    pub last_focused_index: Option<usize>,
}

impl FocusZone {
    pub fn new(id: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            nodes: Vec::new(),
            last_focused_index: None,
        }
    }
}

/// Directional navigation intent from a D-Pad or keyboard.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rect_center_x_returns_midpoint() {
        let r = Rect::new(10.0, 20.0, 100.0, 50.0);
        assert_eq!(r.center_x(), 60.0);
    }

    #[test]
    fn test_rect_center_y_returns_midpoint() {
        let r = Rect::new(10.0, 20.0, 100.0, 50.0);
        assert_eq!(r.center_y(), 45.0);
    }

    #[test]
    fn test_focus_node_new_sets_fields() {
        let n = FocusNode::new("btn-1", "zone-a", Rect::new(0.0, 0.0, 50.0, 30.0));
        assert_eq!(n.id, "btn-1");
        assert_eq!(n.zone_id, "zone-a");
    }

    #[test]
    fn test_focus_zone_default_has_no_nodes() {
        let z = FocusZone::new("nav");
        assert!(z.nodes.is_empty());
        assert!(z.last_focused_index.is_none());
    }
}
