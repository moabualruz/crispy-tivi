//! Protocol-agnostic channel / playlist entry types.
//!
//! Mirrors the field set from `@iptv/playlist`'s `M3uChannel` while
//! remaining protocol-neutral so Xtream and Stalker crates can also
//! produce `PlaylistEntry` values.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use smallvec::SmallVec;

/// A single entry in an IPTV playlist (live channel or radio stream).
///
/// This is the protocol-agnostic representation. Each source crate
/// defines its own native type and consumers implement `From` to
/// convert into app-specific models.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PlaylistEntry {
    /// Primary stream URL.
    pub url: Option<String>,

    /// Alternative stream URLs (multi-URL entries).
    #[serde(default, skip_serializing_if = "SmallVec::is_empty")]
    pub urls: SmallVec<[String; 2]>,

    /// Display name.
    pub name: Option<String>,

    /// `tvg-id` — XMLTV channel identifier for EPG matching.
    pub tvg_id: Option<String>,

    /// `tvg-name` — alternative name for EPG matching.
    pub tvg_name: Option<String>,

    /// `tvg-language` — broadcast language.
    pub tvg_language: Option<String>,

    /// `tvg-logo` — channel logo URL.
    pub tvg_logo: Option<String>,

    /// `tvg-url` — per-channel EPG URL.
    pub tvg_url: Option<String>,

    /// `tvg-rec` — recording/catchup hint.
    pub tvg_rec: Option<String>,

    /// `tvg-chno` — channel number.
    pub tvg_chno: Option<String>,

    /// `group-title` — category / group name.
    pub group_title: Option<String>,

    /// `timeshift` — timeshift duration hint.
    pub timeshift: Option<String>,

    /// Catchup configuration.
    pub catchup: Option<CatchupConfig>,

    /// `#EXTINF` duration in seconds (-1 for live).
    pub duration: Option<f64>,

    /// Whether this entry is a radio stream.
    #[serde(default)]
    pub is_radio: bool,

    /// Extra/unknown attributes not mapped to named fields.
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub extras: HashMap<String, String>,
}

/// Catchup / timeshift configuration for a channel.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CatchupConfig {
    /// Catchup type identifier.
    pub catchup_type: Option<CatchupType>,

    /// Number of days of catchup available.
    pub days: Option<u32>,

    /// URL template for catchup playback.
    pub source: Option<String>,
}

/// Known catchup types.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum CatchupType {
    Default,
    Append,
    Shift,
    Flussonic,
    Fs,
    Xc,
}

impl std::fmt::Display for CatchupType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Default => write!(f, "default"),
            Self::Append => write!(f, "append"),
            Self::Shift => write!(f, "shift"),
            Self::Flussonic => write!(f, "flussonic"),
            Self::Fs => write!(f, "fs"),
            Self::Xc => write!(f, "xc"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_entry_has_no_url() {
        let entry = PlaylistEntry::default();
        assert!(entry.url.is_none());
        assert!(entry.name.is_none());
        assert!(entry.extras.is_empty());
        assert!(!entry.is_radio);
    }

    #[test]
    fn extras_are_skipped_when_empty_in_json() {
        let entry = PlaylistEntry::default();
        let json = serde_json::to_string(&entry).unwrap();
        assert!(!json.contains("extras"));
    }
}
