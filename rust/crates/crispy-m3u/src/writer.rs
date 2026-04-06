//! M3U playlist writer.
//!
//! Generates valid M3U/M3U8 playlist strings from structured data.
//! Faithfully translates `@iptv/playlist`'s `writeM3U` function.

use crate::types::M3uPlaylist;

/// Write an [`M3uPlaylist`] to a valid M3U string.
///
/// # Example
///
/// ```
/// use crispy_m3u::types::{M3uEntry, M3uHeader, M3uPlaylist};
///
/// let playlist = M3uPlaylist {
///     header: M3uHeader {
///         epg_url: Some("http://epg.example.com/xmltv.xml".into()),
///         ..Default::default()
///     },
///     entries: vec![M3uEntry {
///         name: Some("CNN".into()),
///         url: Some("http://example.com/cnn".into()),
///         tvg_id: Some("CNN.us".into()),
///         group_title: Some("News".into()),
///         duration: Some(-1.0),
///         ..Default::default()
///     }],
/// };
///
/// let output = crispy_m3u::write(&playlist);
/// assert!(output.starts_with("#EXTM3U"));
/// assert!(output.contains("CNN"));
/// ```
pub fn write(playlist: &M3uPlaylist) -> String {
    let mut out = String::with_capacity(estimate_capacity(playlist));

    // Header line.
    out.push_str("#EXTM3U");

    // EPG URL header attribute.
    if let Some(ref epg_url) = playlist.header.epg_url {
        write_attr(&mut out, "x-tvg-url", epg_url);
    }

    // Extra header attributes.
    for (key, value) in &playlist.header.extras {
        write_attr(&mut out, key, value);
    }

    // Channel entries.
    for entry in &playlist.entries {
        // Skip entries without a URL (matches TS behavior).
        let Some(url) = entry.url.as_deref() else {
            continue;
        };

        out.push_str("\n#EXTINF:");

        // Duration (default -1 for live).
        match entry.duration {
            Some(d) => {
                // Write integer if it's a whole number, float otherwise.
                if d.fract() == 0.0 {
                    #[allow(clippy::cast_possible_truncation)]
                    write_int(&mut out, d as i64);
                } else {
                    out.push_str(&d.to_string());
                }
            }
            None => out.push_str("-1"),
        }

        // Known attributes.
        write_optional_attr(&mut out, "tvg-id", entry.tvg_id.as_deref());
        write_optional_attr(&mut out, "tvg-name", entry.tvg_name.as_deref());
        write_optional_attr(&mut out, "tvg-language", entry.tvg_language.as_deref());
        write_optional_attr(&mut out, "tvg-logo", entry.tvg_logo.as_deref());
        write_optional_attr(&mut out, "tvg-rec", entry.tvg_rec.as_deref());
        write_optional_attr(&mut out, "tvg-chno", entry.tvg_chno.as_deref());
        write_optional_attr(&mut out, "group-title", entry.group_title.as_deref());
        write_optional_attr(&mut out, "tvg-url", entry.tvg_url.as_deref());
        write_optional_attr(&mut out, "timeshift", entry.timeshift.as_deref());
        write_optional_attr(&mut out, "catchup", entry.catchup.as_deref());
        write_optional_attr(&mut out, "catchup-days", entry.catchup_days.as_deref());
        write_optional_attr(&mut out, "catchup-source", entry.catchup_source.as_deref());

        // Radio flag.
        if entry.is_radio {
            write_attr(&mut out, "radio", "true");
        }

        // EPG time shift.
        if let Some(shift) = entry.tvg_shift {
            out.push_str(" tvg-shift=\"");
            out.push_str(&shift.to_string());
            out.push('"');
        }

        // VOD/media attributes.
        if entry.is_media {
            write_attr(&mut out, "media", "true");
        }
        write_optional_attr(&mut out, "media-dir", entry.media_dir.as_deref());
        if let Some(size) = entry.media_size {
            out.push_str(" media-size=\"");
            out.push_str(&size.to_string());
            out.push('"');
        }

        // Provider attributes.
        write_optional_attr(&mut out, "provider-name", entry.provider_name.as_deref());
        write_optional_attr(&mut out, "provider-type", entry.provider_type.as_deref());
        write_optional_attr(&mut out, "provider-logo", entry.provider_logo.as_deref());
        write_optional_attr(
            &mut out,
            "provider-countries",
            entry.provider_countries.as_deref(),
        );
        write_optional_attr(
            &mut out,
            "provider-languages",
            entry.provider_languages.as_deref(),
        );

        // Extra attributes.
        for (key, value) in &entry.extras {
            write_attr(&mut out, key, value);
        }

        // Comma + channel name.
        out.push(',');
        if let Some(ref name) = entry.name {
            out.push_str(name);
        }

        // Web properties (as #WEBPROP: lines).
        for (key, value) in &entry.web_properties {
            out.push_str("\n#WEBPROP:");
            out.push_str(key);
            out.push('=');
            out.push_str(value);
        }

        // URL line.
        out.push('\n');
        out.push_str(url);
    }

    out
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Write ` key="value"` to the output.
fn write_attr(out: &mut String, key: &str, value: &str) {
    out.push(' ');
    out.push_str(key);
    out.push_str("=\"");
    out.push_str(value);
    out.push('"');
}

/// Write an optional attribute only if it has a value.
fn write_optional_attr(out: &mut String, key: &str, value: Option<&str>) {
    if let Some(v) = value {
        write_attr(out, key, v);
    }
}

/// Write an integer without allocating a string (itoa-style).
fn write_int(out: &mut String, n: i64) {
    // For simplicity, use `format!` which is fast enough for our purposes.
    // The itoa crate could be added for zero-alloc int formatting if needed.
    use std::fmt::Write;
    let _ = write!(out, "{n}");
}

/// Rough capacity estimate to minimize reallocations.
fn estimate_capacity(playlist: &M3uPlaylist) -> usize {
    // ~200 bytes per entry on average + header.
    200 * playlist.entries.len() + 128
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{M3uEntry, M3uHeader, M3uPlaylist};

    #[test]
    fn write_empty_playlist() {
        let playlist = M3uPlaylist::default();
        let output = write(&playlist);
        assert_eq!(output, "#EXTM3U");
    }

    #[test]
    fn write_header_with_epg_url() {
        let playlist = M3uPlaylist {
            header: M3uHeader {
                epg_url: Some("http://epg.com/guide.xml".into()),
                ..Default::default()
            },
            entries: vec![],
        };
        let output = write(&playlist);
        assert_eq!(output, r#"#EXTM3U x-tvg-url="http://epg.com/guide.xml""#);
    }

    #[test]
    fn write_single_channel() {
        let playlist = M3uPlaylist {
            header: M3uHeader::default(),
            entries: vec![M3uEntry {
                name: Some("CNN".into()),
                url: Some("http://example.com/cnn".into()),
                tvg_id: Some("CNN.us".into()),
                group_title: Some("News".into()),
                duration: Some(-1.0),
                ..Default::default()
            }],
        };
        let output = write(&playlist);
        assert!(output.contains(r#"tvg-id="CNN.us""#));
        assert!(output.contains(r#"group-title="News""#));
        assert!(output.contains(",CNN\n"));
        assert!(output.contains("http://example.com/cnn"));
        assert!(output.contains("#EXTINF:-1"));
    }

    #[test]
    fn write_skips_entries_without_url() {
        let playlist = M3uPlaylist {
            header: M3uHeader::default(),
            entries: vec![M3uEntry {
                name: Some("No URL".into()),
                ..Default::default()
            }],
        };
        let output = write(&playlist);
        assert_eq!(output, "#EXTM3U");
    }

    #[test]
    fn write_includes_extras() {
        let mut extras = std::collections::HashMap::new();
        extras.insert("custom".to_string(), "value".to_string());

        let playlist = M3uPlaylist {
            header: M3uHeader::default(),
            entries: vec![M3uEntry {
                name: Some("Ch".into()),
                url: Some("http://example.com/ch".into()),
                duration: Some(-1.0),
                extras,
                ..Default::default()
            }],
        };
        let output = write(&playlist);
        assert!(output.contains(r#"custom="value""#));
    }

    #[test]
    fn write_default_duration_when_none() {
        let playlist = M3uPlaylist {
            header: M3uHeader::default(),
            entries: vec![M3uEntry {
                name: Some("Ch".into()),
                url: Some("http://example.com/ch".into()),
                ..Default::default()
            }],
        };
        let output = write(&playlist);
        assert!(output.contains("#EXTINF:-1"));
    }

    #[test]
    fn roundtrip_parse_write_parse() {
        let original = r#"#EXTM3U x-tvg-url="http://epg.com/guide.xml"
#EXTINF:-1 tvg-id="BBC1.uk" tvg-name="BBC One" tvg-logo="http://logos.com/bbc1.png" group-title="UK",BBC One HD
http://stream.example.com/bbc1
#EXTINF:3600 tvg-id="MOV1" group-title="Movies",Test Movie
http://stream.example.com/movie1"#;

        let parsed = crate::parse(original).unwrap();
        let written = write(&parsed);
        let reparsed = crate::parse(&written).unwrap();

        assert_eq!(parsed.entries.len(), reparsed.entries.len());
        assert_eq!(parsed.header.epg_url, reparsed.header.epg_url);

        for (a, b) in parsed.entries.iter().zip(reparsed.entries.iter()) {
            assert_eq!(a.tvg_id, b.tvg_id);
            assert_eq!(a.name, b.name);
            assert_eq!(a.url, b.url);
            assert_eq!(a.group_title, b.group_title);
            assert_eq!(a.duration, b.duration);
            assert_eq!(a.tvg_logo, b.tvg_logo);
            assert_eq!(a.tvg_name, b.tvg_name);
        }
    }

    #[test]
    fn roundtrip_with_catchup() {
        let original = r#"#EXTM3U
#EXTINF:-1 catchup="shift" catchup-days="5" catchup-source="http://example.com/{utc}",Catchup Ch
http://example.com/stream"#;

        let parsed = crate::parse(original).unwrap();
        let written = write(&parsed);
        let reparsed = crate::parse(&written).unwrap();

        assert_eq!(reparsed.entries[0].catchup.as_deref(), Some("shift"));
        assert_eq!(reparsed.entries[0].catchup_days.as_deref(), Some("5"));
        assert_eq!(
            reparsed.entries[0].catchup_source.as_deref(),
            Some("http://example.com/{utc}")
        );
    }
}
