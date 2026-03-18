//! FocusManager — owns all zones, tracks active focus, manages modal stack.
//!
//! All navigation state lives here; Slint only receives the resulting focused
//! node ID via callbacks.

use std::collections::HashMap;

use super::algorithm::find_nearest;
use super::types::{Direction, FocusNode, FocusZone};

/// Central focus controller for the application.
pub struct FocusManager {
    /// All registered zones keyed by zone ID.
    zones: HashMap<String, FocusZone>,
    /// The currently active zone ID.
    active_zone: String,
    /// The ID of the currently focused node (if any).
    focused_node: Option<String>,
    /// Stack of zone IDs pushed by modal dialogs.
    /// The top of the stack is the zone that was active before the modal.
    modal_stack: Vec<String>,
}

impl FocusManager {
    /// Create a new manager. `default_zone` becomes the initial active zone.
    pub fn new(default_zone: impl Into<String>) -> Self {
        let id = default_zone.into();
        let mut zones = HashMap::new();
        zones.insert(id.clone(), FocusZone::new(id.clone()));
        Self {
            zones,
            active_zone: id,
            focused_node: None,
            modal_stack: Vec::new(),
        }
    }

    // ── Zone registration ─────────────────────────────────────────────────

    /// Register a pre-built zone. Replaces any existing zone with the same ID.
    pub fn register_zone(&mut self, zone: FocusZone) {
        self.zones.insert(zone.id.clone(), zone);
    }

    /// Register a node into an existing zone.
    /// If the zone does not exist it is created automatically.
    pub fn register_node(&mut self, zone_id: &str, node: FocusNode) {
        let zone = self
            .zones
            .entry(zone_id.to_string())
            .or_insert_with(|| FocusZone::new(zone_id));
        zone.nodes.push(node);
    }

    // ── Zone switching ────────────────────────────────────────────────────

    /// Switch the active zone and restore the last focused node in that zone.
    /// Returns the restored focused node ID, if any.
    pub fn set_active_zone(&mut self, zone_id: &str) -> Option<String> {
        if !self.zones.contains_key(zone_id) {
            return None;
        }
        self.active_zone = zone_id.to_string();
        // Restore last focused node in this zone
        let restored = self
            .zones
            .get(zone_id)
            .and_then(|z| z.last_focused_index.and_then(|i| z.nodes.get(i)))
            .map(|n| n.id.clone());
        self.focused_node = restored.clone();
        restored
    }

    // ── Navigation ───────────────────────────────────────────────────────

    /// Navigate in `direction` within the active zone.
    ///
    /// Updates `focused_node` and the zone's `last_focused_index`.
    /// Returns the new node ID, or `None` if there is nowhere to go.
    pub fn navigate(&mut self, direction: Direction) -> Option<String> {
        let effective_zone = self.effective_zone();

        let zone = self.zones.get(&effective_zone)?;

        // Determine the current node — fall back to last focused, then first node.
        let current_id = self.focused_node.clone().or_else(|| {
            zone.last_focused_index
                .and_then(|i| zone.nodes.get(i).map(|n| n.id.clone()))
                .or_else(|| zone.nodes.first().map(|n| n.id.clone()))
        })?;

        let current = zone.nodes.iter().find(|n| n.id == current_id)?;

        let new_idx = find_nearest(current, &zone.nodes, direction)?;

        let new_id = zone.nodes[new_idx].id.clone();

        // Persist focus memory
        if let Some(z) = self.zones.get_mut(&effective_zone) {
            z.last_focused_index = Some(new_idx);
        }
        self.focused_node = Some(new_id.clone());

        Some(new_id)
    }

    // ── Node lookup ───────────────────────────────────────────────────────

    /// Return a reference to the currently focused node.
    pub fn get_focused_node(&self) -> Option<&FocusNode> {
        let id = self.focused_node.as_ref()?;
        let zone = self.zones.get(&self.effective_zone())?;
        zone.nodes.iter().find(|n| &n.id == id)
    }

    // ── Modal stack ───────────────────────────────────────────────────────

    /// Trap focus inside `zone_id`. The current active zone is pushed to the
    /// stack so it can be restored by `pop_modal`.
    pub fn push_modal(&mut self, zone_id: &str) {
        self.modal_stack.push(self.active_zone.clone());
        self.active_zone = zone_id.to_string();
        // Restore last focus inside the modal zone
        let restored = self
            .zones
            .get(zone_id)
            .and_then(|z| z.last_focused_index.and_then(|i| z.nodes.get(i)))
            .map(|n| n.id.clone());
        self.focused_node = restored;
    }

    /// Pop the modal — restores the previous zone and its last focused node.
    /// Returns the restored focused node ID, if any.
    pub fn pop_modal(&mut self) -> Option<String> {
        let previous_zone = self.modal_stack.pop()?;
        self.active_zone = previous_zone.clone();
        let restored = self
            .zones
            .get(&previous_zone)
            .and_then(|z| z.last_focused_index.and_then(|i| z.nodes.get(i)))
            .map(|n| n.id.clone());
        self.focused_node = restored.clone();
        restored
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    /// The zone that navigation should operate in (respects modal stack).
    fn effective_zone(&self) -> String {
        self.active_zone.clone()
    }

    /// Expose the active zone ID for inspection/testing.
    pub fn active_zone_id(&self) -> &str {
        &self.active_zone
    }

    /// Expose the modal stack depth.
    pub fn modal_depth(&self) -> usize {
        self.modal_stack.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::focus::types::Rect;

    fn make_manager_with_nodes() -> FocusManager {
        // Layout: three nodes in a horizontal row inside zone "main"
        //   A(0,0) B(100,0) C(200,0)
        let mut mgr = FocusManager::new("main");
        mgr.register_node(
            "main",
            FocusNode::new("A", "main", Rect::new(0.0, 0.0, 10.0, 10.0)),
        );
        mgr.register_node(
            "main",
            FocusNode::new("B", "main", Rect::new(100.0, 0.0, 10.0, 10.0)),
        );
        mgr.register_node(
            "main",
            FocusNode::new("C", "main", Rect::new(200.0, 0.0, 10.0, 10.0)),
        );
        // Seed focus on A
        mgr.focused_node = Some("A".to_string());
        let zone = mgr.zones.get_mut("main").unwrap();
        zone.last_focused_index = Some(0);
        mgr
    }

    #[test]
    fn test_navigate_right_moves_focus() {
        let mut mgr = make_manager_with_nodes();
        let new_id = mgr.navigate(Direction::Right).unwrap();
        assert_eq!(new_id, "B");
    }

    #[test]
    fn test_navigate_left_from_b_returns_a() {
        let mut mgr = make_manager_with_nodes();
        mgr.navigate(Direction::Right); // now at B
        let id = mgr.navigate(Direction::Left).unwrap();
        assert_eq!(id, "A");
    }

    #[test]
    fn test_navigate_right_at_edge_returns_none() {
        let mut mgr = make_manager_with_nodes();
        mgr.navigate(Direction::Right); // A→B
        mgr.navigate(Direction::Right); // B→C
        // C is rightmost — no further right
        assert!(mgr.navigate(Direction::Right).is_none());
    }

    #[test]
    fn test_focus_memory_persisted_after_navigate() {
        let mut mgr = make_manager_with_nodes();
        mgr.navigate(Direction::Right); // focus B
        // Switch away then back
        mgr.register_zone(FocusZone::new("other"));
        mgr.set_active_zone("other");
        let restored = mgr.set_active_zone("main");
        assert_eq!(restored.unwrap(), "B");
    }

    #[test]
    fn test_get_focused_node_returns_current() {
        let mut mgr = make_manager_with_nodes();
        mgr.navigate(Direction::Right); // B
        assert_eq!(mgr.get_focused_node().unwrap().id, "B");
    }

    #[test]
    fn test_modal_push_traps_navigation_in_modal_zone() {
        let mut mgr = make_manager_with_nodes();
        // Register modal zone with two nodes side by side
        mgr.register_node(
            "modal",
            FocusNode::new("M1", "modal", Rect::new(0.0, 300.0, 10.0, 10.0)),
        );
        mgr.register_node(
            "modal",
            FocusNode::new("M2", "modal", Rect::new(100.0, 300.0, 10.0, 10.0)),
        );

        mgr.push_modal("modal");
        assert_eq!(mgr.active_zone_id(), "modal");
        assert_eq!(mgr.modal_depth(), 1);

        // Seed focus on M1
        mgr.focused_node = Some("M1".to_string());
        mgr.zones.get_mut("modal").unwrap().last_focused_index = Some(0);

        let id = mgr.navigate(Direction::Right).unwrap();
        assert_eq!(id, "M2");
    }

    #[test]
    fn test_modal_pop_restores_previous_zone() {
        let mut mgr = make_manager_with_nodes();
        mgr.register_node(
            "modal",
            FocusNode::new("M1", "modal", Rect::new(0.0, 300.0, 10.0, 10.0)),
        );
        mgr.push_modal("modal");
        mgr.pop_modal();
        assert_eq!(mgr.active_zone_id(), "main");
        assert_eq!(mgr.modal_depth(), 0);
    }

    #[test]
    fn test_pop_modal_on_empty_stack_returns_none() {
        let mut mgr = make_manager_with_nodes();
        assert!(mgr.pop_modal().is_none());
    }

    #[test]
    fn test_register_node_auto_creates_zone() {
        let mut mgr = FocusManager::new("main");
        mgr.register_node(
            "new-zone",
            FocusNode::new("X", "new-zone", Rect::new(0.0, 0.0, 10.0, 10.0)),
        );
        assert!(mgr.zones.contains_key("new-zone"));
    }
}
