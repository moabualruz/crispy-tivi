//! PIN hashing utilities using SHA-256.
//!
//! Ports `PinHasher` from
//! `lib/features/parental/data/pin_hasher.dart` to Rust.

use sha2::{Digest, Sha256};

/// Hash a PIN using SHA-256.
/// Returns lowercase hex string (64 chars).
pub fn hash_pin(pin: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(pin.as_bytes());
    let result = hasher.finalize();
    result.iter().map(|b| format!("{:02x}", b)).collect()
}

/// Verify a PIN against a stored SHA-256 hash.
pub fn verify_pin(input_pin: &str, stored_hash: &str) -> bool {
    hash_pin(input_pin) == stored_hash
}

/// Check if a value looks like a SHA-256 hash
/// (64 hex characters).
pub fn is_hashed_pin(value: &str) -> bool {
    value.len() == 64 && value.chars().all(|c| c.is_ascii_hexdigit())
}

/// Check if a PIN lockout is currently active.
///
/// Returns `true` if `now_ms` is strictly before `locked_until_ms`,
/// meaning the lockout period has not yet expired.
/// Returns `false` if `locked_until_ms` is zero or negative (no lockout).
pub fn is_lock_active(locked_until_ms: i64, now_ms: i64) -> bool {
    if locked_until_ms <= 0 {
        return false;
    }
    now_ms < locked_until_ms
}

/// Return the number of milliseconds remaining in a PIN lockout.
///
/// Returns `max(0, locked_until_ms - now_ms)`.
/// Returns `0` if `locked_until_ms` is zero or negative (no lockout).
pub fn lock_remaining_ms(locked_until_ms: i64, now_ms: i64) -> i64 {
    if locked_until_ms <= 0 {
        return 0;
    }
    (locked_until_ms - now_ms).max(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// SHA-256("1234") is a well-known value.
    #[test]
    fn hash_pin_known_value() {
        // SHA-256 of "1234" (UTF-8 bytes).
        let expected = "03ac674216f3e15c76\
            1ee1a5e255f067953623c8b388b4459e13f978d7c846f4";
        assert_eq!(hash_pin("1234"), expected);
    }

    #[test]
    fn verify_pin_returns_true_for_match() {
        let hash = hash_pin("5678");
        assert!(verify_pin("5678", &hash));
    }

    #[test]
    fn verify_pin_returns_false_for_mismatch() {
        let hash = hash_pin("5678");
        assert!(!verify_pin("9999", &hash));
    }

    #[test]
    fn is_hashed_pin_true_for_64_hex() {
        let hash = hash_pin("0000");
        assert!(is_hashed_pin(&hash));
    }

    #[test]
    fn is_hashed_pin_false_for_non_hash() {
        // Too short.
        assert!(!is_hashed_pin("1234"));
        // Plaintext PIN.
        assert!(!is_hashed_pin("mypin"));
        // Right length but contains non-hex 'g'.
        let non_hex = "g".repeat(64);
        assert!(!is_hashed_pin(&non_hex));
        // Empty string.
        assert!(!is_hashed_pin(""));
    }

    // --- is_lock_active tests ---

    #[test]
    fn is_lock_active_returns_true_when_now_before_locked_until() {
        assert!(is_lock_active(1_000, 500));
    }

    #[test]
    fn is_lock_active_returns_false_when_now_equals_locked_until() {
        assert!(!is_lock_active(1_000, 1_000));
    }

    #[test]
    fn is_lock_active_returns_false_when_now_after_locked_until() {
        assert!(!is_lock_active(1_000, 2_000));
    }

    #[test]
    fn is_lock_active_returns_false_when_locked_until_is_zero() {
        assert!(!is_lock_active(0, 500));
    }

    #[test]
    fn is_lock_active_returns_false_when_locked_until_is_negative() {
        assert!(!is_lock_active(-1, 0));
    }

    // --- lock_remaining_ms tests ---

    #[test]
    fn lock_remaining_ms_returns_remaining_when_lock_active() {
        assert_eq!(lock_remaining_ms(1_000, 600), 400);
    }

    #[test]
    fn lock_remaining_ms_returns_zero_when_lock_expired() {
        assert_eq!(lock_remaining_ms(1_000, 2_000), 0);
    }

    #[test]
    fn lock_remaining_ms_returns_zero_when_locked_until_is_zero() {
        assert_eq!(lock_remaining_ms(0, 500), 0);
    }

    #[test]
    fn lock_remaining_ms_returns_zero_when_locked_until_is_negative() {
        assert_eq!(lock_remaining_ms(-500, 100), 0);
    }
}
