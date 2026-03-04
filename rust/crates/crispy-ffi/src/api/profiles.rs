use super::svc;
use anyhow::{Context, Result};
use crispy_core::models::UserProfile;

/// Load all profiles as JSON array.
pub fn load_profiles() -> Result<String> {
    let profiles = svc()?.load_profiles()?;
    Ok(serde_json::to_string(&profiles)?)
}

/// Save a profile from JSON object.
pub fn save_profile(json: String) -> Result<()> {
    let profile: UserProfile = serde_json::from_str(&json).context("Invalid profile JSON")?;
    Ok(svc()?.save_profile(&profile)?)
}

/// Delete a profile and cascade-delete children.
pub fn delete_profile(id: String) -> Result<()> {
    Ok(svc()?.delete_profile(&id)?)
}

// ── Profile Source Access ────────────────────────────

/// Get source IDs a profile can access.
pub fn get_source_access(profile_id: String) -> Result<Vec<String>> {
    Ok(svc()?.get_source_access(&profile_id)?)
}

/// Grant a profile access to a source.
pub fn grant_source_access(profile_id: String, source_id: String) -> Result<()> {
    Ok(svc()?.grant_source_access(&profile_id, &source_id)?)
}

/// Revoke a profile's access to a source.
pub fn revoke_source_access(profile_id: String, source_id: String) -> Result<()> {
    Ok(svc()?.revoke_source_access(&profile_id, &source_id)?)
}

/// Replace all source access for a profile.
pub fn set_source_access(profile_id: String, source_ids: Vec<String>) -> Result<()> {
    Ok(svc()?.set_source_access(&profile_id, &source_ids)?)
}

/// Get profile IDs that have access to a source.
pub fn get_profiles_for_source(source_id: String) -> Result<Vec<String>> {
    Ok(svc()?.get_profiles_for_source(&source_id)?)
}
