//! Parser command handler tests.

use serde_json::json;

use super::{make_svc, send};

// ── Parser Commands ───────────────────────────────

#[test]
fn parse_m3u() {
    let svc = make_svc();
    let m3u = "#EXTM3U\n\
               #EXTINF:-1,Test Channel\n\
               http://example.com/stream";
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseM3u",
            "id": "r1",
            "args": {"content": m3u},
        }),
    );
    // M3uParseResult is an object with "channels" array.
    assert!(resp["data"].is_object());
    assert!(resp["data"]["channels"].is_array());
}

#[test]
fn parse_epg() {
    let svc = make_svc();
    let xml = r#"<?xml version="1.0"?>
<tv>
  <programme start="20240101100000 +0000"
             stop="20240101110000 +0000"
             channel="ch1">
    <title>News</title>
  </programme>
</tv>"#;
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseEpg",
            "id": "r1",
            "args": {"content": xml},
        }),
    );
    // parse_epg returns Vec<EpgEntry>.
    assert!(resp["data"].is_array());
    assert!(!resp["data"].as_array().unwrap().is_empty());
}

#[test]
fn extract_epg_channel_names() {
    let svc = make_svc();
    let xml = r#"<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Channel One</display-name>
  </channel>
</tv>"#;
    let resp = send(
        &svc,
        &json!({
            "cmd": "extractEpgChannelNames",
            "id": "r1",
            "args": {"content": xml},
        }),
    );
    assert!(resp["data"].is_object());
}

#[test]
fn parse_m3u_missing_content() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseM3u",
            "id": "r1",
            "args": {},
        }),
    );
    assert!(resp["error"].is_string());
}

#[test]
fn parse_vtt_thumbnails() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseVttThumbnails",
            "id": "r1",
            "args": {
                "content": "WEBVTT\n\n",
                "baseUrl": "http://example.com",
            },
        }),
    );
    // May return null if no valid cues.
    assert!(resp["data"].is_null() || resp["data"].is_object());
}

#[test]
fn parse_stalker_epg() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseStalkerEpg",
            "id": "r1",
            "args": {
                "json": "[]",
                "channelId": "ch1",
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn parse_stalker_categories() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseStalkerCategories",
            "id": "r1",
            "args": {"json": "[]"},
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn parse_xtream_categories() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseXtreamCategories",
            "id": "r1",
            "args": {"json": "[]"},
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn parse_s3_list_objects() {
    let svc = make_svc();
    let xml = r#"<?xml version="1.0"?>
<ListBucketResult>
  <Contents>
    <Key>file1.mp4</Key>
    <Size>1024</Size>
  </Contents>
</ListBucketResult>"#;
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseS3ListObjects",
            "id": "r1",
            "args": {"xml": xml},
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn build_stalker_stream_url() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "buildStalkerStreamUrl",
            "id": "r1",
            "args": {
                "cmd": "http://xyz/cmd",
                "baseUrl": "http://portal.com",
            },
        }),
    );
    assert!(resp["data"].is_string());
}

#[test]
fn parse_stalker_create_link() {
    let svc = make_svc();
    let resp = send(
        &svc,
        &json!({
            "cmd": "parseStalkerCreateLink",
            "id": "r1",
            "args": {
                "json": r#"{"js":{"cmd":"http://x/y"}}"#,
                "baseUrl": "http://portal.com",
            },
        }),
    );
    // Returns Some(url) or None depending on parse.
    assert!(resp["data"].is_string() || resp["data"].is_null());
}
