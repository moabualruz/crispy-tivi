//! M3U playlist data types.
//!
//! Mirrors the field set from `@iptv/playlist`'s TypeScript types
//! using Rust idioms (snake_case, `Option<String>`, `HashMap`).

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use smallvec::SmallVec;

/// A parsed M3U playlist containing header metadata and channel entries.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct M3uPlaylist {
    /// Channel / stream entries.
    pub entries: Vec<M3uEntry>,

    /// Playlist-level header metadata.
    pub header: M3uHeader,
}

/// Playlist-level header metadata extracted from the `#EXTM3U` line.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct M3uHeader {
    /// EPG guide URL (`x-tvg-url` or `url-tvg` attribute).
    pub epg_url: Option<String>,

    /// Default catchup type from `#EXTM3U` header (inherited by entries
    /// that don't specify their own).
    pub catchup: Option<String>,

    /// Default catchup days from `#EXTM3U` header.
    pub catchup_days: Option<String>,

    /// Default catchup source URL template from `#EXTM3U` header.
    pub catchup_source: Option<String>,

    /// Extra/unknown header attributes not mapped to named fields.
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub extras: HashMap<String, String>,
}

/// A single M3U entry (live channel, radio stream, or VOD item).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct M3uEntry {
    /// Primary stream URL.
    pub url: Option<String>,

    /// Alternative stream URLs (multi-URL entries).
    #[serde(default, skip_serializing_if = "SmallVec::is_empty")]
    pub urls: SmallVec<[String; 2]>,

    /// Display name (text after the comma on `#EXTINF` line).
    pub name: Option<String>,

    /// `tvg-id` -- XMLTV channel identifier for EPG matching.
    pub tvg_id: Option<String>,

    /// `tvg-name` -- alternative name for EPG matching.
    pub tvg_name: Option<String>,

    /// `tvg-language` -- broadcast language.
    pub tvg_language: Option<String>,

    /// `tvg-logo` -- channel logo URL.
    pub tvg_logo: Option<String>,

    /// `tvg-url` -- per-channel EPG URL.
    pub tvg_url: Option<String>,

    /// `tvg-rec` -- recording/catchup hint.
    pub tvg_rec: Option<String>,

    /// `tvg-chno` -- channel number.
    pub tvg_chno: Option<String>,

    /// `group-title` -- category / group name.
    pub group_title: Option<String>,

    /// `timeshift` -- timeshift duration hint.
    pub timeshift: Option<String>,

    /// `catchup` -- catchup type identifier.
    pub catchup: Option<String>,

    /// `catchup-days` -- number of days of catchup available.
    pub catchup_days: Option<String>,

    /// `catchup-source` -- URL template for catchup playback.
    pub catchup_source: Option<String>,

    /// `#EXTINF` duration in seconds (-1 for live streams).
    pub duration: Option<f64>,

    /// Kodi stream properties from `#KODIPROP:key=value` lines.
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub stream_properties: HashMap<String, String>,

    /// VLC options from `#EXTVLCOPT:key=value` lines.
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub vlc_options: HashMap<String, String>,

    /// All groups this entry belongs to (multi-group support).
    /// First entry is the primary group from `group-title`.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub groups: Vec<String>,

    /// Whether this is a radio/audio-only stream (`radio="true"`).
    #[serde(default)]
    pub is_radio: bool,

    /// `tvg-shift` — EPG time offset in hours (e.g., `2.5` = +2h30m).
    pub tvg_shift: Option<f64>,

    /// `media="true"` — marks entry as VOD/media content.
    #[serde(default)]
    pub is_media: bool,

    /// `media-dir` — directory path for VOD media files.
    pub media_dir: Option<String>,

    /// `media-size` — file size in bytes for VOD media.
    pub media_size: Option<u64>,

    /// `provider-name` — content provider name.
    pub provider_name: Option<String>,

    /// `provider-type` — content provider type (e.g., "iptv", "satellite").
    pub provider_type: Option<String>,

    /// `provider-logo` — content provider logo URL.
    pub provider_logo: Option<String>,

    /// `provider-countries` — comma-separated country codes for the provider.
    pub provider_countries: Option<String>,

    /// `provider-languages` — comma-separated language codes for the provider.
    pub provider_languages: Option<String>,

    /// Web properties from `#WEBPROP:key=value` lines.
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub web_properties: HashMap<String, String>,

    /// Extra/unknown attributes not mapped to named fields.
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub extras: HashMap<String, String>,
}

impl M3uEntry {
    /// Returns `true` if this entry has at least one stream URL.
    pub fn has_url(&self) -> bool {
        self.url.is_some() || !self.urls.is_empty()
    }

    /// Returns `true` if this entry has been identified (has name, tvg_name, or tvg_id).
    pub fn is_identified(&self) -> bool {
        self.name.is_some() || self.tvg_name.is_some() || self.tvg_id.is_some()
    }
}

/// Convert an `M3uEntry` into a `PlaylistEntry` from the shared types crate.
impl From<M3uEntry> for crispy_iptv_types::PlaylistEntry {
    fn from(e: M3uEntry) -> Self {
        use crispy_iptv_types::{CatchupConfig, CatchupType};

        let catchup =
            if e.catchup.is_some() || e.catchup_days.is_some() || e.catchup_source.is_some() {
                Some(CatchupConfig {
                    catchup_type: e.catchup.as_deref().and_then(|s| match s {
                        "default" => Some(CatchupType::Default),
                        "append" => Some(CatchupType::Append),
                        "shift" => Some(CatchupType::Shift),
                        "flussonic" | "fs" => Some(CatchupType::Flussonic),
                        "xc" => Some(CatchupType::Xc),
                        _ => None,
                    }),
                    days: e
                        .catchup_days
                        .as_deref()
                        .and_then(|s| s.parse::<u32>().ok()),
                    source: e.catchup_source.clone(),
                })
            } else {
                None
            };

        // Use the first group from `groups` as the primary `group_title`
        // if `group_title` is not already set.
        let group_title = e.group_title.or_else(|| e.groups.first().cloned());

        // Merge stream_properties, vlc_options, and web_properties into extras
        // with prefixes.
        let mut extras = e.extras;
        for (k, v) in &e.stream_properties {
            extras.insert(format!("kodiprop:{k}"), v.clone());
        }
        for (k, v) in &e.vlc_options {
            extras.insert(format!("vlcopt:{k}"), v.clone());
        }
        for (k, v) in &e.web_properties {
            extras.insert(format!("webprop:{k}"), v.clone());
        }

        // Map provider attributes into extras for downstream consumption.
        if let Some(ref v) = e.provider_name {
            extras.insert("provider-name".to_string(), v.clone());
        }
        if let Some(ref v) = e.provider_type {
            extras.insert("provider-type".to_string(), v.clone());
        }
        if let Some(ref v) = e.provider_logo {
            extras.insert("provider-logo".to_string(), v.clone());
        }
        if let Some(ref v) = e.provider_countries {
            extras.insert("provider-countries".to_string(), v.clone());
        }
        if let Some(ref v) = e.provider_languages {
            extras.insert("provider-languages".to_string(), v.clone());
        }

        // Map VOD/media attributes into extras.
        if e.is_media {
            extras.insert("media".to_string(), "true".to_string());
        }
        if let Some(ref v) = e.media_dir {
            extras.insert("media-dir".to_string(), v.clone());
        }
        if let Some(size) = e.media_size {
            extras.insert("media-size".to_string(), size.to_string());
        }

        // Map tvg-shift into extras (as string hours).
        if let Some(shift) = e.tvg_shift {
            extras.insert("tvg-shift".to_string(), shift.to_string());
        }

        Self {
            url: e.url,
            urls: e.urls,
            name: e.name,
            tvg_id: e.tvg_id,
            tvg_name: e.tvg_name,
            tvg_language: e.tvg_language,
            tvg_logo: e.tvg_logo,
            tvg_url: e.tvg_url,
            tvg_rec: e.tvg_rec,
            tvg_chno: e.tvg_chno,
            group_title,
            timeshift: e.timeshift,
            catchup,
            duration: e.duration,
            is_radio: e.is_radio,
            extras,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_entry_has_no_url() {
        let entry = M3uEntry::default();
        assert!(!entry.has_url());
        assert!(!entry.is_identified());
    }

    #[test]
    fn entry_with_name_is_identified() {
        let entry = M3uEntry {
            name: Some("Test".into()),
            ..Default::default()
        };
        assert!(entry.is_identified());
    }

    #[test]
    fn conversion_to_playlist_entry_preserves_fields() {
        let entry = M3uEntry {
            url: Some("http://example.com/stream".into()),
            name: Some("Test Channel".into()),
            tvg_id: Some("ch1".into()),
            group_title: Some("News".into()),
            duration: Some(-1.0),
            catchup: Some("default".into()),
            catchup_days: Some("3".into()),
            ..Default::default()
        };

        let pe: crispy_iptv_types::PlaylistEntry = entry.into();
        assert_eq!(pe.url.as_deref(), Some("http://example.com/stream"));
        assert_eq!(pe.name.as_deref(), Some("Test Channel"));
        assert_eq!(pe.tvg_id.as_deref(), Some("ch1"));
        assert_eq!(pe.group_title.as_deref(), Some("News"));
        assert_eq!(pe.duration, Some(-1.0));

        let c = pe.catchup.unwrap();
        assert_eq!(
            c.catchup_type,
            Some(crispy_iptv_types::CatchupType::Default)
        );
        assert_eq!(c.days, Some(3));
    }

    #[test]
    fn conversion_preserves_is_radio_flag() {
        let entry = M3uEntry {
            url: Some("http://example.com/radio".into()),
            name: Some("Jazz FM".into()),
            is_radio: true,
            ..Default::default()
        };

        let pe: crispy_iptv_types::PlaylistEntry = entry.into();
        assert!(pe.is_radio);
        assert_eq!(pe.name.as_deref(), Some("Jazz FM"));
    }

    #[test]
    fn conversion_maps_provider_and_media_to_extras() {
        let entry = M3uEntry {
            url: Some("http://example.com/movie".into()),
            name: Some("Movie".into()),
            is_media: true,
            media_dir: Some("/movies".into()),
            media_size: Some(1_073_741_824),
            provider_name: Some("IPTV-Pro".into()),
            tvg_shift: Some(2.5),
            ..Default::default()
        };

        let pe: crispy_iptv_types::PlaylistEntry = entry.into();
        assert_eq!(pe.extras.get("media").map(String::as_str), Some("true"));
        assert_eq!(
            pe.extras.get("media-dir").map(String::as_str),
            Some("/movies")
        );
        assert_eq!(
            pe.extras.get("media-size").map(String::as_str),
            Some("1073741824")
        );
        assert_eq!(
            pe.extras.get("provider-name").map(String::as_str),
            Some("IPTV-Pro")
        );
        assert_eq!(pe.extras.get("tvg-shift").map(String::as_str), Some("2.5"));
    }

    #[test]
    fn conversion_maps_web_properties_to_extras() {
        let mut web_properties = HashMap::new();
        web_properties.insert("web-regex".to_string(), "<pattern>".to_string());

        let entry = M3uEntry {
            url: Some("http://example.com/web".into()),
            name: Some("Web Ch".into()),
            web_properties,
            ..Default::default()
        };

        let pe: crispy_iptv_types::PlaylistEntry = entry.into();
        assert_eq!(
            pe.extras.get("webprop:web-regex").map(String::as_str),
            Some("<pattern>")
        );
    }
}
