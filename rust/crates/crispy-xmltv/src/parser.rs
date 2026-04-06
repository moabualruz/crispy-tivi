//! Streaming XMLTV parser using `quick_xml` event-based pull parsing.
//!
//! Handles 100 MB+ files efficiently by processing `<channel>` and
//! `<programme>` elements as streaming events without buffering the
//! entire DOM.

use std::io::BufRead;

use crispy_iptv_types::epg::{
    EpgAudio, EpgChannel, EpgCredits, EpgEpisodeNumber, EpgIcon, EpgImage, EpgPerson, EpgProgramme,
    EpgRating, EpgReview, EpgStringWithLang, EpgVideo,
};
use quick_xml::Reader;
use quick_xml::events::{BytesStart, Event};

use crate::error::XmltvError;
use crate::timestamp::parse_xmltv_timestamp;
use crate::types::XmltvDocument;

/// Parse XMLTV content from a string.
pub fn parse(content: &str) -> Result<XmltvDocument, XmltvError> {
    let cursor = std::io::Cursor::new(content.as_bytes());
    parse_reader(std::io::BufReader::new(cursor))
}

/// Parse XMLTV content from a byte slice, auto-detecting and decompressing
/// gzip or XZ compression.
///
/// Equivalent to calling `decompress_auto` followed by `parse`.
pub fn parse_compressed(data: &[u8]) -> Result<XmltvDocument, XmltvError> {
    let decompressed = crate::compression::decompress_auto(data)?;
    let content = std::str::from_utf8(&decompressed)
        .map_err(|e| XmltvError::Xml(format!("invalid UTF-8 after decompression: {e}")))?;
    parse(content)
}

/// Parse XMLTV content from a buffered reader (streaming).
///
/// Accepts any `impl BufRead` so the caller controls I/O buffering.
pub fn parse_reader(reader: impl BufRead) -> Result<XmltvDocument, XmltvError> {
    let mut xml_reader = Reader::from_reader(reader);
    xml_reader.config_mut().trim_text(true);
    parse_events(&mut xml_reader)
}

/// Extract channel ID to display name mapping from XMLTV content.
///
/// Utility for quick channel name lookups without parsing full programmes.
pub fn extract_channel_names(
    content: &str,
) -> Result<std::collections::HashMap<String, String>, XmltvError> {
    let doc = parse(content)?;
    let mut result = std::collections::HashMap::new();
    for ch in &doc.channels {
        if let Some(name) = ch.display_name.first()
            && !name.value.is_empty()
        {
            result.entry(ch.id.clone()).or_insert(name.value.clone());
        }
    }
    Ok(result)
}

// ── Core parse loop ─────────────────────────────────────────────

fn parse_events<R: BufRead>(reader: &mut Reader<R>) -> Result<XmltvDocument, XmltvError> {
    let mut doc = XmltvDocument::default();
    let mut buf = Vec::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) => {
                // Extract data from the event before calling sub-parsers.
                match e.name().as_ref() {
                    b"channel" => {
                        let id = get_attr(e, b"id").unwrap_or_default();
                        let mut channel = parse_channel_body(reader)?;
                        channel.id = id;
                        doc.channels.push(channel);
                    }
                    b"programme" => {
                        let prog = parse_programme_start(e);
                        let prog = parse_programme_body(reader, prog)?;
                        doc.programmes.push(prog);
                    }
                    _ => {}
                }
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(XmltvError::Xml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }

    Ok(doc)
}

// ── Channel parsing ─────────────────────────────────────────────

fn parse_channel_body<R: BufRead>(reader: &mut Reader<R>) -> Result<EpgChannel, XmltvError> {
    let mut channel = EpgChannel::default();
    let mut depth: u32 = 1;
    let mut buf = Vec::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) => match e.name().as_ref() {
                b"display-name" => {
                    let lang = get_attr(e, b"lang");
                    let text = read_text_content(reader)?;
                    if !text.is_empty() {
                        channel
                            .display_name
                            .push(EpgStringWithLang { value: text, lang });
                    }
                }
                b"url" => {
                    let text = read_text_content(reader)?;
                    if !text.is_empty() {
                        channel.urls.push(text.clone());
                        // Backward compat: first URL also fills `channel.url`.
                        if channel.url.is_none() {
                            channel.url = Some(text);
                        }
                    }
                }
                _ => {
                    depth += 1;
                }
            },
            Ok(Event::Empty(ref e)) if e.name().as_ref() == b"icon" => {
                let icon = parse_icon_attrs(e);
                channel.icons.push(icon.clone());
                // Backward compat: first icon also fills `channel.icon`.
                if channel.icon.is_none() {
                    channel.icon = Some(icon);
                }
            }
            Ok(Event::End(_)) => {
                if depth <= 1 {
                    break;
                }
                depth -= 1;
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(XmltvError::Xml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }

    Ok(channel)
}

// ── Programme parsing ───────────────────────────────────────────

fn parse_programme_start(e: &BytesStart<'_>) -> EpgProgramme {
    let channel = get_attr(e, b"channel").unwrap_or_default();
    let start = get_attr(e, b"start").and_then(|s| parse_xmltv_timestamp(&s));
    let stop = get_attr(e, b"stop").and_then(|s| parse_xmltv_timestamp(&s));

    EpgProgramme {
        channel,
        start,
        stop,
        ..Default::default()
    }
}

fn parse_programme_body<R: BufRead>(
    reader: &mut Reader<R>,
    mut prog: EpgProgramme,
) -> Result<EpgProgramme, XmltvError> {
    let mut depth: u32 = 1;
    let mut buf = Vec::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) => match e.name().as_ref() {
                b"title" => {
                    let lang = get_attr(e, b"lang");
                    let value = read_text_content(reader)?;
                    prog.title.push(EpgStringWithLang { value, lang });
                }
                b"sub-title" => {
                    let lang = get_attr(e, b"lang");
                    let value = read_text_content(reader)?;
                    prog.sub_title.push(EpgStringWithLang { value, lang });
                }
                b"desc" => {
                    let lang = get_attr(e, b"lang");
                    let value = read_text_content(reader)?;
                    prog.desc.push(EpgStringWithLang { value, lang });
                }
                b"category" => {
                    let lang = get_attr(e, b"lang");
                    let value = read_text_content(reader)?;
                    prog.category.push(EpgStringWithLang { value, lang });
                }
                b"credits" => {
                    prog.credits = Some(parse_credits(reader)?);
                }
                b"date" => {
                    let text = read_text_content(reader)?;
                    if !text.is_empty() {
                        prog.date = Some(text);
                    }
                }
                b"length" => {
                    let text = read_text_content(reader)?;
                    prog.length = text.parse::<u32>().ok();
                }
                b"episode-num" => {
                    let system = get_attr(e, b"system");
                    let value = read_text_content(reader)?;
                    prog.episode_num.push(EpgEpisodeNumber { value, system });
                }
                b"image" => {
                    let image_type = get_attr(e, b"type");
                    let size = get_attr(e, b"size");
                    let orient = get_attr(e, b"orient");
                    let url = read_text_content(reader)?;
                    prog.image.push(EpgImage {
                        url,
                        image_type,
                        size,
                        orient,
                    });
                }
                b"rating" => {
                    let system = get_attr(e, b"system");
                    let value = parse_rating_value(reader)?;
                    prog.rating.push(EpgRating { value, system });
                }
                b"star-rating" => {
                    let system = get_attr(e, b"system");
                    let value = parse_rating_value(reader)?;
                    prog.star_rating.push(EpgRating { value, system });
                }
                b"premiere" => {
                    prog.is_premiere = true;
                    let _ = read_text_content(reader);
                }
                b"last-chance" => {
                    prog.is_last_chance = true;
                    let _ = read_text_content(reader);
                }
                b"keyword" => {
                    let lang = get_attr(e, b"lang");
                    let value = read_text_content(reader)?;
                    prog.keyword.push(EpgStringWithLang { value, lang });
                }
                b"language" => {
                    // XMLTV <language> = "language the programme is in".
                    // Not mapped to a dedicated field; skip text to avoid
                    // depth mismatch.
                    let _ = read_text_content(reader);
                }
                b"orig-language" => {
                    let lang = get_attr(e, b"lang");
                    let value = read_text_content(reader)?;
                    prog.orig_language = Some(EpgStringWithLang { value, lang });
                }
                b"video" => {
                    prog.video = Some(parse_video(reader)?);
                }
                b"audio" => {
                    prog.audio.push(parse_audio(reader)?);
                }
                b"review" => {
                    let review_type = get_attr(e, b"type");
                    let source = get_attr(e, b"source");
                    let reviewer = get_attr(e, b"reviewer");
                    let lang = get_attr(e, b"lang");
                    let value = read_text_content(reader)?;
                    prog.review.push(EpgReview {
                        value,
                        review_type,
                        source,
                        reviewer,
                        lang,
                    });
                }
                _ => {
                    depth += 1;
                }
            },
            Ok(Event::Empty(ref e)) => match e.name().as_ref() {
                b"icon" => {
                    prog.icon = Some(parse_icon_attrs(e));
                }
                b"new" => {
                    prog.is_new = true;
                }
                b"previously-shown" => {
                    prog.is_rerun = true;
                }
                b"premiere" => {
                    prog.is_premiere = true;
                }
                b"last-chance" => {
                    prog.is_last_chance = true;
                }
                b"review" => {
                    // Empty <review/> — unlikely but handle gracefully.
                    prog.review.push(EpgReview {
                        review_type: get_attr(e, b"type"),
                        source: get_attr(e, b"source"),
                        reviewer: get_attr(e, b"reviewer"),
                        lang: get_attr(e, b"lang"),
                        ..Default::default()
                    });
                }
                _ => {}
            },
            Ok(Event::End(_)) => {
                if depth <= 1 {
                    break;
                }
                depth -= 1;
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(XmltvError::Xml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }

    Ok(prog)
}

// ── Credits parsing ─────────────────────────────────────────────

fn parse_credits<R: BufRead>(reader: &mut Reader<R>) -> Result<EpgCredits, XmltvError> {
    let mut credits = EpgCredits::default();
    let mut depth: u32 = 1;
    let mut buf = Vec::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) => match e.name().as_ref() {
                b"director" => {
                    credits.director.push(read_text_content(reader)?);
                }
                b"actor" => {
                    let role = get_attr(e, b"role");
                    let guest = get_attr(e, b"guest")
                        .map(|v| v.eq_ignore_ascii_case("yes"))
                        .unwrap_or(false);
                    let image = get_attr(e, b"image");
                    let url = get_attr(e, b"url");
                    let name = read_text_content(reader)?;
                    credits.actor.push(EpgPerson {
                        name,
                        role,
                        guest,
                        image,
                        url,
                    });
                }
                b"writer" => {
                    credits.writer.push(read_text_content(reader)?);
                }
                b"producer" => {
                    credits.producer.push(read_text_content(reader)?);
                }
                b"composer" => {
                    credits.composer.push(read_text_content(reader)?);
                }
                b"presenter" => {
                    credits.presenter.push(read_text_content(reader)?);
                }
                b"commentator" => {
                    credits.commentator.push(read_text_content(reader)?);
                }
                b"guest" => {
                    let role = get_attr(e, b"role");
                    let image = get_attr(e, b"image");
                    let url = get_attr(e, b"url");
                    let name = read_text_content(reader)?;
                    credits.guest.push(EpgPerson {
                        name,
                        role,
                        guest: true,
                        image,
                        url,
                    });
                }
                _ => {
                    depth += 1;
                }
            },
            Ok(Event::End(_)) => {
                if depth <= 1 {
                    break;
                }
                depth -= 1;
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(XmltvError::Xml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }

    Ok(credits)
}

// ── Rating value parsing ────────────────────────────────────────

/// Parse a `<rating>` or `<star-rating>` body, extracting the `<value>` child.
fn parse_rating_value<R: BufRead>(reader: &mut Reader<R>) -> Result<String, XmltvError> {
    let mut value = String::new();
    let mut depth: u32 = 1;
    let mut buf = Vec::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) if e.name().as_ref() == b"value" => {
                value = read_text_content(reader)?;
            }
            Ok(Event::Start(_)) => {
                depth += 1;
            }
            Ok(Event::End(_)) => {
                if depth <= 1 {
                    break;
                }
                depth -= 1;
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(XmltvError::Xml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }

    Ok(value)
}

// ── Video parsing ───────────────────────────────────────────────

/// Parse a `<video>` body with children `<present>`, `<colour>`, `<aspect>`, `<quality>`.
fn parse_video<R: BufRead>(reader: &mut Reader<R>) -> Result<EpgVideo, XmltvError> {
    let mut video = EpgVideo::default();
    let mut depth: u32 = 1;
    let mut buf = Vec::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) => match e.name().as_ref() {
                b"present" => {
                    let text = read_text_content(reader)?;
                    video.present = Some(text.eq_ignore_ascii_case("yes"));
                }
                b"colour" => {
                    let text = read_text_content(reader)?;
                    video.colour = Some(text.eq_ignore_ascii_case("yes"));
                }
                b"aspect" => {
                    video.aspect = Some(read_text_content(reader)?);
                }
                b"quality" => {
                    video.quality = Some(read_text_content(reader)?);
                }
                _ => {
                    depth += 1;
                }
            },
            Ok(Event::End(_)) => {
                if depth <= 1 {
                    break;
                }
                depth -= 1;
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(XmltvError::Xml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }

    Ok(video)
}

// ── Audio parsing ───────────────────────────────────────────────

/// Parse an `<audio>` body with children `<present>`, `<stereo>`.
fn parse_audio<R: BufRead>(reader: &mut Reader<R>) -> Result<EpgAudio, XmltvError> {
    let mut audio = EpgAudio::default();
    let mut depth: u32 = 1;
    let mut buf = Vec::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) => match e.name().as_ref() {
                b"present" => {
                    let text = read_text_content(reader)?;
                    audio.present = Some(text.eq_ignore_ascii_case("yes"));
                }
                b"stereo" => {
                    audio.stereo = Some(read_text_content(reader)?);
                }
                _ => {
                    depth += 1;
                }
            },
            Ok(Event::End(_)) => {
                if depth <= 1 {
                    break;
                }
                depth -= 1;
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(XmltvError::Xml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }

    Ok(audio)
}

// ── Icon attribute parsing ──────────────────────────────────────

fn parse_icon_attrs(e: &BytesStart<'_>) -> EpgIcon {
    EpgIcon {
        src: get_attr(e, b"src").unwrap_or_default(),
        width: get_attr(e, b"width").and_then(|v| v.parse().ok()),
        height: get_attr(e, b"height").and_then(|v| v.parse().ok()),
    }
}

// ── Helpers ─────────────────────────────────────────────────────

/// Read text content until the closing tag of the current element.
///
/// Consumes all events until the matching `End` event, collecting text.
/// Uses its own buffer to avoid borrow conflicts with the caller.
fn read_text_content<R: BufRead>(reader: &mut Reader<R>) -> Result<String, XmltvError> {
    let mut text = String::new();
    let mut depth: u32 = 1;
    let mut buf = Vec::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Text(ref e)) => {
                if let Ok(t) = e.unescape() {
                    text.push_str(&t);
                }
            }
            Ok(Event::CData(ref e)) => {
                if let Ok(t) = std::str::from_utf8(e.as_ref()) {
                    text.push_str(t);
                }
            }
            Ok(Event::Start(_)) => {
                depth += 1;
            }
            Ok(Event::End(_)) => {
                if depth <= 1 {
                    break;
                }
                depth -= 1;
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(XmltvError::Xml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }

    Ok(text)
}

/// Extract a UTF-8 attribute value from an XML element by key.
fn get_attr(e: &BytesStart<'_>, key: &[u8]) -> Option<String> {
    for attr in e.attributes().flatten() {
        if attr.key.as_ref() == key {
            return attr.unescape_value().ok().map(std::borrow::Cow::into_owned);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    const MINIMAL_XMLTV: &str = r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv>
  <channel id="ch1">
    <display-name>Channel One</display-name>
    <icon src="https://example.com/ch1.png" width="100" height="50"/>
    <url>https://example.com/ch1</url>
  </channel>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title lang="en">Test Show</title>
    <desc lang="en">A test description.</desc>
  </programme>
</tv>"#;

    #[test]
    fn parse_minimal_xmltv() {
        let doc = parse(MINIMAL_XMLTV).unwrap();
        assert_eq!(doc.channels.len(), 1);
        assert_eq!(doc.programmes.len(), 1);

        let ch = &doc.channels[0];
        assert_eq!(ch.id, "ch1");
        assert_eq!(ch.display_name[0].value, "Channel One");
        assert_eq!(ch.icon.as_ref().unwrap().src, "https://example.com/ch1.png");
        assert_eq!(ch.icon.as_ref().unwrap().width, Some(100));
        assert_eq!(ch.url.as_deref(), Some("https://example.com/ch1"));

        let prog = &doc.programmes[0];
        assert_eq!(prog.channel, "ch1");
        assert!(prog.start.is_some());
        assert!(prog.stop.is_some());
        assert_eq!(prog.title[0].value, "Test Show");
        assert_eq!(prog.title[0].lang.as_deref(), Some("en"));
        assert_eq!(prog.desc[0].value, "A test description.");
    }

    #[test]
    fn parse_multilingual_display_names() {
        let xml = r#"<tv>
  <channel id="bbc1">
    <display-name lang="en">BBC One</display-name>
    <display-name lang="cy">BBC Un</display-name>
    <display-name lang="gd">BBC Aon</display-name>
  </channel>
</tv>"#;
        let doc = parse(xml).unwrap();
        let ch = &doc.channels[0];
        assert_eq!(ch.display_name.len(), 3);
        assert_eq!(ch.display_name[0].value, "BBC One");
        assert_eq!(ch.display_name[0].lang.as_deref(), Some("en"));
        assert_eq!(ch.display_name[1].value, "BBC Un");
        assert_eq!(ch.display_name[1].lang.as_deref(), Some("cy"));
        assert_eq!(ch.display_name[2].value, "BBC Aon");
        assert_eq!(ch.display_name[2].lang.as_deref(), Some("gd"));
    }

    #[test]
    fn parse_full_credits() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Movie</title>
    <credits>
      <director>Steven Spielberg</director>
      <director>James Cameron</director>
      <actor role="Hero">Tom Hanks</actor>
      <actor>Meryl Streep</actor>
      <writer>Aaron Sorkin</writer>
      <producer>Kathleen Kennedy</producer>
      <composer>John Williams</composer>
      <presenter>Ryan Seacrest</presenter>
      <commentator>John Madden</commentator>
      <guest>Oprah Winfrey</guest>
    </credits>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let credits = doc.programmes[0].credits.as_ref().unwrap();

        assert_eq!(credits.director.len(), 2);
        assert_eq!(credits.director[0], "Steven Spielberg");
        assert_eq!(credits.director[1], "James Cameron");

        assert_eq!(credits.actor.len(), 2);
        assert_eq!(credits.actor[0].name, "Tom Hanks");
        assert_eq!(credits.actor[0].role.as_deref(), Some("Hero"));
        assert_eq!(credits.actor[1].name, "Meryl Streep");
        assert!(credits.actor[1].role.is_none());

        assert_eq!(credits.writer[0], "Aaron Sorkin");
        assert_eq!(credits.producer[0], "Kathleen Kennedy");
        assert_eq!(credits.composer[0], "John Williams");
        assert_eq!(credits.presenter[0], "Ryan Seacrest");
        assert_eq!(credits.commentator[0], "John Madden");

        assert_eq!(credits.guest.len(), 1);
        assert_eq!(credits.guest[0].name, "Oprah Winfrey");
        assert!(credits.guest[0].guest);
    }

    #[test]
    fn parse_episode_numbers() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Series</title>
    <episode-num system="xmltv_ns">2.5.0/1</episode-num>
    <episode-num system="onscreen">S03E06</episode-num>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let prog = &doc.programmes[0];

        assert_eq!(prog.episode_num.len(), 2);
        assert_eq!(prog.episode_num[0].value, "2.5.0/1");
        assert_eq!(prog.episode_num[0].system.as_deref(), Some("xmltv_ns"));
        assert_eq!(prog.episode_num[1].value, "S03E06");
        assert_eq!(prog.episode_num[1].system.as_deref(), Some("onscreen"));
    }

    #[test]
    fn parse_ratings_and_star_ratings() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Rated Show</title>
    <rating system="MPAA">
      <value>PG-13</value>
    </rating>
    <rating system="VCHIP">
      <value>TV-14</value>
    </rating>
    <star-rating system="imdb">
      <value>8.5/10</value>
    </star-rating>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let prog = &doc.programmes[0];

        assert_eq!(prog.rating.len(), 2);
        assert_eq!(prog.rating[0].value, "PG-13");
        assert_eq!(prog.rating[0].system.as_deref(), Some("MPAA"));
        assert_eq!(prog.rating[1].value, "TV-14");
        assert_eq!(prog.rating[1].system.as_deref(), Some("VCHIP"));

        assert_eq!(prog.star_rating.len(), 1);
        assert_eq!(prog.star_rating[0].value, "8.5/10");
        assert_eq!(prog.star_rating[0].system.as_deref(), Some("imdb"));
    }

    #[test]
    fn parse_boolean_flags() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>New Show</title>
    <new/>
    <premiere/>
  </programme>
  <programme start="20250115130000 +0000" stop="20250115140000 +0000" channel="ch1">
    <title>Rerun</title>
    <previously-shown/>
    <last-chance/>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();

        let new_prog = &doc.programmes[0];
        assert!(new_prog.is_new);
        assert!(new_prog.is_premiere);
        assert!(!new_prog.is_rerun);
        assert!(!new_prog.is_last_chance);

        let rerun_prog = &doc.programmes[1];
        assert!(!rerun_prog.is_new);
        assert!(!rerun_prog.is_premiere);
        assert!(rerun_prog.is_rerun);
        assert!(rerun_prog.is_last_chance);
    }

    #[test]
    fn parse_boolean_flags_with_text_content() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <premiere>First showing</premiere>
    <last-chance>Last chance to watch</last-chance>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let prog = &doc.programmes[0];
        assert!(prog.is_premiere);
        assert!(prog.is_last_chance);
    }

    #[test]
    fn parse_images_and_icons() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <image type="poster" size="3" orient="P">https://example.com/poster.jpg</image>
    <image type="backdrop">https://example.com/backdrop.jpg</image>
    <icon src="https://example.com/thumb.png" width="200" height="300"/>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let prog = &doc.programmes[0];

        assert_eq!(prog.image.len(), 2);
        assert_eq!(prog.image[0].url, "https://example.com/poster.jpg");
        assert_eq!(prog.image[0].image_type.as_deref(), Some("poster"));
        assert_eq!(prog.image[0].size.as_deref(), Some("3"));
        assert_eq!(prog.image[0].orient.as_deref(), Some("P"));
        assert_eq!(prog.image[1].url, "https://example.com/backdrop.jpg");
        assert_eq!(prog.image[1].image_type.as_deref(), Some("backdrop"));

        let icon = prog.icon.as_ref().unwrap();
        assert_eq!(icon.src, "https://example.com/thumb.png");
        assert_eq!(icon.width, Some(200));
        assert_eq!(icon.height, Some(300));
    }

    #[test]
    fn parse_from_bufreader() {
        let cursor = std::io::Cursor::new(MINIMAL_XMLTV.as_bytes());
        let reader = std::io::BufReader::new(cursor);
        let doc = parse_reader(reader).unwrap();
        assert_eq!(doc.channels.len(), 1);
        assert_eq!(doc.programmes.len(), 1);
        assert_eq!(doc.channels[0].id, "ch1");
        assert_eq!(doc.programmes[0].title[0].value, "Test Show");
    }

    #[test]
    fn handle_malformed_xml_gracefully() {
        let bad_xml = r#"<tv>
  <channel id="ch1">
    <display-name>Test</display-name>
  </channel>
  <programme start="20250115120000 +0000" channel="ch1">
    <title>Show</title>
  </programme>
  <!-- Missing closing </tv> tag -->"#;

        let result = parse(bad_xml);
        match result {
            Ok(doc) => {
                assert_eq!(doc.channels.len(), 1);
                assert_eq!(doc.programmes.len(), 1);
            }
            Err(_) => {
                // Also acceptable — graceful error, no panic.
            }
        }
    }

    #[test]
    fn handle_truly_broken_xml() {
        let broken = "<<<not xml at all>>>";
        let result = parse(broken);
        // Must not panic.
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn parse_empty_document() {
        let xml = r#"<?xml version="1.0"?><tv></tv>"#;
        let doc = parse(xml).unwrap();
        assert!(doc.channels.is_empty());
        assert!(doc.programmes.is_empty());
    }

    #[test]
    fn extract_channel_names_works() {
        let names = extract_channel_names(MINIMAL_XMLTV).unwrap();
        assert_eq!(names.get("ch1").unwrap(), "Channel One");
    }

    #[test]
    fn parse_programme_with_subtitle_and_categories() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title lang="en">Main Title</title>
    <sub-title lang="en">The Subtitle</sub-title>
    <category lang="en">Drama</category>
    <category lang="en">Thriller</category>
    <date>2025</date>
    <length>60</length>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let prog = &doc.programmes[0];

        assert_eq!(prog.sub_title[0].value, "The Subtitle");
        assert_eq!(prog.category.len(), 2);
        assert_eq!(prog.category[0].value, "Drama");
        assert_eq!(prog.category[1].value, "Thriller");
        assert_eq!(prog.date.as_deref(), Some("2025"));
        assert_eq!(prog.length, Some(60));
    }

    #[test]
    fn parse_cdata_content() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title><![CDATA[Show <with> special & chars]]></title>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        assert_eq!(
            doc.programmes[0].title[0].value,
            "Show <with> special & chars"
        );
    }

    #[test]
    fn parse_xml_entities() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Rock &amp; Roll</title>
    <desc>A &quot;great&quot; show</desc>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        assert_eq!(doc.programmes[0].title[0].value, "Rock & Roll");
        assert_eq!(doc.programmes[0].desc[0].value, "A \"great\" show");
    }

    #[test]
    fn parse_keyword() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <keyword lang="en">Drama</keyword>
    <keyword lang="fr">Drame</keyword>
    <keyword>Thriller</keyword>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let prog = &doc.programmes[0];
        assert_eq!(prog.keyword.len(), 3);
        assert_eq!(prog.keyword[0].value, "Drama");
        assert_eq!(prog.keyword[0].lang.as_deref(), Some("en"));
        assert_eq!(prog.keyword[1].value, "Drame");
        assert_eq!(prog.keyword[1].lang.as_deref(), Some("fr"));
        assert_eq!(prog.keyword[2].value, "Thriller");
        assert!(prog.keyword[2].lang.is_none());
    }

    #[test]
    fn parse_language_element_does_not_panic() {
        // XMLTV <language> is the language the programme is in.
        // Not currently mapped to a dedicated field but must not break parsing.
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <language>English</language>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        assert_eq!(doc.programmes[0].title[0].value, "Show");
    }

    #[test]
    fn parse_orig_language() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <orig-language lang="fr">French</orig-language>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let prog = &doc.programmes[0];
        let ol = prog.orig_language.as_ref().unwrap();
        assert_eq!(ol.value, "French");
        assert_eq!(ol.lang.as_deref(), Some("fr"));
    }

    #[test]
    fn parse_video_element() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>HD Show</title>
    <video>
      <present>yes</present>
      <colour>yes</colour>
      <aspect>16:9</aspect>
      <quality>HDTV</quality>
    </video>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let video = doc.programmes[0].video.as_ref().unwrap();
        assert_eq!(video.present, Some(true));
        assert_eq!(video.colour, Some(true));
        assert_eq!(video.aspect.as_deref(), Some("16:9"));
        assert_eq!(video.quality.as_deref(), Some("HDTV"));
    }

    #[test]
    fn parse_video_partial() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <video><aspect>16:9</aspect><quality>HDTV</quality></video>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let video = doc.programmes[0].video.as_ref().unwrap();
        assert!(video.present.is_none());
        assert!(video.colour.is_none());
        assert_eq!(video.aspect.as_deref(), Some("16:9"));
        assert_eq!(video.quality.as_deref(), Some("HDTV"));
    }

    #[test]
    fn parse_audio_element() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <audio>
      <present>yes</present>
      <stereo>surround</stereo>
    </audio>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        assert_eq!(doc.programmes[0].audio.len(), 1);
        let audio = &doc.programmes[0].audio[0];
        assert_eq!(audio.present, Some(true));
        assert_eq!(audio.stereo.as_deref(), Some("surround"));
    }

    #[test]
    fn parse_audio_stereo_only() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <audio><stereo>dolby digital</stereo></audio>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let audio = &doc.programmes[0].audio[0];
        assert!(audio.present.is_none());
        assert_eq!(audio.stereo.as_deref(), Some("dolby digital"));
    }

    #[test]
    fn parse_review_element() {
        let xml = r#"<tv>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Show</title>
    <review type="text" source="NYT" reviewer="Jane Doe" lang="en">Great show</review>
    <review type="url">https://example.com/review</review>
  </programme>
</tv>"#;
        let doc = parse(xml).unwrap();
        let prog = &doc.programmes[0];
        assert_eq!(prog.review.len(), 2);

        assert_eq!(prog.review[0].value, "Great show");
        assert_eq!(prog.review[0].review_type.as_deref(), Some("text"));
        assert_eq!(prog.review[0].source.as_deref(), Some("NYT"));
        assert_eq!(prog.review[0].reviewer.as_deref(), Some("Jane Doe"));
        assert_eq!(prog.review[0].lang.as_deref(), Some("en"));

        assert_eq!(prog.review[1].value, "https://example.com/review");
        assert_eq!(prog.review[1].review_type.as_deref(), Some("url"));
        assert!(prog.review[1].source.is_none());
    }

    #[test]
    fn parse_channel_multiple_urls() {
        let xml = r#"<tv>
  <channel id="ch1">
    <display-name>Channel One</display-name>
    <url>https://example.com</url>
    <url>https://mirror.example.com</url>
  </channel>
</tv>"#;
        let doc = parse(xml).unwrap();
        let ch = &doc.channels[0];
        assert_eq!(ch.urls.len(), 2);
        assert_eq!(ch.urls[0], "https://example.com");
        assert_eq!(ch.urls[1], "https://mirror.example.com");
        // Backward compat: first URL in `url`.
        assert_eq!(ch.url.as_deref(), Some("https://example.com"));
    }

    #[test]
    fn parse_channel_multiple_icons() {
        let xml = r#"<tv>
  <channel id="ch1">
    <display-name>Channel One</display-name>
    <icon src="https://example.com/logo1.png" width="100" height="50"/>
    <icon src="https://example.com/logo2.png"/>
  </channel>
</tv>"#;
        let doc = parse(xml).unwrap();
        let ch = &doc.channels[0];
        assert_eq!(ch.icons.len(), 2);
        assert_eq!(ch.icons[0].src, "https://example.com/logo1.png");
        assert_eq!(ch.icons[0].width, Some(100));
        assert_eq!(ch.icons[1].src, "https://example.com/logo2.png");
        assert!(ch.icons[1].width.is_none());
        // Backward compat: first icon in `icon`.
        assert_eq!(
            ch.icon.as_ref().unwrap().src,
            "https://example.com/logo1.png"
        );
    }
}
