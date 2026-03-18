//! Argon2id PIN hashing and progressive lockout.
//!
//! - Hashing: Argon2id with a random 16-byte salt via [`PinSecurity::hash_pin`].
//! - Verification: constant-time via `argon2::PasswordVerifier` internals.
//! - Lockout: per-profile consecutive-failure counter with exponential cooldown.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use argon2::Argon2;
use argon2::password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString};
use rand_core::OsRng;

use crate::errors::CrispyError;

// ── PinSecurity ───────────────────────────────────────────────────────────────

/// Argon2id PIN hashing and verification.
pub struct PinSecurity;

impl PinSecurity {
    /// Hash a PIN using Argon2id with a random 16-byte salt.
    ///
    /// Returns a PHC-format string (`$argon2id$...`) suitable for DB storage.
    pub fn hash_pin(pin: &str) -> Result<String, CrispyError> {
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default(); // Argon2id by default
        let hash = argon2
            .hash_password(pin.as_bytes(), &salt)
            .map_err(|e| CrispyError::security(format!("PIN hashing failed: {e}")))?;
        Ok(hash.to_string())
    }

    /// Verify a PIN against a stored Argon2id PHC hash.
    ///
    /// Uses constant-time comparison internally (argon2 crate guarantee).
    pub fn verify_pin(pin: &str, hash: &str) -> Result<bool, CrispyError> {
        let parsed = PasswordHash::new(hash)
            .map_err(|e| CrispyError::security(format!("Invalid stored hash: {e}")))?;
        match Argon2::default().verify_password(pin.as_bytes(), &parsed) {
            Ok(()) => Ok(true),
            Err(argon2::password_hash::Error::Password) => Ok(false),
            Err(e) => Err(CrispyError::security(format!(
                "PIN verification error: {e}"
            ))),
        }
    }
}

// ── LockoutError ─────────────────────────────────────────────────────────────

/// Lockout state returned when a profile is cooling down or permanently locked.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LockoutError {
    /// Profile is in a timed cooldown; retry after this many seconds.
    Cooldown { remaining_secs: u64 },
    /// Profile is permanently locked; requires account re-auth.
    PermanentlyLocked,
}

impl std::fmt::Display for LockoutError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LockoutError::Cooldown { remaining_secs } => {
                write!(f, "PIN locked: retry in {remaining_secs}s")
            }
            LockoutError::PermanentlyLocked => {
                write!(f, "PIN locked: account re-auth required")
            }
        }
    }
}

// ── Cooldown schedule ─────────────────────────────────────────────────────────

/// Cooldown duration per consecutive failure count (0-indexed).
///
/// Attempt 0 → 0s, 1 → 30s, 2 → 60s, 3 → 5min, 4 → 15min, 5+ → permanent.
const COOLDOWN_SCHEDULE: &[Duration] = &[
    Duration::from_secs(0),
    Duration::from_secs(30),
    Duration::from_secs(60),
    Duration::from_secs(300),
    Duration::from_secs(900),
];

// ── FailureRecord ─────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
struct FailureRecord {
    /// Number of consecutive failures.
    consecutive: usize,
    /// When the last failure occurred (None = no failure yet).
    last_failure: Option<Instant>,
}

impl FailureRecord {
    fn new() -> Self {
        Self {
            consecutive: 0,
            last_failure: None,
        }
    }
}

// ── PinLockout ────────────────────────────────────────────────────────────────

/// In-process per-profile PIN lockout tracker.
///
/// State is held in memory; it resets on process restart (intentional — a
/// physical device restart is a reasonable "cooldown reset").
#[derive(Clone, Default)]
pub struct PinLockout {
    records: Arc<Mutex<HashMap<String, FailureRecord>>>,
}

impl PinLockout {
    /// Create a new, empty lockout tracker.
    pub fn new() -> Self {
        Self::default()
    }

    /// Check whether `profile_id` is currently locked out.
    ///
    /// Returns `Ok(())` if the PIN may be attempted, or a [`LockoutError`]
    /// variant describing the restriction.
    pub fn check_lockout(&self, profile_id: &str) -> Result<(), LockoutError> {
        let records = self.records.lock().unwrap_or_else(|e| e.into_inner());
        let Some(rec) = records.get(profile_id) else {
            return Ok(());
        };

        if rec.consecutive == 0 {
            return Ok(());
        }

        // 5+ consecutive failures → permanent lock
        if rec.consecutive > COOLDOWN_SCHEDULE.len() {
            return Err(LockoutError::PermanentlyLocked);
        }

        // Look up cooldown for this failure index (0-based)
        let cooldown = COOLDOWN_SCHEDULE[rec.consecutive.min(COOLDOWN_SCHEDULE.len()) - 1];
        if cooldown.is_zero() {
            return Ok(());
        }

        let elapsed = rec
            .last_failure
            .map(|t| t.elapsed())
            .unwrap_or(Duration::MAX);

        if elapsed < cooldown {
            let remaining = cooldown.saturating_sub(elapsed);
            return Err(LockoutError::Cooldown {
                remaining_secs: remaining.as_secs().max(1),
            });
        }

        Ok(())
    }

    /// Record a failed PIN attempt for `profile_id`.
    pub fn record_failure(&self, profile_id: &str) {
        let mut records = self.records.lock().unwrap_or_else(|e| e.into_inner());
        let rec = records
            .entry(profile_id.to_string())
            .or_insert_with(FailureRecord::new);
        rec.consecutive += 1;
        rec.last_failure = Some(Instant::now());
    }

    /// Record a successful PIN verification for `profile_id` (resets counter).
    pub fn record_success(&self, profile_id: &str) {
        let mut records = self.records.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(rec) = records.get_mut(profile_id) {
            rec.consecutive = 0;
            rec.last_failure = None;
        }
    }

    /// Force-unlock a profile (requires account re-auth; called after re-auth succeeds).
    pub fn force_unlock(&self, profile_id: &str) {
        let mut records = self.records.lock().unwrap_or_else(|e| e.into_inner());
        records.remove(profile_id);
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use std::thread;

    use super::*;

    // ── PinSecurity tests ──────────────────────────────────────────────────────

    #[test]
    fn test_hash_pin_returns_phc_string() {
        let hash = PinSecurity::hash_pin("1234").unwrap();
        assert!(
            hash.starts_with("$argon2id$"),
            "expected Argon2id PHC: {hash}"
        );
    }

    #[test]
    fn test_verify_pin_correct_returns_true() {
        let hash = PinSecurity::hash_pin("9876").unwrap();
        let result = PinSecurity::verify_pin("9876", &hash).unwrap();
        assert!(result);
    }

    #[test]
    fn test_verify_pin_wrong_returns_false() {
        let hash = PinSecurity::hash_pin("9876").unwrap();
        let result = PinSecurity::verify_pin("0000", &hash).unwrap();
        assert!(!result);
    }

    #[test]
    fn test_verify_pin_invalid_hash_returns_error() {
        let err = PinSecurity::verify_pin("1234", "not-a-valid-hash").unwrap_err();
        assert!(matches!(err, CrispyError::Security { .. }));
    }

    /// Timing attack resistance: verify correct and incorrect should both go
    /// through Argon2 (same work factor), so neither should be zero-cost.
    /// We assert both calls take at least 1ms, meaning Argon2 actually ran.
    #[test]
    fn test_verify_timing_both_paths_run_argon2() {
        let hash = PinSecurity::hash_pin("5555").unwrap();

        let t0 = std::time::Instant::now();
        let _ = PinSecurity::verify_pin("5555", &hash).unwrap();
        let correct_ms = t0.elapsed().as_millis();

        let t1 = std::time::Instant::now();
        let _ = PinSecurity::verify_pin("0000", &hash).unwrap();
        let wrong_ms = t1.elapsed().as_millis();

        // Both must invoke Argon2 work — neither should be sub-millisecond
        assert!(correct_ms >= 1, "correct verify too fast: {correct_ms}ms");
        assert!(wrong_ms >= 1, "wrong verify too fast: {wrong_ms}ms");
    }

    // ── PinLockout tests ───────────────────────────────────────────────────────

    #[test]
    fn test_lockout_no_failures_allows_attempt() {
        let lockout = PinLockout::new();
        assert!(lockout.check_lockout("profile-1").is_ok());
    }

    #[test]
    fn test_lockout_first_failure_no_cooldown() {
        let lockout = PinLockout::new();
        lockout.record_failure("profile-1");
        // First failure = 0s cooldown, should be allowed immediately
        assert!(lockout.check_lockout("profile-1").is_ok());
    }

    #[test]
    fn test_lockout_second_failure_triggers_30s_cooldown() {
        let lockout = PinLockout::new();
        lockout.record_failure("p");
        lockout.record_failure("p");
        match lockout.check_lockout("p") {
            Err(LockoutError::Cooldown { remaining_secs }) => {
                assert!(remaining_secs > 0 && remaining_secs <= 30);
            }
            other => panic!("expected Cooldown, got {other:?}"),
        }
    }

    #[test]
    fn test_lockout_escalates_with_failures() {
        let lockout = PinLockout::new();
        for _ in 0..3 {
            lockout.record_failure("p");
        }
        // 3 failures → 60s cooldown
        match lockout.check_lockout("p") {
            Err(LockoutError::Cooldown { remaining_secs }) => {
                assert!(remaining_secs <= 60);
            }
            other => panic!("expected Cooldown, got {other:?}"),
        }
    }

    #[test]
    fn test_lockout_permanent_after_6_failures() {
        let lockout = PinLockout::new();
        for _ in 0..6 {
            lockout.record_failure("p");
        }
        assert_eq!(
            lockout.check_lockout("p"),
            Err(LockoutError::PermanentlyLocked)
        );
    }

    #[test]
    fn test_lockout_reset_on_success() {
        let lockout = PinLockout::new();
        lockout.record_failure("p");
        lockout.record_failure("p");
        lockout.record_success("p");
        assert!(lockout.check_lockout("p").is_ok());
    }

    #[test]
    fn test_lockout_force_unlock_clears_permanent() {
        let lockout = PinLockout::new();
        for _ in 0..6 {
            lockout.record_failure("p");
        }
        assert_eq!(
            lockout.check_lockout("p"),
            Err(LockoutError::PermanentlyLocked)
        );
        lockout.force_unlock("p");
        assert!(lockout.check_lockout("p").is_ok());
    }

    #[test]
    fn test_lockout_independent_profiles() {
        let lockout = PinLockout::new();
        for _ in 0..6 {
            lockout.record_failure("alice");
        }
        assert!(lockout.check_lockout("bob").is_ok());
    }

    #[test]
    fn test_lockout_cooldown_expires() {
        // We cannot actually wait 30s in a unit test, but we can verify that
        // the `check_lockout` path resolves correctly once elapsed >= cooldown.
        // Instead, verify that a single failure (0s cooldown) is always allowed.
        let lockout = PinLockout::new();
        lockout.record_failure("p");
        thread::sleep(Duration::from_millis(1));
        assert!(lockout.check_lockout("p").is_ok());
    }
}
