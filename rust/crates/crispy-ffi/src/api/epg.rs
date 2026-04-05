use super::{epg, from_json, into_anyhow, json_result, svc};
use anyhow::{Result, anyhow};
use crispy_core::models::{Channel, EpgEntry};
use std::collections::HashMap;

/// Load EPG entries as JSON {channel_id: [entries]}.
pub fn load_epg_entries() -> Result<String> {
    json_result(svc()?.load_epg_entries()?)
}

/// Load EPG entries for specific channels within a time window.
pub fn get_epgs_for_channels(
    channel_ids: Vec<String>,
    start_time: i64,
    end_time: i64,
) -> Result<String> {
    json_result(svc()?.get_epgs_for_channels(&channel_ids, start_time, end_time)?)
}

/// Load EPG entries filtered by source IDs. Returns JSON {channel_id: [entries]}.
///
/// Deserialises `source_ids_json` as `Vec<String>`. An empty
/// array returns ALL EPG entries (same as `load_epg_entries`).
pub fn get_epg_by_sources(source_ids_json: String) -> Result<String> {
    let ids: Vec<String> = from_json(&source_ids_json)?;
    json_result(svc()?.get_epg_by_sources(&ids)?)
}

/// Save EPG entries from JSON {channel_id: [entries]}.
pub fn save_epg_entries(json: String) -> Result<usize> {
    let entries: HashMap<String, Vec<EpgEntry>> = from_json(&json)?;
    Ok(svc()?.save_epg_entries(&entries)?)
}

/// Delete EPG entries older than N days.
pub fn evict_stale_epg(days: i64) -> Result<usize> {
    Ok(svc()?.evict_stale_epg(days)?)
}

/// Download, parse, match, and save XMLTV EPG asynchronously.
///
/// Skips if the same URL was refreshed within the 4-hour
/// cooldown window.
pub async fn sync_xmltv_epg(url: String, source_id: String, force: bool) -> Result<usize> {
    let service = svc()?;
    into_anyhow(
        crispy_core::services::epg_sync::fetch_and_save_xmltv_epg(
            &service,
            &url,
            Some(source_id),
            force,
        )
        .await,
    )
}

/// Download, parse, match, and save Xtream short EPG batches asynchronously.
///
/// Cooldown is applied to the derived XMLTV URL.
pub async fn sync_xtream_epg(
    base_url: String,
    username: String,
    password: String,
    source_id: String,
    channels_json: String,
    force: bool,
) -> Result<usize> {
    let service = svc()?;
    let channels: Vec<Channel> = from_json(&channels_json)?;
    into_anyhow(
        crispy_core::services::epg_sync::fetch_and_save_xtream_epg(
            &service,
            &base_url,
            &username,
            &password,
            Some(source_id),
            &channels,
            force,
        )
        .await,
    )
}

/// Download, parse, match, and save Stalker short EPG batches asynchronously.
///
/// Cooldown is applied to the base URL.
pub async fn sync_stalker_epg(
    base_url: String,
    _mac: String,
    source_id: String,
    channels_json: String,
    force: bool,
) -> Result<usize> {
    let service = svc()?;
    let channels: Vec<Channel> = from_json(&channels_json)?;
    into_anyhow(
        crispy_core::services::epg_sync::fetch_and_save_stalker_epg(
            &service,
            &base_url,
            Some(source_id),
            &channels,
            force,
        )
        .await,
    )
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
    let entries: Vec<EpgEntry> = from_json(&entries_json)?;
    let channels: Vec<Channel> = from_json(&channels_json)?;
    let display_names: HashMap<String, String> = from_json(&display_names_json)?;
    json_result(
        crispy_core::algorithms::epg_matching::match_epg_to_channels(
            &entries,
            &channels,
            &display_names,
        ),
    )
}

/// Build a catch-up URL for a channel + EPG entry.
/// Input: channel JSON, start/end Unix timestamps.
/// Returns the archive URL or null.
pub fn build_catchup_url(
    channel_json: String,
    start_utc: i64,
    end_utc: i64,
) -> Result<Option<String>> {
    let channel: Channel = from_json(&channel_json)?;

    let start_dt = chrono::DateTime::from_timestamp(start_utc, 0)
        .ok_or_else(|| anyhow!("Invalid start"))?
        .naive_utc();
    let end_dt = chrono::DateTime::from_timestamp(end_utc, 0)
        .ok_or_else(|| anyhow!("Invalid end"))?
        .naive_utc();

    let entry = EpgEntry {
        channel_id: channel.id.clone(),
        start_time: start_dt,
        end_time: end_dt,
        ..EpgEntry::default()
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
    let data: Vec<serde_json::Value> = from_json(&listings_json)?;
    let entries = crispy_core::parsers::xtream::parse_short_epg(&data, &channel_id);
    json_result(entries)
}

// ── EPG Mappings ───────────────────────────────────

/// Run confidence-based EPG matching.
/// Returns JSON array of EpgMatchCandidate objects.
pub fn match_epg_with_confidence(
    entries_json: String,
    channels_json: String,
    display_names_json: String,
) -> Result<String> {
    let entries: Vec<EpgEntry> = from_json(&entries_json)?;
    let channels: Vec<Channel> = from_json(&channels_json)?;
    let display_names: HashMap<String, String> = from_json(&display_names_json)?;
    let candidates = crispy_core::algorithms::epg_matching::match_epg_with_confidence(
        &entries,
        &channels,
        &display_names,
    );
    json_result(candidates)
}

/// Save an EPG mapping.
pub fn save_epg_mapping(json: String) -> Result<()> {
    let mapping: crispy_core::models::EpgMapping = from_json(&json)?;
    Ok(svc()?.save_epg_mapping(&mapping)?)
}

/// Get all EPG mappings as JSON array.
pub fn get_epg_mappings() -> Result<String> {
    json_result(svc()?.get_epg_mappings()?)
}

/// Lock an EPG mapping so it won't be overridden.
pub fn lock_epg_mapping(channel_id: String) -> Result<()> {
    Ok(svc()?.lock_epg_mapping(&channel_id)?)
}

/// Delete an EPG mapping.
pub fn delete_epg_mapping(channel_id: String) -> Result<()> {
    Ok(svc()?.delete_epg_mapping(&channel_id)?)
}

/// Get pending EPG suggestions (0.40-0.69 confidence, not locked).
pub fn get_pending_epg_suggestions() -> Result<String> {
    json_result(svc()?.get_pending_epg_suggestions()?)
}

/// Mark a channel as 24/7.
pub fn set_channel_247(channel_id: String, is_247: bool) -> Result<()> {
    Ok(svc()?.set_channel_247(&channel_id, is_247)?)
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

// ── EPG Facade (L1 hot cache + L2 SQLite + L3 network) ───

/// Get EPG for a single channel via the 3-layer facade.
///
/// Resolution: L1 moka hot cache → L2 SQLite → L3 per-channel API fetch.
/// Returns JSON array of EpgEntry.
pub async fn get_channel_epg(channel_id: String, count: usize) -> Result<String> {
    let facade = epg()?;
    let entries = facade.get_epg_for_channel(&channel_id, count).await?;
    json_result(entries)
}

/// Get EPG for multiple channels within a time window via the 3-layer facade.
///
/// Returns JSON `{channel_id: [entries]}`.
pub async fn get_channels_epg(
    channel_ids_json: String,
    start_time: i64,
    end_time: i64,
) -> Result<String> {
    let channel_ids: Vec<String> = from_json(&channel_ids_json)?;
    let facade = epg()?;
    let result = facade
        .get_epg_for_channels(&channel_ids, start_time, end_time)
        .await?;
    json_result(result)
}

/// Invalidate the L1 hot cache for a specific channel.
pub fn invalidate_epg_cache(channel_id: String) -> Result<()> {
    epg()?.invalidate_channel(&channel_id);
    Ok(())
}

/// Clear all EPG caches (L1 hot cache).
pub fn clear_epg_caches() -> Result<()> {
    epg()?.clear_all_caches();
    Ok(())
}

/// Get the number of channels in the L1 hot cache.
pub fn epg_hot_cache_size() -> Result<u64> {
    Ok(epg()?.hot_cache_size())
}
