//! M3U/M3U8 playlist parser.
//!
//! Ported from Dart `m3u_parser.dart`. Pure function,
//! no DB access.

use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

use crate::models::Channel;
use crate::utils::image_sanitizer::sanitize_image_url;

// ── Compiled regexes (once per process) ──────────
static LINE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\r?\n").unwrap());
static EPG_URL_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?i)(?:url-tvg|x-tvg-url)="([^"]+)""#).unwrap());
static ATTR_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"([\w-]+)="([^"]*)""#).unwrap());
static NAME_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r",\s*(.+)$").unwrap());
static UA_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)#EXTVLCOPT:http-user-agent=(.+)").unwrap());
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
}

/// Parse M3U/M3U8 playlist content into channels.
///
/// Supports `#EXTINF` directives, `#EXTVLCOPT`
/// user-agent, catchup attributes, and resolution
/// detection.
pub fn parse_m3u(content: &str) -> M3uParseResult {
    if content.trim().is_empty() {
        return M3uParseResult {
            channels: Vec::new(),
            epg_url: None,
        };
    }

    let lines: Vec<&str> = LINE_RE.split(content).collect();
    let mut channels = Vec::new();
    let mut epg_url: Option<String> = None;

    let mut current_extinf: Option<&str> = None;
    let mut current_ua: Option<String> = None;
    let mut channel_number: i32 = 0;

    for raw_line in &lines {
        let line = raw_line.trim();
        if line.is_empty() {
            continue;
        }

        // Extract EPG URL from #EXTM3U header.
        if line.starts_with("#EXTM3U") {
            if let Some(cap) = EPG_URL_RE.captures(line) {
                epg_url = Some(cap.get(1).unwrap().as_str().trim().to_string());
            }
            continue;
        }

        // Capture #EXTINF directive.
        if line.starts_with("#EXTINF:") {
            current_extinf = Some(line);
            current_ua = None;
            continue;
        }

        // Capture user-agent from #EXTVLCOPT.
        if line.starts_with("#EXTVLCOPT:") {
            if let Some(cap) = UA_RE.captures(line) {
                current_ua = Some(cap.get(1).unwrap().as_str().trim().to_string());
            }
            continue;
        }

        // Skip other directives.
        if line.starts_with('#') {
            continue;
        }

        // Stream URL following an #EXTINF.
        if current_extinf.is_some() && is_stream_url(line) {
            channel_number += 1;
            if let Some(ch) = parse_entry(
                current_extinf.unwrap(),
                line,
                channel_number,
                current_ua.as_deref(),
                &ATTR_RE,
                &NAME_RE,
            ) {
                channels.push(ch);
            }
            current_extinf = None;
            current_ua = None;
        }
    }

    M3uParseResult { channels, epg_url }
}

fn is_stream_url(line: &str) -> bool {
    line.starts_with("http://")
        || line.starts_with("https://")
        || line.starts_with("rtsp://")
        || line.starts_with('/')
}

fn parse_entry(
    ext_inf: &str,
    stream_url: &str,
    number: i32,
    user_agent: Option<&str>,
    attr_re: &Regex,
    name_re: &Regex,
) -> Option<Channel> {
    // Extract key="value" attributes.
    let mut attrs = HashMap::new();
    for cap in attr_re.captures_iter(ext_inf) {
        let key = cap.get(1).unwrap().as_str().to_lowercase();
        let value = cap.get(2).unwrap().as_str().to_string();
        attrs.insert(key, value);
    }

    // Extract display name (text after last comma).
    let name = name_re
        .captures(ext_inf)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().trim().to_string())?;
    if name.is_empty() {
        return None;
    }

    // Generate stable ID from stream URL SHA-256 hash
    // (first 8 bytes → 16 hex chars).
    let mut hasher = Sha256::new();
    hasher.update(stream_url.as_bytes());
    let hash = hasher.finalize();
    let id = hash
        .iter()
        .take(8)
        .map(|b| format!("{b:02x}"))
        .collect::<String>();

    // Catchup attributes.
    let catchup_type = attrs
        .get("catchup")
        .or_else(|| attrs.get("timeshift"))
        .or_else(|| attrs.get("archive"))
        .cloned();

    let catchup_days_str = attrs
        .get("catchup-days")
        .or_else(|| attrs.get("catchup-archive"))
        .or_else(|| attrs.get("archive-days"));
    let catchup_days: i32 = catchup_days_str.and_then(|s| s.parse().ok()).unwrap_or(0);

    let catchup_source = attrs.get("catchup-source").cloned();

    let has_catchup = catchup_type.as_ref().is_some_and(|t| !t.is_empty()) && catchup_days > 0;

    // Detect resolution.
    let resolution = detect_resolution(&attrs, &name, stream_url);

    Some(Channel {
        id,
        name,
        stream_url: stream_url.to_string(),
        number: Some(number),
        channel_group: attrs.get("group-title").cloned(),
        logo_url: sanitize_image_url(attrs.get("tvg-logo").cloned()),
        tvg_id: attrs.get("tvg-id").cloned(),
        tvg_name: attrs.get("tvg-name").cloned(),
        is_favorite: false,
        user_agent: user_agent.map(String::from),
        has_catchup,
        catchup_days,
        catchup_type,
        catchup_source,
        resolution,
        source_id: None,
        added_at: None,
        updated_at: None,
    })
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
            "http://s.example.com/fhd\n",
        );
        let result = parse_m3u(content);
        assert_eq!(result.channels[0].resolution.as_deref(), Some("FHD"),);
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
    fn parse_rtsp_and_path_urls() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1,RTSP Stream\n",
            "rtsp://cam.local:554/live\n",
            "#EXTINF:-1,Local Path\n",
            "/mnt/media/stream.ts\n",
        );

        let result = parse_m3u(content);

        assert_eq!(result.channels.len(), 2);
        assert_eq!(result.channels[0].stream_url, "rtsp://cam.local:554/live",);
        assert_eq!(result.channels[1].stream_url, "/mnt/media/stream.ts",);
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
        let r2 = parse_m3u(content);

        assert_eq!(r1.channels[0].id, r2.channels[0].id);
        assert!(!r1.channels[0].id.is_empty());
    }
}
