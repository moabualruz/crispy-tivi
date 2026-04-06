use super::{ctx, from_json};
use anyhow::Result;
use crispy_core::models::UserProfile;
use crispy_core::services::{BulkService, ProfileService};

/// Load all profiles as JSON array.
pub fn load_profiles() -> Result<String> {
    let profiles = ProfileService(ctx()?).load_profiles()?;
    Ok(serde_json::to_string(&profiles)?)
}

/// Save a profile from JSON object.
pub fn save_profile(json: String) -> Result<()> {
    let profile: UserProfile = from_json(&json)?;
    Ok(ProfileService(ctx()?).save_profile(&profile)?)
}

/// Delete a profile and cascade-delete children.
pub fn delete_profile(id: String) -> Result<()> {
    Ok(ProfileService(ctx()?).delete_profile(&id)?)
}

// ── Profile Source Access ────────────────────────────

/// Get source IDs a profile can access.
pub fn get_source_access(profile_id: String) -> Result<Vec<String>> {
    Ok(ProfileService(ctx()?).get_source_access(&profile_id)?)
}

/// Grant a profile access to a source.
pub fn grant_source_access(profile_id: String, source_id: String) -> Result<()> {
    Ok(ProfileService(ctx()?).grant_source_access(&profile_id, &source_id)?)
}

/// Revoke a profile's access to a source.
pub fn revoke_source_access(profile_id: String, source_id: String) -> Result<()> {
    Ok(ProfileService(ctx()?).revoke_source_access(&profile_id, &source_id)?)
}

/// Replace all source access for a profile.
pub fn set_source_access(profile_id: String, source_ids: Vec<String>) -> Result<()> {
    Ok(ProfileService(ctx()?).set_source_access(&profile_id, &source_ids)?)
}

/// Get profile IDs that have access to a source.
pub fn get_profiles_for_source(source_id: String) -> Result<Vec<String>> {
    Ok(BulkService(ctx()?).get_profiles_for_source(&source_id)?)
}
