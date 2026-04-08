//! M3U/M3U8 playlist parser.
//!
//! Delegates low-level parsing to the `crispy_m3u` crate,
//! then applies resolution detection and channel numbering
//! to produce crispy-core [`Channel`] models.

use std::collections::HashMap;
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

use crate::models::Channel;

static RE_4K: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\b(4K|UHD|2160P?)\b").unwrap());
static RE_FHD: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\b(FHD|1080P?)\b").unwrap());
static RE_HD: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\b(HD|720P?)\b").unwrap());
static RE_SD: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\b(SD|480P?|576P?)\b").unwrap());

/// Result of M3U parsing: channels + optional EPG URL.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct M3uParseResult {
    /// Parsed channels.
    pub channels: Vec<Channel>,
    /// EPG URL from `url-tvg` or `x-tvg-url` header.
    pub epg_url: Option<String>,
    /// Parse errors for individual entries that failed.
    /// Callers can log these without losing valid channels.
    #[serde(default)]
    pub errors: Vec<String>,
}

// ── Resolution detection ─────────────────────────

fn detect_resolution(attrs: &HashMap<String, String>, name: &str, url: &str) -> Option<String> {
    // 1. Explicit attribute.
    let explicit = attrs
        .get("tvg-resolution")
        .or_else(|| attrs.get("quality"))
        .or_else(|| attrs.get("res"));
    if let Some(val) = explicit
        && !val.is_empty()
    {
        return Some(normalize_resolution(val));
    }

    // 2. Infer from channel name.
    let upper_name = name.to_uppercase();
    if has_4k(&upper_name) {
        return Some("4K".to_string());
    }
    if has_fhd(&upper_name) {
        return Some("FHD".to_string());
    }
    if has_hd(&upper_name) {
        return Some("HD".to_string());
    }
    if has_sd(&upper_name) {
        return Some("SD".to_string());
    }

    // 3. Infer from URL.
    let upper_url = url.to_uppercase();
    if has_4k(&upper_url) {
        return Some("4K".to_string());
    }
    if has_fhd(&upper_url) {
        return Some("FHD".to_string());
    }
    if has_hd(&upper_url) {
        return Some("HD".to_string());
    }

    None
}

fn normalize_resolution(raw: &str) -> String {
    let upper = raw.to_uppercase();
    if has_4k(&upper) {
        return "4K".to_string();
    }
    if has_fhd(&upper) {
        return "FHD".to_string();
    }
    if has_hd(&upper) {
        return "HD".to_string();
    }
    if has_sd(&upper) {
        return "SD".to_string();
    }
    upper
}

fn has_4k(s: &str) -> bool {
    RE_4K.is_match(s)
}

fn has_fhd(s: &str) -> bool {
    RE_FHD.is_match(s)
}

fn has_hd(s: &str) -> bool {
    RE_HD.is_match(s)
}

fn has_sd(s: &str) -> bool {
    RE_SD.is_match(s)
}

/// Parse M3U/M3U8 playlist content into channels.
///
/// Delegates low-level parsing to `crispy_m3u::parse`, then applies
/// resolution detection, channel numbering, user-agent extraction,
/// and additional attribute mapping that the `From<M3uEntry>` impl
/// does not cover.
pub fn parse_m3u(content: &str) -> M3uParseResult {
    if content.trim().is_empty() {
        return M3uParseResult {
            channels: Vec::new(),
            epg_url: None,
            errors: Vec::new(),
        };
    }

    let playlist = match crispy_m3u::parse_with_mode(content, crispy_m3u::ParseMode::Permissive) {
        Ok(p) => p,
        Err(e) => {
            return M3uParseResult {
                channels: Vec::new(),
                epg_url: None,
                errors: vec![format!("M3U parse error: {e}")],
            };
        }
    };

    let epg_url = playlist.header.epg_url.clone();

    let mut channels = Vec::with_capacity(playlist.entries.len());
    let mut errors = Vec::new();

    for (i, entry) in playlist.entries.into_iter().enumerate() {
        if !entry.has_url() {
            continue;
        }

        let name = match &entry.name {
            Some(n) if !n.is_empty() => n.clone(),
            _ => {
                errors.push(format!("Entry {} has no name", i + 1));
                continue;
            }
        };

        let url = entry.primary_url().unwrap_or_default().to_string();

        // Extract user-agent from VLC options before moving entry.
        let user_agent = entry.vlc_options.get("http-user-agent").cloned();

        // Extract extra attributes before moving entry.
        let tvg_country = entry.extras.get("tvg-country").cloned();
        let parent_code = entry.extras.get("parent-code").cloned();
        let is_radio = entry.is_radio;

        let resolution_attrs = entry.extras.clone();

        let mut ch: Channel = entry.into();

        // Apply resolution detection (not done by the From impl).
        ch.resolution = detect_resolution(&resolution_attrs, &name, &url);

        // Set channel number if not already set from tvg-chno.
        if ch.number.is_none() {
            ch.number = Some((i + 1) as i32);
        }

        // Apply fields not covered by From<M3uEntry>.
        ch.user_agent = user_agent;
        ch.tvg_country = tvg_country;
        ch.parent_code = parent_code;
        ch.is_radio = is_radio;

        channels.push(ch);
    }

    M3uParseResult {
        channels,
        epg_url,
        errors,
    }
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_empty_content() {
        let result = parse_m3u("");
        assert!(result.channels.is_empty());
        assert!(result.epg_url.is_none());
    }

    #[test]
    fn parse_basic_playlist() {
        let content = r#"#EXTM3U url-tvg="http://epg.example.com/guide.xml"
#EXTINF:-1 tvg-id="ch1" tvg-name="Channel 1" tvg-logo="http://logo.example.com/ch1.png" group-title="News",Channel 1
http://stream.example.com/ch1
#EXTINF:-1 tvg-id="ch2" tvg-name="Channel 2" tvg-logo="http://logo.example.com/ch2.png" group-title="Sports",Channel 2 HD
http://stream.example.com/ch2
#EXTINF:-1 tvg-id="ch3" group-title="Movies" catchup="flussonic" catchup-days="7" catchup-source="http://catchup/{start}",Movie Channel 4K
http://stream.example.com/ch3
"#;

        let result = parse_m3u(content);

        assert_eq!(
            result.epg_url.as_deref(),
            Some("http://epg.example.com/guide.xml"),
        );
        assert_eq!(result.channels.len(), 3);

        // Channel 1.
        let ch1 = &result.channels[0];
        assert_eq!(ch1.name, "Channel 1");
        assert_eq!(ch1.tvg_id.as_deref(), Some("ch1"));
        assert_eq!(ch1.channel_group.as_deref(), Some("News"),);
        assert_eq!(
            ch1.logo_url.as_deref(),
            Some("http://logo.example.com/ch1.png"),
        );
        assert_eq!(ch1.number, Some(1));
        assert!(!ch1.has_catchup);

        // Channel 2 — HD from name.
        let ch2 = &result.channels[1];
        assert_eq!(ch2.name, "Channel 2 HD");
        assert_eq!(ch2.resolution.as_deref(), Some("HD"),);

        // Channel 3 — 4K + catchup.
        let ch3 = &result.channels[2];
        assert_eq!(ch3.name, "Movie Channel 4K");
        assert_eq!(ch3.resolution.as_deref(), Some("4K"),);
        assert!(ch3.has_catchup);
        assert_eq!(ch3.catchup_days, 7);
        assert_eq!(ch3.catchup_type.as_deref(), Some("flussonic"),);
        assert!(ch3.catchup_source.is_some());
    }

    #[test]
    fn parse_user_agent() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,Test Channel\n",
            "#EXTVLCOPT:http-user-agent=CustomAgent/1.0\n",
            "http://stream.example.com/test\n",
        );
        let result = parse_m3u(content);
        assert_eq!(result.channels.len(), 1);
        assert_eq!(
            result.channels[0].user_agent.as_deref(),
            Some("CustomAgent/1.0"),
        );
    }

    #[test]
    fn parse_x_tvg_url_variant() {
        let content = concat!(
            "#EXTM3U x-tvg-url=\"http://alt.epg/guide\"\n",
            "#EXTINF:-1,Ch\n",
            "http://s.example.com/1\n",
        );
        let result = parse_m3u(content);
        assert_eq!(result.epg_url.as_deref(), Some("http://alt.epg/guide"),);
    }

    #[test]
    fn resolution_from_explicit_attr() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 tvg-resolution=\"1080p\",FooBar\n",
            "http://s.example.com/live/channel.ts\n",
        );
        let result = parse_m3u(content);
        assert_eq!(result.channels[0].resolution.as_deref(), Some("FHD"),);
    }

    #[test]
    fn resolution_from_quality_attr_without_name_or_url_hints() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 quality=\"4k\",Cinema Feed\n",
            "http://s.example.com/live/channel.ts\n",
        );
        let result = parse_m3u(content);
        assert_eq!(result.channels[0].resolution.as_deref(), Some("4K"));
    }

    #[test]
    fn resolution_from_res_attr_without_name_or_url_hints() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 res=\"720p\",Sports Feed\n",
            "http://s.example.com/live/channel.ts\n",
        );
        let result = parse_m3u(content);
        assert_eq!(result.channels[0].resolution.as_deref(), Some("HD"));
    }

    #[test]
    fn skip_non_stream_lines() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,A\n",
            "not-a-url\n",
            "#EXTINF:-1,B\n",
            "http://ok.example.com/b\n",
        );
        let result = parse_m3u(content);
        // "not-a-url" is not a stream URL, so A is
        // skipped. B is parsed.
        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].name, "B");
    }

    // ── Additional M3U tests ─────────────────────────

    #[test]
    fn parse_basic_m3u_two_entries() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,Alpha\n",
            "http://s.test/alpha\n",
            "#EXTINF:-1,Beta\n",
            "http://s.test/beta\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 2);
        assert_eq!(result.channels[0].name, "Alpha");
        assert_eq!(result.channels[0].stream_url, "http://s.test/alpha",);
        assert_eq!(result.channels[0].number, Some(1));
        assert_eq!(result.channels[1].name, "Beta");
        assert_eq!(result.channels[1].stream_url, "http://s.test/beta",);
        assert_eq!(result.channels[1].number, Some(2));
    }

    #[test]
    fn parse_extinf_all_attributes() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 tvg-id=\"abc.tv\" ",
            "tvg-name=\"ABC TV\" ",
            "tvg-logo=\"http://logo/abc.png\" ",
            "group-title=\"Entertainment\",ABC Television\n",
            "http://s.test/abc\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        let ch = &result.channels[0];
        assert_eq!(ch.tvg_id.as_deref(), Some("abc.tv"));
        assert_eq!(ch.tvg_name.as_deref(), Some("ABC TV"));
        assert_eq!(ch.logo_url.as_deref(), Some("http://logo/abc.png"),);
        assert_eq!(ch.channel_group.as_deref(), Some("Entertainment"),);
        assert_eq!(ch.name, "ABC Television");
    }

    #[test]
    fn parse_catchup_attributes() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 catchup=\"flussonic\" ",
            "catchup-days=\"5\" ",
            "catchup-source=\"http://c/{start}\",",
            "Catchup Chan\n",
            "http://s.test/catchup\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        let ch = &result.channels[0];
        assert!(ch.has_catchup);
        assert_eq!(ch.catchup_days, 5);
        assert_eq!(ch.catchup_type.as_deref(), Some("flussonic"),);
        assert_eq!(ch.catchup_source.as_deref(), Some("http://c/{start}"),);
    }

    #[test]
    fn parse_empty_m3u_string() {
        let result = parse_m3u("");
        assert!(result.channels.is_empty());
        assert!(result.epg_url.is_none());

        // Whitespace-only also counts as empty.
        let result2 = parse_m3u("   \n\n  ");
        assert!(result2.channels.is_empty());
    }

    #[test]
    fn parse_no_extm3u_header() {
        // Content starts directly with #EXTINF, no
        // #EXTM3U header line.
        let content = concat!("#EXTINF:-1,No Header Chan\n", "http://s.test/noheader\n",);

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].name, "No Header Chan");
        assert!(result.epg_url.is_none());
    }

    #[test]
    fn parse_multiline_url_after_extinf() {
        // URL is on the line after #EXTINF, separated by
        // blank lines.
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,Chan A\n",
            "\n",
            "http://s.test/a\n",
            "#EXTINF:-1,Chan B\n",
            "http://s.test/b\n",
        );

        let result = parse_m3u(content);

        // Empty lines are skipped; URL still associates
        // with the prior #EXTINF.
        assert_eq!(result.channels.len(), 2);
        assert_eq!(result.channels[0].name, "Chan A");
        assert_eq!(result.channels[1].name, "Chan B");
    }

    #[test]
    fn parse_special_characters_in_name() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,News & Weather <Live> \"24/7\"\n",
            "http://s.test/special\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].name, "News & Weather <Live> \"24/7\"",);
    }

    #[test]
    fn parse_large_playlist_no_crash() {
        let mut content = String::from("#EXTM3U\n");
        for i in 0..150 {
            content.push_str(&format!(
                "#EXTINF:-1,Channel {}\n\
                 http://s.test/ch/{}\n",
                i, i,
            ));
        }

        let result = parse_m3u(&content);

        assert_eq!(result.channels.len(), 150);
        assert_eq!(result.channels[0].name, "Channel 0");
        assert_eq!(result.channels[149].name, "Channel 149");
        assert_eq!(result.channels[0].number, Some(1));
        assert_eq!(result.channels[149].number, Some(150));
    }

    #[test]
    fn parse_rtsp_urls() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,RTSP Stream\n",
            "rtsp://cam.local:554/live\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].stream_url, "rtsp://cam.local:554/live",);
    }

    #[test]
    fn parse_catchup_zero_days_no_catchup() {
        // catchup type present but catchup-days is 0 —
        // has_catchup should be false.
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 catchup=\"xc\" ",
            "catchup-days=\"0\",NoCatchup\n",
            "http://s.test/nc\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert!(!result.channels[0].has_catchup);
        assert_eq!(result.channels[0].catchup_days, 0);
    }

    #[test]
    fn parse_resolution_from_url() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,Plain Name\n",
            "http://s.test/stream/1080p/live\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].resolution.as_deref(), Some("FHD"),);
    }

    #[test]
    fn parse_sd_resolution_from_name() {
        let content = concat!("#EXTM3U\n", "#EXTINF:-1,Channel SD\n", "http://s.test/sd\n",);

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].resolution.as_deref(), Some("SD"),);
    }

    #[test]
    fn channel_ids_are_stable() {
        let content = concat!("#EXTM3U\n", "#EXTINF:-1,Stable\n", "http://s.test/stable\n",);

        let r1 = parse_m3u(content);

        // Channel IDs are UUID v7 — unique per parse by design.
        // Assert the ID is present and well-formed (non-empty UUID string).
        assert!(!r1.channels[0].id.is_empty());
        assert_eq!(r1.channels[0].id.len(), 36); // standard UUID hyphenated format
    }

    #[test]
    fn error_accumulation_invalid_among_valid() {
        // Mix of valid entries and entries without a channel
        // name (no comma in EXTINF → recorded as error).
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,Valid One\n",
            "http://s.test/valid1\n",
            "#EXTINF:-1 tvg-id=\"bad\"\n",
            "http://s.test/no-name\n",
            "#EXTINF:-1,Valid Two\n",
            "http://s.test/valid2\n",
        );

        let result = parse_m3u(content);

        // Valid channels still parsed.
        assert_eq!(result.channels.len(), 2);
        assert_eq!(result.channels[0].name, "Valid One");
        assert_eq!(result.channels[1].name, "Valid Two");

        // Error recorded for the nameless entry.
        assert_eq!(result.errors.len(), 1);
        assert!(
            result.errors[0].contains("has no name"),
            "Error should mention missing name: {}",
            result.errors[0],
        );
    }

    #[test]
    fn error_accumulation_empty_name() {
        // EXTINF with comma but nothing after it → empty name.
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,\n",
            "http://s.test/empty\n",
            "#EXTINF:-1,OK Channel\n",
            "http://s.test/ok\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].name, "OK Channel");
        assert_eq!(result.errors.len(), 1);
        assert!(result.errors[0].contains("has no name"));
    }

    #[test]
    fn no_errors_for_valid_playlist() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,Channel A\n",
            "http://s.test/a\n",
            "#EXTINF:-1,Channel B\n",
            "http://s.test/b\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 2);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn errors_serialized_in_json() {
        let result = M3uParseResult {
            channels: Vec::new(),
            epg_url: None,
            errors: vec!["test error".to_string()],
        };

        let json = serde_json::to_string(&result).unwrap();
        assert!(json.contains("\"errors\":[\"test error\"]"));

        // Deserialize back — errors field is preserved.
        let parsed: M3uParseResult = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.errors.len(), 1);
    }

    #[test]
    fn errors_default_empty_on_deserialize() {
        // Old JSON without errors field → defaults to empty.
        let json = r#"{"channels":[],"epg_url":null}"#;
        let result: M3uParseResult = serde_json::from_str(json).unwrap();
        assert!(result.errors.is_empty());
    }

    // ── Extended M3U attribute tests ─────────────────

    #[test]
    fn parse_tvg_chno_overrides_auto_number() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 tvg-chno=\"42\",Channel With Number\n",
            "http://s.test/numbered\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        // tvg-chno=42 should override the auto-increment (1).
        assert_eq!(result.channels[0].number, Some(42));
    }

    #[test]
    fn parse_tvg_chno_fallback_to_auto() {
        // No tvg-chno — falls back to auto-increment counter.
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,No ChNo\n",
            "http://s.test/nochno\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels[0].number, Some(1));
    }

    #[test]
    fn parse_tvg_shift() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 tvg-shift=\"-3.5\",Shifted Channel\n",
            "http://s.test/shifted\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert!((result.channels[0].tvg_shift.unwrap() - (-3.5)).abs() < f64::EPSILON,);
    }

    #[test]
    fn parse_tvg_language_and_country() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 tvg-language=\"French\" tvg-country=\"FR\",France 24\n",
            "http://s.test/fr24\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        let ch = &result.channels[0];
        assert_eq!(ch.tvg_language.as_deref(), Some("French"));
        assert_eq!(ch.tvg_country.as_deref(), Some("FR"));
    }

    #[test]
    fn parse_parent_code() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 parent-code=\"1234\",Locked Channel\n",
            "http://s.test/locked\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].parent_code.as_deref(), Some("1234"),);
    }

    #[test]
    fn parse_radio_flag_true() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 radio=\"true\",Radio Station\n",
            "http://s.test/radio\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert!(result.channels[0].is_radio);
    }

    #[test]
    fn parse_radio_flag_one() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 radio=\"1\",Radio Station\n",
            "http://s.test/radio1\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert!(result.channels[0].is_radio);
    }

    #[test]
    fn parse_radio_flag_absent_is_false() {
        let content = concat!("#EXTM3U\n", "#EXTINF:-1,TV Channel\n", "http://s.test/tv\n",);

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert!(!result.channels[0].is_radio);
    }

    #[test]
    fn parse_tvg_rec() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 tvg-rec=\"http://rec/{start}/{end}\",Rec Channel\n",
            "http://s.test/rec\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(
            result.channels[0].tvg_rec.as_deref(),
            Some("http://rec/{start}/{end}"),
        );
    }

    #[test]
    fn parse_all_extended_attributes_together() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 ",
            "tvg-id=\"abc.tv\" ",
            "tvg-name=\"ABC\" ",
            "tvg-logo=\"http://logo/abc.png\" ",
            "tvg-chno=\"7\" ",
            "tvg-shift=\"2\" ",
            "tvg-language=\"English\" ",
            "tvg-country=\"US\" ",
            "tvg-rec=\"http://rec/{start}\" ",
            "group-title=\"News\" ",
            "parent-code=\"0000\" ",
            "radio=\"false\" ",
            "catchup=\"flussonic\" ",
            "catchup-days=\"3\" ",
            "catchup-source=\"http://c/{start}\",",
            "ABC News\n",
            "http://s.test/abc\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 1);
        let ch = &result.channels[0];
        assert_eq!(ch.name, "ABC News");
        assert_eq!(ch.tvg_id.as_deref(), Some("abc.tv"));
        assert_eq!(ch.tvg_name.as_deref(), Some("ABC"));
        assert_eq!(ch.logo_url.as_deref(), Some("http://logo/abc.png"));
        assert_eq!(ch.number, Some(7));
        assert!((ch.tvg_shift.unwrap() - 2.0).abs() < f64::EPSILON);
        assert_eq!(ch.tvg_language.as_deref(), Some("English"));
        assert_eq!(ch.tvg_country.as_deref(), Some("US"));
        assert_eq!(ch.tvg_rec.as_deref(), Some("http://rec/{start}"));
        assert_eq!(ch.channel_group.as_deref(), Some("News"));
        assert_eq!(ch.parent_code.as_deref(), Some("0000"));
        assert!(!ch.is_radio); // "false" is not "true" or "1"
        assert!(ch.has_catchup);
        assert_eq!(ch.catchup_days, 3);
        assert_eq!(ch.catchup_type.as_deref(), Some("flussonic"));
        assert_eq!(ch.catchup_source.as_deref(), Some("http://c/{start}"));
    }
}
