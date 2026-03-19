//! PIN hashing utilities.
//!
//! Provides both legacy SHA-256 hashing (kept for transparent migration) and
//! the current Argon2id hashing (m=19456, t=2, p=1, random 16-byte salt).
//!
//! Ports `PinHasher` from
//! `lib/features/parental/data/pin_hasher.dart` to Rust.

use argon2::password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString};
use argon2::{Algorithm, Argon2, Params, Version};
use rand_core::OsRng;
use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;

use crate::errors::CrispyError;

// ── Argon2id parameters ───────────────────────────────────────────────────────

/// Memory cost: 19 MiB (OWASP minimum for Argon2id).
const ARGON2_M_COST: u32 = 19_456;
/// Time cost: 2 iterations.
const ARGON2_T_COST: u32 = 2;
/// Parallelism: 1 lane.
const ARGON2_P_COST: u32 = 1;

/// Build the project-standard `Argon2id` instance (m=19456, t=2, p=1).
fn argon2_instance() -> Argon2<'static> {
    let params = Params::new(ARGON2_M_COST, ARGON2_T_COST, ARGON2_P_COST, None)
        .expect("valid Argon2 params");
    Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
}

// ── Argon2id API ─────────────────────────────────────────────────────────────

/// Hash a PIN using Argon2id (m=19456, t=2, p=1) with a fresh random salt.
///
/// Returns a PHC-format string (`$argon2id$v=19$m=19456,t=2,p=1$...`) suitable
/// for storage in the `db_profiles.pin` column.
pub fn hash_pin_argon2id(pin: &str) -> Result<String, CrispyError> {
    let salt = SaltString::generate(&mut OsRng);
    let hash = argon2_instance()
        .hash_password(pin.as_bytes(), &salt)
        .map_err(|e| CrispyError::security(format!("PIN hashing failed: {e}")))?;
    Ok(hash.to_string())
}

/// Verify a PIN against a stored Argon2id PHC hash.
///
/// Uses constant-time comparison internally (argon2 crate guarantee).
/// Returns `Ok(false)` for a wrong PIN; `Err` only for a malformed hash.
pub fn verify_pin_argon2id(pin: &str, hash: &str) -> Result<bool, CrispyError> {
    let parsed = PasswordHash::new(hash)
        .map_err(|e| CrispyError::security(format!("Invalid stored hash: {e}")))?;
    match argon2_instance().verify_password(pin.as_bytes(), &parsed) {
        Ok(()) => Ok(true),
        Err(argon2::password_hash::Error::Password) => Ok(false),
        Err(e) => Err(CrispyError::security(format!(
            "PIN verification error: {e}"
        ))),
    }
}

/// Return `true` if `value` is an Argon2id PHC string (starts with `$argon2id$`).
pub fn is_argon2id_hash(value: &str) -> bool {
    value.starts_with("$argon2id$")
}

// ── Legacy SHA-256 API ────────────────────────────────────────────────────────

/// Hash a PIN using SHA-256 (legacy, unsalted).
///
/// Kept for transparent migration: call this to verify an old stored hash,
/// then immediately re-hash with [`hash_pin_argon2id`] and update the DB.
///
/// Returns lowercase hex string (64 chars).
pub fn hash_pin_legacy(pin: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(pin.as_bytes());
    let result = hasher.finalize();
    result.iter().map(|b| format!("{:02x}", b)).collect()
}

/// Verify a PIN against a stored SHA-256 hex hash (legacy).
///
/// Uses constant-time comparison to prevent timing attacks.
pub fn verify_pin_legacy(input_pin: &str, stored_hash: &str) -> bool {
    let computed = hash_pin_legacy(input_pin);
    computed.as_bytes().ct_eq(stored_hash.as_bytes()).into()
}

/// Return `true` if `value` looks like a raw SHA-256 hash (64 hex chars).
///
/// Used during migration to detect old-format stored PINs.
pub fn is_legacy_sha256_hash(value: &str) -> bool {
    value.len() == 64 && value.chars().all(|c| c.is_ascii_hexdigit())
}

// ── Compatibility shims (kept for call-sites that pre-date the migration) ─────

/// Hash a PIN using SHA-256.
///
/// **Deprecated**: use [`hash_pin_argon2id`] for new PINs.
/// Retained so existing call-sites continue to compile during migration.
pub fn hash_pin(pin: &str) -> String {
    hash_pin_legacy(pin)
}

/// Verify a PIN against a stored SHA-256 hash.
///
/// **Deprecated**: use [`verify_pin_argon2id`] / [`verify_pin_legacy`] via the
/// migration path in `PinSecurity`.
pub fn verify_pin(input_pin: &str, stored_hash: &str) -> bool {
    verify_pin_legacy(input_pin, stored_hash)
}

/// Check if a value looks like a SHA-256 hash (64 hex characters).
///
/// **Deprecated**: prefer [`is_legacy_sha256_hash`].
pub fn is_hashed_pin(value: &str) -> bool {
    is_legacy_sha256_hash(value)
}

// ── Lockout helpers ───────────────────────────────────────────────────────────

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

    // ── Argon2id tests ────────────────────────────────────────────────────────

    #[test]
    fn test_hash_argon2id_produces_phc_string() {
        let hash = hash_pin_argon2id("1234").unwrap();
        assert!(
            hash.starts_with("$argon2id$"),
            "expected PHC string, got: {hash}"
        );
    }

    #[test]
    fn test_hash_argon2id_includes_correct_params() {
        let hash = hash_pin_argon2id("1234").unwrap();
        // PHC string encodes params: m=19456,t=2,p=1
        assert!(
            hash.contains("m=19456"),
            "expected m=19456 in PHC string: {hash}"
        );
        assert!(hash.contains("t=2"), "expected t=2 in PHC string: {hash}");
        assert!(hash.contains("p=1"), "expected p=1 in PHC string: {hash}");
    }

    #[test]
    fn test_hash_argon2id_different_salt_each_time() {
        let h1 = hash_pin_argon2id("same-pin").unwrap();
        let h2 = hash_pin_argon2id("same-pin").unwrap();
        assert_ne!(
            h1, h2,
            "two hashes of the same PIN must differ (random salt)"
        );
    }

    #[test]
    fn test_verify_argon2id_correct_pin() {
        let hash = hash_pin_argon2id("9876").unwrap();
        assert!(verify_pin_argon2id("9876", &hash).unwrap());
    }

    #[test]
    fn test_verify_argon2id_wrong_pin() {
        let hash = hash_pin_argon2id("9876").unwrap();
        assert!(!verify_pin_argon2id("0000", &hash).unwrap());
    }

    #[test]
    fn test_verify_argon2id_constant_time_does_not_panic() {
        // Correct and incorrect paths must both complete without panic
        let hash = hash_pin_argon2id("5555").unwrap();
        let _ = verify_pin_argon2id("5555", &hash).unwrap();
        let _ = verify_pin_argon2id("9999", &hash).unwrap();
    }

    #[test]
    fn test_pin_roundtrip_argon2id() {
        for pin in &["0000", "1234", "9999", "abcd", "!@#$"] {
            let hash = hash_pin_argon2id(pin).unwrap();
            assert!(
                verify_pin_argon2id(pin, &hash).unwrap(),
                "roundtrip failed for pin: {pin}"
            );
        }
    }

    #[test]
    fn test_empty_pin_handled() {
        // Empty string is a valid (if weak) PIN — must not panic or error
        let hash = hash_pin_argon2id("").unwrap();
        assert!(verify_pin_argon2id("", &hash).unwrap());
        assert!(!verify_pin_argon2id("x", &hash).unwrap());
    }

    // ── is_argon2id_hash / is_legacy_sha256_hash ──────────────────────────────

    #[test]
    fn test_migration_detects_argon2id_hash() {
        let hash = hash_pin_argon2id("1234").unwrap();
        assert!(is_argon2id_hash(&hash));
        assert!(!is_legacy_sha256_hash(&hash));
    }

    #[test]
    fn test_migration_detects_legacy_hash() {
        let hash = hash_pin_legacy("1234");
        assert!(is_legacy_sha256_hash(&hash));
        assert!(!is_argon2id_hash(&hash));
    }

    // ── Legacy SHA-256 tests ──────────────────────────────────────────────────

    #[test]
    fn test_legacy_sha256_still_verifies() {
        // SHA-256("1234") well-known value
        let expected = "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4";
        assert_eq!(hash_pin_legacy("1234"), expected);
        assert!(verify_pin_legacy("1234", expected));
        assert!(!verify_pin_legacy("wrong", expected));
    }

    // ── Compatibility shim tests ──────────────────────────────────────────────

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

    // ── is_lock_active tests ──────────────────────────────────────────────────

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

    // ── lock_remaining_ms tests ───────────────────────────────────────────────

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
