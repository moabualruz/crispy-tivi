/// Returns `true` if the lockout period has not yet expired.
///
/// [lockedUntil] is the expiry timestamp; `null` means no lockout.
/// [now] defaults to [DateTime.now] when omitted (injectable for
/// deterministic tests).
bool isLockActive(DateTime? lockedUntil, {DateTime? now}) {
  if (lockedUntil == null) return false;
  return (now ?? DateTime.now()).isBefore(lockedUntil);
}

/// Returns the remaining lockout duration.
///
/// Returns [Duration.zero] when [lockedUntil] is `null` or already
/// in the past.
/// [now] defaults to [DateTime.now] when omitted.
Duration lockRemaining(DateTime? lockedUntil, {DateTime? now}) {
  if (lockedUntil == null) return Duration.zero;
  final diff = lockedUntil.difference(now ?? DateTime.now());
  return diff.isNegative ? Duration.zero : diff;
}
