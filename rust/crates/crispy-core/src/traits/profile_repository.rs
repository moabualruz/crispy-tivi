use std::collections::HashMap;

use crate::database::DbError;
use crate::models::UserProfile;

/// Persistence contract for user profiles, source access, and channel order.
pub trait ProfileRepository {
    fn save_profile(&self, profile: &UserProfile) -> Result<(), DbError>;
    fn delete_profile(&self, id: &str) -> Result<(), DbError>;
    fn load_profiles(&self) -> Result<Vec<UserProfile>, DbError>;
    fn grant_source_access(
        &self,
        profile_id: &str,
        source_id: &str,
    ) -> Result<(), DbError>;
    fn revoke_source_access(
        &self,
        profile_id: &str,
        source_id: &str,
    ) -> Result<(), DbError>;
    fn get_source_access(&self, profile_id: &str) -> Result<Vec<String>, DbError>;
    fn set_source_access(
        &self,
        profile_id: &str,
        source_ids: &[String],
    ) -> Result<(), DbError>;
    fn save_channel_order(
        &self,
        profile_id: &str,
        group_name: &str,
        channel_ids: &[String],
    ) -> Result<(), DbError>;
    fn load_channel_order(
        &self,
        profile_id: &str,
        group_name: &str,
    ) -> Result<Option<HashMap<String, i32>>, DbError>;
    fn reset_channel_order(
        &self,
        profile_id: &str,
        group_name: &str,
    ) -> Result<(), DbError>;
}
