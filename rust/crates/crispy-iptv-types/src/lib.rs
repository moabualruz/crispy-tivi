//! Protocol-agnostic IPTV domain types and traits.
//!
//! This crate defines the shared vocabulary for all crispy-* IPTV crates.
//! Each protocol crate (crispy-m3u, crispy-xtream, crispy-stalker, etc.)
//! defines its own protocol-native output types. Consumers implement
//! `From<ProtocolType>` conversions to map into their app-specific models.

pub mod channel;
pub mod epg;
pub mod error;
pub mod resolution;
pub mod stream;
pub mod vod;

pub use channel::{CatchupConfig, CatchupType, PlaylistEntry};
pub use epg::{
    EpgAudio, EpgCredits, EpgEpisodeNumber, EpgIcon, EpgImage, EpgProgramme, EpgRating, EpgReview,
    EpgStringWithLang, EpgVideo,
};
pub use error::IptvError;
pub use resolution::Resolution;
pub use stream::{StreamProtocol, StreamStatus, StreamUrl};
pub use vod::VodEntry;
