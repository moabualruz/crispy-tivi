use std::collections::HashMap;

use crate::errors::DomainError;
use crate::models::UserProfile;

/// Persistence contract for user profiles, source access, and channel order.
pub trait ProfileRepository {
    fn save_profile(&self, profile: &UserProfile) -> Result<(), DomainError>;
    fn delete_profile(&self, id: &str) -> Result<(), DomainError>;
    fn load_profiles(&self) -> Result<Vec<UserProfile>, DomainError>;
    fn grant_source_access(&self, profile_id: &str, source_id: &str) -> Result<(), DomainError>;
    fn revoke_source_access(&self, profile_id: &str, source_id: &str) -> Result<(), DomainError>;
    fn get_source_access(&self, profile_id: &str) -> Result<Vec<String>, DomainError>;
    fn set_source_access(&self, profile_id: &str, source_ids: &[String])
    -> Result<(), DomainError>;
    fn save_channel_order(
        &self,
        profile_id: &str,
        group_name: &str,
        channel_ids: &[String],
    ) -> Result<(), DomainError>;
    fn load_channel_order(
        &self,
        profile_id: &str,
        group_name: &str,
    ) -> Result<Option<HashMap<String, i32>>, DomainError>;
    fn reset_channel_order(&self, profile_id: &str, group_name: &str) -> Result<(), DomainError>;
}
