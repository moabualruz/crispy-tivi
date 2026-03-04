/// Shared application-wide constants.
library;

/// Watch progress threshold: >= 95% = completed.
///
/// Matches Rust `COMPLETION_THRESHOLD` in watch_progress.rs.
const double kCompletionThreshold = 0.95;

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
