//! Domain value objects — typed replacements for primitive String fields.
pub mod category_type;
pub mod match_method;
pub mod media_type;
pub mod recording_status;
pub mod source_type;

pub use category_type::CategoryType;
pub use match_method::MatchMethod;
pub use media_type::MediaType;
pub use recording_status::RecordingStatus;
pub use source_type::SourceType;
