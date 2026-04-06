//! Repository trait abstractions for all domain persistence operations.
//!
//! These traits define the public contract between consumers (services,
//! application layer, FFI bridge) and the concrete rusqlite implementation
//! in [`crate::services::CrispyService`].  Depending on the trait rather
//! than the concrete type satisfies the Dependency-Inversion Principle and
//! allows test doubles to be injected without touching the real database.

pub mod bookmark_repository;
pub mod channel_repository;
pub mod dvr_repository;
pub mod epg_repository;
pub mod history_repository;
pub mod profile_repository;
pub mod reminder_repository;
pub mod settings_repository;
pub mod source_repository;
pub mod vod_repository;

pub use bookmark_repository::BookmarkRepository;
pub use channel_repository::ChannelRepository;
pub use dvr_repository::DvrRepository;
pub use epg_repository::EpgRepository;
pub use history_repository::HistoryRepository;
pub use profile_repository::ProfileRepository;
pub use reminder_repository::ReminderRepository;
pub use settings_repository::SettingsRepository;
pub use source_repository::SourceRepository;
pub use vod_repository::VodRepository;
