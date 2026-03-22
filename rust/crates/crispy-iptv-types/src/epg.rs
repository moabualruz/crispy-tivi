//! Protocol-agnostic EPG (Electronic Programme Guide) types.
//!
//! Mirrors the XMLTV DTD as defined by `@iptv/xmltv` while remaining
//! usable by Xtream short-EPG and Stalker EPG responses.

use serde::{Deserialize, Serialize};
use smallvec::SmallVec;

/// A single EPG programme entry.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgProgramme {
    /// Channel ID this programme belongs to (XMLTV channel@id).
    pub channel: String,

    /// Programme start time (UTC timestamp).
    pub start: Option<i64>,

    /// Programme stop time (UTC timestamp).
    pub stop: Option<i64>,

    /// Programme title(s), potentially multilingual.
    #[serde(default)]
    pub title: SmallVec<[EpgStringWithLang; 1]>,

    /// Subtitle(s).
    #[serde(default)]
    pub sub_title: SmallVec<[EpgStringWithLang; 1]>,

    /// Description(s).
    #[serde(default)]
    pub desc: SmallVec<[EpgStringWithLang; 1]>,

    /// Category / genre tags.
    #[serde(default)]
    pub category: SmallVec<[EpgStringWithLang; 2]>,

    /// Credits (directors, actors, writers, etc.).
    pub credits: Option<EpgCredits>,

    /// Original air date.
    pub date: Option<String>,

    /// Programme length in minutes.
    pub length: Option<u32>,

    /// Episode numbering (xmltv_ns, onscreen, etc.).
    #[serde(default)]
    pub episode_num: SmallVec<[EpgEpisodeNumber; 1]>,

    /// Programme images (poster, backdrop, still).
    #[serde(default)]
    pub image: SmallVec<[EpgImage; 1]>,

    /// Programme icon.
    pub icon: Option<EpgIcon>,

    /// Content ratings.
    #[serde(default)]
    pub rating: SmallVec<[EpgRating; 1]>,

    /// Star ratings (critic scores).
    #[serde(default)]
    pub star_rating: SmallVec<[EpgRating; 1]>,

    /// Broadcast flags.
    #[serde(default)]
    pub is_new: bool,

    #[serde(default)]
    pub is_premiere: bool,

    #[serde(default)]
    pub is_rerun: bool,

    #[serde(default)]
    pub is_last_chance: bool,

    /// Keyword(s) for the programme.
    #[serde(default)]
    pub keyword: SmallVec<[EpgStringWithLang; 2]>,

    /// Original language of the programme.
    pub orig_language: Option<EpgStringWithLang>,

    /// Video properties (aspect ratio, colour, quality).
    pub video: Option<EpgVideo>,

    /// Audio properties (stereo mode, presence).
    #[serde(default)]
    pub audio: SmallVec<[EpgAudio; 1]>,

    /// Reviews / critiques.
    #[serde(default)]
    pub review: SmallVec<[EpgReview; 1]>,
}

/// A string value with an optional language attribute.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgStringWithLang {
    pub value: String,
    pub lang: Option<String>,
}

impl EpgStringWithLang {
    pub fn new(value: impl Into<String>) -> Self {
        Self {
            value: value.into(),
            lang: None,
        }
    }

    pub fn with_lang(value: impl Into<String>, lang: impl Into<String>) -> Self {
        Self {
            value: value.into(),
            lang: Some(lang.into()),
        }
    }
}

/// Credits for a programme (cast & crew).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgCredits {
    #[serde(default)]
    pub director: SmallVec<[String; 2]>,

    #[serde(default)]
    pub actor: SmallVec<[EpgPerson; 4]>,

    #[serde(default)]
    pub writer: SmallVec<[String; 2]>,

    #[serde(default)]
    pub producer: SmallVec<[String; 1]>,

    #[serde(default)]
    pub composer: SmallVec<[String; 1]>,

    #[serde(default)]
    pub presenter: SmallVec<[String; 2]>,

    #[serde(default)]
    pub commentator: SmallVec<[String; 1]>,

    #[serde(default)]
    pub guest: SmallVec<[EpgPerson; 2]>,
}

/// A person with optional role and guest flag.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgPerson {
    pub name: String,
    pub role: Option<String>,
    #[serde(default)]
    pub guest: bool,
    pub image: Option<String>,
    pub url: Option<String>,
}

/// Episode numbering entry.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgEpisodeNumber {
    pub value: String,
    /// Numbering system: "xmltv_ns", "onscreen", etc.
    pub system: Option<String>,
}

/// Programme image with type metadata.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgImage {
    pub url: String,
    /// Image type: "poster", "backdrop", "still".
    pub image_type: Option<String>,
    pub size: Option<String>,
    pub orient: Option<String>,
}

/// Programme icon (typically a small thumbnail).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgIcon {
    pub src: String,
    pub width: Option<u32>,
    pub height: Option<u32>,
}

/// Content or star rating.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgRating {
    pub value: String,
    pub system: Option<String>,
}

/// Video properties for a programme (XMLTV `<video>`).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgVideo {
    pub present: Option<bool>,
    pub colour: Option<bool>,
    pub aspect: Option<String>,
    pub quality: Option<String>,
}

/// Audio properties for a programme (XMLTV `<audio>`).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgAudio {
    pub present: Option<bool>,
    pub stereo: Option<String>,
}

/// A review for a programme (XMLTV `<review>`).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgReview {
    pub value: String,
    pub review_type: Option<String>,
    pub source: Option<String>,
    pub reviewer: Option<String>,
    pub lang: Option<String>,
}

/// An XMLTV channel definition.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EpgChannel {
    pub id: String,
    #[serde(default)]
    pub display_name: SmallVec<[EpgStringWithLang; 1]>,
    /// Single icon (backward compat).
    pub icon: Option<EpgIcon>,
    /// Single URL (backward compat).
    pub url: Option<String>,
    /// Multiple icons.
    #[serde(default)]
    pub icons: SmallVec<[EpgIcon; 1]>,
    /// Multiple URLs.
    #[serde(default)]
    pub urls: SmallVec<[String; 1]>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn programme_default_has_empty_title() {
        let p = EpgProgramme::default();
        assert!(p.title.is_empty());
        assert!(p.channel.is_empty());
        assert!(!p.is_new);
    }

    #[test]
    fn programme_default_has_empty_new_fields() {
        let p = EpgProgramme::default();
        assert!(p.keyword.is_empty());
        assert!(p.orig_language.is_none());
        assert!(p.video.is_none());
        assert!(p.audio.is_empty());
        assert!(p.review.is_empty());
    }

    #[test]
    fn epg_video_default_has_all_none() {
        let v = EpgVideo::default();
        assert!(v.present.is_none());
        assert!(v.colour.is_none());
        assert!(v.aspect.is_none());
        assert!(v.quality.is_none());
    }

    #[test]
    fn string_with_lang_constructors() {
        let plain = EpgStringWithLang::new("Hello");
        assert_eq!(plain.value, "Hello");
        assert!(plain.lang.is_none());

        let lang = EpgStringWithLang::with_lang("Bonjour", "fr");
        assert_eq!(lang.value, "Bonjour");
        assert_eq!(lang.lang.as_deref(), Some("fr"));
    }
}
