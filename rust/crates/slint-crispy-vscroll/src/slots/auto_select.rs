//! Auto-select integrity mode based on runtime capabilities (Task 7).

use crate::core::config::IntegrityMode;

/// Choose the best IntegrityMode automatically.
///
/// - Touch devices with double-buffer preference → DoubleBuffer
/// - Touch devices (no preference) → AsyncAck  
/// - Non-touch (mouse/D-pad) → Sync
pub fn auto_select_integrity(has_touch: bool, double_buffer_preferred: bool) -> IntegrityMode {
    if has_touch && double_buffer_preferred {
        IntegrityMode::DoubleBuffer
    } else if has_touch {
        IntegrityMode::AsyncAck
    } else {
        IntegrityMode::Sync
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_touch_selects_sync() {
        assert_eq!(auto_select_integrity(false, false), IntegrityMode::Sync);
    }

    #[test]
    fn test_touch_selects_async_ack() {
        assert_eq!(auto_select_integrity(true, false), IntegrityMode::AsyncAck);
    }

    #[test]
    fn test_touch_with_double_buffer_preferred() {
        assert_eq!(
            auto_select_integrity(true, true),
            IntegrityMode::DoubleBuffer
        );
    }
}
