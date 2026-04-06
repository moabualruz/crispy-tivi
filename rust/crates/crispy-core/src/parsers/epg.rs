//! XMLTV electronic programme guide parser.
//!
//! Uses `quick_xml` event-based pull parsing to handle
//! large (100 MB+) EPG files efficiently. Replaces the
//! previous regex-based approach for correct handling of
//! CDATA sections, attribute order variations, and XML
//! entity encoding.

use std::collections::HashMap;

use chrono::NaiveDateTime;
use quick_xml::Reader;
use quick_xml::events::Event;

use crate::models::EpgEntry;

const DEFAULT_PREFERRED_LANG: &str = "en";

/// A single XMLTV `<channel>` element parsed from the guide.
#[derive(Debug, Clone, Default)]
pub struct EpgChannel {
    /// The XMLTV channel ID (the `id` attribute).
    pub xmltv_id: String,
    /// First `<display-name>` text found (preferred language).
    pub display_name: String,
    /// Optional channel icon URL from `<icon src="…"/>`.
    pub icon_url: Option<String>,
}

/// Combined result of a full XMLTV parse — both programme entries
/// and channel definitions.
#[derive(Debug, Default)]
pub struct ParsedEpg {
    /// All `<programme>` entries found in the guide.
    pub entries: Vec<EpgEntry>,
    /// All `<channel>` definitions found in the guide.
    pub channels: Vec<EpgChannel>,
}

/// Parse XMLTV content into EPG entries **and** channel definitions.
///
/// Single-pass over the XML: collects both `<channel>` and
/// `<programme>` elements.  Use this instead of the separate
/// `parse_epg` / `extract_channel_names` helpers when you need both.
pub fn parse_epg_full(content: &str) -> ParsedEpg {
    if content.trim().is_empty() {
        return ParsedEpg::default();
    }

    let mut reader = Reader::from_str(content);
    reader.config_mut().trim_text(true);

    let mut result = ParsedEpg::default();

    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) if e.name().as_ref() == b"channel" => {
                if let Some(channel) = parse_channel_element(e, &mut reader) {
                    result.channels.push(channel);
                }
            }
            Ok(Event::Start(ref e)) if e.name().as_ref() == b"programme" => {
                if let Some(entry) = parse_programme_element(e, &mut reader) {
                    result.entries.push(entry);
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }

    result
}

/// Parse XMLTV content into EPG entries.
///
/// Extracts `<programme>` blocks and maps them to
/// [`EpgEntry`] structs. Skips entries that lack
/// required fields (channel, start, stop, title).
pub fn parse_epg(content: &str) -> Vec<EpgEntry> {
    if content.trim().is_empty() {
        return Vec::new();
    }

    let mut reader = Reader::from_str(content);
    reader.config_mut().trim_text(true);

    let mut entries = Vec::new();

    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) if e.name().as_ref() == b"programme" => {
                if let Some(entry) = parse_programme_element(e, &mut reader) {
                    entries.push(entry);
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }

    entries
}

/// Extract XMLTV `<channel>` display names.
///
/// Returns a map of channel ID to display name.
pub fn extract_channel_names(content: &str) -> HashMap<String, String> {
    if content.trim().is_empty() {
        return HashMap::new();
    }

    let mut reader = Reader::from_str(content);
    reader.config_mut().trim_text(true);

    let mut result = HashMap::new();

    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) if e.name().as_ref() == b"channel" => {
                let channel_id = get_attr(e, b"id");
                if let Some(id) = channel_id {
                    match read_channel_display_name(&mut reader) {
                        ChannelNameResult::Found(name) => {
                            if !name.is_empty() {
                                result.entry(id).or_insert(name);
                            }
                            // Display name was found but </channel> not
                            // yet consumed — skip remaining children.
                            let _ = reader.read_to_end(e.name());
                        }
                        ChannelNameResult::EndReached => {
                            // </channel> was already consumed by the
                            // helper — do NOT call read_to_end.
                        }
                    }
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }

    result
}

// ── Internal helpers ─────────────────────────────

/// Extract a UTF-8 attribute value from an XML element by key.
fn get_attr(e: &quick_xml::events::BytesStart<'_>, key: &[u8]) -> Option<String> {
    for attr in e.attributes().flatten() {
        if attr.key.as_ref() == key {
            return String::from_utf8(attr.value.to_vec()).ok();
        }
    }
    None
}

fn get_lang_attr(e: &quick_xml::events::BytesStart<'_>) -> Option<String> {
    get_attr(e, b"xml:lang").or_else(|| get_attr(e, b"lang"))
}

fn pick_preferred_lang(
    values: &[(Option<String>, String)],
    preferred_lang: &str,
) -> Option<String> {
    let preferred_lang = preferred_lang.trim();
    if preferred_lang.is_empty() {
        return values.first().map(|(_, text)| text.clone());
    }

    if let Some((_, text)) = values.iter().find(|(lang, _)| {
        lang.as_deref()
            .is_some_and(|lang| lang.eq_ignore_ascii_case(preferred_lang))
    }) {
        return Some(text.clone());
    }

    if let Some((_, text)) = values.iter().find(|(lang, _)| {
        lang.as_deref()
            .is_some_and(|lang| lang.eq_ignore_ascii_case(DEFAULT_PREFERRED_LANG))
    }) {
        return Some(text.clone());
    }

    values.first().map(|(_, text)| text.clone())
}

/// Parse a `<channel>` element into an [`EpgChannel`].
///
/// Collects the first `<display-name>` and the first `<icon src="…"/>`.
/// Returns `None` if the element has no `id` attribute.
fn parse_channel_element(
    start: &quick_xml::events::BytesStart<'_>,
    reader: &mut Reader<&[u8]>,
) -> Option<EpgChannel> {
    let xmltv_id = get_attr(start, b"id")?;
    let mut display_name = String::new();
    let mut icon_url: Option<String> = None;

    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) if e.name().as_ref() == b"display-name" => {
                if display_name.is_empty() {
                    let text = read_element_text(reader, e.name())
                        .map(|t| t.trim().to_string())
                        .unwrap_or_default();
                    if !text.is_empty() {
                        display_name = text;
                    }
                } else {
                    let _ = reader.read_to_end(e.name());
                }
            }
            Ok(Event::Empty(ref e)) if e.name().as_ref() == b"icon" => {
                if icon_url.is_none() {
                    icon_url = get_attr(e, b"src").filter(|s| !s.is_empty());
                }
            }
            Ok(Event::Start(ref e)) if e.name().as_ref() == b"icon" => {
                if icon_url.is_none() {
                    icon_url = get_attr(e, b"src").filter(|s| !s.is_empty());
                }
                let _ = reader.read_to_end(e.name());
            }
            Ok(Event::End(ref e)) if e.name().as_ref() == b"channel" => break,
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }

    if display_name.is_empty() {
        return None;
    }

    Some(EpgChannel {
        xmltv_id,
        display_name,
        icon_url,
    })
}

/// Result from scanning a `<channel>` for its display name.
enum ChannelNameResult {
    /// A `<display-name>` was found (may be empty). The reader
    /// is positioned after `</display-name>` but before `</channel>`.
    Found(String),
    /// `</channel>` was encountered without finding a display name.
    /// The reader has already consumed the `</channel>` end tag.
    EndReached,
}

/// Read the first `<display-name>` text inside a `<channel>`.
/// Returns how the scan terminated so the caller knows whether
/// `</channel>` was already consumed.
fn read_channel_display_name(reader: &mut Reader<&[u8]>) -> ChannelNameResult {
    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) if e.name().as_ref() == b"display-name" => {
                let text = read_element_text(reader, e.name())
                    .map(|t| t.trim().to_string())
                    .unwrap_or_default();
                return ChannelNameResult::Found(text);
            }
            // End of <channel> without finding <display-name>.
            Ok(Event::End(ref e)) if e.name().as_ref() == b"channel" => {
                return ChannelNameResult::EndReached;
            }
            Ok(Event::Eof) => return ChannelNameResult::EndReached,
            Err(_) => return ChannelNameResult::EndReached,
            _ => {}
        }
    }
}

/// Read the text content of an element, properly handling XML
/// entity unescaping and CDATA sections.
///
/// Reads events until the matching end tag for `end_name` is
/// encountered. Concatenates `Event::Text` (unescaped) and
/// `Event::CData` (raw) content. Returns `None` on error.
fn read_element_text(
    reader: &mut Reader<&[u8]>,
    end_name: quick_xml::name::QName<'_>,
) -> Option<String> {
    let mut result = String::new();
    loop {
        match reader.read_event() {
            Ok(Event::Text(ref e)) => {
                // Unescape XML entities (&amp; → &, etc.)
                let unescaped = e.unescape().ok()?;
                result.push_str(&unescaped);
            }
            Ok(Event::CData(ref e)) => {
                // CDATA content is literal — no unescaping needed.
                if let Ok(text) = std::str::from_utf8(e.as_ref()) {
                    result.push_str(text);
                }
            }
            Ok(Event::End(ref e)) if e.name() == end_name => {
                return Some(result);
            }
            // Nested elements inside text content — skip them.
            Ok(Event::Start(ref e)) => {
                let _ = reader.read_to_end(e.name());
            }
            Ok(Event::Eof) => return Some(result),
            Err(_) => return None,
            _ => {}
        }
    }
}

/// Parse a single `<programme>` element and its children into
/// an `EpgEntry`. Returns `None` if required fields are missing.
fn parse_programme_element(
    start: &quick_xml::events::BytesStart<'_>,
    reader: &mut Reader<&[u8]>,
) -> Option<EpgEntry> {
    // Extract attributes from the <programme> opening tag.
    let channel_id = get_attr(start, b"channel")?;
    let start_attr = get_attr(start, b"start");
    let start_ts_attr = get_attr(start, b"start_timestamp");
    let stop_attr = get_attr(start, b"stop");
    let stop_ts_attr = get_attr(start, b"stop_timestamp");

    // Resolve start_time: prefer "start" attr, fall back to "start_timestamp".
    let start_time = if let Some(ref raw) = start_attr {
        parse_xmltv_datetime(raw)?
    } else if let Some(ref ts) = start_ts_attr {
        let ts_val: i64 = ts.parse().ok()?;
        chrono::DateTime::from_timestamp(ts_val, 0).map(|dt| dt.naive_utc())?
    } else {
        // Consume remaining content to avoid desync.
        let _ = reader.read_to_end(start.name());
        return None;
    };

    // Resolve end_time: prefer "stop" attr, fall back to "stop_timestamp".
    let end_time = if let Some(ref raw) = stop_attr {
        parse_xmltv_datetime(raw)?
    } else if let Some(ref ts) = stop_ts_attr {
        let ts_val: i64 = ts.parse().ok()?;
        chrono::DateTime::from_timestamp(ts_val, 0).map(|dt| dt.naive_utc())?
    } else {
        let _ = reader.read_to_end(start.name());
        return None;
    };

    // Parse child elements within <programme>.
    let mut titles: Vec<(Option<String>, String)> = Vec::new();
    let mut descriptions: Vec<(Option<String>, String)> = Vec::new();
    let mut categories: Vec<String> = Vec::new();
    let mut icon_url: Option<String> = None;
    let mut sub_title: Option<String> = None;
    let mut air_date: Option<String> = None;
    let mut language: Option<String> = None;
    let mut country: Option<String> = None;
    let mut directors: Option<String> = None;
    let mut cast: Option<String> = None;
    let mut writers: Option<String> = None;
    let mut presenters: Option<String> = None;
    // These will be merged into credits_json at the end.
    let mut season: Option<i32> = None;
    let mut episode: Option<i32> = None;
    let mut episode_label: Option<String> = None;
    let mut content_rating: Option<String> = None;
    let mut star_rating: Option<String> = None;
    let mut is_rerun = false;
    let mut is_new = false;
    let mut is_premiere = false;
    let mut length_minutes: Option<i32> = None;

    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) => {
                match e.name().as_ref() {
                    b"title" => {
                        if let Some(text) = read_element_text(reader, e.name()) {
                            let t = text.trim().to_string();
                            if !t.is_empty() {
                                titles.push((get_lang_attr(e), t));
                            }
                        }
                    }
                    b"sub-title" => {
                        let lang = get_attr(e, b"lang");
                        if let Some(text) = read_element_text(reader, e.name()) {
                            let t = text.trim().to_string();
                            if !t.is_empty() {
                                let is_better = match (&sub_title, &lang) {
                                    (None, _) => true,
                                    (Some(_), Some(l)) if l == "en" => true,
                                    _ => false,
                                };
                                if is_better {
                                    sub_title = Some(t);
                                }
                            }
                        }
                    }
                    b"desc" => {
                        if let Some(text) = read_element_text(reader, e.name()) {
                            let t = text.trim().to_string();
                            if !t.is_empty() {
                                descriptions.push((get_lang_attr(e), t));
                            }
                        }
                    }
                    b"category" => {
                        if let Some(text) = read_element_text(reader, e.name()) {
                            let trimmed = text.trim().to_string();
                            if !trimmed.is_empty() {
                                categories.push(trimmed);
                            }
                        }
                    }
                    b"date" => {
                        if air_date.is_none() {
                            if let Some(text) = read_element_text(reader, e.name()) {
                                let t = text.trim().to_string();
                                if !t.is_empty() {
                                    air_date = Some(t);
                                }
                            }
                        } else {
                            let _ = reader.read_to_end(e.name());
                        }
                    }
                    b"language" => {
                        if language.is_none() {
                            if let Some(text) = read_element_text(reader, e.name()) {
                                let t = text.trim().to_string();
                                if !t.is_empty() {
                                    language = Some(t);
                                }
                            }
                        } else {
                            let _ = reader.read_to_end(e.name());
                        }
                    }
                    b"country" => {
                        if country.is_none() {
                            if let Some(text) = read_element_text(reader, e.name()) {
                                let t = text.trim().to_string();
                                if !t.is_empty() {
                                    country = Some(t);
                                }
                            }
                        } else {
                            let _ = reader.read_to_end(e.name());
                        }
                    }
                    b"credits" => {
                        parse_credits(
                            reader,
                            &mut directors,
                            &mut cast,
                            &mut writers,
                            &mut presenters,
                        );
                    }
                    b"episode-num" => {
                        let system = get_attr(e, b"system").unwrap_or_default();
                        if let Some(text) = read_element_text(reader, e.name()) {
                            let t = text.trim();
                            match system.as_str() {
                                "xmltv_ns" => {
                                    let (s, ep) = parse_xmltv_ns(t);
                                    if season.is_none() {
                                        season = s.map(|v| v as i32);
                                    }
                                    if episode.is_none() {
                                        episode = ep.map(|v| v as i32);
                                    }
                                }
                                "onscreen" => {
                                    if episode_label.is_none() && !t.is_empty() {
                                        episode_label = Some(t.to_string());
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                    b"rating" => {
                        if content_rating.is_none() {
                            content_rating = read_value_element(reader, e.name());
                        } else {
                            let _ = reader.read_to_end(e.name());
                        }
                    }
                    b"star-rating" => {
                        if star_rating.is_none() {
                            star_rating = read_value_element(reader, e.name());
                        } else {
                            let _ = reader.read_to_end(e.name());
                        }
                    }
                    b"length" => {
                        let units = get_attr(e, b"units").unwrap_or_default();
                        if let Some(text) = read_element_text(reader, e.name())
                            && let Ok(val) = text.trim().parse::<f64>()
                        {
                            length_minutes = Some(match units.as_str() {
                                "hours" => (val * 60.0) as i32,
                                "seconds" => (val / 60.0) as i32,
                                _ => val as i32, // "minutes" or default
                            });
                        }
                    }
                    b"premiere" => {
                        is_premiere = true;
                        let _ = reader.read_to_end(e.name());
                    }
                    _ => {
                        let _ = reader.read_to_end(e.name());
                    }
                }
            }
            Ok(Event::Empty(ref e)) => match e.name().as_ref() {
                b"icon" if icon_url.is_none() => {
                    icon_url = get_attr(e, b"src");
                }
                b"previously-shown" => is_rerun = true,
                b"new" => is_new = true,
                b"premiere" => is_premiere = true,
                _ => {}
            },
            Ok(Event::End(ref e)) if e.name().as_ref() == b"programme" => {
                break;
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }

    let title = pick_preferred_lang(&titles, DEFAULT_PREFERRED_LANG)?;
    let description = pick_preferred_lang(&descriptions, DEFAULT_PREFERRED_LANG);
    let category = if categories.is_empty() {
        None
    } else {
        Some(categories.join("; "))
    };

    Some(EpgEntry {
        epg_channel_id: channel_id,
        xmltv_id: None,
        title,
        start_time,
        end_time,
        description,
        category,
        icon_url,
        source_id: None,
        is_placeholder: false,
        sub_title,
        season,
        episode,
        episode_label,
        air_date,
        content_rating,
        star_rating,
        credits_json: build_credits_json(&directors, &cast, &writers, &presenters),
        language,
        country,
        is_rerun,
        is_new,
        is_premiere,
        length_minutes,
    })
}

/// Parse `<credits>` children: `<director>`, `<actor>`, `<writer>`, `<presenter>`.
/// Collects semicolon-separated lists.
fn parse_credits(
    reader: &mut Reader<&[u8]>,
    directors: &mut Option<String>,
    cast: &mut Option<String>,
    writers: &mut Option<String>,
    presenters: &mut Option<String>,
) {
    let mut dirs: Vec<String> = Vec::new();
    let mut actors: Vec<String> = Vec::new();
    let mut wrtrs: Vec<String> = Vec::new();
    let mut prsnts: Vec<String> = Vec::new();

    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) => {
                let name = e.name();
                match name.as_ref() {
                    b"director" => {
                        if let Some(t) = read_element_text(reader, name) {
                            let t = t.trim().to_string();
                            if !t.is_empty() {
                                dirs.push(t);
                            }
                        }
                    }
                    b"actor" => {
                        if let Some(t) = read_element_text(reader, name) {
                            let t = t.trim().to_string();
                            if !t.is_empty() {
                                actors.push(t);
                            }
                        }
                    }
                    b"writer" => {
                        if let Some(t) = read_element_text(reader, name) {
                            let t = t.trim().to_string();
                            if !t.is_empty() {
                                wrtrs.push(t);
                            }
                        }
                    }
                    b"presenter" => {
                        if let Some(t) = read_element_text(reader, name) {
                            let t = t.trim().to_string();
                            if !t.is_empty() {
                                prsnts.push(t);
                            }
                        }
                    }
                    _ => {
                        let _ = reader.read_to_end(name);
                    }
                }
            }
            Ok(Event::End(ref e)) if e.name().as_ref() == b"credits" => break,
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }

    if !dirs.is_empty() {
        *directors = Some(dirs.join("; "));
    }
    if !actors.is_empty() {
        *cast = Some(actors.join("; "));
    }
    if !wrtrs.is_empty() {
        *writers = Some(wrtrs.join("; "));
    }
    if !prsnts.is_empty() {
        *presenters = Some(prsnts.join("; "));
    }
}

/// Build a JSON string from the four credit fields.
/// Returns `None` if all fields are empty.
fn build_credits_json(
    directors: &Option<String>,
    cast: &Option<String>,
    writers: &Option<String>,
    presenters: &Option<String>,
) -> Option<String> {
    if directors.is_none() && cast.is_none() && writers.is_none() && presenters.is_none() {
        return None;
    }
    let mut obj = serde_json::Map::new();
    if let Some(d) = directors {
        obj.insert(
            "directors".to_string(),
            serde_json::Value::String(d.clone()),
        );
    }
    if let Some(c) = cast {
        obj.insert("cast".to_string(), serde_json::Value::String(c.clone()));
    }
    if let Some(w) = writers {
        obj.insert("writers".to_string(), serde_json::Value::String(w.clone()));
    }
    if let Some(p) = presenters {
        obj.insert(
            "presenters".to_string(),
            serde_json::Value::String(p.clone()),
        );
    }
    Some(serde_json::Value::Object(obj).to_string())
}

/// Read the `<value>` child from elements like `<rating>` or `<star-rating>`.
fn read_value_element(
    reader: &mut Reader<&[u8]>,
    parent_name: quick_xml::name::QName<'_>,
) -> Option<String> {
    let mut result: Option<String> = None;
    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) => {
                if e.name().as_ref() == b"value" {
                    if let Some(text) = read_element_text(reader, e.name()) {
                        let t = text.trim().to_string();
                        if !t.is_empty() && result.is_none() {
                            result = Some(t);
                        }
                    }
                } else {
                    let _ = reader.read_to_end(e.name());
                }
            }
            Ok(Event::End(ref e)) if e.name() == parent_name => break,
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }
    result
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

/// Parse XMLTV episode numbering in `xmltv_ns` format.
///
/// Format: `season.episode.part` (all zero-indexed).
/// Example: `1.5.0` means season 2, episode 6, part 1.
#[allow(dead_code)]
fn parse_xmltv_ns(value: &str) -> (Option<u32>, Option<u32>) {
    let parts: Vec<&str> = value.split('.').collect();
    let season = parts
        .first()
        .and_then(|s| s.trim().parse::<u32>().ok())
        .map(|n| n + 1);
    let episode = parts
        .get(1)
        .and_then(|s| s.trim().parse::<u32>().ok())
        .map(|n| n + 1);
    (season, episode)
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
        assert_eq!(e0.epg_channel_id, "bbc1");
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
    fn parse_epg_full_collects_channels_and_entries() {
        let parsed = parse_epg_full(SAMPLE_XMLTV);
        assert_eq!(parsed.channels.len(), 2);
        assert_eq!(parsed.entries.len(), 2);
        assert_eq!(parsed.channels[0].xmltv_id, "bbc1");
        assert_eq!(parsed.channels[0].display_name, "BBC One");
        assert!(parsed.channels[0].icon_url.is_none());
    }

    #[test]
    fn parse_epg_with_timezone_offset() {
        let entries = parse_epg(SAMPLE_XMLTV);
        let e1 = &entries[1];
        assert_eq!(e1.epg_channel_id, "itv1");
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
        assert_eq!(e.epg_channel_id, "hbo");
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

        assert_eq!(entries[0].epg_channel_id, "ch1");
        assert_eq!(entries[0].title, "Morning Show");
        assert_eq!(entries[1].epg_channel_id, "ch2");
        assert_eq!(entries[1].title, "News Hour");
        assert_eq!(
            entries[1].description.as_deref(),
            Some("Daily news roundup"),
        );
        assert_eq!(entries[2].epg_channel_id, "ch3");
        assert_eq!(entries[2].title, "Cooking Time");
        assert_eq!(entries[2].category.as_deref(), Some("Food"),);
        assert_eq!(entries[3].epg_channel_id, "ch1");
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
        assert_eq!(e.epg_channel_id, "sky1");
        assert_eq!(e.title, "Minimal Programme");
        assert!(e.description.is_none());
        assert!(e.category.is_none());
        assert!(e.icon_url.is_none());
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
        // <title></title> yields an empty string after trim.
        // The parser requires a non-empty title — programmes
        // with only empty <title> tags are skipped entirely.
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
    <title></title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 0);
    }

    #[test]
    fn channel_with_no_display_name() {
        // With quick-xml, each <channel> element is parsed
        // independently, so a channel without <display-name>
        // is correctly skipped without absorbing a sibling's
        // display name.
        let xml = r#"<tv>
  <channel id="no-name">
    <icon src="http://example.com/logo.png"/>
  </channel>
  <channel id="has-name">
    <display-name>Good Channel</display-name>
  </channel>
</tv>"#;
        let names = extract_channel_names(xml);
        // "no-name" has no <display-name>, so it is not in the map.
        // "has-name" is correctly extracted.
        assert_eq!(names.len(), 1);
        assert_eq!(
            names.get("has-name").map(|s| s.as_str()),
            Some("Good Channel"),
        );
        assert!(!names.contains_key("no-name"));

        // When all channels have display-name, all are extracted.
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
    fn multiple_title_elements_prefers_en() {
        // XMLTV allows multiple <title lang="xx">. Our
        // parser captures "en" if available, else first.
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
    <title lang="fr">Titre Français</title>
    <title lang="en">English Title</title>
    <title lang="de">Deutscher Titel</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "English Title");
    }

    #[test]
    fn helper_prefers_exact_locale_then_en_then_first() {
        let multilingual = vec![
            (Some("fr".to_string()), "Titre".to_string()),
            (Some("en".to_string()), "English".to_string()),
            (Some("en-US".to_string()), "American English".to_string()),
        ];
        assert_eq!(
            pick_preferred_lang(&multilingual, "en-US").as_deref(),
            Some("American English"),
        );
        assert_eq!(
            pick_preferred_lang(&multilingual, "de").as_deref(),
            Some("English"),
        );

        let no_english = vec![
            (Some("fr".to_string()), "Titre".to_string()),
            (Some("de".to_string()), "Titel".to_string()),
        ];
        assert_eq!(
            pick_preferred_lang(&no_english, "es").as_deref(),
            Some("Titre"),
        );
    }

    #[test]
    fn xml_lang_is_honored_for_title_and_description() {
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
    <title xml:lang="fr">Titre Français</title>
    <title xml:lang="en">English Title</title>
    <desc xml:lang="fr">Résumé Français</desc>
    <desc xml:lang="en">English Description</desc>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "English Title");
        assert_eq!(
            entries[0].description.as_deref(),
            Some("English Description"),
        );
    }

    #[test]
    fn common_words_not_corrupted() {
        // "Show" and "Film" used to be corrupted by base64 decoding.
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
    <title>Show</title>
    <desc>Film</desc>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries[0].title, "Show");
        assert_eq!(entries[0].description.as_deref(), Some("Film"));
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
        assert_eq!(entries[0].epg_channel_id, "future");
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
        // elements. These should be ignored gracefully.
        let xml = r#"<tv>
  <programme start="20240501200000 +0000" stop="20240501220000 +0000" channel="hbo">
    <title>Movie</title>
    <desc>A great movie</desc>
    <credits>
      <director>John Doe</director>
      <actor>Jane Smith</actor>
    </credits>
    <category>Drama</category>
    <rating system="MPAA">
      <value>PG-13</value>
    </rating>
    <icon src="http://img.example.com/m.png"/>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "Movie");
        assert_eq!(entries[0].description.as_deref(), Some("A great movie"),);
        assert_eq!(entries[0].category.as_deref(), Some("Drama"),);
        assert_eq!(
            entries[0].icon_url.as_deref(),
            Some("http://img.example.com/m.png"),
        );
    }

    #[test]
    fn timezone_offset_variants() {
        // +0530 (India): 12:00 local → 06:30 UTC
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

        // -0800 (PST): 04:00 local → 12:00 UTC
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

    #[test]
    fn parse_cdata_title() {
        // quick-xml handles CDATA sections automatically.
        let xml = r#"<tv>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="c1">
    <title><![CDATA[Breaking <News> & More]]></title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].title, "Breaking <News> & More");
    }

    #[test]
    fn parse_programme_with_start_timestamp() {
        // Some providers use start_timestamp/stop_timestamp
        // (Unix epoch) instead of XMLTV datetime strings.
        let xml = r#"<tv>
  <programme start_timestamp="1705305600" stop_timestamp="1705309200" channel="ts1">
    <title>Timestamp Show</title>
  </programme>
</tv>"#;
        let entries = parse_epg(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].epg_channel_id, "ts1");
        assert_eq!(entries[0].title, "Timestamp Show");
        // 1705305600 = 2024-01-15 08:00:00 UTC
        assert_eq!(
            entries[0].start_time,
            NaiveDateTime::new(
                chrono::NaiveDate::from_ymd_opt(2024, 1, 15).unwrap(),
                chrono::NaiveTime::from_hms_opt(8, 0, 0).unwrap(),
            ),
        );
    }

    #[test]
    fn parse_xmltv_ns_episode_numbering() {
        // Season 2, Episode 6: "1.5.0" (zero-indexed)
        let (season, episode) = parse_xmltv_ns("1.5.0");
        assert_eq!(season, Some(2));
        assert_eq!(episode, Some(6));

        // Only season: "3.."
        let (s, e) = parse_xmltv_ns("3..");
        assert_eq!(s, Some(4));
        assert_eq!(e, None);

        // Empty string
        let (s2, e2) = parse_xmltv_ns("");
        assert_eq!(s2, None);
        assert_eq!(e2, None);
    }
}
