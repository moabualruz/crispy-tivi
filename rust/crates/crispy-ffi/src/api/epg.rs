use super::svc;
use anyhow::{Context, Result, anyhow};
use crispy_core::models::{Channel, EpgEntry};
use std::collections::HashMap;

/// Load EPG entries as JSON {channel_id: [entries]}.
pub fn load_epg_entries() -> Result<String> {
    let epg = svc()?.load_epg_entries()?;
    Ok(serde_json::to_string(&epg)?)
}

/// Load EPG entries for specific channels within a time window.
pub fn get_epgs_for_channels(
    channel_ids: Vec<String>,
    start_time: i64,
    end_time: i64,
) -> Result<String> {
    let epg = svc()?.get_epgs_for_channels(&channel_ids, start_time, end_time)?;
    Ok(serde_json::to_string(&epg)?)
}

/// Load EPG entries filtered by source IDs. Returns JSON {channel_id: [entries]}.
///
/// Deserialises `source_ids_json` as `Vec<String>`. An empty
/// array returns ALL EPG entries (same as `load_epg_entries`).
pub fn get_epg_by_sources(source_ids_json: String) -> Result<String> {
    let ids: Vec<String> =
        serde_json::from_str(&source_ids_json).context("Invalid source_ids JSON")?;
    let epg = svc()?.get_epg_by_sources(&ids)?;
    Ok(serde_json::to_string(&epg)?)
}

/// Save EPG entries from JSON {channel_id: [entries]}.
pub fn save_epg_entries(json: String) -> Result<usize> {
    let entries: HashMap<String, Vec<EpgEntry>> =
        serde_json::from_str(&json).context("Invalid EPG JSON")?;
    Ok(svc()?.save_epg_entries(&entries)?)
}

/// Delete EPG entries older than N days.
pub fn evict_stale_epg(days: i64) -> Result<usize> {
    Ok(svc()?.evict_stale_epg(days)?)
}

/// Download, parse, match, and save XMLTV EPG asynchronously.
pub async fn sync_xmltv_epg(url: String) -> Result<usize> {
    let service = svc()?;
    crispy_core::services::epg_sync::fetch_and_save_xmltv_epg(&service, &url)
        .await
        .map_err(|e| anyhow!("{e}"))
}

/// Download, parse, match, and save Xtream short EPG batches asynchronously.
pub async fn sync_xtream_epg(
    base_url: String,
    username: String,
    password: String,
    channels_json: String,
) -> Result<usize> {
    let service = svc()?;
    let channels: Vec<Channel> =
        serde_json::from_str(&channels_json).context("Invalid channel JSON")?;
    crispy_core::services::epg_sync::fetch_and_save_xtream_epg(
        &service, &base_url, &username, &password, &channels,
    )
    .await
    .map_err(|e| anyhow!("{e}"))
}

/// Download, parse, match, and save Stalker short EPG batches asynchronously.
pub async fn sync_stalker_epg(base_url: String, channels_json: String) -> Result<usize> {
    let service = svc()?;
    let channels: Vec<Channel> =
        serde_json::from_str(&channels_json).context("Invalid channel JSON")?;
    crispy_core::services::epg_sync::fetch_and_save_stalker_epg(&service, &base_url, &channels)
        .await
        .map_err(|e| anyhow!("{e}"))
}

/// Delete all EPG entries.
pub fn clear_epg_entries() -> Result<()> {
    Ok(svc()?.clear_epg_entries()?)
}

/// Match EPG entries to channels using 6 strategies.
/// Returns JSON `{"entries":{...},"stats":{...}}`
pub fn match_epg_to_channels(
    entries_json: String,
    channels_json: String,
    display_names_json: String,
) -> Result<String> {
    let entries: Vec<EpgEntry> =
        serde_json::from_str(&entries_json).context("Invalid entries JSON")?;
    let channels: Vec<Channel> =
        serde_json::from_str(&channels_json).context("Invalid channels JSON")?;
    let display_names: HashMap<String, String> =
        serde_json::from_str(&display_names_json).context("Invalid display names JSON")?;
    let result = crispy_core::algorithms::epg_matching::match_epg_to_channels(
        &entries,
        &channels,
        &display_names,
    );
    Ok(serde_json::to_string(&result)?)
}

/// Build a catch-up URL for a channel + EPG entry.
/// Input: channel JSON, start/end Unix timestamps.
/// Returns the archive URL or null.
pub fn build_catchup_url(
    channel_json: String,
    start_utc: i64,
    end_utc: i64,
) -> Result<Option<String>> {
    let channel: Channel = serde_json::from_str(&channel_json).context("Invalid channel JSON")?;

    let start_dt = chrono::DateTime::from_timestamp(start_utc, 0)
        .ok_or_else(|| anyhow!("Invalid start"))?
        .naive_utc();
    let end_dt = chrono::DateTime::from_timestamp(end_utc, 0)
        .ok_or_else(|| anyhow!("Invalid end"))?
        .naive_utc();

    let entry = EpgEntry {
        channel_id: channel.id.clone(),
        title: String::new(),
        start_time: start_dt,
        end_time: end_dt,
        description: None,
        category: None,
        icon_url: None,
        source_id: None,
    };

    // Try M3U catchup (flussonic, shift, template).
    if let Some(info) = crispy_core::algorithms::catchup::build_m3u_catchup(&channel, &entry) {
        return Ok(Some(info.archive_url));
    }

    // Try Xtream (extract creds from stream URL).
    let parts: Vec<&str> = channel.stream_url.split('/').collect();
    if parts.len() >= 6 {
        let base = format!("{}//{}", parts[0], parts[2]);
        let user = parts[3];
        let pass = parts[4];
        if let Some(info) = crispy_core::algorithms::catchup::build_xtream_catchup(
            &channel, &entry, &base, user, pass,
        ) {
            return Ok(Some(info.archive_url));
        }
    }

    // Try Stalker as fallback.
    if let Some(info) =
        crispy_core::algorithms::catchup::build_stalker_catchup(&channel, &entry, "")
    {
        return Ok(Some(info.archive_url));
    }

    Ok(None)
}

/// Parse Xtream short EPG listings.
/// Returns JSON array of EpgEntry objects.
pub fn parse_xtream_short_epg(listings_json: String, channel_id: String) -> Result<String> {
    let data: Vec<serde_json::Value> =
        serde_json::from_str(&listings_json).context("Invalid Xtream EPG JSON")?;
    let entries = crispy_core::parsers::xtream::parse_short_epg(&data, &channel_id);
    Ok(serde_json::to_string(&entries)?)
}

/// Merges new EPG entries into existing entries,
/// deduplicating by `startTime`.
///
/// Both inputs are JSON objects:
/// `{ "channelId": [ { "startTime": epochMs, ... } ] }`
///
/// Returns merged JSON object.
pub fn merge_epg_window(existing_json: String, new_json: String) -> String {
    crispy_core::algorithms::epg_matching::merge_epg_window(&existing_json, &new_json)
}

/// Filter EPG entries for upcoming programs on
/// favorite channels.
pub fn filter_upcoming_programs(
    epg_map_json: String,
    favorites_json: String,
    now_ms: i64,
    window_minutes: u32,
    limit: usize,
) -> String {
    crispy_core::algorithms::epg_matching::filter_upcoming_programs(
        &epg_map_json,
        &favorites_json,
        now_ms,
        window_minutes,
        limit,
    )
}
