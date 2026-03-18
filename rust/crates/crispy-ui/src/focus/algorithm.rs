//! Nearest-neighbour spatial focus algorithm.
//!
//! Scoring: `primary_distance * 3.0 + secondary_distance`
//! - Left/Right: primary = horizontal gap, secondary = vertical offset
//! - Up/Down:    primary = vertical gap,   secondary = horizontal offset
//!
//! Candidates are filtered to those that lie strictly in the requested
//! direction from the current node's centre. No wrapping is performed.

use super::types::{Direction, FocusNode};

/// Find the index of the best candidate in `candidates` when navigating
/// `direction` from `current`.  Returns `None` when no candidate lies in
/// the requested direction.
pub fn find_nearest(
    current: &FocusNode,
    candidates: &[FocusNode],
    direction: Direction,
) -> Option<usize> {
    let cx = current.rect.center_x();
    let cy = current.rect.center_y();

    let mut best_index: Option<usize> = None;
    let mut best_score = f32::MAX;

    for (i, candidate) in candidates.iter().enumerate() {
        // Skip self
        if candidate.id == current.id {
            continue;
        }

        let tx = candidate.rect.center_x();
        let ty = candidate.rect.center_y();

        // Guard: candidate must be strictly in the requested direction.
        let in_direction = match direction {
            Direction::Left => tx < cx,
            Direction::Right => tx > cx,
            Direction::Up => ty < cy,
            Direction::Down => ty > cy,
        };

        if !in_direction {
            continue;
        }

        let score = match direction {
            Direction::Left | Direction::Right => {
                let primary = (tx - cx).abs();
                let secondary = (ty - cy).abs();
                primary * 3.0 + secondary
            }
            Direction::Up | Direction::Down => {
                let primary = (ty - cy).abs();
                let secondary = (tx - cx).abs();
                primary * 3.0 + secondary
            }
        };

        if score < best_score {
            best_score = score;
            best_index = Some(i);
        }
    }

    best_index
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::focus::types::{FocusNode, Rect};

    fn node(id: &str, x: f32, y: f32) -> FocusNode {
        FocusNode::new(id, "z", Rect::new(x, y, 10.0, 10.0))
    }

    // Helpers — centre of a 10×10 node is at (x+5, y+5)

    #[test]
    fn test_find_nearest_right_picks_closest_rightward_node() {
        let current = node("curr", 0.0, 0.0);
        let candidates = vec![node("far", 200.0, 0.0), node("close", 50.0, 0.0)];
        let idx = find_nearest(&current, &candidates, Direction::Right).unwrap();
        assert_eq!(candidates[idx].id, "close");
    }

    #[test]
    fn test_find_nearest_left_picks_closest_leftward_node() {
        let current = node("curr", 100.0, 0.0);
        let candidates = vec![node("far", 0.0, 0.0), node("close", 60.0, 0.0)];
        let idx = find_nearest(&current, &candidates, Direction::Left).unwrap();
        assert_eq!(candidates[idx].id, "close");
    }

    #[test]
    fn test_find_nearest_down_picks_closest_downward_node() {
        let current = node("curr", 0.0, 0.0);
        let candidates = vec![node("far", 0.0, 200.0), node("close", 0.0, 50.0)];
        let idx = find_nearest(&current, &candidates, Direction::Down).unwrap();
        assert_eq!(candidates[idx].id, "close");
    }

    #[test]
    fn test_find_nearest_up_picks_closest_upward_node() {
        let current = node("curr", 0.0, 100.0);
        let candidates = vec![node("far", 0.0, 0.0), node("close", 0.0, 60.0)];
        let idx = find_nearest(&current, &candidates, Direction::Up).unwrap();
        assert_eq!(candidates[idx].id, "close");
    }

    #[test]
    fn test_find_nearest_returns_none_when_no_candidate_in_direction() {
        let current = node("curr", 100.0, 100.0);
        // All candidates are to the right — none to the left
        let candidates = vec![node("a", 150.0, 100.0), node("b", 200.0, 100.0)];
        assert!(find_nearest(&current, &candidates, Direction::Left).is_none());
    }

    #[test]
    fn test_find_nearest_single_candidate_in_direction() {
        let current = node("curr", 0.0, 0.0);
        let candidates = vec![node("only", 80.0, 0.0)];
        let idx = find_nearest(&current, &candidates, Direction::Right).unwrap();
        assert_eq!(idx, 0);
    }

    #[test]
    fn test_find_nearest_empty_candidates_returns_none() {
        let current = node("curr", 0.0, 0.0);
        assert!(find_nearest(&current, &[], Direction::Right).is_none());
    }

    #[test]
    fn test_find_nearest_skips_self_when_self_in_candidates() {
        let current = node("curr", 0.0, 0.0);
        // Same id included — should be skipped, leaving only "other"
        let candidates = vec![node("curr", 0.0, 0.0), node("other", 60.0, 0.0)];
        let idx = find_nearest(&current, &candidates, Direction::Right).unwrap();
        assert_eq!(candidates[idx].id, "other");
    }

    #[test]
    fn test_find_nearest_prefers_aligned_over_diagonal_with_3to1_weight() {
        // "aligned" is further away horizontally but perfectly aligned vertically.
        // "diagonal" is closer horizontally but has significant vertical offset.
        // Score aligned:  (100-0)*3 + 0   = 300
        // Score diagonal: (40-0)*3  + 80  = 200  → diagonal wins (lower score)
        // This confirms the 3:1 weighting in action.
        let current = node("curr", 0.0, 0.0);
        // centres: curr=(5,5), aligned=(105,5), diagonal=(45,85)
        let aligned = FocusNode::new("aligned", "z", Rect::new(100.0, 0.0, 10.0, 10.0));
        let diagonal = FocusNode::new("diagonal", "z", Rect::new(40.0, 80.0, 10.0, 10.0));
        let candidates = vec![aligned, diagonal];
        let idx = find_nearest(&current, &candidates, Direction::Right).unwrap();
        assert_eq!(candidates[idx].id, "diagonal");
    }
}
