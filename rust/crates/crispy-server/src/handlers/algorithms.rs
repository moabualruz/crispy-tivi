//! Algorithm command handlers.

use std::collections::HashMap;

use anyhow::{Context, Result, anyhow};
use serde_json::{Value, json};

use crispy_core::models::*;
use crispy_core::services::{HistoryService, ServiceContext};

use super::{get_i64, get_str, get_str_opt, get_str_vec, svc_call, svc_data};

/// Handle algorithm commands. Returns `Some(result)` if the
/// command matched, `None` otherwise.
pub(super) fn handle(svc: &ServiceContext, cmd: &str, args: &Value) -> Option<Result<Value>> {
    let r = match cmd {
        // ── Normalize ──────────────────────────
        "normalizeChannelName" => (|| {
            let name = get_str(args, "name")?;
            let result = crispy_core::algorithms::normalize::normalize_name(&name);
            Ok(json!({"data": result}))
        })(),
        "normalizeStreamUrl" => (|| {
            let url = get_str(args, "url")?;
            let result = crispy_core::algorithms::normalize::normalize_url(&url);
            Ok(json!({"data": result}))
        })(),
        "tryBase64Decode" => (|| {
            let input = get_str(args, "input")?;
            let result = crispy_core::algorithms::normalize::try_base64_decode(&input);
            Ok(json!({"data": result}))
        })(),

        // ── Dedup ──────────────────────────────
        "detectDuplicateChannels" => (|| {
            let json_str = get_str(args, "json")?;
            let channels: Vec<Channel> =
                serde_json::from_str(&json_str).context("Invalid channels JSON")?;
            let groups = crispy_core::algorithms::dedup::detect_duplicates(&channels);
            Ok(json!({"data": groups}))
        })(),

        // ── EPG Matching ───────────────────────
        "matchEpgToChannels" => (|| {
            let entries_json = get_str(args, "entriesJson")?;
            let channels_json = get_str(args, "channelsJson")?;
            let names_json = get_str(args, "displayNamesJson")?;
            let entries: Vec<EpgEntry> =
                serde_json::from_str(&entries_json).context("Invalid entries JSON")?;
            let channels: Vec<Channel> =
                serde_json::from_str(&channels_json).context("Invalid channels JSON")?;
            let display_names: HashMap<String, String> =
                serde_json::from_str(&names_json).context("Invalid display names JSON")?;
            let result = crispy_core::algorithms::epg_matching::match_epg_to_channels(
                &entries,
                &channels,
                &display_names,
            );
            Ok(json!({"data": result}))
        })(),
        "matchEpgWithConfidence" => (|| {
            let entries_json = get_str(args, "entriesJson")?;
            let channels_json = get_str(args, "channelsJson")?;
            let names_json = get_str(args, "displayNamesJson")?;
            let entries: Vec<EpgEntry> =
                serde_json::from_str(&entries_json).context("Invalid entries JSON")?;
            let channels: Vec<Channel> =
                serde_json::from_str(&channels_json).context("Invalid channels JSON")?;
            let display_names: HashMap<String, String> =
                serde_json::from_str(&names_json).context("Invalid display names JSON")?;
            let candidates = crispy_core::algorithms::epg_matching::match_epg_with_confidence(
                &entries,
                &channels,
                &display_names,
            );
            Ok(json!({"data": candidates}))
        })(),

        // ── Catchup ────────────────────────────
        "buildCatchupUrl" => (|| {
            let ch_json = get_str(args, "channelJson")?;
            let start_utc = get_i64(args, "startUtc")?;
            let end_utc = get_i64(args, "endUtc")?;
            let channel: Channel =
                serde_json::from_str(&ch_json).context("Invalid channel JSON")?;

            let start_dt = chrono::DateTime::from_timestamp(start_utc, 0)
                .ok_or_else(|| anyhow!("Invalid start"))?
                .naive_utc();
            let end_dt = chrono::DateTime::from_timestamp(end_utc, 0)
                .ok_or_else(|| anyhow!("Invalid end"))?
                .naive_utc();

            let entry = EpgEntry {
                epg_channel_id: channel.id.clone(),
                start_time: start_dt,
                end_time: end_dt,
                ..EpgEntry::default()
            };

            // Try M3U catchup first.
            if let Some(info) =
                crispy_core::algorithms::catchup::build_m3u_catchup(&channel, &entry)
            {
                return Ok(json!({
                    "data": info.archive_url
                }));
            }

            // Try Xtream.
            let parts: Vec<&str> = channel.stream_url.split('/').collect();
            if parts.len() >= 6 {
                let base = format!("{}//{}", parts[0], parts[2],);
                if let Some(info) = crispy_core::algorithms::catchup::build_xtream_catchup(
                    &channel, &entry, &base, parts[3], parts[4],
                ) {
                    return Ok(json!({
                        "data": info.archive_url
                    }));
                }
            }

            // Try Stalker fallback.
            if let Some(info) =
                crispy_core::algorithms::catchup::build_stalker_catchup(&channel, &entry, "")
            {
                return Ok(json!({
                    "data": info.archive_url
                }));
            }

            Ok(json!({"data": null}))
        })(),

        // ── DVR Algorithms ──────────────────
        "expandRecurringRecordings" => (|| {
            let json_str = get_str(args, "recordingsJson")?;
            let now_ms = get_i64(args, "nowUtcMs")?;
            let recordings: Vec<Recording> =
                serde_json::from_str(&json_str).context("Invalid recordings JSON")?;
            let now = chrono::DateTime::from_timestamp(now_ms / 1000, 0)
                .ok_or_else(|| anyhow!("Invalid timestamp"))?
                .naive_utc();
            let instances =
                crispy_core::algorithms::dvr::expand_recurring_recordings(&recordings, now);
            let s = serde_json::to_string(&instances)?;
            Ok(json!({"data": s}))
        })(),
        "detectRecordingConflict" => (|| {
            let json_str = get_str(args, "recordingsJson")?;
            let exclude_id = get_str_opt(args, "excludeId")?;
            let channel_name = get_str(args, "channelName")?;
            let start_ms = get_i64(args, "startUtcMs")?;
            let end_ms = get_i64(args, "endUtcMs")?;
            let recordings: Vec<Recording> =
                serde_json::from_str(&json_str).context("Invalid recordings JSON")?;
            let start = chrono::DateTime::from_timestamp(start_ms / 1000, 0)
                .ok_or_else(|| anyhow!("Invalid start"))?
                .naive_utc();
            let end = chrono::DateTime::from_timestamp(end_ms / 1000, 0)
                .ok_or_else(|| anyhow!("Invalid end"))?
                .naive_utc();
            let conflict = crispy_core::algorithms::dvr::detect_recording_conflict(
                &recordings,
                exclude_id.as_deref(),
                &channel_name,
                start,
                end,
            );
            Ok(json!({"data": conflict}))
        })(),
        "sanitizeFilename" => (|| {
            let name = get_str(args, "name")?;
            let result = crispy_core::algorithms::dvr::sanitize_filename(&name);
            Ok(json!({"data": result}))
        })(),

        // ── S3 Crypto ───────────────────────
        "signS3Request" => (|| {
            let method = get_str(args, "method")?;
            let path = get_str(args, "path")?;
            let now_ms = get_i64(args, "nowUtcMs")?;
            let host = get_str(args, "host")?;
            let region = get_str(args, "region")?;
            let access_key = get_str(args, "accessKey")?;
            let secret_key = get_str(args, "secretKey")?;
            let extra_json = get_str_opt(args, "extraHeadersJson")?;
            let now = chrono::DateTime::from_timestamp(now_ms / 1000, 0)
                .ok_or_else(|| anyhow!("Invalid timestamp"))?
                .naive_utc();
            let extra: std::collections::HashMap<String, String> = match extra_json {
                Some(ref j) => serde_json::from_str(j).context("Invalid extra headers")?,
                None => std::collections::HashMap::new(),
            };
            let headers = crispy_core::algorithms::crypto::sign_s3_request(
                &method,
                &path,
                now,
                &host,
                &region,
                &access_key,
                &secret_key,
                &extra,
            );
            let s = serde_json::to_string(&headers)?;
            Ok(json!({"data": s}))
        })(),
        "generatePresignedUrl" => (|| {
            let endpoint = get_str(args, "endpoint")?;
            let bucket = get_str(args, "bucket")?;
            let object_key = get_str(args, "objectKey")?;
            let region = get_str(args, "region")?;
            let access_key = get_str(args, "accessKey")?;
            let secret_key = get_str(args, "secretKey")?;
            let expiry_secs = get_i64(args, "expirySecs")?;
            let now_ms = get_i64(args, "nowUtcMs")?;
            let now = chrono::DateTime::from_timestamp(now_ms / 1000, 0)
                .ok_or_else(|| anyhow!("Invalid timestamp"))?
                .naive_utc();
            let url = crispy_core::algorithms::crypto::generate_presigned_url(
                &endpoint,
                &bucket,
                &object_key,
                &region,
                &access_key,
                &secret_key,
                expiry_secs,
                now,
            );
            Ok(json!({"data": url}))
        })(),

        // ── Watch History Algorithms ────────
        "computeWatchStreak" => (|| {
            let timestamps = get_str(args, "timestampsJson")?;
            let now_ms = get_i64(args, "nowMs")?;
            let result =
                crispy_core::algorithms::watch_history::compute_watch_streak(&timestamps, now_ms);
            Ok(json!({"data": result}))
        })(),
        "computeProfileStats" => (|| {
            let history = get_str(args, "historyJson")?;
            let now_ms = get_i64(args, "nowMs")?;
            let result =
                crispy_core::algorithms::watch_history::compute_profile_stats(&history, now_ms);
            Ok(json!({"data": result}))
        })(),
        "mergeDedupSortHistory" => (|| {
            let a = get_str(args, "aJson")?;
            let b = get_str(args, "bJson")?;
            let result = crispy_core::algorithms::watch_history::merge_dedup_sort_history(&a, &b);
            Ok(json!({"data": result}))
        })(),
        "filterByCwStatus" => (|| {
            let history = get_str(args, "historyJson")?;
            let filter = get_str(args, "filter")?;
            let result =
                crispy_core::algorithms::watch_history::filter_by_cw_status(&history, &filter);
            Ok(json!({"data": result}))
        })(),
        "seriesIdsWithNewEpisodes" => (|| {
            let series = get_str(args, "seriesJson")?;
            let days = get_i64(args, "days")? as u32;
            let now_ms = get_i64(args, "nowMs")?;
            let result = crispy_core::algorithms::watch_history::series_ids_with_new_episodes(
                &series, days, now_ms,
            );
            Ok(json!({"data": result}))
        })(),
        "countInProgressEpisodes" => (|| {
            let history = get_str(args, "historyJson")?;
            let series_id = get_str(args, "seriesId")?;
            let result = crispy_core::algorithms::watch_history::count_in_progress_episodes(
                &history, &series_id,
            );
            Ok(json!({"data": result}))
        })(),
        "filterContinueWatching" => (|| {
            let json_str = get_str(args, "historyJson")?;
            let media_type = get_str_opt(args, "mediaType")?;
            let profile_id = get_str_opt(args, "profileId")?;
            let entries: Vec<WatchHistory> =
                serde_json::from_str(&json_str).context("Invalid watch history")?;
            let result = crispy_core::algorithms::watch_history::filter_continue_watching(
                &entries,
                media_type.as_deref(),
                profile_id.as_deref(),
            );
            let s = serde_json::to_string(&result)?;
            Ok(json!({"data": s}))
        })(),
        "filterCrossDevice" => (|| {
            let json_str = get_str(args, "historyJson")?;
            let device_id = get_str(args, "currentDeviceId")?;
            let cutoff_ms = get_i64(args, "cutoffUtcMs")?;
            let entries: Vec<WatchHistory> =
                serde_json::from_str(&json_str).context("Invalid watch history")?;
            let cutoff = chrono::DateTime::from_timestamp(cutoff_ms / 1000, 0)
                .ok_or_else(|| anyhow!("Invalid cutoff"))?
                .naive_utc();
            let result = crispy_core::algorithms::watch_history::filter_cross_device(
                &entries, &device_id, cutoff,
            );
            let s = serde_json::to_string(&result)?;
            Ok(json!({"data": s}))
        })(),

        // ── Categories ─────────────────────────
        "buildCategoryMap" => (|| {
            let json_str = get_str(args, "categoriesJson")?;
            let data: Vec<serde_json::Value> =
                serde_json::from_str(&json_str).context("Invalid categories JSON")?;
            let map = crispy_core::algorithms::categories::build_category_map(&data);
            let s = serde_json::to_string(&map)?;
            Ok(json!({"data": s}))
        })(),
        "sortCategoriesWithFavorites" => (|| {
            let categories = get_str(args, "categoriesJson")?;
            let favorites = get_str(args, "favoritesJson")?;
            let result = crispy_core::algorithms::categories::sort_categories_with_favorites(
                &categories,
                &favorites,
            );
            Ok(json!({"data": result}))
        })(),
        "buildTypeCategories" => (|| {
            let items = get_str(args, "itemsJson")?;
            let vod_type = get_str(args, "vodType")?;
            let result =
                crispy_core::algorithms::categories::build_type_categories(&items, &vod_type);
            Ok(json!({"data": result}))
        })(),

        // ── Recommendations ────────────────────
        "computeRecommendations" => (|| {
            let vod_json = get_str(args, "vodItemsJson")?;
            let ch_json = get_str(args, "channelsJson")?;
            let hist_json = get_str(args, "historyJson")?;
            let fav_ch = get_str_vec(args, "favoriteChannelIds")?;
            let fav_vod = get_str_vec(args, "favoriteVodIds")?;
            let max_rating = get_i64(args, "maxAllowedRating")? as i32;
            let now_ms = get_i64(args, "nowUtcMs")?;
            let vod_items: Vec<VodItem> =
                serde_json::from_str(&vod_json).context("Invalid VOD items JSON")?;
            let channels: Vec<Channel> =
                serde_json::from_str(&ch_json).context("Invalid channels JSON")?;
            let history: Vec<crispy_core::algorithms::recommendations::WatchSignal> =
                serde_json::from_str(&hist_json).context("Invalid history JSON")?;
            let result = crispy_core::algorithms::recommendations::compute_recommendations(
                &vod_items, &channels, &history, &fav_ch, &fav_vod, max_rating, now_ms,
            );
            let s = serde_json::to_string(&result)?;
            Ok(json!({"data": s}))
        })(),
        "mergeCloudBackups" => (|| {
            let local_json = get_str(args, "localJson")?;
            let cloud_json = get_str(args, "cloudJson")?;
            let device_id = get_str(args, "currentDeviceId")?;
            let local: serde_json::Value =
                serde_json::from_str(&local_json).context("Invalid local JSON")?;
            let cloud: serde_json::Value =
                serde_json::from_str(&cloud_json).context("Invalid cloud JSON")?;
            let result =
                crispy_core::algorithms::cloud_sync::merge_backups(&local, &cloud, &device_id);
            let s = serde_json::to_string(&result)?;
            Ok(json!({"data": s}))
        })(),

        // ── Pin ────────────────────────────────
        "hashPin" => (|| {
            let pin = get_str(args, "pin")?;
            let hash = crispy_core::algorithms::pin::hash_pin(&pin);
            Ok(json!({"data": hash}))
        })(),
        "verifyPin" => (|| {
            let input_pin = get_str(args, "inputPin")?;
            let stored_hash = get_str(args, "storedHash")?;
            let ok = crispy_core::algorithms::pin::verify_pin(&input_pin, &stored_hash);
            Ok(json!({"data": ok}))
        })(),
        "isHashedPin" => (|| {
            let value = get_str(args, "value")?;
            let ok = crispy_core::algorithms::pin::is_hashed_pin(&value);
            Ok(json!({"data": ok}))
        })(),

        // ── Xtream URL Builders ────────────────
        "buildXtreamActionUrl" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let action = get_str(args, "action")?;
            let params_json = get_str_opt(args, "paramsJson")?;
            let params: Vec<(String, String)> = match params_json {
                Some(ref j) if !j.is_empty() => {
                    let map: serde_json::Map<String, serde_json::Value> =
                        serde_json::from_str(j).context("Invalid params")?;
                    map.into_iter()
                        .map(|(k, v)| (k, v.as_str().unwrap_or("").to_string()))
                        .collect()
                }
                _ => Vec::new(),
            };
            let url = crispy_core::parsers::xtream::build_xtream_action_url(
                &base_url, &username, &password, &action, &params,
            );
            Ok(json!({"data": url}))
        })(),
        "buildXtreamStreamUrl" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let stream_id = get_i64(args, "streamId")?;
            let stream_type = get_str(args, "streamType")?;
            let ext = get_str(args, "extension")?;
            let url = crispy_core::parsers::xtream::build_xtream_stream_url(
                &base_url,
                &username,
                &password,
                stream_id,
                &stream_type,
                &ext,
            );
            Ok(json!({"data": url}))
        })(),
        "buildXtreamCatchupUrl" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let stream_id = get_i64(args, "streamId")?;
            let start_utc = get_i64(args, "startUtc")?;
            let dur = get_i64(args, "durationMinutes")? as i32;
            let url = crispy_core::parsers::xtream::build_xtream_catchup_url(
                &base_url, &username, &password, stream_id, start_utc, dur,
            );
            Ok(json!({"data": url}))
        })(),

        // ── Watch Progress ─────────────────────
        "calculateWatchProgress" => (|| {
            let pos = get_i64(args, "positionMs")?;
            let dur = get_i64(args, "durationMs")?;
            let result = crispy_core::algorithms::watch_progress::calculate_progress(pos, dur);
            Ok(json!({"data": result}))
        })(),
        "filterContinueWatchingPositions" => (|| {
            let json_str = get_str(args, "json")?;
            let limit = get_i64(args, "limit")? as usize;
            let result =
                crispy_core::algorithms::watch_progress::filter_continue_watching_positions(
                    &json_str, limit,
                );
            Ok(json!({"data": result}))
        })(),

        // ── Group Icon ────────────────────────────
        "matchGroupIcon" => (|| {
            let name = get_str(args, "groupName")?;
            let result = crispy_core::algorithms::group_icon::match_group_icon(&name);
            Ok(json!({"data": result}))
        })(),

        // ── Search Grouping ───────────────────────
        "groupSearchResults" => (|| {
            let results_json = get_str(args, "resultsJson")?;
            let ch_json = get_str(args, "channelsJson")?;
            let vod_json = get_str(args, "vodJson")?;
            let epg_json = get_str(args, "epgJson")?;
            let result = crispy_core::algorithms::search_grouping::group_search_results(
                &results_json,
                &ch_json,
                &vod_json,
                &epg_json,
            );
            Ok(json!({"data": result}))
        })(),

        // ── Search ─────────────────────────────
        "searchContent" => (|| {
            let query = get_str(args, "query")?;
            let ch_json = get_str(args, "channelsJson")?;
            let vod_json = get_str(args, "vodItemsJson")?;
            let epg_json = get_str(args, "epgEntriesJson")?;
            let filter_json = get_str(args, "filterJson")?;
            let channels: Vec<Channel> =
                serde_json::from_str(&ch_json).context("Invalid channels JSON")?;
            let vod_items: Vec<VodItem> =
                serde_json::from_str(&vod_json).context("Invalid VOD items JSON")?;
            let epg: std::collections::HashMap<String, Vec<EpgEntry>> =
                serde_json::from_str(&epg_json).context("Invalid EPG entries JSON")?;
            let filter: crispy_core::algorithms::search::SearchFilter =
                serde_json::from_str(&filter_json).context("Invalid filter JSON")?;
            let result = crispy_core::algorithms::search::search(
                &query, &channels, &vod_items, &epg, &filter,
            );
            let s = serde_json::to_string(&result)?;
            Ok(json!({"data": s}))
        })(),
        "enrichSearchResults" => (|| {
            let query = get_str(args, "query").unwrap_or_default();
            let results_json = get_str(args, "resultsJson")?;
            let ch_json = get_str(args, "channelsJson")?;
            let vod_json = get_str(args, "vodItemsJson")?;
            let results: crispy_core::algorithms::search::SearchResults =
                serde_json::from_str(&results_json).context("Invalid search results")?;
            let channels: Vec<Channel> =
                serde_json::from_str(&ch_json).context("Invalid channels JSON")?;
            let vod_items: Vec<VodItem> =
                serde_json::from_str(&vod_json).context("Invalid VOD items JSON")?;
            let enriched = crispy_core::algorithms::search::enrich_search_results(
                &query, &results, &channels, &vod_items,
            );
            let s = serde_json::to_string(&enriched)?;
            Ok(json!({"data": s}))
        })(),

        // ── Sorting ────────────────────────────
        "sortChannels" => (|| {
            let json_str = get_str(args, "json")?;
            let mut channels: Vec<Channel> =
                serde_json::from_str(&json_str).context("Invalid channels JSON")?;
            crispy_core::algorithms::sorting::sort_channels(&mut channels);
            let s = serde_json::to_string(&channels)?;
            Ok(json!({"data": s}))
        })(),
        "filterAndSortChannels" => (|| {
            let channels = get_str(args, "channelsJson")?;
            let params = get_str(args, "paramsJson")?;
            let result =
                crispy_core::algorithms::sorting::filter_and_sort_channels(&channels, &params);
            Ok(json!({"data": result}))
        })(),
        "sortFavorites" => (|| {
            let channels = get_str(args, "channelsJson")?;
            let sort_mode = get_str(args, "sortMode")?;
            let result = crispy_core::algorithms::sorting::sort_favorites(&channels, &sort_mode);
            Ok(json!({"data": result}))
        })(),

        // ── Categories resolution ──────────────
        "resolveChannelCategories" => (|| {
            let ch_json = get_str(args, "channelsJson")?;
            let map_json = get_str(args, "catMapJson")?;
            let channels: Vec<Channel> =
                serde_json::from_str(&ch_json).context("Invalid channels JSON")?;
            let cat_map: std::collections::HashMap<String, String> =
                serde_json::from_str(&map_json).context("Invalid cat map JSON")?;
            let resolved = crispy_core::algorithms::categories::resolve_channel_categories(
                &channels, &cat_map,
            );
            let s = serde_json::to_string(&resolved)?;
            Ok(json!({"data": s}))
        })(),
        "resolveVodCategories" => (|| {
            let items_json = get_str(args, "itemsJson")?;
            let map_json = get_str(args, "catMapJson")?;
            let items: Vec<VodItem> =
                serde_json::from_str(&items_json).context("Invalid VOD items JSON")?;
            let cat_map: std::collections::HashMap<String, String> =
                serde_json::from_str(&map_json).context("Invalid cat map JSON")?;
            let resolved =
                crispy_core::algorithms::categories::resolve_vod_categories(&items, &cat_map);
            let s = serde_json::to_string(&resolved)?;
            Ok(json!({"data": s}))
        })(),
        "extractSortedGroups" => (|| {
            let ch_json = get_str(args, "channelsJson")?;
            let channels: Vec<Channel> =
                serde_json::from_str(&ch_json).context("Invalid channels JSON")?;
            let groups = crispy_core::algorithms::categories::extract_sorted_groups(&channels);
            Ok(json!({"data": groups}))
        })(),
        "extractSortedVodCategories" => (|| {
            let items_json = get_str(args, "itemsJson")?;
            let items: Vec<VodItem> =
                serde_json::from_str(&items_json).context("Invalid VOD items JSON")?;
            let cats = crispy_core::algorithms::categories::extract_sorted_vod_categories(&items);
            Ok(json!({"data": cats}))
        })(),

        // ── Dedup helpers ──────────────────────
        "findGroupForChannel" => (|| {
            let groups_json = get_str(args, "groupsJson")?;
            let channel_id = get_str(args, "channelId")?;
            let groups: Vec<crispy_core::algorithms::dedup::DuplicateGroup> =
                serde_json::from_str(&groups_json).context("Invalid groups JSON")?;
            match crispy_core::algorithms::dedup::find_group_for_channel(&groups, &channel_id) {
                Some(g) => {
                    let s = serde_json::to_string(g)?;
                    Ok(json!({"data": s}))
                }
                None => Ok(json!({"data": null})),
            }
        })(),
        "isDuplicate" => (|| {
            let groups_json = get_str(args, "groupsJson")?;
            let channel_id = get_str(args, "channelId")?;
            let groups: Vec<crispy_core::algorithms::dedup::DuplicateGroup> =
                serde_json::from_str(&groups_json).context("Invalid groups JSON")?;
            let result = crispy_core::algorithms::dedup::is_duplicate(&groups, &channel_id);
            Ok(json!({"data": result}))
        })(),
        "getAllDuplicateIds" => (|| {
            let groups_json = get_str(args, "groupsJson")?;
            let groups: Vec<crispy_core::algorithms::dedup::DuplicateGroup> =
                serde_json::from_str(&groups_json).context("Invalid groups JSON")?;
            let ids = crispy_core::algorithms::dedup::get_all_duplicate_ids(&groups);
            Ok(json!({"data": ids}))
        })(),

        // ── Normalize helpers ──────────────────
        "validateMacAddress" => (|| {
            let mac = get_str(args, "mac")?;
            let ok = crispy_core::algorithms::normalize::validate_mac_address(&mac);
            Ok(json!({"data": ok}))
        })(),
        "macToDeviceId" => (|| {
            let mac = get_str(args, "mac")?;
            let result = crispy_core::algorithms::normalize::mac_to_device_id(&mac);
            Ok(json!({"data": result}))
        })(),
        "guessLogoDomains" => (|| {
            let name = get_str(args, "name")?;
            let domains = crispy_core::algorithms::normalize::guess_logo_domains(&name);
            Ok(json!({"data": domains}))
        })(),

        // ── Timezone ───────────────────────────
        "formatEpgTime" => (|| {
            let ts = get_i64(args, "timestampMs")?;
            let offset = args
                .get("offsetHours")
                .and_then(serde_json::Value::as_f64)
                .ok_or_else(|| anyhow!("Missing f64: offsetHours"))?;
            let result = crispy_core::algorithms::timezone::format_epg_time(ts, offset);
            Ok(json!({"data": result}))
        })(),
        "formatEpgDatetime" => (|| {
            let ts = get_i64(args, "timestampMs")?;
            let offset = args
                .get("offsetHours")
                .and_then(serde_json::Value::as_f64)
                .ok_or_else(|| anyhow!("Missing f64: offsetHours"))?;
            let result = crispy_core::algorithms::timezone::format_epg_datetime(ts, offset);
            Ok(json!({"data": result}))
        })(),
        "formatDurationMinutes" => (|| {
            let mins = get_i64(args, "minutes")? as i32;
            let result = crispy_core::algorithms::timezone::format_duration_minutes(mins);
            Ok(json!({"data": result}))
        })(),
        "durationBetweenMs" => (|| {
            let start = get_i64(args, "startMs")?;
            let end = get_i64(args, "endMs")?;
            let result = crispy_core::algorithms::timezone::duration_between_ms(start, end);
            Ok(json!({"data": result}))
        })(),

        // ── VOD Sorting ────────────────────────
        "sortVodItems" => (|| {
            let items = get_str(args, "itemsJson")?;
            let sort_by = get_str(args, "sortBy")?;
            let result = crispy_core::algorithms::vod_sorting::sort_vod_items(&items, &sort_by);
            Ok(json!({"data": result}))
        })(),
        "buildVodCategoryMap" => (|| {
            let items = get_str(args, "itemsJson")?;
            let result = crispy_core::algorithms::vod_sorting::build_vod_category_map(&items);
            Ok(json!({"data": result}))
        })(),
        "filterTopVod" => (|| {
            let items = get_str(args, "itemsJson")?;
            let limit = get_i64(args, "limit")? as usize;
            let result = crispy_core::algorithms::vod_sorting::filter_top_vod(&items, limit);
            Ok(json!({"data": result}))
        })(),
        "filterRecentlyAdded" => (|| {
            let items = get_str(args, "itemsJson")?;
            let cutoff_days = get_i64(args, "cutoffDays")? as u32;
            let now_ms = get_i64(args, "nowMs")?;
            let result = crispy_core::algorithms::vod_sorting::filter_recently_added(
                &items,
                cutoff_days,
                now_ms,
            );
            Ok(json!({"data": result}))
        })(),
        "computeEpisodeProgress" => (|| {
            let history = get_str(args, "historyJson")?;
            let series_id = get_str(args, "seriesId")?;
            let result = crispy_core::algorithms::vod_sorting::compute_episode_progress(
                &history, &series_id,
            );
            Ok(json!({"data": result}))
        })(),
        "computeEpisodeProgressFromDb" => (|| {
            let series_id = get_str(args, "seriesId")?;
            svc_data!(HistoryService(svc.clone()), compute_episode_progress_from_db, &series_id)
        })(),
        "filterVodByContentRating" => (|| {
            let items = get_str(args, "itemsJson")?;
            let max_val = get_i64(args, "maxRatingValue")? as i32;
            let result =
                crispy_core::algorithms::vod_sorting::filter_vod_by_content_rating(&items, max_val);
            Ok(json!({"data": result}))
        })(),

        // ── URL Normalize ─────────────────────
        "normalizeApiBaseUrl" => (|| {
            let url = get_str(args, "url")?;
            let result = crispy_core::algorithms::url_normalize::normalize_api_base_url(&url)
                .map_err(|e| anyhow::anyhow!("{e}"))?;
            Ok(json!({"data": result}))
        })(),

        // ── Config Merge ──────────────────────
        "deepMergeJson" => (|| {
            let base = get_str(args, "baseJson")?;
            let overrides = get_str(args, "overridesJson")?;
            let result = crispy_core::algorithms::config_merge::deep_merge_json(&base, &overrides);
            Ok(json!({"data": result}))
        })(),
        "setNestedValue" => (|| {
            let map = get_str(args, "mapJson")?;
            let path = get_str(args, "dotPath")?;
            let value = get_str(args, "valueJson")?;
            let result =
                crispy_core::algorithms::config_merge::set_nested_value(&map, &path, &value);
            Ok(json!({"data": result}))
        })(),

        // ── Permission ───────────────────────
        "canViewRecording" => (|| {
            let role = get_str(args, "role")?;
            let owner = get_str(args, "recordingOwnerId")?;
            let profile = get_str(args, "currentProfileId")?;
            let result =
                crispy_core::algorithms::permission::can_view_recording(&role, &owner, &profile);
            Ok(json!({"data": result}))
        })(),
        "canDeleteRecording" => (|| {
            let role = get_str(args, "role")?;
            let owner = get_str(args, "recordingOwnerId")?;
            let profile = get_str(args, "currentProfileId")?;
            let result =
                crispy_core::algorithms::permission::can_delete_recording(&role, &owner, &profile);
            Ok(json!({"data": result}))
        })(),

        // ── Source Filter ─────────────────────
        "filterChannelsBySource" => (|| {
            let channels = get_str(args, "channelsJson")?;
            let sources = get_str(args, "accessibleSourceIdsJson")?;
            let is_admin = args
                .get("isAdmin")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false);
            let result = crispy_core::algorithms::source_filter::filter_channels_by_source(
                &channels, &sources, is_admin,
            );
            Ok(json!({"data": result}))
        })(),

        // ── GPU Detection ────────────────────────
        "detectGpu" => (|| {
            let info = crispy_core::gpu::detect_gpu();
            let s = serde_json::to_string(&info)?;
            Ok(json!({"data": s}))
        })(),

        // ── Watch Progress Thresholds ─────────────
        "completionThreshold" => Ok(json!({
            "data": crispy_core::algorithms::watch_progress::COMPLETION_THRESHOLD
        })),
        "nextEpisodeThreshold" => Ok(json!({
            "data": crispy_core::algorithms::watch_progress::NEXT_EPISODE_THRESHOLD
        })),

        // ── EPG Upcoming ─────────────────────────
        "filterUpcomingPrograms" => (|| {
            let epg_map = get_str(args, "epgMapJson")?;
            let favorites = get_str(args, "favoritesJson")?;
            let now_ms = get_i64(args, "nowMs")?;
            let window = get_i64(args, "windowMinutes")? as u32;
            let limit = get_i64(args, "limit")? as usize;
            let result = crispy_core::algorithms::epg_matching::filter_upcoming_programs(
                &epg_map, &favorites, now_ms, window, limit,
            );
            Ok(json!({"data": result}))
        })(),

        // ── Search (advanced) ─────────────────────
        "searchChannelsByLiveProgram" => (|| {
            let epg_map = get_str(args, "epgMapJson")?;
            let query = get_str(args, "query")?;
            let now_ms = get_i64(args, "nowMs")?;
            let result = crispy_core::algorithms::search::search_channels_by_live_program(
                &epg_map, &query, now_ms,
            );
            Ok(json!({"data": result}))
        })(),
        "mergeEpgMatchedChannels" => (|| {
            let base = get_str(args, "baseJson")?;
            let all_channels = get_str(args, "allChannelsJson")?;
            let matched_ids = get_str(args, "matchedIdsJson")?;
            let overrides = get_str(args, "epgOverridesJson")?;
            let result = crispy_core::algorithms::search::merge_epg_matched_channels(
                &base,
                &all_channels,
                &matched_ids,
                &overrides,
            );
            Ok(json!({"data": result}))
        })(),

        // ── Categories (search) ───────────────────
        "buildSearchCategories" => (|| {
            let vod_cats = get_str(args, "vodCategoriesJson")?;
            let ch_groups = get_str(args, "channelGroupsJson")?;
            let result =
                crispy_core::algorithms::categories::build_search_categories(&vod_cats, &ch_groups);
            Ok(json!({"data": result}))
        })(),

        // ── DVR (advanced) ────────────────────────
        "getRecordingsToStart" => (|| {
            let recordings = get_str(args, "recordingsJson")?;
            let now_ms = get_i64(args, "nowMs")?;
            let result = crispy_core::algorithms::dvr::get_recordings_to_start(&recordings, now_ms);
            Ok(json!({"data": result}))
        })(),
        "computeStorageBreakdown" => (|| {
            let recordings = get_str(args, "recordingsJson")?;
            let now_ms = get_i64(args, "nowMs")?;
            let result =
                crispy_core::algorithms::dvr::compute_storage_breakdown(&recordings, now_ms);
            Ok(json!({"data": result}))
        })(),
        "filterRecordings" => (|| {
            let recordings = get_str(args, "recordingsJson")?;
            let query = get_str(args, "query")?;
            let result = crispy_core::algorithms::dvr::filter_recordings(&recordings, &query);
            Ok(json!({"data": result}))
        })(),
        "classifyFileType" => (|| {
            let filename = get_str(args, "filename")?;
            let result = crispy_core::algorithms::dvr::classify_file_type(&filename);
            Ok(json!({"data": result}))
        })(),
        "sortRemoteFiles" => (|| {
            let files = get_str(args, "filesJson")?;
            let order = get_str(args, "order")?;
            let result = crispy_core::algorithms::dvr::sort_remote_files(&files, &order);
            Ok(json!({"data": result}))
        })(),

        // ── PIN Lockout ───────────────────────────
        "isLockActive" => (|| {
            let locked_until = get_i64(args, "lockedUntilMs")?;
            let now = get_i64(args, "nowMs")?;
            let result = crispy_core::algorithms::pin::is_lock_active(locked_until, now);
            Ok(json!({"data": result}))
        })(),
        "lockRemainingMs" => (|| {
            let locked_until = get_i64(args, "lockedUntilMs")?;
            let now = get_i64(args, "nowMs")?;
            let result = crispy_core::algorithms::pin::lock_remaining_ms(locked_until, now);
            Ok(json!({"data": result}))
        })(),

        // ── Watch History (advanced) ──────────────
        "resolveNextEpisodes" => (|| {
            let entries = get_str(args, "entriesJson")?;
            let vod_items = get_str(args, "vodItemsJson")?;
            let threshold = args
                .get("threshold")
                .and_then(serde_json::Value::as_f64)
                .ok_or_else(|| anyhow!("Missing f64: threshold"))?;
            let result = crispy_core::algorithms::watch_history::resolve_next_episodes(
                &entries, &vod_items, threshold,
            );
            Ok(json!({"data": result}))
        })(),
        "episodeCountBySeason" => (|| {
            let episodes = get_str(args, "episodesJson")?;
            let result = crispy_core::algorithms::watch_history::episode_count_by_season(&episodes);
            Ok(json!({"data": result}))
        })(),
        "vodBadgeKind" => (|| {
            let year = args
                .get("year")
                .and_then(serde_json::Value::as_i64)
                .map(|v| v as i32);
            let added_at = args.get("addedAtMs").and_then(serde_json::Value::as_i64);
            let now_ms = get_i64(args, "nowMs")?;
            let result =
                crispy_core::algorithms::watch_history::vod_badge_kind(year, added_at, now_ms);
            Ok(json!({"data": result}))
        })(),

        // ── VOD Similarity ────────────────────────
        "similarVodItems" => (|| {
            let items = get_str(args, "itemsJson")?;
            let item_id = get_str(args, "itemId")?;
            let limit = get_i64(args, "limit")? as usize;
            let result =
                crispy_core::algorithms::vod_sorting::similar_vod_items(&items, &item_id, limit);
            Ok(json!({"data": result}))
        })(),

        // ── Stream Alternatives ──────────────────
        "rankStreamAlternatives" => (|| {
            let target_json = get_str(args, "targetJson")?;
            let all_json = get_str(args, "allChannelsJson")?;
            let health_json = get_str(args, "healthScoresJson")?;
            let target: Channel =
                serde_json::from_str(&target_json).context("Invalid target channel JSON")?;
            let all_channels: Vec<Channel> =
                serde_json::from_str(&all_json).context("Invalid channels JSON")?;
            let health_scores: HashMap<String, f64> =
                serde_json::from_str(&health_json).context("Invalid health scores JSON")?;
            let ranked = crispy_core::algorithms::stream_alternatives::rank_stream_alternatives(
                &target,
                &all_channels,
                &health_scores,
                &HashMap::new(),
                None,
            );
            let s = serde_json::to_string(&ranked)?;
            Ok(json!({"data": s}))
        })(),
        "extractCallSign" => (|| {
            let name = get_str(args, "name")?;
            let result = crispy_core::algorithms::stream_alternatives::extract_call_sign(&name);
            Ok(json!({"data": result}))
        })(),

        _ => return None,
    };
    Some(r)
}
