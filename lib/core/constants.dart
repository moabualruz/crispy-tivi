/// Shared application-wide constants.
library;

/// Watch progress threshold: >= 95% = completed.
///
/// Matches Rust `COMPLETION_THRESHOLD` in watch_progress.rs.
const double kCompletionThreshold = 0.95;

/// Next-episode auto-queue threshold.
///
/// When an episode's progress meets or exceeds this value the Continue
/// Watching row shows the NEXT episode instead of the nearly-completed
/// one. Set lower than [kCompletionThreshold] (0.95) so the card
/// switches before the backend removes the entry from the list.
const double kNextEpisodeThreshold = 0.90;

/// Default page size for paginated media server library requests
/// (Jellyfin, Emby, Plex). Applies to both startIndex-based and
/// cursor-based pagination.
const int kMediaServerPageSize = 50;

// ── Cloud sync metadata keys ─────────────────────────────
//
// Canonical Rust definitions: `SYNC_META_KEYS` in
// `rust/crates/crispy-core/src/algorithms/cloud_sync/merge.rs`.
// Both sides must use identical string values.

/// Settings key storing the timestamp of the last successful
/// cloud sync operation.
const String kSyncLastTimeKey = 'crispy_tivi_last_sync_time';

/// Settings key storing the timestamp of the most recent local
/// data modification (used for conflict detection).
const String kSyncLocalModifiedTimeKey = 'crispy_tivi_local_modified_time';

// ── Validation patterns ──────────────────────────────────────────────────

/// Canonical MAC address validation pattern.
///
/// Accepts both upper and lowercase hex digits (e.g. `00:1a:2b:3c:4d:5e`
/// and `00:1A:2B:3C:4D:5E`). Format: `XX:XX:XX:XX:XX:XX`.
const String kMacAddressPattern = r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$';
