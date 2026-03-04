import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lockout duration applied after [kPinMaxAttempts] consecutive wrong
/// PIN attempts for a given profile.
// FE-PM-03
const _kLockoutDuration = Duration(minutes: 5);

/// Maximum consecutive wrong PIN attempts before lockout.
// FE-PM-03
const kPinMaxAttempts = 3;

/// Immutable per-profile PIN attempt record.
// FE-PM-03
class _ProfileLockEntry {
  const _ProfileLockEntry({this.failedAttempts = 0, this.lockedUntil});

  final int failedAttempts;
  final DateTime? lockedUntil;

  bool get isLocked {
    if (lockedUntil == null) return false;
    return DateTime.now().isBefore(lockedUntil!);
  }

  Duration get remaining {
    if (lockedUntil == null) return Duration.zero;
    final diff = lockedUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  _ProfileLockEntry copyWith({
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) {
    return _ProfileLockEntry(
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
    );
  }
}

/// Immutable state for the PIN lockout system.
///
/// Tracks failed attempts and lockout expiry independently per
/// profile ID so that a failed attempt on Profile A does not
/// affect Profile B.
// FE-PM-03
class PinLockoutState {
  // FE-PM-03: public no-arg constructor for the initial empty state.
  const PinLockoutState() : _entries = const {};

  // Internal constructor used by mutation helpers.
  const PinLockoutState._withEntries(this._entries);

  final Map<String, _ProfileLockEntry> _entries;

  // ── Legacy single-profile accessors (profile-agnostic callers) ────────────

  /// Whether any profile is currently locked.
  ///
  /// Use [isLockedFor] for per-profile checks.
  bool get isLocked => _entries.values.any((e) => e.isLocked);

  /// Remaining lockout of the first locked entry found.
  ///
  /// Use [remainingFor] for per-profile lookups.
  Duration get remaining {
    for (final e in _entries.values) {
      if (e.isLocked) return e.remaining;
    }
    return Duration.zero;
  }

  /// Consecutive failed attempts across all profiles (sum).
  ///
  /// Use [failedAttemptsFor] for per-profile counts.
  int get failedAttempts =>
      _entries.values.fold(0, (sum, e) => sum + e.failedAttempts);

  // ── Per-profile accessors ─────────────────────────────────────────────────

  /// Whether [profileId] is currently locked out.
  // FE-PM-03
  bool isLockedFor(String profileId) => _entries[profileId]?.isLocked ?? false;

  /// Remaining lockout duration for [profileId].
  // FE-PM-03
  Duration remainingFor(String profileId) =>
      _entries[profileId]?.remaining ?? Duration.zero;

  /// Failed attempt count for [profileId].
  // FE-PM-03
  int failedAttemptsFor(String profileId) =>
      _entries[profileId]?.failedAttempts ?? 0;

  // ── State mutation helpers ────────────────────────────────────────────────

  PinLockoutState _withEntry(
    String profileId,
    _ProfileLockEntry Function(_ProfileLockEntry) update,
  ) {
    final current = _entries[profileId] ?? const _ProfileLockEntry();
    final next = Map<String, _ProfileLockEntry>.from(_entries);
    next[profileId] = update(current);
    return PinLockoutState._withEntries(next);
  }

  PinLockoutState _withoutEntry(String profileId) {
    final next = Map<String, _ProfileLockEntry>.from(_entries)
      ..remove(profileId);
    return PinLockoutState._withEntries(next);
  }
}

/// Manages PIN attempt tracking and lockout state per profile.
///
/// Persists in a provider (not local widget state) so lockouts
/// survive dialog dismissal and reopening within the same session.
/// State is in-memory only and resets on app restart.
// FE-PM-03
class PinLockoutNotifier extends Notifier<PinLockoutState> {
  // FE-PM-03: per-profile tick timers for the countdown display.
  final Map<String, Timer> _timers = {};

  @override
  PinLockoutState build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
    });
    return const PinLockoutState();
  }

  // ── Per-profile API ───────────────────────────────────────────────────────

  /// Records a failed PIN attempt for [profileId].
  ///
  /// Triggers a 5-minute lockout after [kPinMaxAttempts] consecutive
  /// failures. The lockout is scoped to [profileId] only.
  // FE-PM-03
  void recordFailure({required String profileId}) {
    final attempts = state.failedAttemptsFor(profileId) + 1;
    if (attempts >= kPinMaxAttempts) {
      final lockedUntil = DateTime.now().add(_kLockoutDuration);
      state = state._withEntry(
        profileId,
        (e) => e.copyWith(failedAttempts: attempts, lockedUntil: lockedUntil),
      );
      _startTicker(profileId);
    } else {
      state = state._withEntry(
        profileId,
        (e) => e.copyWith(failedAttempts: attempts),
      );
    }
  }

  /// Resets attempt count and clears any lockout for [profileId].
  ///
  /// Call on successful PIN entry.
  // FE-PM-03
  void recordSuccess({required String profileId}) {
    _timers[profileId]?.cancel();
    _timers.remove(profileId);
    state = state._withoutEntry(profileId);
  }

  /// Whether [profileId] is currently locked.
  // FE-PM-03
  bool isLocked({required String profileId}) => state.isLockedFor(profileId);

  /// Remaining lockout time for [profileId].
  // FE-PM-03
  Duration remainingLockTime({required String profileId}) =>
      state.remainingFor(profileId);

  // ── Legacy single-profile shims (backwards compat) ────────────────────────
  //
  // Callers that don't supply a profileId fall back to a sentinel key so
  // the provider contract stays the same for non-profile dialogs (e.g.
  // parental-PIN dialogs that are not tied to a specific profile).

  /// Records a failure without a specific profile context.
  ///
  /// Prefer [recordFailure] with an explicit [profileId].
  // FE-PM-03
  @Deprecated('Use recordFailure(profileId: id) instead.')
  void recordFailureLegacy() => recordFailure(profileId: _kLegacyKey);

  /// Resets lockout without a specific profile context.
  ///
  /// Prefer [recordSuccess] with an explicit [profileId].
  // FE-PM-03
  @Deprecated('Use recordSuccess(profileId: id) instead.')
  void recordSuccessLegacy() => recordSuccess(profileId: _kLegacyKey);

  // ── Internal ──────────────────────────────────────────────────────────────

  void _startTicker(String profileId) {
    _timers[profileId]?.cancel();
    _timers[profileId] = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isLockedFor(profileId)) {
        _timers[profileId]?.cancel();
        _timers.remove(profileId);
        // Clear the locked timestamp so callers know the lockout expired.
        state = state._withEntry(
          profileId,
          (e) => e.copyWith(clearLockedUntil: true),
        );
      } else {
        // Force a rebuild so the countdown text updates.
        final attempts = state.failedAttemptsFor(profileId);
        final lockedUntil = state._entries[profileId]?.lockedUntil;
        state = state._withEntry(
          profileId,
          (_) => _ProfileLockEntry(
            failedAttempts: attempts,
            lockedUntil: lockedUntil,
          ),
        );
      }
    });
  }
}

/// Sentinel key used by legacy (non-profile) callers.
// FE-PM-03
const _kLegacyKey = '__global__';

/// Global PIN lockout provider.
///
/// Tracks consecutive failed PIN attempts **per profile** across dialog
/// open/close cycles. Survives navigation — lockouts persist as long
/// as the provider is alive (in-memory, session-scoped).
// FE-PM-03
final pinLockoutProvider =
    NotifierProvider<PinLockoutNotifier, PinLockoutState>(
      PinLockoutNotifier.new,
    );
