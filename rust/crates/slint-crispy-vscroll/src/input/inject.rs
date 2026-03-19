//! Software input injection queue (Task 4).
//!
//! Allows programmatic scrolling commands to be enqueued and drained
//! at tick time, enabling smooth animated scroll-to-index operations.

use crate::core::types::NavDirection;

// ---------------------------------------------------------------------------
// InjectCommand
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq)]
pub enum InjectCommand {
    /// Scroll by a pixel delta.
    ScrollBy(f32),
    /// Scroll to an absolute position.
    ScrollTo(f32),
    /// Navigate in a direction (D-pad style).
    Navigate(NavDirection),
    /// Jump focus to a specific index.
    FocusIndex(usize),
    /// Stop all ongoing animation immediately.
    StopAll,
}

// ---------------------------------------------------------------------------
// InjectQueue (Task 4)
// ---------------------------------------------------------------------------

pub struct InjectQueue {
    commands: Vec<InjectCommand>,
}

impl InjectQueue {
    pub fn new() -> Self {
        Self {
            commands: Vec::new(),
        }
    }

    /// Enqueue a command to be processed on the next tick.
    pub fn push(&mut self, cmd: InjectCommand) {
        self.commands.push(cmd);
    }

    /// Drain all pending commands (call once per tick).
    pub fn drain(&mut self) -> Vec<InjectCommand> {
        std::mem::take(&mut self.commands)
    }

    /// Returns true if there are pending commands.
    pub fn is_empty(&self) -> bool {
        self.commands.is_empty()
    }

    /// Number of pending commands.
    pub fn len(&self) -> usize {
        self.commands.len()
    }

    /// Clear all pending commands without processing them.
    pub fn clear(&mut self) {
        self.commands.clear();
    }
}

impl Default for InjectQueue {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_inject_queue_starts_empty() {
        let q = InjectQueue::new();
        assert!(q.is_empty());
        assert_eq!(q.len(), 0);
    }

    #[test]
    fn test_push_increases_len() {
        let mut q = InjectQueue::new();
        q.push(InjectCommand::ScrollBy(100.0));
        assert_eq!(q.len(), 1);
        assert!(!q.is_empty());
    }

    #[test]
    fn test_drain_returns_all_commands_in_order() {
        let mut q = InjectQueue::new();
        q.push(InjectCommand::ScrollBy(100.0));
        q.push(InjectCommand::Navigate(NavDirection::Down));
        q.push(InjectCommand::FocusIndex(5));
        let drained = q.drain();
        assert_eq!(drained.len(), 3);
        assert_eq!(drained[0], InjectCommand::ScrollBy(100.0));
        assert_eq!(drained[1], InjectCommand::Navigate(NavDirection::Down));
        assert_eq!(drained[2], InjectCommand::FocusIndex(5));
    }

    #[test]
    fn test_drain_empties_queue() {
        let mut q = InjectQueue::new();
        q.push(InjectCommand::ScrollTo(500.0));
        let _ = q.drain();
        assert!(q.is_empty());
    }

    #[test]
    fn test_clear_empties_without_draining() {
        let mut q = InjectQueue::new();
        q.push(InjectCommand::StopAll);
        q.push(InjectCommand::ScrollBy(50.0));
        q.clear();
        assert!(q.is_empty());
    }

    #[test]
    fn test_multiple_drain_calls_safe() {
        let mut q = InjectQueue::new();
        let first = q.drain();
        assert!(first.is_empty());
        let second = q.drain();
        assert!(second.is_empty());
    }

    #[test]
    fn test_push_after_drain() {
        let mut q = InjectQueue::new();
        q.push(InjectCommand::ScrollBy(10.0));
        let _ = q.drain();
        q.push(InjectCommand::ScrollTo(200.0));
        assert_eq!(q.len(), 1);
        let drained = q.drain();
        assert_eq!(drained[0], InjectCommand::ScrollTo(200.0));
    }

    #[test]
    fn test_default_creates_empty_queue() {
        let q = InjectQueue::default();
        assert!(q.is_empty());
    }

    #[test]
    fn test_inject_navigate_command() {
        let mut q = InjectQueue::new();
        q.push(InjectCommand::Navigate(NavDirection::Right));
        let drained = q.drain();
        assert_eq!(drained[0], InjectCommand::Navigate(NavDirection::Right));
    }

    #[test]
    fn test_inject_stop_all_command() {
        let mut q = InjectQueue::new();
        q.push(InjectCommand::StopAll);
        let drained = q.drain();
        assert_eq!(drained[0], InjectCommand::StopAll);
    }
}
