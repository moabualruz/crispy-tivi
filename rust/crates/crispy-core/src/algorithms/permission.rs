//! Recording permission algorithms.
//!
//! Ports `canViewRecording` and `canDeleteRecording`
//! from Dart `permission_guard.dart`. Uses string-based
//! role identifiers that map to `DvrPermission` enum
//! values: `"admin"`, `"full_dvr"`, `"view_only"`.

/// Whether the given role can view a specific recording.
///
/// Rules:
/// - `"admin"` — always `true`
/// - `"full_dvr"` — always `true` (can view all)
/// - `"view_only"` — only own recordings
///   (`recording_owner_id == current_profile_id`)
/// - Any other role — `false`
pub fn can_view_recording(role: &str, recording_owner_id: &str, current_profile_id: &str) -> bool {
    match role {
        "admin" => true,
        "full_dvr" => true,
        "view_only" => recording_owner_id == current_profile_id,
        _ => false,
    }
}

/// Whether the given role can delete a specific
/// recording.
///
/// Rules:
/// - `"admin"` — always `true`
/// - `"full_dvr"` — only own recordings
///   (`recording_owner_id == current_profile_id`)
/// - All other roles — `false`
pub fn can_delete_recording(
    role: &str,
    recording_owner_id: &str,
    current_profile_id: &str,
) -> bool {
    match role {
        "admin" => true,
        "full_dvr" => recording_owner_id == current_profile_id,
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── can_view_recording ─────────────────────────

    #[test]
    fn admin_can_view_any_recording() {
        assert!(can_view_recording("admin", "other", "me"));
        assert!(can_view_recording("admin", "me", "me"));
    }

    #[test]
    fn full_dvr_can_view_any_recording() {
        assert!(can_view_recording("full_dvr", "other", "me"));
        assert!(can_view_recording("full_dvr", "me", "me"));
    }

    #[test]
    fn view_only_can_view_own_recording() {
        assert!(can_view_recording("view_only", "me", "me"));
    }

    #[test]
    fn view_only_cannot_view_others_recording() {
        assert!(!can_view_recording("view_only", "other", "me"));
    }

    #[test]
    fn unknown_role_cannot_view() {
        assert!(!can_view_recording("restricted", "me", "me"));
        assert!(!can_view_recording("", "me", "me"));
        assert!(!can_view_recording("none", "me", "me"));
    }

    // ── can_delete_recording ───────────────────────

    #[test]
    fn admin_can_delete_any_recording() {
        assert!(can_delete_recording("admin", "other", "me"));
        assert!(can_delete_recording("admin", "me", "me"));
    }

    #[test]
    fn full_dvr_can_delete_own_recording() {
        assert!(can_delete_recording("full_dvr", "me", "me"));
    }

    #[test]
    fn full_dvr_cannot_delete_others_recording() {
        assert!(!can_delete_recording("full_dvr", "other", "me"));
    }

    #[test]
    fn view_only_cannot_delete() {
        assert!(!can_delete_recording("view_only", "me", "me"));
        assert!(!can_delete_recording("view_only", "other", "me"));
    }

    #[test]
    fn unknown_role_cannot_delete() {
        assert!(!can_delete_recording("restricted", "me", "me"));
        assert!(!can_delete_recording("", "me", "me"));
        assert!(!can_delete_recording("none", "other", "me"));
    }

    // ── edge cases ─────────────────────────────────

    #[test]
    fn empty_ids_handled() {
        // Admin still works with empty IDs.
        assert!(can_view_recording("admin", "", ""));
        assert!(can_delete_recording("admin", "", ""));

        // view_only: empty == empty → match.
        assert!(can_view_recording("view_only", "", ""));

        // full_dvr delete: empty == empty → match.
        assert!(can_delete_recording("full_dvr", "", ""));

        // Mismatched empties.
        assert!(!can_view_recording("view_only", "x", ""));
        assert!(!can_delete_recording("full_dvr", "x", ""));
    }
}
