//! Domain value objects — typed replacements for primitive String fields.
pub mod backend_type;
pub mod category_type;
pub mod dvr_permission;
pub mod layout_type;
pub mod match_method;
pub mod media_type;
pub mod profile_role;
pub mod recording_status;
pub mod source_type;
pub mod transfer_direction;
pub mod transfer_status;

pub use backend_type::BackendType;
pub use category_type::CategoryType;
pub use dvr_permission::DvrPermission;
pub use layout_type::LayoutType;
pub use match_method::MatchMethod;
pub use media_type::MediaType;
pub use profile_role::ProfileRole;
pub use recording_status::RecordingStatus;
pub use source_type::SourceType;
pub use transfer_direction::TransferDirection;
pub use transfer_status::TransferStatus;
