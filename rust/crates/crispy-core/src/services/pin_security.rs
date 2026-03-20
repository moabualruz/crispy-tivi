//! Argon2id PIN hashing and progressive lockout.
//!
//! - Hashing: Argon2id (m=19456, t=2, p=1) with a random 16-byte salt via
//!   [`PinSecurity::hash_pin`].
//! - Verification: constant-time via `argon2::PasswordVerifier` internals.
//! - Migration: [`PinSecurity::verify_and_migrate`] transparently upgrades
//!   old SHA-256 hashes to Argon2id on first successful login.
//! - Lockout: per-profile consecutive-failure counter with exponential cooldown.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use argon2::password_hash::{PasswordHash, PasswordVerifier};
use argon2::{Algorithm, Argon2, Params, Version};

use crate::algorithms::pin::{
    hash_pin_argon2id, is_argon2id_hash, is_legacy_sha256_hash, verify_pin_legacy,
};
use crate::errors::CrispyError;

// ── Argon2id parameters ───────────────────────────────────────────────────────

/// Memory cost: 19 MiB (OWASP minimum for Argon2id).
const ARGON2_M_COST: u32 = 19_456;
/// Time cost: 2 iterations.
const ARGON2_T_COST: u32 = 2;
/// Parallelism: 1 lane.
const ARGON2_P_COST: u32 = 1;

fn argon2_instance() -> Argon2<'static> {
    let params = Params::new(ARGON2_M_COST, ARGON2_T_COST, ARGON2_P_COST, None)
        .expect("valid Argon2 params");
    Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
}

// ── HashFormat ────────────────────────────────────────────────────────────────

/// The detected format of a stored PIN hash.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HashFormat {
    /// Argon2id PHC string (`$argon2id$...`).
    Argon2id,
    /// Legacy unsalted SHA-256 hex string (64 chars).
    LegacySha256,
    /// Unrecognised format.
    Unknown,
}

impl HashFormat {
    /// Detect the format of a stored hash string.
    pub fn detect(hash: &str) -> Self {
        if is_argon2id_hash(hash) {
            HashFormat::Argon2id
        } else if is_legacy_sha256_hash(hash) {
            HashFormat::LegacySha256
        } else {
            HashFormat::Unknown
        }
    }
}

// ── MigrationOutcome ──────────────────────────────────────────────────────────

/// Result of [`PinSecurity::verify_and_migrate`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MigrationOutcome {
    /// PIN was correct; hash was already Argon2id — no update needed.
    VerifiedNoMigration,
    /// PIN was correct; hash was legacy SHA-256 and has been re-hashed.
    /// The caller MUST persist `new_hash` to `db_profiles.pin`.
    VerifiedMigrated { new_hash: String },
    /// PIN was incorrect.
    WrongPin,
}

// ── PinSecurity ───────────────────────────────────────────────────────────────

/// Argon2id PIN hashing, verification, and transparent legacy migration.
pub struct PinSecurity;

impl PinSecurity {
    /// Hash a PIN using Argon2id (m=19456, t=2, p=1) with a fresh random salt.
    ///
    /// Returns a PHC-format string (`$argon2id$v=19$m=19456,t=2,p=1$...`)
    /// suitable for storage in `db_profiles.pin`.
    pub fn hash_pin(pin: &str) -> Result<String, CrispyError> {
        hash_pin_argon2id(pin)
    }

    /// Verify a PIN against a stored Argon2id PHC hash.
    ///
    /// Uses constant-time comparison internally (argon2 crate guarantee).
    /// Returns `Ok(false)` for a wrong PIN; `Err` only for a malformed hash.
    pub fn verify_pin(pin: &str, hash: &str) -> Result<bool, CrispyError> {
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

    /// Verify a PIN against any stored hash format, transparently migrating
    /// legacy SHA-256 hashes to Argon2id on successful verification.
    ///
    /// ## Usage
    ///
    /// ```ignore
    /// match PinSecurity::verify_and_migrate(entered_pin, stored_hash)? {
    ///     MigrationOutcome::VerifiedNoMigration => { /* proceed */ }
    ///     MigrationOutcome::VerifiedMigrated { new_hash } => {
    ///         db.update_profile_pin(profile_id, &new_hash)?; // persist upgrade
    ///     }
    ///     MigrationOutcome::WrongPin => { /* reject */ }
    /// }
    /// ```
    pub fn verify_and_migrate(
        pin: &str,
        stored_hash: &str,
    ) -> Result<MigrationOutcome, CrispyError> {
        match HashFormat::detect(stored_hash) {
            HashFormat::Argon2id => {
                let ok = Self::verify_pin(pin, stored_hash)?;
                if ok {
                    Ok(MigrationOutcome::VerifiedNoMigration)
                } else {
                    Ok(MigrationOutcome::WrongPin)
                }
            }
            HashFormat::LegacySha256 => {
                if verify_pin_legacy(pin, stored_hash) {
                    // Re-hash with Argon2id so the DB is upgraded on next write
                    let new_hash = hash_pin_argon2id(pin)?;
                    Ok(MigrationOutcome::VerifiedMigrated { new_hash })
                } else {
                    Ok(MigrationOutcome::WrongPin)
                }
            }
            HashFormat::Unknown => Err(CrispyError::security(
                "Stored PIN hash has unrecognised format".to_string(),
            )),
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

    use crate::algorithms::pin::hash_pin_legacy;

    use super::*;

    // ── PinSecurity::hash_pin / verify_pin ────────────────────────────────────

    #[test]
    fn test_hash_pin_returns_phc_string() {
        let hash = PinSecurity::hash_pin("1234").unwrap();
        assert!(
            hash.starts_with("$argon2id$"),
            "expected Argon2id PHC: {hash}"
        );
    }

    #[test]
    fn test_hash_pin_uses_required_params() {
        let hash = PinSecurity::hash_pin("1234").unwrap();
        assert!(hash.contains("m=19456"), "expected m=19456: {hash}");
        assert!(hash.contains("t=2"), "expected t=2: {hash}");
        assert!(hash.contains("p=1"), "expected p=1: {hash}");
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

    // ── HashFormat detection ──────────────────────────────────────────────────

    #[test]
    fn test_migration_detects_argon2id_hash() {
        let hash = PinSecurity::hash_pin("1234").unwrap();
        assert_eq!(HashFormat::detect(&hash), HashFormat::Argon2id);
    }

    #[test]
    fn test_migration_detects_legacy_hash() {
        let hash = hash_pin_legacy("1234");
        assert_eq!(HashFormat::detect(&hash), HashFormat::LegacySha256);
    }

    #[test]
    fn test_migration_detects_unknown_hash() {
        assert_eq!(HashFormat::detect("not-a-hash"), HashFormat::Unknown);
        assert_eq!(HashFormat::detect(""), HashFormat::Unknown);
    }

    // ── verify_and_migrate ────────────────────────────────────────────────────

    #[test]
    fn test_verify_and_migrate_argon2id_correct_no_migration() {
        let hash = PinSecurity::hash_pin("correct").unwrap();
        let outcome = PinSecurity::verify_and_migrate("correct", &hash).unwrap();
        assert_eq!(outcome, MigrationOutcome::VerifiedNoMigration);
    }

    #[test]
    fn test_verify_and_migrate_argon2id_wrong_returns_wrong_pin() {
        let hash = PinSecurity::hash_pin("correct").unwrap();
        let outcome = PinSecurity::verify_and_migrate("wrong", &hash).unwrap();
        assert_eq!(outcome, MigrationOutcome::WrongPin);
    }

    #[test]
    fn test_verify_and_migrate_legacy_correct_returns_new_hash() {
        let legacy_hash = hash_pin_legacy("migrated");
        let outcome = PinSecurity::verify_and_migrate("migrated", &legacy_hash).unwrap();
        match outcome {
            MigrationOutcome::VerifiedMigrated { new_hash } => {
                // New hash must be Argon2id and must verify the same PIN
                assert!(new_hash.starts_with("$argon2id$"), "upgraded to Argon2id");
                assert!(PinSecurity::verify_pin("migrated", &new_hash).unwrap());
            }
            other => panic!("expected VerifiedMigrated, got {other:?}"),
        }
    }

    #[test]
    fn test_verify_and_migrate_legacy_wrong_returns_wrong_pin() {
        let legacy_hash = hash_pin_legacy("correct");
        let outcome = PinSecurity::verify_and_migrate("wrong", &legacy_hash).unwrap();
        assert_eq!(outcome, MigrationOutcome::WrongPin);
    }

    #[test]
    fn test_verify_and_migrate_unknown_hash_returns_error() {
        let err = PinSecurity::verify_and_migrate("1234", "garbage-hash").unwrap_err();
        assert!(matches!(err, CrispyError::Security { .. }));
    }

    #[test]
    fn test_verify_and_migrate_empty_pin_legacy() {
        // Empty PIN on a legacy hash must migrate correctly
        let legacy_hash = hash_pin_legacy("");
        let outcome = PinSecurity::verify_and_migrate("", &legacy_hash).unwrap();
        assert!(matches!(outcome, MigrationOutcome::VerifiedMigrated { .. }));
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
