//! XMLTV electronic programme guide parser.
//!
//! Ported from Dart `epg_parser.dart`. Pure function,
//! no DB access. Uses regex-based extraction to handle
//! large (100 MB+) EPG files efficiently.

use std::collections::HashMap;
use std::sync::LazyLock;

use chrono::NaiveDateTime;
use regex::Regex;

use crate::models::EpgEntry;

// ── Compiled regexes (once per process) ──────────
static PROGRAMME_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<programme\s([^>]*)>(.*?)</programme>").unwrap());
static START_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"start="([^"]+)""#).unwrap());
static START_TS_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"start_timestamp="([^"]+)""#).unwrap());
static STOP_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"stop="([^"]+)""#).unwrap());
static STOP_TS_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"stop_timestamp="([^"]+)""#).unwrap());
static CHANNEL_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"channel="([^"]+)""#).unwrap());
static TITLE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<title[^>]*>(.*?)</title>").unwrap());
static DESC_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<desc[^>]*>(.*?)</desc>").unwrap());
static CAT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<category[^>]*>(.*?)</category>").unwrap());
static ICON_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"<icon\s+src="([^"]+)""#).unwrap());
static CHANNEL_NAME_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?s)<channel\s+id="([^"]+)"[^>]*>.*?<display-name[^>]*>(.*?)</display-name>.*?</channel>"#,
    )
    .unwrap()
});

// New regexes for extended XMLTV elements
static SUB_TITLE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<sub-title[^>]*>(.*?)</sub-title>").unwrap());
static DATE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<date[^>]*>(.*?)</date>").unwrap());
static LANGUAGE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<language[^>]*>(.*?)</language>").unwrap());
static COUNTRY_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<country[^>]*>(.*?)</country>").unwrap());
static CREDITS_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<credits>(.*?)</credits>").unwrap());
static DIRECTOR_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<director[^>]*>(.*?)</director>").unwrap());
static ACTOR_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<actor[^>]*>(.*?)</actor>").unwrap());
static WRITER_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<writer[^>]*>(.*?)</writer>").unwrap());
static PRESENTER_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<presenter[^>]*>(.*?)</presenter>").unwrap());
static EPISODE_NUM_XMLTV_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?s)<episode-num\s+system="xmltv_ns"[^>]*>(.*?)</episode-num>"#).unwrap()
});
static EPISODE_NUM_ONSCREEN_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?s)<episode-num\s+system="onscreen"[^>]*>(.*?)</episode-num>"#).unwrap()
});
static RATING_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<rating[^>]*>.*?<value>(.*?)</value>.*?</rating>").unwrap());
static STAR_RATING_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?s)<star-rating[^>]*>.*?<value>(.*?)</value>.*?</star-rating>").unwrap()
});
static PREVIOUSLY_SHOWN_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"<previously-shown").unwrap());
static NEW_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<new\s*/?>").unwrap());
static PREMIERE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<premiere").unwrap());
static LENGTH_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?s)<length\s+units="([^"]+)"[^>]*>(.*?)</length>"#).unwrap());

/// Parse XMLTV content into EPG entries.
///
/// Extracts `<programme>` blocks and maps them to
/// [`EpgEntry`] structs. Skips entries that lack
/// required fields (channel, start, stop, title).
pub fn parse_epg(content: &str) -> Vec<EpgEntry> {
    if content.trim().is_empty() {
        return Vec::new();
    }

    let mut entries = Vec::new();

    for cap in PROGRAMME_RE.captures_iter(content) {
        let attrs = cap.get(1).unwrap().as_str();
        let body = cap.get(2).unwrap().as_str();

        if let Some(entry) = parse_programme(attrs, body) {
            entries.push(entry);
        }
    }

    entries
}

/// Extract XMLTV `<channel>` display names.
///
/// Returns a map of channel ID to display name.
pub fn extract_channel_names(content: &str) -> HashMap<String, String> {
    let mut result = HashMap::new();
    for cap in CHANNEL_NAME_RE.captures_iter(content) {
        let id = cap.get(1).unwrap().as_str().to_string();
        let name = cap.get(2).unwrap().as_str().trim().to_string();
        if !name.is_empty() {
            result.entry(id).or_insert(name);
        }
    }
    result
}

// ── Internal helpers ─────────────────────────────

fn parse_programme(attrs: &str, body: &str) -> Option<EpgEntry> {
    let channel_id = CHANNEL_RE.captures(attrs)?.get(1)?.as_str().to_string();

    let start_raw = START_RE.captures(attrs).map(|c| c.get(1).unwrap().as_str());
    let start_ts_raw = START_TS_RE
        .captures(attrs)
        .map(|c| c.get(1).unwrap().as_str());

    let start_time = if let Some(raw) = start_raw {
        parse_xmltv_datetime(raw)?
    } else if let Some(ts) = start_ts_raw {
        let ts_val: i64 = ts.parse().ok()?;
        chrono::DateTime::from_timestamp(ts_val, 0).map(|dt| dt.naive_utc())?
    } else {
        return None;
    };

    let stop_raw = STOP_RE.captures(attrs).map(|c| c.get(1).unwrap().as_str());
    let stop_ts_raw = STOP_TS_RE
        .captures(attrs)
        .map(|c| c.get(1).unwrap().as_str());

    let end_time = if let Some(raw) = stop_raw {
        parse_xmltv_datetime(raw)?
    } else if let Some(ts) = stop_ts_raw {
        let ts_val: i64 = ts.parse().ok()?;
        chrono::DateTime::from_timestamp(ts_val, 0).map(|dt| dt.naive_utc())?
    } else {
        return None;
    };

    let title_match = TITLE_RE.captures(body)?;
    let title_text = decode_xml_entities(title_match.get(1)?.as_str().trim());
    let title = decode_maybe_base64(&title_text);

    let description = DESC_RE.captures(body).map(|c| {
        let desc_text = decode_xml_entities(c.get(1).unwrap().as_str().trim());
        decode_maybe_base64(&desc_text)
    });

    // Collect ALL <category> elements, joined with semicolons.
    let category = {
        let cats: Vec<String> = CAT_RE
            .captures_iter(body)
            .filter_map(|c| {
                let text = decode_xml_entities(c.get(1)?.as_str().trim());
                if text.is_empty() { None } else { Some(text) }
            })
            .collect();
        if cats.is_empty() {
            None
        } else {
            Some(cats.join("; "))
        }
    };

    let icon_url = ICON_RE
        .captures(body)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().trim().to_string());

    // Sub-title (episode name)
    let sub_title = SUB_TITLE_RE.captures(body).map(|c| {
        let text = decode_xml_entities(c.get(1).unwrap().as_str().trim());
        decode_maybe_base64(&text)
    });

    // Original air date
    let air_date = DATE_RE
        .captures(body)
        .map(|c| c.get(1).unwrap().as_str().trim().to_string())
        .filter(|s| !s.is_empty());

    // Language
    let language = LANGUAGE_RE
        .captures(body)
        .map(|c| decode_xml_entities(c.get(1).unwrap().as_str().trim()))
        .filter(|s| !s.is_empty());

    // Country
    let country = COUNTRY_RE
        .captures(body)
        .map(|c| decode_xml_entities(c.get(1).unwrap().as_str().trim()))
        .filter(|s| !s.is_empty());

    // Credits (directors, actors, writers, presenters)
    let (directors, cast, writers, presenters) =
        if let Some(credits_cap) = CREDITS_RE.captures(body) {
            let credits_body = credits_cap.get(1).unwrap().as_str();
            (
                extract_multi(&DIRECTOR_RE, credits_body),
                extract_multi(&ACTOR_RE, credits_body),
                extract_multi(&WRITER_RE, credits_body),
                extract_multi(&PRESENTER_RE, credits_body),
            )
        } else {
            (None, None, None, None)
        };

    // Episode numbering — xmltv_ns format: "season.episode.part"
    // Numbers are zero-based in xmltv_ns, so we add 1.
    let (season, episode) = EPISODE_NUM_XMLTV_RE
        .captures(body)
        .map(|c| parse_xmltv_ns(c.get(1).unwrap().as_str().trim()))
        .unwrap_or((None, None));

    // On-screen episode label (e.g. "S01E05")
    let episode_label = EPISODE_NUM_ONSCREEN_RE
        .captures(body)
        .map(|c| c.get(1).unwrap().as_str().trim().to_string())
        .filter(|s| !s.is_empty());

    // Content rating (e.g. "PG-13")
    let content_rating = RATING_RE
        .captures(body)
        .map(|c| c.get(1).unwrap().as_str().trim().to_string())
        .filter(|s| !s.is_empty());

    // Star rating (e.g. "7.5/10")
    let star_rating = STAR_RATING_RE
        .captures(body)
        .map(|c| c.get(1).unwrap().as_str().trim().to_string())
        .filter(|s| !s.is_empty());

    // Boolean flags
    let is_rerun = PREVIOUSLY_SHOWN_RE.is_match(body);
    let is_new = NEW_RE.is_match(body);
    let is_premiere = PREMIERE_RE.is_match(body);

    // Programme length
    let length_minutes = LENGTH_RE.captures(body).and_then(|c| {
        let units = c.get(1).unwrap().as_str();
        let value: f64 = c.get(2).unwrap().as_str().trim().parse().ok()?;
        match units {
            "minutes" => Some(value as i32),
            "hours" => Some((value * 60.0) as i32),
            "seconds" => Some((value / 60.0).round() as i32),
            _ => None,
        }
    });

    Some(EpgEntry {
        channel_id,
        title,
        start_time,
        end_time,
        description,
        category,
        icon_url,
        source_id: None,
        sub_title,
        season,
        episode,
        episode_label,
        air_date,
        content_rating,
        star_rating,
        directors,
        cast,
        writers,
        presenters,
        language,
        country,
        is_rerun,
        is_new,
        is_premiere,
        length_minutes,
    })
}

/// Collect all matches for a credits sub-element regex into a
/// semicolon-separated string. Returns `None` when no matches.
fn extract_multi(re: &Regex, text: &str) -> Option<String> {
    let items: Vec<String> = re
        .captures_iter(text)
        .filter_map(|c| {
            let val = decode_xml_entities(c.get(1)?.as_str().trim());
            if val.is_empty() { None } else { Some(val) }
        })
        .collect();
    if items.is_empty() {
        None
    } else {
        Some(items.join("; "))
    }
}

/// Parse XMLTV episode-num with `system="xmltv_ns"`.
///
/// Format: `season.episode.part` where each is zero-based.
/// We add 1 to return human-friendly 1-based numbers.
/// Fields may contain a range like `0/2` — we take the first number.
fn parse_xmltv_ns(raw: &str) -> (Option<i32>, Option<i32>) {
    let parts: Vec<&str> = raw.split('.').collect();

    let parse_part = |s: &str| -> Option<i32> {
        let s = s.trim();
        if s.is_empty() {
            return None;
        }
        // Handle ranges like "0/24" — take the first number.
        let num_str = s.split('/').next()?.trim();
        let n: i32 = num_str.parse().ok()?;
        Some(n + 1) // Convert from zero-based to one-based
    };

    let season = parts.first().and_then(|s| parse_part(s));
    let episode = parts.get(1).and_then(|s| parse_part(s));

    (season, episode)
}

/// Parse XMLTV datetime: `YYYYMMDDHHmmss +HHMM`.
///
/// Returns a `NaiveDateTime` adjusted to UTC.
fn parse_xmltv_datetime(raw: &str) -> Option<NaiveDateTime> {
    let parts: Vec<&str> = raw.split_whitespace().collect();
    let date_str = parts.first()?;

    if date_str.len() < 14 {
        return None;
    }

    let year: i32 = date_str[0..4].parse().ok()?;
    let month: u32 = date_str[4..6].parse().ok()?;
    let day: u32 = date_str[6..8].parse().ok()?;
    let hour: u32 = date_str[8..10].parse().ok()?;
    let minute: u32 = date_str[10..12].parse().ok()?;
    let second: u32 = date_str[12..14].parse().ok()?;

    let dt = NaiveDateTime::new(
        chrono::NaiveDate::from_ymd_opt(year, month, day)?,
        chrono::NaiveTime::from_hms_opt(hour, minute, second)?,
    );

    // Apply timezone offset if present.
    if parts.len() > 1 {
        let tz = parts[1];
        let sign: i64 = if tz.starts_with('-') { 1 } else { -1 };
        let tz_clean: String = tz.chars().filter(|c| c.is_ascii_digit()).collect();
        if tz_clean.len() >= 4 {
            let tz_hours: i64 = tz_clean[0..2].parse().unwrap_or(0);
            let tz_minutes: i64 = tz_clean[2..4].parse().unwrap_or(0);
            let offset_secs = sign * (tz_hours * 3600 + tz_minutes * 60);
            return Some(dt + chrono::Duration::seconds(offset_secs));
        }
    }

    Some(dt)
}

/// Decode common XML entities.
fn decode_xml_entities(text: &str) -> String {
    text.replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
}

/// Try base64-decoding `value`. If the decoded bytes
/// are valid UTF-8, return the decoded string; otherwise
/// return the original.
fn decode_maybe_base64(value: &str) -> String {
    use base64::{Engine as _, engine::general_purpose::STANDARD};
    if value.is_empty() {
        return String::new();
    }
    match STANDARD.decode(value) {
        Ok(bytes) => String::from_utf8(bytes).unwrap_or_else(|_| value.to_string()),
        Err(_) => value.to_string(),
    }
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE_XMLTV: &str = r#"<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="test">
  <channel id="bbc1">
    <display-name>BBC One</display-name>
  </channel>
  <channel id="itv1">
    <display-name>ITV</display-name>
  </channel>
  <programme start="20240115060000 +0000" stop="20240115070000 +0000" channel="bbc1">
    <title>Breakfast News</title>
    <desc>Morning news &amp; weather</desc>
    <category>News</category>
    <icon src="http://img.example.com/bn.png"/>
  </programme>
  <programme start="20240115070000 +0100" stop="20240115080000 +0100" channel="itv1">
    <title>Good Morning</title>
  </programme>
</tv>"#;

    #[test]
    fn parse_epg_entries() {
        let entries = parse_epg(SAMPLE_XMLTV);
        assert_eq!(entries.len(), 2);

        let e0 = &entries[0];
        assert_eq!(e0.channel_id, "bbc1");
        assert_eq!(e0.title, "Breakfast News");
        assert_eq!(e0.description.as_deref(), Some("Morning news & weather"),);
        assert_eq!(e0.category.as_deref(), Some("News"),);
        assert_eq!(
            e0.icon_url.as_deref(),
            Some("http://img.example.com/bn.png"),
        );

        // Start is 2024-01-15 06:00 UTC (offset +0000).
        assert_eq!(
            e0.start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 15,).unwrap(),
                chrono::NaiveTime::from_hms_opt(6, 0, 0,).unwrap(),
            ),
        );
    }

    #[test]
    fn parse_epg_with_timezone_offset() {
        let entries = parse_epg(SAMPLE_XMLTV);
        let e1 = &entries[1];
        assert_eq!(e1.channel_id, "itv1");
        assert_eq!(e1.title, "Good Morning");
        assert!(e1.description.is_none());

        // +0100: 07:00 local = 06:00 UTC.
        assert_eq!(
            e1.start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 15,).unwrap(),
                chrono::NaiveTime::from_hms_opt(6, 0, 0,).unwrap(),
            ),
        );
    }

    #[test]
    fn extract_channel_names_test() {
        let names = extract_channel_names(SAMPLE_XMLTV);
        assert_eq!(names.len(), 2);
        assert_eq!(names.get("bbc1").map(|s| s.as_str()), Some("BBC One"),);
        assert_eq!(names.get("itv1").map(|s| s.as_str()), Some("ITV"),);
    }

    #[test]
    fn parse_empty_epg() {
        let entries = parse_epg("");
        assert!(entries.is_empty());
    }

    #[test]
    fn xml_entity_decoding() {
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="c1">
    <title>Tom &amp; Jerry&apos;s &quot;Show&quot;</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "Tom & Jerry's \"Show\"",);
    }

    #[test]
    fn parse_single_programme_all_fields() {
        let xml = r#"<tv>
  <programme start="20240320180000 +0000" stop="20240320190000 +0000" channel="hbo">
    <title>Movie Night</title>
    <desc>A thrilling adventure film</desc>
    <category>Film</category>
    <icon src="https://img.example.com/movie.png"/>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);

        let e = &entries[0];
        assert_eq!(e.channel_id, "hbo");
        assert_eq!(e.title, "Movie Night");
        assert_eq!(e.description.as_deref(), Some("A thrilling adventure film"),);
        assert_eq!(e.category.as_deref(), Some("Film"));
        assert_eq!(
            e.icon_url.as_deref(),
            Some("https://img.example.com/movie.png"),
        );
        assert_eq!(
            e.start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 3, 20).unwrap(),
                chrono::NaiveTime::from_hms_opt(18, 0, 0).unwrap(),
            ),
        );
        assert_eq!(
            e.end_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 3, 20).unwrap(),
                chrono::NaiveTime::from_hms_opt(19, 0, 0).unwrap(),
            ),
        );
    }

    #[test]
    fn parse_multiple_programmes_different_channels() {
        let xml = r#"<tv>
  <programme start="20240101080000 +0000" stop="20240101090000 +0000" channel="ch1">
    <title>Morning Show</title>
  </programme>
  <programme start="20240101090000 +0000" stop="20240101100000 +0000" channel="ch2">
    <title>News Hour</title>
    <desc>Daily news roundup</desc>
  </programme>
  <programme start="20240101100000 +0000" stop="20240101110000 +0000" channel="ch3">
    <title>Cooking Time</title>
    <category>Food</category>
  </programme>
  <programme start="20240101110000 +0000" stop="20240101120000 +0000" channel="ch1">
    <title>Late Morning</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 4);

        assert_eq!(entries[0].channel_id, "ch1");
        assert_eq!(entries[0].title, "Morning Show");
        assert_eq!(entries[1].channel_id, "ch2");
        assert_eq!(entries[1].title, "News Hour");
        assert_eq!(
            entries[1].description.as_deref(),
            Some("Daily news roundup"),
        );
        assert_eq!(entries[2].channel_id, "ch3");
        assert_eq!(entries[2].title, "Cooking Time");
        assert_eq!(entries[2].category.as_deref(), Some("Food"),);
        assert_eq!(entries[3].channel_id, "ch1");
        assert_eq!(entries[3].title, "Late Morning");
    }

    #[test]
    fn parse_missing_optional_fields() {
        let xml = r#"<tv>
  <programme start="20240601120000 +0000" stop="20240601130000 +0000" channel="sky1">
    <title>Minimal Programme</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);

        let e = &entries[0];
        assert_eq!(e.channel_id, "sky1");
        assert_eq!(e.title, "Minimal Programme");
        assert!(e.description.is_none());
        assert!(e.category.is_none());
        assert!(e.icon_url.is_none());
        assert!(e.sub_title.is_none());
        assert!(e.season.is_none());
        assert!(e.episode.is_none());
        assert!(e.episode_label.is_none());
        assert!(e.air_date.is_none());
        assert!(e.content_rating.is_none());
        assert!(e.star_rating.is_none());
        assert!(e.directors.is_none());
        assert!(e.cast.is_none());
        assert!(e.writers.is_none());
        assert!(e.presenters.is_none());
        assert!(e.language.is_none());
        assert!(e.country.is_none());
        assert!(!e.is_rerun);
        assert!(!e.is_new);
        assert!(!e.is_premiere);
        assert!(e.length_minutes.is_none());
    }

    #[test]
    fn parse_empty_xml_returns_empty() {
        assert!(parse_epg("").is_empty());
        assert!(parse_epg("   ").is_empty());
        assert!(parse_epg("\n\t\n").is_empty());
    }

    #[test]
    fn parse_invalid_xml_does_not_crash() {
        // Malformed: no closing tag.
        let xml1 = r#"<tv><programme start="20240101">"#;
        let r1 = parse_epg(xml1);
        assert!(r1.is_empty());

        // Missing required attributes (no start/stop).
        let xml2 = r#"<tv>
  <programme channel="ch1">
    <title>No Times</title>
  </programme>
</tv>"#;
        let r2 = parse_epg(xml2);
        assert!(r2.is_empty());

        // Missing title.
        let xml3 = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
    <desc>No title here</desc>
  </programme>
</tv>"#;
        let r3 = parse_epg(xml3);
        assert!(r3.is_empty());

        // Random garbage.
        let r4 = parse_epg("not xml at all {{{}}}");
        assert!(r4.is_empty());
    }

    #[test]
    fn extract_channel_names_basic() {
        let xml = r#"<tv>
  <channel id="abc">
    <display-name>ABC Network</display-name>
  </channel>
  <channel id="nbc">
    <display-name>NBC</display-name>
  </channel>
  <channel id="fox">
    <display-name>FOX</display-name>
  </channel>
</tv>"#;
        let names = extract_channel_names(xml);
        assert_eq!(names.len(), 3);
        assert_eq!(names.get("abc").map(|s| s.as_str()), Some("ABC Network"),);
        assert_eq!(names.get("nbc").map(|s| s.as_str()), Some("NBC"),);
        assert_eq!(names.get("fox").map(|s| s.as_str()), Some("FOX"),);
    }

    #[test]
    fn extract_channel_names_empty() {
        let names = extract_channel_names("");
        assert!(names.is_empty());

        let names2 = extract_channel_names("<tv></tv>");
        assert!(names2.is_empty());

        // No channel elements at all.
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="c1">
    <title>Show</title>
  </programme>
</tv>"#;
        let names3 = extract_channel_names(xml);
        assert!(names3.is_empty());
    }

    #[test]
    fn programme_missing_start_attribute() {
        // Programme has stop and channel but no start.
        // parse_programme returns None because start_re
        // fails to match.
        let xml = r#"<tv>
  <programme stop="20240101130000 +0000" channel="ch1">
    <title>No Start</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert!(entries.is_empty());
    }

    #[test]
    fn programme_with_empty_title_tag() {
        // <title></title> matches the regex but yields an
        // empty string after trim. The parser does not
        // reject empty titles — it stores them as-is.
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
    <title></title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "");
    }

    #[test]
    fn channel_with_no_display_name() {
        // The regex is greedy across channel boundaries:
        // a channel without <display-name> will absorb
        // the next channel's display-name. This test
        // documents the actual behavior.
        let xml = r#"<tv>
  <channel id="no-name">
    <icon src="http://example.com/logo.png"/>
  </channel>
  <channel id="has-name">
    <display-name>Good Channel</display-name>
  </channel>
</tv>"#;
        let names = extract_channel_names(xml);
        // The lazy .*? crosses from "no-name" to
        // "has-name"'s display-name, consuming both
        // channels in one match. Result: "no-name"
        // gets "Good Channel", "has-name" is consumed.
        assert_eq!(names.len(), 1);
        assert_eq!(
            names.get("no-name").map(|s| s.as_str()),
            Some("Good Channel"),
        );

        // When there's no channel without display-name
        // to interfere, extraction works correctly.
        let xml2 = r#"<tv>
  <channel id="abc">
    <display-name>ABC</display-name>
  </channel>
  <channel id="nbc">
    <display-name>NBC</display-name>
  </channel>
</tv>"#;
        let names2 = extract_channel_names(xml2);
        assert_eq!(names2.len(), 2);
        assert_eq!(names2.get("abc").map(|s| s.as_str()), Some("ABC"),);
        assert_eq!(names2.get("nbc").map(|s| s.as_str()), Some("NBC"),);
    }

    #[test]
    fn multiple_title_elements_picks_first() {
        // XMLTV allows multiple <title lang="xx">. Our
        // regex captures the first match only.
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
    <title lang="en">English Title</title>
    <title lang="fr">Titre Français</title>
    <title lang="de">Deutscher Titel</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "English Title");
    }

    #[test]
    fn very_large_timestamp_year_2099() {
        let xml = r#"<tv>
  <programme start="20991231235959 +0000" stop="21000101000000 +0000" channel="future">
    <title>New Year 2100</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].channel_id, "future");
        assert_eq!(
            entries[0].start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2099, 12, 31).unwrap(),
                chrono::NaiveTime::from_hms_opt(23, 59, 59).unwrap(),
            ),
        );
        assert_eq!(
            entries[0].end_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2100, 1, 1).unwrap(),
                chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap(),
            ),
        );
    }

    #[test]
    fn programme_with_credits_and_rating() {
        // Real XMLTV files include <credits> and <rating>
        // elements. These are now fully parsed.
        let xml = r#"<tv>
  <programme start="20240501200000 +0000" stop="20240501220000 +0000" channel="hbo">
    <title>Movie</title>
    <desc>A great movie</desc>
    <credits>
      <director>John Doe</director>
      <actor>Jane Smith</actor>
      <actor>Bob Wilson</actor>
      <writer>Alice Brown</writer>
      <presenter>Tom Host</presenter>
    </credits>
    <category>Drama</category>
    <rating system="MPAA">
      <value>PG-13</value>
    </rating>
    <star-rating>
      <value>8.5/10</value>
    </star-rating>
    <icon src="http://img.example.com/m.png"/>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        let e = &entries[0];
        assert_eq!(e.title, "Movie");
        assert_eq!(e.description.as_deref(), Some("A great movie"),);
        assert_eq!(e.category.as_deref(), Some("Drama"),);
        assert_eq!(e.icon_url.as_deref(), Some("http://img.example.com/m.png"),);
        assert_eq!(e.directors.as_deref(), Some("John Doe"));
        assert_eq!(e.cast.as_deref(), Some("Jane Smith; Bob Wilson"));
        assert_eq!(e.writers.as_deref(), Some("Alice Brown"));
        assert_eq!(e.presenters.as_deref(), Some("Tom Host"));
        assert_eq!(e.content_rating.as_deref(), Some("PG-13"));
        assert_eq!(e.star_rating.as_deref(), Some("8.5/10"));
    }

    #[test]
    fn timezone_offset_variants() {
        // +0530 (India): 12:00 local -> 06:30 UTC
        let xml_india = r#"<tv>
  <programme start="20240101120000 +0530" stop="20240101130000 +0530" channel="ch">
    <title>India Show</title>
  </programme>
</tv>"#;
        let e = &parse_epg(xml_india)[0];
        assert_eq!(
            e.start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
                chrono::NaiveTime::from_hms_opt(6, 30, 0).unwrap(),
            ),
        );

        // -0800 (PST): 04:00 local -> 12:00 UTC
        let xml_pst = r#"<tv>
  <programme start="20240101040000 -0800" stop="20240101050000 -0800" channel="ch">
    <title>West Coast</title>
  </programme>
</tv>"#;
        let e2 = &parse_epg(xml_pst)[0];
        assert_eq!(
            e2.start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
                chrono::NaiveTime::from_hms_opt(12, 0, 0).unwrap(),
            ),
        );
    }

    #[test]
    fn programme_spanning_midnight() {
        // 23:00 start, 01:00 next day stop (both UTC).
        let xml = r#"<tv>
  <programme start="20240115230000 +0000" stop="20240116010000 +0000" channel="late">
    <title>Late Night</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(
            entries[0].start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 15).unwrap(),
                chrono::NaiveTime::from_hms_opt(23, 0, 0).unwrap(),
            ),
        );
        assert_eq!(
            entries[0].end_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 16).unwrap(),
                chrono::NaiveTime::from_hms_opt(1, 0, 0).unwrap(),
            ),
        );
    }

    #[test]
    fn timestamp_too_short_skipped() {
        // Datetime string shorter than 14 chars returns
        // None from parse_xmltv_datetime, skipping the
        // programme.
        let xml = r#"<tv>
  <programme start="20240101" stop="20240102" channel="ch1">
    <title>Short Date</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert!(entries.is_empty());
    }

    #[test]
    fn channel_with_empty_display_name_ignored() {
        // <display-name> tag exists but is empty or
        // whitespace-only. extract_channel_names checks
        // !name.is_empty() after trim.
        let xml = r#"<tv>
  <channel id="empty">
    <display-name>   </display-name>
  </channel>
  <channel id="valid">
    <display-name>Real Name</display-name>
  </channel>
</tv>"#;
        let names = extract_channel_names(xml);
        assert_eq!(names.len(), 1);
        assert!(!names.contains_key("empty"));
        assert_eq!(names.get("valid").map(|s| s.as_str()), Some("Real Name"),);
    }

    #[test]
    fn parse_with_replacement_characters() {
        // Simulate content that went through from_utf8_lossy:
        // U+FFFD replacement characters in title/description.
        let xml = "<tv>\n\
          <programme start=\"20240216150000 +0000\" \
            stop=\"20240216160000 +0000\" channel=\"ch1\">\n\
            <title>News \u{FFFD} Bulletin</title>\n\
            <desc>Weather \u{FFFD}\u{FFFD} report</desc>\n\
          </programme>\n\
        </tv>";
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert!(entries[0].title.contains('\u{FFFD}'));
        assert_eq!(entries[0].title, "News \u{FFFD} Bulletin");
    }

    // ── New extended-field tests ──────────────────────

    #[test]
    fn parse_sub_title() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Breaking Bad</title>
    <sub-title>Ozymandias</sub-title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].sub_title.as_deref(), Some("Ozymandias"));
    }

    #[test]
    fn parse_episode_num_xmltv_ns() {
        // xmltv_ns format: "4.12." means season 5, episode 13 (zero-based).
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Show</title>
    <episode-num system="xmltv_ns">4.12.</episode-num>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].season, Some(5));
        assert_eq!(entries[0].episode, Some(13));
    }

    #[test]
    fn parse_episode_num_xmltv_ns_with_ranges() {
        // "0/1.5/24." — season 1 (of 2), episode 6 (of 25)
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Show</title>
    <episode-num system="xmltv_ns">0/1.5/24.</episode-num>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].season, Some(1));
        assert_eq!(entries[0].episode, Some(6));
    }

    #[test]
    fn parse_episode_num_onscreen() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Show</title>
    <episode-num system="onscreen">S02E08</episode-num>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].episode_label.as_deref(), Some("S02E08"));
    }

    #[test]
    fn parse_air_date() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Classic Movie</title>
    <date>1994</date>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].air_date.as_deref(), Some("1994"));
    }

    #[test]
    fn parse_language_and_country() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Show</title>
    <language>en</language>
    <country>US</country>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].language.as_deref(), Some("en"));
        assert_eq!(entries[0].country.as_deref(), Some("US"));
    }

    #[test]
    fn parse_previously_shown_flag() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Rerun Show</title>
    <previously-shown start="20230601"/>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert!(entries[0].is_rerun);
        assert!(!entries[0].is_new);
    }

    #[test]
    fn parse_new_flag() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Brand New</title>
    <new/>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert!(entries[0].is_new);
        assert!(!entries[0].is_rerun);
    }

    #[test]
    fn parse_premiere_flag() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Season Premiere</title>
    <premiere>Season premiere</premiere>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert!(entries[0].is_premiere);
    }

    #[test]
    fn parse_length_minutes() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101220000 +0000" channel="ch1">
    <title>Movie</title>
    <length units="minutes">120</length>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].length_minutes, Some(120));
    }

    #[test]
    fn parse_length_hours() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101220000 +0000" channel="ch1">
    <title>Movie</title>
    <length units="hours">2</length>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].length_minutes, Some(120));
    }

    #[test]
    fn parse_length_seconds() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101203000 +0000" channel="ch1">
    <title>Short</title>
    <length units="seconds">1800</length>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].length_minutes, Some(30));
    }

    #[test]
    fn parse_multiple_categories() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
    <title>Multi Genre</title>
    <category>Drama</category>
    <category>Thriller</category>
    <category>Mystery</category>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(
            entries[0].category.as_deref(),
            Some("Drama; Thriller; Mystery"),
        );
    }

    #[test]
    fn parse_star_rating_only() {
        let xml = r#"<tv>
  <programme start="20240101200000 +0000" stop="20240101220000 +0000" channel="ch1">
    <title>Rated Movie</title>
    <star-rating>
      <value>7.5/10</value>
    </star-rating>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].star_rating.as_deref(), Some("7.5/10"));
        assert!(entries[0].content_rating.is_none());
    }

    #[test]
    fn parse_full_programme_all_extended_fields() {
        let xml = r#"<tv>
  <programme start="20240901200000 +0000" stop="20240901220000 +0000" channel="hbo">
    <title>The Grand Show</title>
    <sub-title>Pilot Episode</sub-title>
    <desc>An epic new series begins</desc>
    <credits>
      <director>Christopher Nolan</director>
      <director>Denis Villeneuve</director>
      <actor>Christian Bale</actor>
      <actor>Timothee Chalamet</actor>
      <writer>Jonathan Nolan</writer>
      <presenter>Ryan Seacrest</presenter>
    </credits>
    <date>2024</date>
    <category>Drama</category>
    <category>Sci-Fi</category>
    <language>en</language>
    <country>GB</country>
    <episode-num system="xmltv_ns">0.0.</episode-num>
    <episode-num system="onscreen">S01E01</episode-num>
    <icon src="https://img.example.com/grand.jpg"/>
    <rating system="MPAA">
      <value>TV-14</value>
    </rating>
    <star-rating>
      <value>9.2/10</value>
    </star-rating>
    <premiere>Series premiere</premiere>
    <new/>
    <length units="minutes">120</length>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        let e = &entries[0];

        assert_eq!(e.channel_id, "hbo");
        assert_eq!(e.title, "The Grand Show");
        assert_eq!(e.sub_title.as_deref(), Some("Pilot Episode"));
        assert_eq!(e.description.as_deref(), Some("An epic new series begins"));
        assert_eq!(
            e.directors.as_deref(),
            Some("Christopher Nolan; Denis Villeneuve"),
        );
        assert_eq!(e.cast.as_deref(), Some("Christian Bale; Timothee Chalamet"),);
        assert_eq!(e.writers.as_deref(), Some("Jonathan Nolan"));
        assert_eq!(e.presenters.as_deref(), Some("Ryan Seacrest"));
        assert_eq!(e.air_date.as_deref(), Some("2024"));
        assert_eq!(e.category.as_deref(), Some("Drama; Sci-Fi"));
        assert_eq!(e.language.as_deref(), Some("en"));
        assert_eq!(e.country.as_deref(), Some("GB"));
        assert_eq!(e.season, Some(1));
        assert_eq!(e.episode, Some(1));
        assert_eq!(e.episode_label.as_deref(), Some("S01E01"));
        assert_eq!(
            e.icon_url.as_deref(),
            Some("https://img.example.com/grand.jpg"),
        );
        assert_eq!(e.content_rating.as_deref(), Some("TV-14"));
        assert_eq!(e.star_rating.as_deref(), Some("9.2/10"));
        assert!(e.is_premiere);
        assert!(e.is_new);
        assert!(!e.is_rerun);
        assert_eq!(e.length_minutes, Some(120));
    }

    #[test]
    fn parse_xmltv_ns_season_only() {
        // "2.." means season 3, no episode
        let (s, ep) = parse_xmltv_ns("2..");
        assert_eq!(s, Some(3));
        assert_eq!(ep, None);
    }

    #[test]
    fn parse_xmltv_ns_episode_only() {
        // ".5." means no season, episode 6
        let (s, ep) = parse_xmltv_ns(".5.");
        assert_eq!(s, None);
        assert_eq!(ep, Some(6));
    }

    #[test]
    fn parse_xmltv_ns_empty() {
        let (s, ep) = parse_xmltv_ns("..");
        assert_eq!(s, None);
        assert_eq!(ep, None);
    }
}
