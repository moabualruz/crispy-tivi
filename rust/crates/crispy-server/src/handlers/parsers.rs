//! Parser command handlers.

use anyhow::{Context, Result, anyhow};
use serde_json::{Value, json};

use crispy_core::services::CrispyService;

use super::{get_str, get_str_opt};

/// Handle parser commands. Returns `Some(result)` if the
/// command matched, `None` otherwise.
pub(super) fn handle(_svc: &CrispyService, cmd: &str, args: &Value) -> Option<Result<Value>> {
    let r = match cmd {
        // ── M3U / EPG ──────────────────────────
        "parseM3u" => (|| {
            let content = get_str(args, "content")?;
            let result = crispy_core::parsers::m3u::parse_m3u(&content);
            Ok(json!({"data": result}))
        })(),
        "parseEpg" => (|| {
            let content = get_str(args, "content")?;
            let entries = crispy_core::parsers::epg::parse_epg(&content);
            Ok(json!({"data": entries}))
        })(),
        "extractEpgChannelNames" => (|| {
            let content = get_str(args, "content")?;
            let names = crispy_core::parsers::epg::extract_channel_names(&content);
            Ok(json!({"data": names}))
        })(),

        // ── VOD Parsers ────────────────────────
        "parseVodStreams" => (|| {
            let json_str = get_str(args, "json")?;
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let source_id = get_str_opt(args, "sourceId")?;
            let data: Vec<serde_json::Value> =
                serde_json::from_str::<Vec<serde_json::Value>>(&json_str)
                    .map_err(|e| anyhow::anyhow!("Invalid VOD JSON: {}", e))?;
            let items = crispy_core::parsers::vod::parse_vod_streams(
                &data,
                &base_url,
                &username,
                &password,
                source_id.as_deref(),
            );
            Ok(json!({"data": items}))
        })(),
        "parseSeries" => (|| {
            let json_str = get_str(args, "json")?;
            let source_id = get_str_opt(args, "sourceId")?;
            let data: Vec<serde_json::Value> =
                serde_json::from_str(&json_str).context("Invalid series JSON")?;
            let items = crispy_core::parsers::vod::parse_series(&data, source_id.as_deref());
            Ok(json!({"data": items}))
        })(),
        "parseEpisodes" => (|| {
            let json_str = get_str(args, "json")?;
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let series_id = get_str(args, "seriesId")?;
            let data: serde_json::Value =
                serde_json::from_str(&json_str).context("Invalid episodes JSON")?;
            let items = crispy_core::parsers::vod::parse_episodes(
                &data, &base_url, &username, &password, &series_id,
            );
            Ok(json!({"data": items}))
        })(),
        "parseM3uVod" => (|| {
            let json_str = get_str(args, "json")?;
            let source_id = get_str_opt(args, "sourceId")?;
            let channels: Vec<serde_json::Value> =
                serde_json::from_str(&json_str).context("Invalid M3U VOD JSON")?;
            let items = crispy_core::parsers::vod::parse_m3u_vod(&channels, source_id.as_deref());
            Ok(json!({"data": items}))
        })(),
        "parseVttThumbnails" => (|| {
            let content = get_str(args, "content")?;
            let base_url = get_str(args, "baseUrl")?;
            let sprite = crispy_core::parsers::vtt::parse_vtt(&content, &base_url);
            match sprite {
                Some(s) => Ok(json!({"data": s})),
                None => Ok(json!({"data": null})),
            }
        })(),

        // ── Stalker Parsers ──────────────────
        "parseStalkerEpg" => (|| {
            let json_str = get_str(args, "json")?;
            let channel_id = get_str(args, "channelId")?;
            let entries = crispy_core::parsers::stalker::parse_stalker_epg(&json_str, &channel_id);
            let s = serde_json::to_string(&entries)?;
            Ok(json!({"data": s}))
        })(),
        "parseStalkerVodItems" => (|| {
            let json_str = get_str(args, "json")?;
            let base_url = get_str(args, "baseUrl")?;
            let vod_type = get_str_opt(args, "vodType")?.unwrap_or_else(|| "movie".to_string());
            let data: Vec<serde_json::Value> =
                serde_json::from_str(&json_str).context("Invalid Stalker VOD JSON")?;
            let items =
                crispy_core::parsers::stalker::parse_stalker_vod_items(&data, &base_url, &vod_type);
            let s = serde_json::to_string(&items)?;
            Ok(json!({"data": s}))
        })(),
        "parseStalkerChannels" => (|| {
            let json_str = get_str(args, "json")?;
            let result = crispy_core::parsers::stalker::parse_stalker_channels_result(&json_str);
            let s = serde_json::to_string(&result)?;
            Ok(json!({"data": s}))
        })(),
        "parseStalkerLiveStreams" => (|| {
            let json_str = get_str(args, "json")?;
            let source_id = get_str(args, "sourceId")?;
            let base_url = get_str(args, "baseUrl")?;
            let data: Vec<serde_json::Value> =
                serde_json::from_str(&json_str).context("Invalid Stalker JSON")?;
            let channels = crispy_core::parsers::stalker::parse_stalker_live_streams(
                &data, &source_id, &base_url,
            );
            let s = serde_json::to_string(&channels)?;
            Ok(json!({"data": s}))
        })(),
        "buildStalkerStreamUrl" => (|| {
            let cmd = get_str(args, "cmd")?;
            let base_url = get_str(args, "baseUrl")?;
            let url = crispy_core::parsers::stalker::build_stalker_stream_url(&cmd, &base_url);
            Ok(json!({"data": url}))
        })(),
        "parseStalkerCreateLink" => (|| {
            let json_str = get_str(args, "json")?;
            let base_url = get_str(args, "baseUrl")?;
            let url =
                crispy_core::parsers::stalker::parse_stalker_create_link(&json_str, &base_url);
            Ok(json!({"data": url}))
        })(),
        "parseStalkerCategories" => (|| {
            let json_str = get_str(args, "json")?;
            let cats = crispy_core::parsers::stalker::parse_stalker_categories(&json_str);
            let s = serde_json::to_string(&cats)?;
            Ok(json!({"data": s}))
        })(),
        "parseStalkerVodResult" => (|| {
            let json_str = get_str(args, "json")?;
            let result = crispy_core::parsers::stalker::parse_stalker_vod_result(&json_str);
            let s = serde_json::to_string(&result)?;
            Ok(json!({"data": s}))
        })(),

        // ── Xtream Parsers ───────────────────
        "parseXtreamShortEpg" => (|| {
            let json_str = get_str(args, "listingsJson")?;
            let channel_id = get_str(args, "channelId")?;
            let data: Vec<serde_json::Value> =
                serde_json::from_str(&json_str).context("Invalid Xtream EPG JSON")?;
            let entries = crispy_core::parsers::xtream::parse_short_epg(&data, &channel_id);
            let s = serde_json::to_string(&entries)?;
            Ok(json!({"data": s}))
        })(),
        "parseXtreamLiveStreams" => (|| {
            let json_str = get_str(args, "json")?;
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let data: Vec<serde_json::Value> =
                serde_json::from_str(&json_str).context("Invalid Xtream JSON")?;
            let channels = crispy_core::parsers::xtream::parse_xtream_live_streams(
                &data, &base_url, &username, &password,
            );
            let s = serde_json::to_string(&channels)?;
            Ok(json!({"data": s}))
        })(),
        "parseXtreamCategories" => (|| {
            let json_str = get_str(args, "json")?;
            let data: Vec<serde_json::Value> =
                serde_json::from_str(&json_str).context("Invalid Xtream categories")?;
            let names = crispy_core::parsers::xtream::parse_xtream_categories(&data);
            let s = serde_json::to_string(&names)?;
            Ok(json!({"data": s}))
        })(),

        // ── S3 Parser ──────────────────────────
        "parseS3ListObjects" => (|| {
            let xml = get_str(args, "xml")?;
            let objects = crispy_core::parsers::s3::parse_s3_list_objects(&xml);
            let s = serde_json::to_string(&objects)?;
            Ok(json!({"data": s}))
        })(),

        // ── Recommendation Parsers ─────────────
        "parseRecommendationSections" => (|| {
            let json_str = get_str(args, "sectionsJson")?;
            let sections: Vec<crispy_core::algorithms::recommendations::RecommendationSection> =
                serde_json::from_str(&json_str).context("Invalid sections JSON")?;
            let typed =
                crispy_core::algorithms::recommendations::parse_recommendation_sections(&sections)
                    .map_err(|e| anyhow!("{e}"))?;
            let s = serde_json::to_string(&typed)?;
            Ok(json!({"data": s}))
        })(),
        "deserializeRecommendationSections" => (|| {
            let json_str = get_str(args, "sectionsJson")?;
            let sections: Vec<crispy_core::algorithms::recommendations::RecommendationSection> =
                serde_json::from_str(&json_str).context("Invalid sections JSON")?;
            let full =
                crispy_core::algorithms::recommendations::deserialize_full_sections(&sections)
                    .map_err(|e| anyhow!("{e}"))?;
            let s = serde_json::to_string(&full)?;
            Ok(json!({"data": s}))
        })(),

        _ => return None,
    };
    Some(r)
}
