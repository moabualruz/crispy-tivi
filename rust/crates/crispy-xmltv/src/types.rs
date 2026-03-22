//! XMLTV document types.
//!
//! Uses shared types from `crispy_iptv_types::epg` where they align
//! (channels, programmes, credits, etc.) and re-exports them for
//! convenience.

use crispy_iptv_types::epg::{EpgChannel, EpgProgramme};
use serde::{Deserialize, Serialize};

/// A parsed XMLTV document containing channels and programmes.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct XmltvDocument {
    /// Channel definitions.
    pub channels: Vec<EpgChannel>,

    /// Programme schedule entries.
    pub programmes: Vec<EpgProgramme>,
}

// Re-export shared types so consumers don't need crispy_iptv_types directly.
pub use crispy_iptv_types::epg::{
    EpgAudio as XmltvAudio, EpgChannel as XmltvChannel, EpgCredits as XmltvCredits,
    EpgEpisodeNumber as XmltvEpisodeNumber, EpgIcon as XmltvIcon, EpgImage as XmltvImage,
    EpgPerson as XmltvPerson, EpgProgramme as XmltvProgramme, EpgRating as XmltvRating,
    EpgReview as XmltvReview, EpgStringWithLang as XmltvStringWithLang, EpgVideo as XmltvVideo,
};
