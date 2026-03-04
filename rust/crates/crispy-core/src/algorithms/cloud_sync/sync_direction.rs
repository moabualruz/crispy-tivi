//! Sync direction determination for cloud sync.

/// Determines cloud sync direction from timestamps and device IDs.
///
/// Returns one of: `"upload"`, `"download"`, `"no_change"`, `"conflict"`.
///
/// Logic:
/// - `cloud_ms == 0` (no cloud backup) → `"upload"`
/// - `local_ms == 0` (no local backup) → `"download"`
/// - `|local_ms - cloud_ms| <= 5000` (5-sec tolerance) → `"no_change"`
/// - `cloud_device != local_device && local_ms > last_sync_ms` → `"conflict"`
/// - `local_ms > cloud_ms` → `"upload"`
/// - else → `"download"`
pub fn determine_sync_direction(
    local_ms: i64,
    cloud_ms: i64,
    last_sync_ms: i64,
    local_device: &str,
    cloud_device: &str,
) -> String {
    // No cloud backup exists → upload.
    if cloud_ms == 0 {
        // Edge case: both zero → no change.
        if local_ms == 0 {
            return "no_change".to_string();
        }
        return "upload".to_string();
    }

    // No local backup exists → download.
    if local_ms == 0 {
        return "download".to_string();
    }

    // Within 5-second tolerance → no_change.
    if (local_ms - cloud_ms).abs() <= 5000 {
        return "no_change".to_string();
    }

    // Different device, local modified after last sync, AND local is newer → conflict.
    if cloud_device != local_device && local_ms > last_sync_ms && local_ms > cloud_ms {
        return "conflict".to_string();
    }

    // Newer local → upload; otherwise download.
    if local_ms > cloud_ms {
        "upload".to_string()
    } else {
        "download".to_string()
    }
}
