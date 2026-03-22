//! XMLTV writer — serializes `XmltvDocument` to valid XMLTV XML.

use crispy_iptv_types::epg::{
    EpgAudio, EpgChannel, EpgIcon, EpgProgramme, EpgRating, EpgReview, EpgStringWithLang, EpgVideo,
};

use crate::timestamp::format_xmltv_timestamp;
use crate::types::XmltvDocument;

/// Write an `XmltvDocument` to a valid XMLTV XML string.
///
/// Output includes XML declaration and DOCTYPE, followed by channels
/// then programmes, matching the canonical XMLTV order.
pub fn write(doc: &XmltvDocument) -> String {
    let mut out = String::with_capacity(4096);

    out.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    out.push_str("<!DOCTYPE tv SYSTEM \"xmltv.dtd\">\n");
    out.push_str("<tv>\n");

    for channel in &doc.channels {
        write_channel(&mut out, channel);
    }

    for programme in &doc.programmes {
        write_programme(&mut out, programme);
    }

    out.push_str("</tv>\n");
    out
}

fn write_channel(out: &mut String, ch: &EpgChannel) {
    out.push_str("  <channel id=\"");
    write_escaped(out, &ch.id);
    out.push_str("\">\n");

    for dn in &ch.display_name {
        write_string_with_lang(out, "display-name", dn);
    }

    // Write icons: prefer `icons` SmallVec; fall back to single `icon`.
    if !ch.icons.is_empty() {
        for icon in &ch.icons {
            write_icon(out, icon);
        }
    } else if let Some(ref icon) = ch.icon {
        write_icon(out, icon);
    }

    // Write urls: prefer `urls` SmallVec; fall back to single `url`.
    if !ch.urls.is_empty() {
        for url in &ch.urls {
            out.push_str("    <url>");
            write_escaped(out, url);
            out.push_str("</url>\n");
        }
    } else if let Some(ref url) = ch.url {
        out.push_str("    <url>");
        write_escaped(out, url);
        out.push_str("</url>\n");
    }

    out.push_str("  </channel>\n");
}

fn write_programme(out: &mut String, prog: &EpgProgramme) {
    out.push_str("  <programme");

    if let Some(start) = prog.start {
        out.push_str(" start=\"");
        out.push_str(&format_xmltv_timestamp(start));
        out.push('"');
    }
    if let Some(stop) = prog.stop {
        out.push_str(" stop=\"");
        out.push_str(&format_xmltv_timestamp(stop));
        out.push('"');
    }
    if !prog.channel.is_empty() {
        out.push_str(" channel=\"");
        write_escaped(out, &prog.channel);
        out.push('"');
    }
    out.push_str(">\n");

    for title in &prog.title {
        write_string_with_lang(out, "title", title);
    }
    for sub in &prog.sub_title {
        write_string_with_lang(out, "sub-title", sub);
    }
    for desc in &prog.desc {
        write_string_with_lang(out, "desc", desc);
    }

    if let Some(ref credits) = prog.credits {
        out.push_str("    <credits>\n");
        for d in &credits.director {
            out.push_str("      <director>");
            write_escaped(out, d);
            out.push_str("</director>\n");
        }
        for actor in &credits.actor {
            out.push_str("      <actor");
            if let Some(ref role) = actor.role {
                out.push_str(" role=\"");
                write_escaped(out, role);
                out.push('"');
            }
            if actor.guest {
                out.push_str(" guest=\"yes\"");
            }
            out.push('>');
            write_escaped(out, &actor.name);
            out.push_str("</actor>\n");
        }
        for w in &credits.writer {
            out.push_str("      <writer>");
            write_escaped(out, w);
            out.push_str("</writer>\n");
        }
        for p in &credits.producer {
            out.push_str("      <producer>");
            write_escaped(out, p);
            out.push_str("</producer>\n");
        }
        for c in &credits.composer {
            out.push_str("      <composer>");
            write_escaped(out, c);
            out.push_str("</composer>\n");
        }
        for p in &credits.presenter {
            out.push_str("      <presenter>");
            write_escaped(out, p);
            out.push_str("</presenter>\n");
        }
        for c in &credits.commentator {
            out.push_str("      <commentator>");
            write_escaped(out, c);
            out.push_str("</commentator>\n");
        }
        for g in &credits.guest {
            out.push_str("      <guest>");
            write_escaped(out, &g.name);
            out.push_str("</guest>\n");
        }
        out.push_str("    </credits>\n");
    }

    if let Some(ref date) = prog.date {
        out.push_str("    <date>");
        write_escaped(out, date);
        out.push_str("</date>\n");
    }

    if let Some(length) = prog.length {
        out.push_str("    <length>");
        out.push_str(&length.to_string());
        out.push_str("</length>\n");
    }

    for cat in &prog.category {
        write_string_with_lang(out, "category", cat);
    }

    for kw in &prog.keyword {
        write_string_with_lang(out, "keyword", kw);
    }

    if let Some(ref ol) = prog.orig_language {
        write_string_with_lang(out, "orig-language", ol);
    }

    if let Some(ref video) = prog.video {
        write_video(out, video);
    }

    for audio in &prog.audio {
        write_audio(out, audio);
    }

    for review in &prog.review {
        write_review(out, review);
    }

    for ep in &prog.episode_num {
        out.push_str("    <episode-num");
        if let Some(ref sys) = ep.system {
            out.push_str(" system=\"");
            write_escaped(out, sys);
            out.push('"');
        }
        out.push('>');
        write_escaped(out, &ep.value);
        out.push_str("</episode-num>\n");
    }

    for img in &prog.image {
        out.push_str("    <image");
        if let Some(ref t) = img.image_type {
            out.push_str(" type=\"");
            write_escaped(out, t);
            out.push('"');
        }
        if let Some(ref s) = img.size {
            out.push_str(" size=\"");
            write_escaped(out, s);
            out.push('"');
        }
        if let Some(ref o) = img.orient {
            out.push_str(" orient=\"");
            write_escaped(out, o);
            out.push('"');
        }
        out.push('>');
        write_escaped(out, &img.url);
        out.push_str("</image>\n");
    }

    if let Some(ref icon) = prog.icon {
        write_icon(out, icon);
    }

    for r in &prog.rating {
        write_rating(out, "rating", r);
    }
    for r in &prog.star_rating {
        write_rating(out, "star-rating", r);
    }

    // Boolean flags — self-closing tags.
    if prog.is_new {
        out.push_str("    <new/>\n");
    }
    if prog.is_premiere {
        out.push_str("    <premiere/>\n");
    }
    if prog.is_rerun {
        out.push_str("    <previously-shown/>\n");
    }
    if prog.is_last_chance {
        out.push_str("    <last-chance/>\n");
    }

    out.push_str("  </programme>\n");
}

fn write_string_with_lang(out: &mut String, tag: &str, swl: &EpgStringWithLang) {
    out.push_str("    <");
    out.push_str(tag);
    if let Some(ref lang) = swl.lang {
        out.push_str(" lang=\"");
        write_escaped(out, lang);
        out.push('"');
    }
    out.push('>');
    write_escaped(out, &swl.value);
    out.push_str("</");
    out.push_str(tag);
    out.push_str(">\n");
}

fn write_icon(out: &mut String, icon: &EpgIcon) {
    out.push_str("    <icon src=\"");
    write_escaped(out, &icon.src);
    out.push('"');
    if let Some(w) = icon.width {
        out.push_str(" width=\"");
        out.push_str(&w.to_string());
        out.push('"');
    }
    if let Some(h) = icon.height {
        out.push_str(" height=\"");
        out.push_str(&h.to_string());
        out.push('"');
    }
    out.push_str("/>\n");
}

fn write_rating(out: &mut String, tag: &str, rating: &EpgRating) {
    out.push_str("    <");
    out.push_str(tag);
    if let Some(ref sys) = rating.system {
        out.push_str(" system=\"");
        write_escaped(out, sys);
        out.push('"');
    }
    out.push_str(">\n      <value>");
    write_escaped(out, &rating.value);
    out.push_str("</value>\n    </");
    out.push_str(tag);
    out.push_str(">\n");
}

fn write_video(out: &mut String, video: &EpgVideo) {
    out.push_str("    <video>\n");
    if let Some(present) = video.present {
        out.push_str("      <present>");
        out.push_str(if present { "yes" } else { "no" });
        out.push_str("</present>\n");
    }
    if let Some(colour) = video.colour {
        out.push_str("      <colour>");
        out.push_str(if colour { "yes" } else { "no" });
        out.push_str("</colour>\n");
    }
    if let Some(ref aspect) = video.aspect {
        out.push_str("      <aspect>");
        write_escaped(out, aspect);
        out.push_str("</aspect>\n");
    }
    if let Some(ref quality) = video.quality {
        out.push_str("      <quality>");
        write_escaped(out, quality);
        out.push_str("</quality>\n");
    }
    out.push_str("    </video>\n");
}

fn write_audio(out: &mut String, audio: &EpgAudio) {
    out.push_str("    <audio>\n");
    if let Some(present) = audio.present {
        out.push_str("      <present>");
        out.push_str(if present { "yes" } else { "no" });
        out.push_str("</present>\n");
    }
    if let Some(ref stereo) = audio.stereo {
        out.push_str("      <stereo>");
        write_escaped(out, stereo);
        out.push_str("</stereo>\n");
    }
    out.push_str("    </audio>\n");
}

fn write_review(out: &mut String, review: &EpgReview) {
    out.push_str("    <review");
    if let Some(ref rt) = review.review_type {
        out.push_str(" type=\"");
        write_escaped(out, rt);
        out.push('"');
    }
    if let Some(ref src) = review.source {
        out.push_str(" source=\"");
        write_escaped(out, src);
        out.push('"');
    }
    if let Some(ref r) = review.reviewer {
        out.push_str(" reviewer=\"");
        write_escaped(out, r);
        out.push('"');
    }
    if let Some(ref lang) = review.lang {
        out.push_str(" lang=\"");
        write_escaped(out, lang);
        out.push('"');
    }
    out.push('>');
    write_escaped(out, &review.value);
    out.push_str("</review>\n");
}

/// Escape XML special characters in text content and attribute values.
fn write_escaped(out: &mut String, s: &str) {
    for c in s.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&apos;"),
            _ => out.push(c),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn write_empty_document() {
        let doc = XmltvDocument::default();
        let xml = write(&doc);
        assert!(xml.contains("<?xml version=\"1.0\""));
        assert!(xml.contains("<!DOCTYPE tv"));
        assert!(xml.contains("<tv>"));
        assert!(xml.contains("</tv>"));
    }

    #[test]
    fn write_parse_roundtrip() {
        let doc = XmltvDocument {
            channels: vec![EpgChannel {
                id: "ch1".into(),
                display_name: smallvec::smallvec![EpgStringWithLang::with_lang("BBC One", "en")],
                icon: Some(EpgIcon {
                    src: "https://example.com/icon.png".into(),
                    width: Some(100),
                    height: Some(50),
                }),
                url: Some("https://example.com".into()),
                ..Default::default()
            }],
            programmes: vec![EpgProgramme {
                channel: "ch1".into(),
                start: Some(1_736_942_400), // 2025-01-15 12:00:00 UTC
                stop: Some(1_736_946_000),  // 2025-01-15 13:00:00 UTC
                title: smallvec::smallvec![EpgStringWithLang::with_lang("Test Show", "en")],
                desc: smallvec::smallvec![EpgStringWithLang::new("A description")],
                is_new: true,
                ..Default::default()
            }],
        };

        let xml = write(&doc);
        let parsed = crate::parse(&xml).unwrap();

        assert_eq!(parsed.channels.len(), 1);
        assert_eq!(parsed.channels[0].id, "ch1");
        assert_eq!(parsed.channels[0].display_name[0].value, "BBC One");
        assert_eq!(
            parsed.channels[0].icon.as_ref().unwrap().src,
            "https://example.com/icon.png"
        );
        assert_eq!(
            parsed.channels[0].url.as_deref(),
            Some("https://example.com")
        );

        assert_eq!(parsed.programmes.len(), 1);
        assert_eq!(parsed.programmes[0].channel, "ch1");
        assert_eq!(parsed.programmes[0].start, Some(1_736_942_400));
        assert_eq!(parsed.programmes[0].stop, Some(1_736_946_000));
        assert_eq!(parsed.programmes[0].title[0].value, "Test Show");
        assert_eq!(parsed.programmes[0].desc[0].value, "A description");
        assert!(parsed.programmes[0].is_new);
    }

    #[test]
    fn write_escapes_special_chars() {
        let doc = XmltvDocument {
            channels: vec![],
            programmes: vec![EpgProgramme {
                channel: "ch1".into(),
                start: Some(0),
                title: smallvec::smallvec![EpgStringWithLang::new("Rock & Roll <Live>")],
                ..Default::default()
            }],
        };

        let xml = write(&doc);
        assert!(xml.contains("Rock &amp; Roll &lt;Live&gt;"));
    }

    #[test]
    fn write_ratings() {
        let doc = XmltvDocument {
            channels: vec![],
            programmes: vec![EpgProgramme {
                channel: "ch1".into(),
                start: Some(0),
                title: smallvec::smallvec![EpgStringWithLang::new("Rated")],
                rating: smallvec::smallvec![EpgRating {
                    value: "PG-13".into(),
                    system: Some("MPAA".into()),
                }],
                star_rating: smallvec::smallvec![EpgRating {
                    value: "8/10".into(),
                    system: Some("imdb".into()),
                }],
                ..Default::default()
            }],
        };

        let xml = write(&doc);
        assert!(xml.contains("<rating system=\"MPAA\">"));
        assert!(xml.contains("<value>PG-13</value>"));
        assert!(xml.contains("<star-rating system=\"imdb\">"));
        assert!(xml.contains("<value>8/10</value>"));
    }

    #[test]
    fn write_video_audio_review() {
        use crispy_iptv_types::epg::{EpgAudio, EpgReview, EpgVideo};

        let doc = XmltvDocument {
            channels: vec![],
            programmes: vec![EpgProgramme {
                channel: "ch1".into(),
                start: Some(0),
                title: smallvec::smallvec![EpgStringWithLang::new("Show")],
                video: Some(EpgVideo {
                    present: Some(true),
                    colour: Some(true),
                    aspect: Some("16:9".into()),
                    quality: Some("HDTV".into()),
                }),
                audio: smallvec::smallvec![EpgAudio {
                    present: Some(true),
                    stereo: Some("surround".into()),
                }],
                review: smallvec::smallvec![EpgReview {
                    value: "Great show".into(),
                    review_type: Some("text".into()),
                    source: Some("NYT".into()),
                    reviewer: Some("Jane".into()),
                    lang: Some("en".into()),
                }],
                keyword: smallvec::smallvec![EpgStringWithLang::with_lang("Drama", "en")],
                orig_language: Some(EpgStringWithLang::with_lang("French", "fr")),
                ..Default::default()
            }],
        };

        let xml = write(&doc);

        // Video
        assert!(xml.contains("<video>"));
        assert!(xml.contains("<aspect>16:9</aspect>"));
        assert!(xml.contains("<quality>HDTV</quality>"));
        assert!(xml.contains("<present>yes</present>"));
        assert!(xml.contains("<colour>yes</colour>"));

        // Audio
        assert!(xml.contains("<audio>"));
        assert!(xml.contains("<stereo>surround</stereo>"));

        // Review
        assert!(xml.contains("review type=\"text\""));
        assert!(xml.contains("source=\"NYT\""));
        assert!(xml.contains("reviewer=\"Jane\""));
        assert!(xml.contains("lang=\"en\""));
        assert!(xml.contains("Great show</review>"));

        // Keyword
        assert!(xml.contains("<keyword lang=\"en\">Drama</keyword>"));

        // Orig-language
        assert!(xml.contains("<orig-language lang=\"fr\">French</orig-language>"));

        // Roundtrip: parse the written output
        let parsed = crate::parse(&xml).unwrap();
        let prog = &parsed.programmes[0];
        let video = prog.video.as_ref().unwrap();
        assert_eq!(video.aspect.as_deref(), Some("16:9"));
        assert_eq!(video.quality.as_deref(), Some("HDTV"));
        assert_eq!(prog.audio[0].stereo.as_deref(), Some("surround"));
        assert_eq!(prog.review[0].value, "Great show");
        assert_eq!(prog.review[0].review_type.as_deref(), Some("text"));
        assert_eq!(prog.keyword[0].value, "Drama");
        assert_eq!(prog.orig_language.as_ref().unwrap().value, "French");
    }

    #[test]
    fn write_channel_multiple_icons_and_urls() {
        use crispy_iptv_types::epg::EpgIcon;

        let doc = XmltvDocument {
            channels: vec![EpgChannel {
                id: "ch1".into(),
                display_name: smallvec::smallvec![EpgStringWithLang::new("Channel")],
                icon: None,
                url: None,
                icons: smallvec::smallvec![
                    EpgIcon {
                        src: "https://example.com/a.png".into(),
                        width: Some(100),
                        height: None,
                    },
                    EpgIcon {
                        src: "https://example.com/b.png".into(),
                        width: None,
                        height: None,
                    },
                ],
                urls: smallvec::smallvec![
                    "https://example.com".into(),
                    "https://mirror.example.com".into(),
                ],
            }],
            programmes: vec![],
        };

        let xml = write(&doc);
        assert!(xml.contains("icon src=\"https://example.com/a.png\""));
        assert!(xml.contains("icon src=\"https://example.com/b.png\""));
        assert!(xml.contains("<url>https://example.com</url>"));
        assert!(xml.contains("<url>https://mirror.example.com</url>"));

        // Roundtrip
        let parsed = crate::parse(&xml).unwrap();
        let ch = &parsed.channels[0];
        assert_eq!(ch.icons.len(), 2);
        assert_eq!(ch.urls.len(), 2);
    }
}
