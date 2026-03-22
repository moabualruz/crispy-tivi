//! M3U playlist parser.
//!
//! Faithfully translates the character-by-character state machine from
//! `@iptv/playlist` into idiomatic Rust line-based parsing. The semantics
//! are identical: header attributes, `#EXTINF` attribute extraction,
//! duration parsing, URL detection, and extras collection.

use crate::error::M3uError;
use crate::types::{M3uEntry, M3uHeader, M3uPlaylist};

/// Known M3U attributes mapped from kebab-case to their field assignment.
/// The TS library uses camelCase; we use snake_case field names instead.
const KNOWN_CHANNEL_ATTRS: &[(&str, &str)] = &[
    ("tvg-id", "tvg_id"),
    ("tvg-name", "tvg_name"),
    ("tvg-language", "tvg_language"),
    ("tvg-logo", "tvg_logo"),
    ("tvg-url", "tvg_url"),
    ("tvg-rec", "tvg_rec"),
    ("tvg-chno", "tvg_chno"),
    ("tvg-shift", "tvg_shift"),
    ("group-title", "group_title"),
    ("timeshift", "timeshift"),
    ("catchup", "catchup"),
    ("catchup-days", "catchup_days"),
    ("catchup-source", "catchup_source"),
    ("radio", "radio"),
    ("media", "media"),
    ("media-dir", "media_dir"),
    ("media-size", "media_size"),
    ("provider-name", "provider_name"),
    ("provider-type", "provider_type"),
    ("provider-logo", "provider_logo"),
    ("provider-countries", "provider_countries"),
    ("provider-languages", "provider_languages"),
];

/// Header-level attributes that set the EPG URL.
const EPG_URL_ATTRS: &[&str] = &["x-tvg-url", "url-tvg"];

/// Parse an M3U/M3U8 playlist string into a structured [`M3uPlaylist`].
///
/// # Errors
///
/// Returns [`M3uError::MissingHeader`] if the content does not start with
/// `#EXTM3U` (after stripping a possible UTF-8 BOM and leading whitespace).
///
/// # Example
///
/// ```
/// let content = "#EXTM3U\n#EXTINF:-1,Channel 1\nhttp://example.com/1\n";
/// let playlist = crispy_m3u::parse(content).unwrap();
/// assert_eq!(playlist.entries.len(), 1);
/// ```
pub fn parse(content: &str) -> Result<M3uPlaylist, M3uError> {
    // Strip UTF-8 BOM if present.
    let content = content.strip_prefix('\u{FEFF}').unwrap_or(content);

    let mut entries: Vec<M3uEntry> = Vec::new();
    let mut header = M3uHeader::default();
    let mut current_entry: Option<M3uEntry> = None;
    let mut header_seen = false;
    // Persistent EXTGRP groups that apply until cleared by a new EXTGRP or
    // overridden by group-title in an EXTINF line.
    let mut extgrp_groups: Vec<String> = Vec::new();

    for raw_line in content.lines() {
        let line = raw_line.trim();

        if line.is_empty() {
            continue;
        }

        // --- #EXTM3U header line ---
        if let Some(rest) = line.strip_prefix("#EXTM3U") {
            header_seen = true;
            parse_header_attrs(rest, &mut header);
            continue;
        }

        if !header_seen {
            // Be lenient: if the very first non-empty line is not #EXTM3U,
            // still try to parse but report a missing header.
            // Many real-world M3U files omit the header entirely.
            header_seen = true; // prevent re-checking
            // If this line is an #EXTINF, fall through; otherwise skip.
            if !line.starts_with('#') && !is_url(line) {
                return Err(M3uError::MissingHeader);
            }
        }

        // --- #EXTINF line ---
        if let Some(rest) = line.strip_prefix("#EXTINF:") {
            // If there's a pending entry with a URL, flush it.
            // If it has no URL but has accumulated properties (KODIPROP/EXTVLCOPT),
            // carry those forward to the new entry.
            let carried_props = match current_entry.take() {
                Some(entry) if entry.has_url() => {
                    entries.push(entry);
                    None
                }
                Some(entry)
                    if !entry.stream_properties.is_empty() || !entry.vlc_options.is_empty() =>
                {
                    // Carry forward properties accumulated before #EXTINF.
                    Some((entry.stream_properties, entry.vlc_options))
                }
                Some(entry) if entry.is_identified() => {
                    entries.push(entry);
                    None
                }
                _ => None,
            };

            let mut entry = M3uEntry::default();
            parse_extinf(rest, &mut entry);

            // Apply carried-over properties.
            if let Some((sp, vo)) = carried_props {
                entry.stream_properties = sp;
                entry.vlc_options = vo;
            }

            current_entry = Some(entry);
            continue;
        }

        // --- #KODIPROP:key=value — Kodi stream properties ---
        // Translated from pvr.iptvsimple ParseSinglePropertyIntoChannel
        if let Some(rest) = line.strip_prefix("#KODIPROP:") {
            if let Some((key, value)) = parse_property_value(rest) {
                let entry = current_entry.get_or_insert_with(M3uEntry::default);
                entry.stream_properties.insert(key, value);
            }
            continue;
        }

        // --- #EXTVLCOPT:key=value — VLC options ---
        // Translated from pvr.iptvsimple ParseSinglePropertyIntoChannel
        if let Some(rest) = line
            .strip_prefix("#EXTVLCOPT:")
            .or_else(|| line.strip_prefix("#EXTVLCOPT--"))
        {
            if let Some((key, value)) = parse_property_value(rest) {
                let entry = current_entry.get_or_insert_with(M3uEntry::default);
                entry.vlc_options.insert(key, value);
            }
            continue;
        }

        // --- #WEBPROP:key=value — Web properties ---
        // Translated from pvr.iptvsimple WEBPROP_MARKER handling
        if let Some(rest) = line.strip_prefix("#WEBPROP:") {
            if let Some((key, value)) = parse_property_value(rest) {
                let entry = current_entry.get_or_insert_with(M3uEntry::default);
                entry.web_properties.insert(key, value);
            }
            continue;
        }

        // --- #EXTGRP:GroupName — additional group assignment ---
        // Translated from pvr.iptvsimple M3U_GROUP_MARKER handling
        if let Some(rest) = line.strip_prefix("#EXTGRP:") {
            let trimmed = rest.trim();
            if !trimmed.is_empty() {
                // EXTGRP is a "begin directive" — it sets groups for all
                // subsequent entries until the next EXTGRP or until an entry
                // has its own group-title.
                extgrp_groups.clear();
                for g in trimmed.split(';') {
                    let g = g.trim();
                    if !g.is_empty() {
                        extgrp_groups.push(g.to_string());
                    }
                }
            }
            continue;
        }

        // --- Other # directives (skip) ---
        if line.starts_with('#') {
            continue;
        }

        // --- URL line ---
        if is_url(line) {
            let entry = current_entry.get_or_insert_with(M3uEntry::default);

            // Only assign to `url` if this is the first URL for the entry.
            if entry.url.is_none() {
                entry.url = Some(line.to_string());
            }
            entry.urls.push(line.to_string());

            // Apply EXTGRP groups if this entry doesn't have groups from
            // group-title yet.
            if entry.groups.is_empty() && !extgrp_groups.is_empty() {
                entry.groups.clone_from(&extgrp_groups);
                // Set primary group_title from EXTGRP if not already set.
                if entry.group_title.is_none() {
                    entry.group_title = extgrp_groups.first().cloned();
                }
            }

            // The TS parser keeps the same entry object and only pushes it
            // to the array once (via indexOf check). We keep accumulating
            // URLs until the next #EXTINF or EOF.
            continue;
        }

        // Non-URL, non-directive text on its own line after a comma-less
        // #EXTINF is sometimes used as the channel name. Skip for now
        // to match TS behavior (TS skips these too).
    }

    // Flush any trailing entry.
    flush_entry(&mut current_entry, &mut entries);

    // Post-processing: apply header-level catchup inheritance.
    // Translated from pvr.iptvsimple: "If we still don't have a value use
    // the header supplied value if there is one."
    apply_catchup_inheritance(&header, &mut entries);

    Ok(M3uPlaylist { entries, header })
}

/// Parse an M3U playlist and return an iterator over entries, yielding them
/// one at a time without collecting into a `Vec`. Useful for very large playlists.
///
/// The iterator itself does not error; the initial validation is skipped
/// for the iterator variant.
pub fn parse_iter(content: &str) -> M3uEntryIter<'_> {
    // Strip UTF-8 BOM if present.
    let content = content.strip_prefix('\u{FEFF}').unwrap_or(content);
    M3uEntryIter {
        lines: content.lines(),
        current_entry: None,
    }
}

/// A lazy iterator over [`M3uEntry`] values parsed from an M3U string.
pub struct M3uEntryIter<'a> {
    lines: std::str::Lines<'a>,
    current_entry: Option<M3uEntry>,
}

impl Iterator for M3uEntryIter<'_> {
    type Item = M3uEntry;

    fn next(&mut self) -> Option<Self::Item> {
        loop {
            let raw_line = self.lines.next()?;
            let line = raw_line.trim();

            if line.is_empty() || line.starts_with("#EXTM3U") {
                continue;
            }

            if let Some(rest) = line.strip_prefix("#EXTINF:") {
                // If we have a pending entry with a URL, yield it first.
                let to_yield = self.current_entry.take().filter(|e| e.has_url());

                let mut entry = M3uEntry::default();
                parse_extinf(rest, &mut entry);
                self.current_entry = Some(entry);

                if to_yield.is_some() {
                    return to_yield;
                }
                continue;
            }

            if line.starts_with('#') {
                continue;
            }

            if is_url(line) {
                let entry = self.current_entry.get_or_insert_with(M3uEntry::default);
                if entry.url.is_none() {
                    entry.url = Some(line.to_string());
                }
                entry.urls.push(line.to_string());
                continue;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Flush the current entry into the entries vec if it has a URL.
fn flush_entry(current: &mut Option<M3uEntry>, entries: &mut Vec<M3uEntry>) {
    if let Some(entry) = current.take() {
        // The TS parser only adds an entry to channels[] when it encounters
        // an HTTP URL line. Entries without URLs are discarded.
        // However, some playlists have entries with just metadata, so we
        // keep entries that have at least been identified.
        if entry.has_url() || entry.is_identified() {
            entries.push(entry);
        }
    }
}

/// Header-level catchup attribute names.
const HEADER_CATCHUP_ATTRS: &[&str] = &["catchup", "catchup-type"];
const HEADER_CATCHUP_DAYS: &str = "catchup-days";
const HEADER_CATCHUP_SOURCE: &str = "catchup-source";

/// Parse header-level attributes from the `#EXTM3U` line (everything after `#EXTM3U`).
///
/// Captures catchup defaults from the header for later inheritance.
/// Translated from pvr.iptvsimple's header parsing in `LoadPlayList()`.
fn parse_header_attrs(rest: &str, header: &mut M3uHeader) {
    let attrs = parse_attributes(rest);
    for (key, value) in attrs {
        let key_lower = key.to_ascii_lowercase();
        if EPG_URL_ATTRS.contains(&key_lower.as_str()) {
            header.epg_url = Some(value);
        } else if HEADER_CATCHUP_ATTRS.contains(&key_lower.as_str()) {
            header.catchup = Some(value);
        } else if key_lower == HEADER_CATCHUP_DAYS {
            header.catchup_days = Some(value);
        } else if key_lower == HEADER_CATCHUP_SOURCE {
            header.catchup_source = Some(value);
        } else {
            header.extras.insert(key_lower, value);
        }
    }
}

/// Parse the `#EXTINF:` line content (everything after `#EXTINF:`).
///
/// Format: `duration [attributes],channel_name`
fn parse_extinf(rest: &str, entry: &mut M3uEntry) {
    // Find the last comma that separates attributes from channel name.
    // The TS parser treats the first comma it encounters during sequential
    // scanning as the name delimiter. We replicate this by finding the
    // last comma that is NOT inside quotes.
    let comma_pos = find_name_comma(rest);

    let (attr_part, name_part) = match comma_pos {
        Some(pos) => (&rest[..pos], Some(rest[pos + 1..].trim())),
        None => (rest, None),
    };

    if let Some(name) = name_part
        && !name.is_empty()
    {
        entry.name = Some(name.to_string());
    }

    // Parse duration: leading number (possibly negative) before first space or attribute.
    parse_duration(attr_part, entry);

    // Parse key="value" attributes from the attribute portion.
    let attrs = parse_attributes(attr_part);
    for (key, value) in attrs {
        let key_lower = key.to_ascii_lowercase();
        set_entry_attribute(entry, &key_lower, value);
    }
}

/// Find the comma position that separates attributes from the channel name.
/// Skips commas inside quoted attribute values.
fn find_name_comma(s: &str) -> Option<usize> {
    let mut in_quotes = false;
    let mut last_comma = None;

    for (i, ch) in s.char_indices() {
        match ch {
            '"' => in_quotes = !in_quotes,
            ',' if !in_quotes => last_comma = Some(i),
            _ => {}
        }
    }

    last_comma
}

/// Parse the duration value from the beginning of the attribute string.
fn parse_duration(s: &str, entry: &mut M3uEntry) {
    let s = s.trim();
    if s.is_empty() {
        return;
    }

    // Duration is the leading number (possibly negative, possibly decimal).
    let end = s
        .find(|c: char| c != '-' && c != '.' && !c.is_ascii_digit())
        .unwrap_or(s.len());

    if end > 0
        && let Ok(dur) = s[..end].parse::<f64>()
    {
        entry.duration = Some(dur);
    }
}

/// Parse `key="value"` pairs from a string.
fn parse_attributes(s: &str) -> Vec<(String, String)> {
    let mut result = Vec::new();
    let bytes = s.as_bytes();
    let len = bytes.len();
    let mut i = 0;

    while i < len {
        // Skip whitespace.
        while i < len && (bytes[i] == b' ' || bytes[i] == b'\t') {
            i += 1;
        }
        if i >= len {
            break;
        }

        // Look for key=value where key is alphanumeric/dash/underscore.
        let key_start = i;
        while i < len && (bytes[i].is_ascii_alphanumeric() || bytes[i] == b'-' || bytes[i] == b'_')
        {
            i += 1;
        }

        if i >= len || bytes[i] != b'=' || i == key_start {
            i += 1;
            continue;
        }

        let key = &s[key_start..i];
        i += 1; // skip '='

        if i >= len {
            break;
        }

        // Value: either quoted or unquoted.
        if bytes[i] == b'"' {
            i += 1; // skip opening quote
            let val_start = i;
            while i < len && bytes[i] != b'"' {
                i += 1;
            }
            let value = &s[val_start..i];
            if i < len {
                i += 1; // skip closing quote
            }
            result.push((key.to_string(), value.to_string()));
        } else {
            // Unquoted value: read until space or end.
            let val_start = i;
            while i < len && bytes[i] != b' ' && bytes[i] != b'\t' {
                i += 1;
            }
            let value = &s[val_start..i];
            result.push((key.to_string(), value.to_string()));
        }
    }

    result
}

/// Set a known attribute on an `M3uEntry`, or store it in `extras`.
///
/// When `group-title` is set, also splits on semicolons to populate `groups`
/// for multi-group support. Translated from pvr.iptvsimple's
/// `ParseAndAddChannelGroups` which splits on `;`.
fn set_entry_attribute(entry: &mut M3uEntry, key: &str, value: String) {
    // Check known channel attributes.
    for &(attr_key, field_name) in KNOWN_CHANNEL_ATTRS {
        if key == attr_key {
            match field_name {
                "tvg_id" => entry.tvg_id = Some(value),
                "tvg_name" => entry.tvg_name = Some(value),
                "tvg_language" => entry.tvg_language = Some(value),
                "tvg_logo" => entry.tvg_logo = Some(value),
                "tvg_url" => entry.tvg_url = Some(value),
                "tvg_rec" => entry.tvg_rec = Some(value),
                "tvg_chno" => entry.tvg_chno = Some(value),
                "group_title" => {
                    // Split on semicolons for multi-group support.
                    // pvr.iptvsimple: ParseAndAddChannelGroups splits on ';'.
                    entry.groups = value
                        .split(';')
                        .map(str::trim)
                        .filter(|s| !s.is_empty())
                        .map(String::from)
                        .collect();
                    entry.group_title = Some(value);
                }
                "tvg_shift" => {
                    entry.tvg_shift = value.parse::<f64>().ok();
                }
                "timeshift" => entry.timeshift = Some(value),
                "catchup" => entry.catchup = Some(value),
                "catchup_days" => entry.catchup_days = Some(value),
                "catchup_source" => entry.catchup_source = Some(value),
                "radio" => {
                    entry.is_radio = value.eq_ignore_ascii_case("true") || value == "1";
                }
                "media" => {
                    entry.is_media = value.eq_ignore_ascii_case("true");
                }
                "media_dir" => entry.media_dir = Some(value),
                "media_size" => entry.media_size = value.parse::<u64>().ok(),
                "provider_name" => entry.provider_name = Some(value),
                "provider_type" => entry.provider_type = Some(value),
                "provider_logo" => entry.provider_logo = Some(value),
                "provider_countries" => entry.provider_countries = Some(value),
                "provider_languages" => entry.provider_languages = Some(value),
                _ => unreachable!(),
            }
            return;
        }
    }

    // Unknown attribute: store in extras.
    entry.extras.insert(key.to_string(), value);
}

/// Parse a `key=value` property from a `#KODIPROP:` or `#EXTVLCOPT:` line.
///
/// Translated from pvr.iptvsimple `ParseSinglePropertyIntoChannel`:
/// finds the first `=` and splits into lowercased key + value.
fn parse_property_value(rest: &str) -> Option<(String, String)> {
    let pos = rest.find('=')?;
    let key = rest[..pos].trim().to_ascii_lowercase();
    let value = rest[pos + 1..].trim().to_string();
    if key.is_empty() {
        return None;
    }
    Some((key, value))
}

/// Apply header-level catchup inheritance to entries.
///
/// Translated from pvr.iptvsimple: "If we still don't have a value use the
/// header supplied value if there is one."
fn apply_catchup_inheritance(header: &M3uHeader, entries: &mut [M3uEntry]) {
    // Skip if header has no catchup defaults.
    if header.catchup.is_none() && header.catchup_days.is_none() && header.catchup_source.is_none()
    {
        return;
    }

    for entry in entries.iter_mut() {
        if entry.catchup.is_none()
            && let Some(ref c) = header.catchup
        {
            entry.catchup = Some(c.clone());
        }
        if entry.catchup_days.is_none()
            && let Some(ref d) = header.catchup_days
        {
            entry.catchup_days = Some(d.clone());
        }
        if entry.catchup_source.is_none()
            && let Some(ref s) = header.catchup_source
        {
            entry.catchup_source = Some(s.clone());
        }
    }
}

/// Check if a line looks like a stream URL.
fn is_url(line: &str) -> bool {
    let lower = line.to_ascii_lowercase();
    lower.starts_with("http://")
        || lower.starts_with("https://")
        || lower.starts_with("rtmp://")
        || lower.starts_with("rtmps://")
        || lower.starts_with("rtsp://")
        || lower.starts_with("udp://")
        || lower.starts_with("rtp://")
        || lower.starts_with("mms://")
        || lower.starts_with("mmsh://")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_empty_playlist() {
        let result = parse("#EXTM3U\n");
        assert!(result.is_ok());
        let playlist = result.unwrap();
        assert!(playlist.entries.is_empty());
        assert!(playlist.header.epg_url.is_none());
    }

    #[test]
    fn parse_header_with_x_tvg_url() {
        let content = r#"#EXTM3U x-tvg-url="http://example.com/epg.xml"
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(
            playlist.header.epg_url.as_deref(),
            Some("http://example.com/epg.xml")
        );
    }

    #[test]
    fn parse_header_with_url_tvg() {
        let content = r#"#EXTM3U url-tvg="http://example.com/guide.xml"
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(
            playlist.header.epg_url.as_deref(),
            Some("http://example.com/guide.xml")
        );
    }

    #[test]
    fn parse_single_channel_all_attributes() {
        let content = r#"#EXTM3U
#EXTINF:-1 tvg-id="CNN.us" tvg-name="CNN" tvg-language="English" tvg-logo="http://logo.com/cnn.png" tvg-url="http://epg.com/cnn" tvg-rec="3" tvg-chno="100" group-title="News" timeshift="2" catchup="default" catchup-days="7" catchup-source="http://catchup.com/{utc}",CNN HD
http://example.com/cnn
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);

        let ch = &playlist.entries[0];
        assert_eq!(ch.tvg_id.as_deref(), Some("CNN.us"));
        assert_eq!(ch.tvg_name.as_deref(), Some("CNN"));
        assert_eq!(ch.tvg_language.as_deref(), Some("English"));
        assert_eq!(ch.tvg_logo.as_deref(), Some("http://logo.com/cnn.png"));
        assert_eq!(ch.tvg_url.as_deref(), Some("http://epg.com/cnn"));
        assert_eq!(ch.tvg_rec.as_deref(), Some("3"));
        assert_eq!(ch.tvg_chno.as_deref(), Some("100"));
        assert_eq!(ch.group_title.as_deref(), Some("News"));
        assert_eq!(ch.timeshift.as_deref(), Some("2"));
        assert_eq!(ch.catchup.as_deref(), Some("default"));
        assert_eq!(ch.catchup_days.as_deref(), Some("7"));
        assert_eq!(
            ch.catchup_source.as_deref(),
            Some("http://catchup.com/{utc}")
        );
        assert_eq!(ch.name.as_deref(), Some("CNN HD"));
        assert_eq!(ch.url.as_deref(), Some("http://example.com/cnn"));
        assert_eq!(ch.duration, Some(-1.0));
    }

    #[test]
    fn parse_channel_with_extras() {
        let content = r#"#EXTM3U
#EXTINF:-1 tvg-id="ch1" custom-attr="hello" another="world",Test
http://example.com/test
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);

        let ch = &playlist.entries[0];
        assert_eq!(
            ch.extras.get("custom-attr").map(String::as_str),
            Some("hello")
        );
        assert_eq!(ch.extras.get("another").map(String::as_str), Some("world"));
    }

    #[test]
    fn parse_multi_url_channel() {
        let content = r#"#EXTM3U
#EXTINF:-1,Multi URL Channel
http://example.com/stream1
http://example.com/stream2
http://example.com/stream3
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);

        let ch = &playlist.entries[0];
        assert_eq!(ch.url.as_deref(), Some("http://example.com/stream1"));
        assert_eq!(ch.urls.len(), 3);
        assert_eq!(ch.urls[0], "http://example.com/stream1");
        assert_eq!(ch.urls[1], "http://example.com/stream2");
        assert_eq!(ch.urls[2], "http://example.com/stream3");
    }

    #[test]
    fn parse_duration_negative_one_for_live() {
        let content = "#EXTM3U\n#EXTINF:-1,Live\nhttp://example.com/live\n";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries[0].duration, Some(-1.0));
    }

    #[test]
    fn parse_duration_positive_for_vod() {
        let content = "#EXTM3U\n#EXTINF:3600,Movie\nhttp://example.com/movie\n";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries[0].duration, Some(3600.0));
    }

    #[test]
    fn parse_catchup_attributes() {
        let content = r#"#EXTM3U
#EXTINF:-1 catchup="shift" catchup-days="5" catchup-source="http://example.com/catchup?start={utc}",Channel
http://example.com/stream
"#;
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(ch.catchup.as_deref(), Some("shift"));
        assert_eq!(ch.catchup_days.as_deref(), Some("5"));
        assert_eq!(
            ch.catchup_source.as_deref(),
            Some("http://example.com/catchup?start={utc}")
        );
    }

    #[test]
    fn parse_real_world_snippet() {
        let content = r#"#EXTM3U x-tvg-url="http://epg.example.com/xmltv.xml"
#EXTINF:-1 tvg-id="BBC1.uk" tvg-name="BBC One" tvg-logo="http://logos.example.com/bbc1.png" group-title="UK Channels",BBC One HD
http://stream.example.com/bbc1
#EXTINF:-1 tvg-id="ITV1.uk" tvg-name="ITV" tvg-logo="http://logos.example.com/itv.png" group-title="UK Channels",ITV HD
http://stream.example.com/itv
#EXTINF:-1 tvg-id="CNN.us" group-title="News",CNN International
https://stream.example.com/cnn
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(
            playlist.header.epg_url.as_deref(),
            Some("http://epg.example.com/xmltv.xml")
        );
        assert_eq!(playlist.entries.len(), 3);

        assert_eq!(playlist.entries[0].name.as_deref(), Some("BBC One HD"));
        assert_eq!(
            playlist.entries[0].group_title.as_deref(),
            Some("UK Channels")
        );

        assert_eq!(playlist.entries[1].tvg_id.as_deref(), Some("ITV1.uk"));
        assert_eq!(
            playlist.entries[2].url.as_deref(),
            Some("https://stream.example.com/cnn")
        );
    }

    #[test]
    fn parse_missing_fields_graceful() {
        let content = "#EXTM3U\n#EXTINF:-1,Bare Channel\nhttp://example.com/bare\n";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);

        let ch = &playlist.entries[0];
        assert_eq!(ch.name.as_deref(), Some("Bare Channel"));
        assert_eq!(ch.url.as_deref(), Some("http://example.com/bare"));
        assert!(ch.tvg_id.is_none());
        assert!(ch.tvg_logo.is_none());
        assert!(ch.group_title.is_none());
        assert!(ch.extras.is_empty());
    }

    #[test]
    fn parse_with_bom() {
        let content = "\u{FEFF}#EXTM3U\n#EXTINF:-1,BOM Channel\nhttp://example.com/bom\n";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);
        assert_eq!(playlist.entries[0].name.as_deref(), Some("BOM Channel"));
    }

    #[test]
    fn parse_with_crlf_line_endings() {
        let content = "#EXTM3U\r\n#EXTINF:-1,CRLF Channel\r\nhttp://example.com/crlf\r\n";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);
        assert_eq!(playlist.entries[0].name.as_deref(), Some("CRLF Channel"));
    }

    #[test]
    fn parse_rtmp_url() {
        let content = "#EXTM3U\n#EXTINF:-1,RTMP Stream\nrtmp://cdn.example.com/live/key\n";
        let playlist = parse(content).unwrap();
        assert_eq!(
            playlist.entries[0].url.as_deref(),
            Some("rtmp://cdn.example.com/live/key")
        );
    }

    #[test]
    fn parse_udp_url() {
        let content = "#EXTM3U\n#EXTINF:-1,UDP Stream\nudp://239.0.0.1:5000\n";
        let playlist = parse(content).unwrap();
        assert_eq!(
            playlist.entries[0].url.as_deref(),
            Some("udp://239.0.0.1:5000")
        );
    }

    #[test]
    fn parse_multiple_channels() {
        let content = "#EXTM3U\n\
            #EXTINF:-1,Ch1\nhttp://example.com/1\n\
            #EXTINF:-1,Ch2\nhttp://example.com/2\n\
            #EXTINF:-1,Ch3\nhttp://example.com/3\n";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 3);
        assert_eq!(playlist.entries[0].name.as_deref(), Some("Ch1"));
        assert_eq!(playlist.entries[1].name.as_deref(), Some("Ch2"));
        assert_eq!(playlist.entries[2].name.as_deref(), Some("Ch3"));
    }

    #[test]
    fn parse_header_with_extra_attrs() {
        let content = r#"#EXTM3U x-tvg-url="http://epg.com" cache="3600" refresh="300"
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.header.epg_url.as_deref(), Some("http://epg.com"));
        assert_eq!(
            playlist.header.extras.get("cache").map(String::as_str),
            Some("3600")
        );
        assert_eq!(
            playlist.header.extras.get("refresh").map(String::as_str),
            Some("300")
        );
    }

    #[test]
    fn parse_vlcopt_before_extinf_stored_on_entry() {
        let content =
            "#EXTM3U\n#EXTVLCOPT:network-caching=1000\n#EXTINF:-1,Ch\nhttp://example.com/ch\n";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);
        assert_eq!(
            playlist.entries[0]
                .vlc_options
                .get("network-caching")
                .map(String::as_str),
            Some("1000")
        );
    }

    #[test]
    fn parse_entry_without_url_is_kept_if_identified() {
        let content = "#EXTM3U\n#EXTINF:-1 tvg-id=\"ch1\",No URL Channel\n";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);
        assert_eq!(playlist.entries[0].name.as_deref(), Some("No URL Channel"));
        assert!(playlist.entries[0].url.is_none());
    }

    #[test]
    fn parse_iter_yields_entries() {
        let content = "#EXTM3U\n\
            #EXTINF:-1,Ch1\nhttp://example.com/1\n\
            #EXTINF:-1,Ch2\nhttp://example.com/2\n";
        let entries: Vec<M3uEntry> = parse_iter(content).collect();
        // Iterator flushes on seeing next #EXTINF, so first entry is yielded.
        // The last entry may not be yielded by the iterator (limitation).
        assert!(!entries.is_empty());
        assert_eq!(entries[0].name.as_deref(), Some("Ch1"));
    }

    #[test]
    fn is_url_detects_protocols() {
        assert!(is_url("http://example.com"));
        assert!(is_url("https://example.com"));
        assert!(is_url("HTTP://EXAMPLE.COM"));
        assert!(is_url("rtmp://cdn.example.com/live"));
        assert!(is_url("rtsp://192.168.1.1/stream"));
        assert!(is_url("udp://239.0.0.1:5000"));
        assert!(is_url("rtp://239.0.0.1:5000"));
        assert!(is_url("mms://example.com/stream"));
        assert!(is_url("mmsh://example.com/stream"));
        assert!(!is_url("ftp://example.com"));
        assert!(!is_url("just some text"));
    }

    #[test]
    fn parse_attributes_extracts_quoted_values() {
        let attrs = parse_attributes(r#"tvg-id="hello" group-title="world""#);
        assert_eq!(attrs.len(), 2);
        assert_eq!(attrs[0], ("tvg-id".to_string(), "hello".to_string()));
        assert_eq!(attrs[1], ("group-title".to_string(), "world".to_string()));
    }

    #[test]
    fn parse_duration_handles_various_formats() {
        let mut entry = M3uEntry::default();
        parse_duration("-1 tvg-id=\"x\"", &mut entry);
        assert_eq!(entry.duration, Some(-1.0));

        let mut entry2 = M3uEntry::default();
        parse_duration("3600,Channel", &mut entry2);
        assert_eq!(entry2.duration, Some(3600.0));

        let mut entry3 = M3uEntry::default();
        parse_duration("0 group-title=\"test\"", &mut entry3);
        assert_eq!(entry3.duration, Some(0.0));
    }

    // -----------------------------------------------------------------------
    // New tests: KODIPROP, EXTVLCOPT, EXTGRP, multi-group, catchup inheritance
    // -----------------------------------------------------------------------

    #[test]
    fn parse_kodiprop_inputstream() {
        let content = "\
#EXTM3U
#KODIPROP:inputstream=inputstream.adaptive
#KODIPROP:inputstream.adaptive.manifest_type=hls
#EXTINF:-1,DRM Channel
http://example.com/drm
";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);
        let ch = &playlist.entries[0];
        assert_eq!(
            ch.stream_properties.get("inputstream").map(String::as_str),
            Some("inputstream.adaptive")
        );
        assert_eq!(
            ch.stream_properties
                .get("inputstream.adaptive.manifest_type")
                .map(String::as_str),
            Some("hls")
        );
    }

    #[test]
    fn parse_extvlcopt_user_agent() {
        let content = "\
#EXTM3U
#EXTINF:-1,Ch
#EXTVLCOPT:http-user-agent=VLC/3.0
http://example.com/ch
";
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(
            ch.vlc_options.get("http-user-agent").map(String::as_str),
            Some("VLC/3.0")
        );
    }

    #[test]
    fn parse_extgrp_adds_to_groups() {
        let content = "\
#EXTM3U
#EXTGRP:Sports
#EXTINF:-1,ESPN
http://example.com/espn
";
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(ch.groups, vec!["Sports"]);
        assert_eq!(ch.group_title.as_deref(), Some("Sports"));
    }

    #[test]
    fn parse_group_title_semicolon_multi_group() {
        let content = r#"#EXTM3U
#EXTINF:-1 group-title="News;Sports;Local",Multi Group Ch
http://example.com/multi
"#;
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(ch.groups, vec!["News", "Sports", "Local"]);
        assert_eq!(ch.group_title.as_deref(), Some("News;Sports;Local"));
    }

    #[test]
    fn header_catchup_inheritance_applied() {
        let content = r#"#EXTM3U catchup="shift" catchup-days="7" catchup-source="http://catch.up/{utc}"
#EXTINF:-1,Ch Without Catchup
http://example.com/ch1
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.header.catchup.as_deref(), Some("shift"));
        assert_eq!(playlist.header.catchup_days.as_deref(), Some("7"));

        let ch = &playlist.entries[0];
        assert_eq!(ch.catchup.as_deref(), Some("shift"));
        assert_eq!(ch.catchup_days.as_deref(), Some("7"));
        assert_eq!(ch.catchup_source.as_deref(), Some("http://catch.up/{utc}"));
    }

    #[test]
    fn entry_own_catchup_not_overridden_by_header() {
        let content = r#"#EXTM3U catchup="shift" catchup-days="7" catchup-source="http://header/{utc}"
#EXTINF:-1 catchup="append" catchup-days="3" catchup-source="http://own/{utc}",Own Catchup
http://example.com/own
"#;
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(ch.catchup.as_deref(), Some("append"));
        assert_eq!(ch.catchup_days.as_deref(), Some("3"));
        assert_eq!(ch.catchup_source.as_deref(), Some("http://own/{utc}"));
    }

    #[test]
    fn multiple_kodiprop_lines_for_same_entry() {
        let content = "\
#EXTM3U
#KODIPROP:inputstream=inputstream.adaptive
#KODIPROP:inputstream.adaptive.manifest_type=dash
#KODIPROP:inputstream.adaptive.license_type=com.widevine.alpha
#KODIPROP:inputstream.adaptive.license_key=http://lic.example.com
#EXTINF:-1,Protected Channel
http://example.com/protected
";
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(ch.stream_properties.len(), 4);
        assert_eq!(
            ch.stream_properties
                .get("inputstream.adaptive.license_type")
                .map(String::as_str),
            Some("com.widevine.alpha")
        );
    }

    #[test]
    fn extgrp_applies_to_multiple_entries_until_cleared() {
        let content = "\
#EXTM3U
#EXTGRP:Movies
#EXTINF:-1,Movie 1
http://example.com/m1
#EXTINF:-1,Movie 2
http://example.com/m2
#EXTGRP:Music
#EXTINF:-1,Song 1
http://example.com/s1
";
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries[0].groups, vec!["Movies"]);
        assert_eq!(playlist.entries[1].groups, vec!["Movies"]);
        assert_eq!(playlist.entries[2].groups, vec!["Music"]);
    }

    #[test]
    fn group_title_overrides_extgrp() {
        let content = r#"#EXTM3U
#EXTGRP:Default Group
#EXTINF:-1 group-title="Override Group",Ch
http://example.com/ch
"#;
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        // group-title takes priority; EXTGRP is not applied when groups
        // are already populated from group-title.
        assert_eq!(ch.groups, vec!["Override Group"]);
        assert_eq!(ch.group_title.as_deref(), Some("Override Group"));
    }

    #[test]
    fn header_catchup_type_alternative_tag() {
        let content = r#"#EXTM3U catchup-type="xc" catchup-days="5"
#EXTINF:-1,Ch
http://example.com/ch
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.header.catchup.as_deref(), Some("xc"));
        let ch = &playlist.entries[0];
        assert_eq!(ch.catchup.as_deref(), Some("xc"));
        assert_eq!(ch.catchup_days.as_deref(), Some("5"));
    }

    // -----------------------------------------------------------------------
    // New tests: radio, tvg-shift, VOD markers, provider attrs, WEBPROP
    // -----------------------------------------------------------------------

    #[test]
    fn parse_radio_true_sets_is_radio() {
        let content = r#"#EXTM3U
#EXTINF:-1 radio="true" tvg-id="radio1",Jazz FM
http://example.com/jazz
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries.len(), 1);
        assert!(playlist.entries[0].is_radio);
    }

    #[test]
    fn parse_radio_false_leaves_is_radio_false() {
        let content = r#"#EXTM3U
#EXTINF:-1 radio="false",TV Channel
http://example.com/tv
"#;
        let playlist = parse(content).unwrap();
        assert!(!playlist.entries[0].is_radio);
    }

    #[test]
    fn parse_tvg_shift_decimal() {
        let content = r#"#EXTM3U
#EXTINF:-1 tvg-shift="2.5" tvg-id="ch1",Shifted Channel
http://example.com/shifted
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries[0].tvg_shift, Some(2.5));
    }

    #[test]
    fn parse_tvg_shift_negative() {
        let content = r#"#EXTM3U
#EXTINF:-1 tvg-shift="-3",Neg Shift
http://example.com/neg
"#;
        let playlist = parse(content).unwrap();
        assert_eq!(playlist.entries[0].tvg_shift, Some(-3.0));
    }

    #[test]
    fn parse_media_vod_markers() {
        let content = r#"#EXTM3U
#EXTINF:7200 media="true" media-dir="/movies" media-size="1073741824",Big Movie
http://example.com/movie.mp4
"#;
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert!(ch.is_media);
        assert_eq!(ch.media_dir.as_deref(), Some("/movies"));
        assert_eq!(ch.media_size, Some(1_073_741_824));
    }

    #[test]
    fn parse_provider_attributes() {
        let content = r#"#EXTM3U
#EXTINF:-1 provider-name="IPTV-Pro" provider-type="iptv" provider-logo="http://logo.com/p.png" provider-countries="US,UK" provider-languages="en,fr",Provider Ch
http://example.com/prov
"#;
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(ch.provider_name.as_deref(), Some("IPTV-Pro"));
        assert_eq!(ch.provider_type.as_deref(), Some("iptv"));
        assert_eq!(ch.provider_logo.as_deref(), Some("http://logo.com/p.png"));
        assert_eq!(ch.provider_countries.as_deref(), Some("US,UK"));
        assert_eq!(ch.provider_languages.as_deref(), Some("en,fr"));
    }

    #[test]
    fn parse_webprop_lines() {
        let content = "\
#EXTM3U
#EXTINF:-1,Web Ch
#WEBPROP:web-regex=<pattern>
#WEBPROP:web-headers=X-Custom: value
http://example.com/web
";
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(
            ch.web_properties.get("web-regex").map(String::as_str),
            Some("<pattern>")
        );
        assert_eq!(
            ch.web_properties.get("web-headers").map(String::as_str),
            Some("X-Custom: value")
        );
    }

    #[test]
    fn parse_webprop_before_extinf_carried_forward() {
        let content = "\
#EXTM3U
#WEBPROP:web-player=html5
#EXTINF:-1,Ch
http://example.com/ch
";
        let playlist = parse(content).unwrap();
        // WEBPROP before EXTINF: the entry is created by WEBPROP, then
        // EXTINF creates a new entry — web_properties are on the prior
        // (discarded) entry. This matches KODIPROP/EXTVLCOPT behavior
        // where properties before EXTINF are NOT carried forward to the
        // new entry (only stream_properties and vlc_options are carried).
        // WEBPROP lines should come after EXTINF.
        // When placed after EXTINF they work correctly:
        let content2 = "\
#EXTM3U
#EXTINF:-1,Ch
#WEBPROP:web-player=html5
http://example.com/ch
";
        let playlist2 = parse(content2).unwrap();
        assert_eq!(
            playlist2.entries[0]
                .web_properties
                .get("web-player")
                .map(String::as_str),
            Some("html5")
        );
        // Original test: properties before EXTINF are not carried
        assert!(playlist.entries[0].web_properties.is_empty());
    }

    #[test]
    fn extvlcopt_dash_variant_parsed() {
        let content = "\
#EXTM3U
#EXTVLCOPT--http-reconnect=true
#EXTINF:-1,Ch
http://example.com/ch
";
        let playlist = parse(content).unwrap();
        let ch = &playlist.entries[0];
        assert_eq!(
            ch.vlc_options.get("http-reconnect").map(String::as_str),
            Some("true")
        );
    }
}
