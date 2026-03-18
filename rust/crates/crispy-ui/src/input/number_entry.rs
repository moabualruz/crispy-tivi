//! Number key accumulator for direct channel tuning.
//!
//! Digit presses are accumulated up to `MAX_DIGITS` (4). The entry is
//! considered complete when either `MAX_DIGITS` are pressed or the
//! 2-second inactivity timeout is detected via [`NumberEntry::tick`].
//!
//! This module is intentionally free of async / timers so it can be driven
//! by either a Slint timer callback or a test harness.

use std::time::{Duration, Instant};

/// Maximum digits before the entry auto-completes.
const MAX_DIGITS: usize = 4;

/// Inactivity window — entry completes after this much silence.
const TIMEOUT: Duration = Duration::from_secs(2);

// ── NumberEntryState ──────────────────────────────────────────────────────────

/// Snapshot returned after every digit press or tick.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NumberEntryState {
    /// Digits accumulated so far (e.g. `"12"`).
    pub digits: String,
    /// `true` when the entry is finished and the channel number is ready.
    pub is_complete: bool,
}

// ── NumberEntry ───────────────────────────────────────────────────────────────

/// Stateful digit accumulator.
pub struct NumberEntry {
    digits: String,
    last_press: Option<Instant>,
}

impl NumberEntry {
    pub fn new() -> Self {
        Self {
            digits: String::new(),
            last_press: None,
        }
    }

    /// Record a single digit press.
    ///
    /// Panics in debug mode if `digit > 9`.
    pub fn press(&mut self, digit: u8) -> NumberEntryState {
        debug_assert!(digit <= 9, "digit must be 0–9");

        self.digits
            .push(char::from_digit(digit as u32, 10).unwrap_or('0'));
        self.last_press = Some(Instant::now());

        let is_complete = self.digits.len() >= MAX_DIGITS;
        if is_complete {
            // Keep digits for the caller to read; caller must call reset().
        }
        NumberEntryState {
            digits: self.digits.clone(),
            is_complete,
        }
    }

    /// Drive the timeout check.  Call this from a periodic timer.
    ///
    /// Returns `Some(state)` when the timeout has elapsed and there are
    /// accumulated digits.  Returns `None` if nothing has changed.
    pub fn tick(&self) -> Option<NumberEntryState> {
        if self.digits.is_empty() {
            return None;
        }
        let elapsed = self
            .last_press
            .map(|t| t.elapsed())
            .unwrap_or(Duration::ZERO);

        if elapsed >= TIMEOUT {
            Some(NumberEntryState {
                digits: self.digits.clone(),
                is_complete: true,
            })
        } else {
            None
        }
    }

    /// Reset accumulator after the entry has been consumed.
    pub fn reset(&mut self) {
        self.digits.clear();
        self.last_press = None;
    }

    /// Current accumulated digits (may be empty).
    pub fn current(&self) -> &str {
        &self.digits
    }

    /// Number of accumulated digits.
    pub fn len(&self) -> usize {
        self.digits.len()
    }

    /// `true` when no digits have been pressed since the last reset.
    pub fn is_empty(&self) -> bool {
        self.digits.is_empty()
    }
}

impl Default for NumberEntry {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_press_single_digit_not_complete() {
        let mut ne = NumberEntry::new();
        let state = ne.press(5);
        assert_eq!(state.digits, "5");
        assert!(!state.is_complete);
    }

    #[test]
    fn test_press_accumulates_digits() {
        let mut ne = NumberEntry::new();
        ne.press(1);
        ne.press(2);
        let state = ne.press(3);
        assert_eq!(state.digits, "123");
        assert!(!state.is_complete);
    }

    #[test]
    fn test_press_4_digits_completes() {
        let mut ne = NumberEntry::new();
        ne.press(1);
        ne.press(2);
        ne.press(3);
        let state = ne.press(4);
        assert_eq!(state.digits, "1234");
        assert!(state.is_complete);
    }

    #[test]
    fn test_reset_clears_state() {
        let mut ne = NumberEntry::new();
        ne.press(7);
        ne.reset();
        assert!(ne.is_empty());
        assert_eq!(ne.current(), "");
    }

    #[test]
    fn test_tick_returns_none_when_empty() {
        let ne = NumberEntry::new();
        assert!(ne.tick().is_none());
    }

    #[test]
    fn test_tick_returns_none_before_timeout() {
        let mut ne = NumberEntry::new();
        ne.press(3);
        // Immediately after press — elapsed < 2s
        assert!(ne.tick().is_none());
    }

    #[test]
    fn test_tick_returns_complete_after_timeout() {
        use std::time::Duration;
        // Simulate timeout by manipulating last_press to the past
        let mut ne = NumberEntry::new();
        ne.press(4);
        // Override last_press to simulate 3s ago
        ne.last_press = Some(Instant::now() - Duration::from_secs(3));
        let result = ne.tick().unwrap();
        assert_eq!(result.digits, "4");
        assert!(result.is_complete);
    }

    #[test]
    fn test_max_digits_is_4() {
        assert_eq!(MAX_DIGITS, 4);
    }

    #[test]
    fn test_press_zero_digit() {
        let mut ne = NumberEntry::new();
        let state = ne.press(0);
        assert_eq!(state.digits, "0");
    }

    #[test]
    fn test_len_tracks_digit_count() {
        let mut ne = NumberEntry::new();
        ne.press(1);
        ne.press(2);
        assert_eq!(ne.len(), 2);
    }
}
