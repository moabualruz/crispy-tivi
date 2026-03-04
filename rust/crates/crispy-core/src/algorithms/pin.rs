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
}
