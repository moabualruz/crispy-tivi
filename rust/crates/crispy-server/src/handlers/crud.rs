//! CRUD / database command handlers.

use std::collections::HashMap;

use anyhow::{Context, Result, anyhow};
use serde_json::{Value, json};

use crispy_core::models::*;
use crispy_core::services::CrispyService;

use super::{get_i64, get_str, get_str_opt, get_str_vec, svc_call, svc_data, svc_ok, ts_to_dt};

/// Handle CRUD commands. Returns `Some(result)` if the
/// command matched, `None` otherwise.
pub(super) fn handle(svc: &CrispyService, cmd: &str, args: &Value) -> Option<Result<Value>> {
    let r = match cmd {
        // ── Channels ────────────────────────────
        "loadChannels" => svc_data!(svc, load_channels),
        "saveChannels" => (|| {
            let channels: Vec<Channel> = serde_json::from_value(
                args.get("channels")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing channels"))?,
            )
            .context("Invalid channels")?;
            let count = svc.save_channels(&channels).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),
        "getChannelsByIds" => (|| {
            let ids = get_str_vec(args, "ids")?;
            svc_data!(svc, get_channels_by_ids, &ids)
        })(),
        "deleteRemovedChannels" => (|| {
            let source_id = get_str(args, "sourceId")?;
            let keep_ids = get_str_vec(args, "keepIds")?;
            let count = svc
                .delete_removed_channels(&source_id, &keep_ids)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),

        // ── Channel Favorites ───────────────────
        "getFavorites" => (|| {
            let pid = get_str(args, "profileId")?;
            svc_data!(svc, get_favorites, &pid)
        })(),
        "addFavorite" => (|| {
            let pid = get_str(args, "profileId")?;
            let cid = get_str(args, "channelId")?;
            svc_ok!(svc, add_favorite, &pid, &cid)
        })(),
        "removeFavorite" => (|| {
            let pid = get_str(args, "profileId")?;
            let cid = get_str(args, "channelId")?;
            svc_ok!(svc, remove_favorite, &pid, &cid)
        })(),

        // ── VOD Items ──────────────────────────
        "loadVodItems" => svc_data!(svc, load_vod_items),
        "saveVodItems" => (|| {
            let items: Vec<VodItem> = serde_json::from_value(
                args.get("items")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing items"))?,
            )
            .context("Invalid VOD items")?;
            let count = svc.save_vod_items(&items).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),
        "deleteRemovedVodItems" => (|| {
            let source_id = get_str(args, "sourceId")?;
            let keep_ids = get_str_vec(args, "keepIds")?;
            let count = svc
                .delete_removed_vod_items(&source_id, &keep_ids)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),
        "findVodAlternatives" => (|| {
            let name = get_str(args, "name")?;
            let year = get_i64(args, "year")? as i32;
            let year_opt = if year > 0 { Some(year) } else { None };
            let exclude_id = get_str(args, "excludeId")?;
            let limit = get_i64(args, "limit")? as usize;
            let items = svc
                .find_vod_alternatives(&name, year_opt, &exclude_id, limit)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": items}))
        })(),

        // ── VOD Favorites ──────────────────────
        "getVodFavorites" => (|| {
            let pid = get_str(args, "profileId")?;
            svc_data!(svc, get_vod_favorites, &pid)
        })(),
        "addVodFavorite" => (|| {
            let pid = get_str(args, "profileId")?;
            let vid = get_str(args, "vodItemId")?;
            svc_ok!(svc, add_vod_favorite, &pid, &vid)
        })(),
        "removeVodFavorite" => (|| {
            let pid = get_str(args, "profileId")?;
            let vid = get_str(args, "vodItemId")?;
            svc_ok!(svc, remove_vod_favorite, &pid, &vid)
        })(),

        // ── Watchlist ──────────────────────────
        "getWatchlistItems" => (|| {
            let pid = get_str(args, "profileId")?;
            svc_data!(svc, get_watchlist_items, &pid)
        })(),
        "addWatchlistItem" => (|| {
            let pid = get_str(args, "profileId")?;
            let vid = get_str(args, "vodItemId")?;
            svc_ok!(svc, add_watchlist_item, &pid, &vid)
        })(),
        "removeWatchlistItem" => (|| {
            let pid = get_str(args, "profileId")?;
            let vid = get_str(args, "vodItemId")?;
            svc_ok!(svc, remove_watchlist_item, &pid, &vid)
        })(),

        // ── Categories ─────────────────────────
        "loadCategories" => svc_data!(svc, load_categories),
        "saveCategories" => (|| {
            let cats: HashMap<String, Vec<String>> = serde_json::from_value(
                args.get("categories")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing categories"))?,
            )
            .context("Invalid categories")?;
            svc.save_categories(&cats).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Favorite Categories ────────────────
        "getFavoriteCategories" => (|| {
            let pid = get_str(args, "profileId")?;
            let ct = get_str(args, "categoryType")?;
            svc_data!(svc, get_favorite_categories, &pid, &ct)
        })(),
        "addFavoriteCategory" => (|| {
            let pid = get_str(args, "profileId")?;
            let ct = get_str(args, "categoryType")?;
            let cn = get_str(args, "categoryName")?;
            svc_ok!(svc, add_favorite_category, &pid, &ct, &cn)
        })(),
        "removeFavoriteCategory" => (|| {
            let pid = get_str(args, "profileId")?;
            let ct = get_str(args, "categoryType")?;
            let cn = get_str(args, "categoryName")?;
            svc_ok!(svc, remove_favorite_category, &pid, &ct, &cn)
        })(),

        // ── Profiles ───────────────────────────
        "loadProfiles" => svc_data!(svc, load_profiles),
        "saveProfile" => (|| {
            let profile: UserProfile = serde_json::from_value(
                args.get("profile")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing profile"))?,
            )
            .context("Invalid profile")?;
            svc_ok!(svc, save_profile, &profile)
        })(),
        "deleteProfile" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_profile, &id)
        })(),

        // ── Profile Source Access ───────────────
        "getSourceAccess" => (|| {
            let pid = get_str(args, "profileId")?;
            svc_data!(svc, get_source_access, &pid)
        })(),
        "grantSourceAccess" => (|| {
            let pid = get_str(args, "profileId")?;
            let sid = get_str(args, "sourceId")?;
            svc_ok!(svc, grant_source_access, &pid, &sid)
        })(),
        "revokeSourceAccess" => (|| {
            let pid = get_str(args, "profileId")?;
            let sid = get_str(args, "sourceId")?;
            svc_ok!(svc, revoke_source_access, &pid, &sid)
        })(),
        "setSourceAccess" => (|| {
            let pid = get_str(args, "profileId")?;
            let sids = get_str_vec(args, "sourceIds")?;
            svc_ok!(svc, set_source_access, &pid, &sids)
        })(),

        // ── Channel Order ──────────────────────
        "saveChannelOrder" => (|| {
            let pid = get_str(args, "profileId")?;
            let gn = get_str(args, "groupName")?;
            let cids = get_str_vec(args, "channelIds")?;
            svc_ok!(svc, save_channel_order, &pid, &gn, &cids)
        })(),
        "loadChannelOrder" => (|| {
            let pid = get_str(args, "profileId")?;
            let gn = get_str(args, "groupName")?;
            let order = svc
                .load_channel_order(&pid, &gn)
                .map_err(|e| anyhow!("{e}"))?;
            match order {
                Some(map) => Ok(json!({"data": map})),
                None => Ok(json!({"data": null})),
            }
        })(),
        "resetChannelOrder" => (|| {
            let pid = get_str(args, "profileId")?;
            let gn = get_str(args, "groupName")?;
            svc_ok!(svc, reset_channel_order, &pid, &gn)
        })(),

        // ── EPG ────────────────────────────────
        "syncXmltvEpg" => (|| {
            let url = get_str(args, "url")?;
            // Already inside spawn_blocking — drive the async EPG fetch
            // with the current runtime handle directly (no block_in_place).
            let count = tokio::runtime::Handle::current()
                .block_on(crispy_core::services::epg_sync::fetch_and_save_xmltv_epg(
                    svc, &url,
                ))
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),
        "syncXtreamEpg" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let channels_json = get_str(args, "channelsJson")?;
            let channels: Vec<crispy_core::models::Channel> =
                serde_json::from_str(&channels_json).context("Invalid channels JSON")?;

            let count = tokio::runtime::Handle::current()
                .block_on(crispy_core::services::epg_sync::fetch_and_save_xtream_epg(
                    svc, &base_url, &username, &password, &channels,
                ))
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),
        "syncStalkerEpg" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let channels_json = get_str(args, "channelsJson")?;
            let channels: Vec<crispy_core::models::Channel> =
                serde_json::from_str(&channels_json).context("Invalid channels JSON")?;

            let count = tokio::runtime::Handle::current()
                .block_on(crispy_core::services::epg_sync::fetch_and_save_stalker_epg(
                    svc, &base_url, &channels,
                ))
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),
        "loadEpgEntries" => svc_data!(svc, load_epg_entries),
        "getEpgsForChannels" => (|| {
            let channel_ids = get_str_vec(args, "channelIds")?;
            let start_time_ms = get_i64(args, "startTimeMs")?;
            let end_time_ms = get_i64(args, "endTimeMs")?;

            let start_s = start_time_ms / 1000;
            let end_s = end_time_ms / 1000;

            let data = svc
                .get_epgs_for_channels(&channel_ids, start_s, end_s)
                .map_err(|e| anyhow!("{e}"))?;

            Ok(json!({"data": data}))
        })(),
        "saveEpgEntries" => (|| {
            let entries: HashMap<String, Vec<EpgEntry>> = serde_json::from_value(
                args.get("entries")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing entries"))?,
            )
            .context("Invalid EPG entries")?;
            let count = svc.save_epg_entries(&entries).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),
        "evictStaleEpg" => (|| {
            let days = get_i64(args, "days")?;
            let count = svc.evict_stale_epg(days).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true, "count": count}))
        })(),
        "clearEpgEntries" => svc_ok!(svc, clear_epg_entries),

        // ── Watch History ──────────────────────
        "loadWatchHistory" => svc_data!(svc, load_watch_history),
        "saveWatchHistory" => (|| {
            let entry: WatchHistory = serde_json::from_value(
                args.get("entry")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing entry"))?,
            )
            .context("Invalid watch history")?;
            svc_ok!(svc, save_watch_history, &entry)
        })(),
        "deleteWatchHistory" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_watch_history, &id)
        })(),

        // ── Settings ───────────────────────────
        "getSetting" => (|| {
            let key = get_str(args, "key")?;
            let val = svc_call!(svc, get_setting, &key)?;
            match val {
                Some(v) => Ok(json!({"data": v})),
                None => Ok(json!({"data": null})),
            }
        })(),
        "setSetting" => (|| {
            let key = get_str(args, "key")?;
            let val = get_str(args, "value")?;
            svc_ok!(svc, set_setting, &key, &val)
        })(),
        "removeSetting" => (|| {
            let key = get_str(args, "key")?;
            svc_ok!(svc, remove_setting, &key)
        })(),

        // ── Sync Meta ──────────────────────────
        "getLastSyncTime" => (|| {
            let sid = get_str(args, "sourceId")?;
            let time = svc.get_last_sync_time(&sid).map_err(|e| anyhow!("{e}"))?;
            match time {
                Some(dt) => {
                    let ts = dt.and_utc().timestamp();
                    Ok(json!({"data": ts}))
                }
                None => Ok(json!({"data": null})),
            }
        })(),
        "setLastSyncTime" => (|| {
            let sid = get_str(args, "sourceId")?;
            let ts = get_i64(args, "timestamp")?;
            let dt = ts_to_dt(ts)?;
            svc.set_last_sync_time(&sid, dt)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Recordings ─────────────────────────
        "loadRecordings" => svc_data!(svc, load_recordings),
        "saveRecording" => (|| {
            let rec: Recording = serde_json::from_value(
                args.get("recording")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing recording"))?,
            )
            .context("Invalid recording")?;
            svc_ok!(svc, save_recording, &rec)
        })(),
        "updateRecording" => (|| {
            let rec: Recording = serde_json::from_value(
                args.get("recording")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing recording"))?,
            )
            .context("Invalid recording")?;
            svc_ok!(svc, save_recording, &rec)
        })(),
        "deleteRecording" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_recording, &id)
        })(),

        // ── Storage Backends ───────────────────
        "loadStorageBackends" => svc_data!(svc, load_storage_backends),
        "saveStorageBackend" => (|| {
            let backend: StorageBackend = serde_json::from_value(
                args.get("backend")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing backend"))?,
            )
            .context("Invalid storage backend")?;
            svc_ok!(svc, save_storage_backend, &backend)
        })(),
        "deleteStorageBackend" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_storage_backend, &id)
        })(),

        // ── Transfer Tasks ─────────────────────
        "loadTransferTasks" => svc_data!(svc, load_transfer_tasks),
        "saveTransferTask" => (|| {
            let task: TransferTask = serde_json::from_value(
                args.get("task")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing task"))?,
            )
            .context("Invalid transfer task")?;
            svc_ok!(svc, save_transfer_task, &task)
        })(),
        "updateTransferTask" => (|| {
            let task: TransferTask = serde_json::from_value(
                args.get("task")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing task"))?,
            )
            .context("Invalid transfer task")?;
            svc_ok!(svc, update_transfer_task, &task)
        })(),
        "deleteTransferTask" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_transfer_task, &id)
        })(),

        // ── Saved Layouts ──────────────────────
        "loadSavedLayouts" => svc_data!(svc, load_saved_layouts),
        "saveSavedLayout" => (|| {
            let layout: SavedLayout = serde_json::from_value(
                args.get("layout")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing layout"))?,
            )
            .context("Invalid layout")?;
            svc_ok!(svc, save_saved_layout, &layout)
        })(),
        "deleteSavedLayout" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_saved_layout, &id)
        })(),
        "getSavedLayoutById" => (|| {
            let id = get_str(args, "id")?;
            let layout = svc
                .get_saved_layout_by_id(&id)
                .map_err(|e| anyhow!("{e}"))?;
            let data = serde_json::to_value(&layout).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
        })(),

        // ── Search History ────────────────────
        "loadSearchHistory" => svc_data!(svc, load_search_history),
        "saveSearchEntry" => (|| {
            let entry: SearchHistory = serde_json::from_value(
                args.get("entry")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing entry"))?,
            )
            .context("Invalid search entry")?;
            svc_ok!(svc, save_search_entry, &entry)
        })(),
        "deleteSearchEntry" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_search_entry, &id)
        })(),
        "clearSearchHistory" => svc_ok!(svc, clear_search_history),

        // ── Reminders ─────────────────────────
        "loadReminders" => svc_data!(svc, load_reminders),
        "saveReminder" => (|| {
            let reminder: Reminder = serde_json::from_value(
                args.get("reminder")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing reminder"))?,
            )
            .context("Invalid reminder")?;
            svc_ok!(svc, save_reminder, &reminder)
        })(),
        "deleteReminder" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_reminder, &id)
        })(),
        "clearFiredReminders" => svc_ok!(svc, clear_fired_reminders),
        "markReminderFired" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, mark_reminder_fired, &id)
        })(),

        // ── Source Sync ──────────────────────────
        "verifyXtreamCredentials" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let accept_invalid_certs = args
                .get("acceptInvalidCerts")
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            let ok = tokio::runtime::Handle::current()
                .block_on(
                    crispy_core::services::xtream_sync::verify_xtream_credentials(
                        &base_url,
                        &username,
                        &password,
                        accept_invalid_certs,
                    ),
                )
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": ok}))
        })(),
        "syncXtreamSource" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let username = get_str(args, "username")?;
            let password = get_str(args, "password")?;
            let source_id = get_str(args, "sourceId")?;
            let accept_invalid_certs = args
                .get("acceptInvalidCerts")
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            let report = tokio::runtime::Handle::current()
                .block_on(crispy_core::services::xtream_sync::sync_xtream_source(
                    svc,
                    &base_url,
                    &username,
                    &password,
                    &source_id,
                    accept_invalid_certs,
                ))
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": report}))
        })(),
        "syncM3uSource" => (|| {
            let url = get_str(args, "url")?;
            let source_id = get_str(args, "sourceId")?;
            let accept_invalid_certs = args
                .get("acceptInvalidCerts")
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            let report = tokio::runtime::Handle::current()
                .block_on(crispy_core::services::m3u_sync::sync_m3u_source(
                    svc,
                    &url,
                    &source_id,
                    accept_invalid_certs,
                ))
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": report}))
        })(),
        "verifyStalkerPortal" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let mac_address = get_str(args, "macAddress")?;
            let accept_invalid_certs = args
                .get("acceptInvalidCerts")
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            let ok = tokio::runtime::Handle::current()
                .block_on(crispy_core::services::stalker_sync::verify_stalker_portal(
                    &base_url,
                    &mac_address,
                    accept_invalid_certs,
                ))
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": ok}))
        })(),
        "syncStalkerSource" => (|| {
            let base_url = get_str(args, "baseUrl")?;
            let mac_address = get_str(args, "macAddress")?;
            let source_id = get_str(args, "sourceId")?;
            let accept_invalid_certs = args
                .get("acceptInvalidCerts")
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            let report = tokio::runtime::Handle::current()
                .block_on(crispy_core::services::stalker_sync::sync_stalker_source(
                    svc,
                    &base_url,
                    &mac_address,
                    &source_id,
                    accept_invalid_certs,
                ))
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": report}))
        })(),

        // ── Source-Filtered Queries ────────────
        "getChannelsBySources" => (|| {
            let ids = get_str_vec(args, "sourceIds")?;
            svc_data!(svc, get_channels_by_sources, &ids)
        })(),
        "getVodBySources" => (|| {
            let ids = get_str_vec(args, "sourceIds")?;
            svc_data!(svc, get_vod_by_sources, &ids)
        })(),
        "getEpgBySources" => (|| {
            let ids = get_str_vec(args, "sourceIds")?;
            svc_data!(svc, get_epg_by_sources, &ids)
        })(),
        "getCategoriesBySources" => (|| {
            let ids = get_str_vec(args, "sourceIds")?;
            svc_data!(svc, get_categories_by_sources, &ids)
        })(),
        "getSourceStats" => svc_data!(svc, get_source_stats),

        // ── Bulk ───────────────────────────────
        "clearAll" => svc_ok!(svc, clear_all),

        // ── Phase 8: Service methods ────────
        "updateVodFavorite" => (|| {
            let item_id = get_str(args, "itemId")?;
            let is_fav = args
                .get("isFavorite")
                .and_then(|v| v.as_bool())
                .ok_or_else(|| anyhow!("Missing bool: isFavorite"))?;
            svc_ok!(svc, update_vod_favorite, &item_id, is_fav)
        })(),
        "getProfilesForSource" => (|| {
            let sid = get_str(args, "sourceId")?;
            svc_data!(svc, get_profiles_for_source, &sid)
        })(),
        "deleteSearchByQuery" => (|| {
            let query = get_str(args, "query")?;
            let count = svc
                .delete_search_by_query(&query)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({
                "ok": true,
                "count": count,
            }))
        })(),
        "clearAllWatchHistory" => (|| {
            let count = svc.clear_all_watch_history().map_err(|e| anyhow!("{e}"))?;
            Ok(json!({
                "ok": true,
                "count": count,
            }))
        })(),

        // ── Backup ──────────────────────────
        "exportBackup" => (|| {
            let json_str = crispy_core::backup::export_backup(svc).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": json_str}))
        })(),
        "importBackup" => (|| {
            let json_str = get_str(args, "json")?;
            let summary =
                crispy_core::backup::import_backup(svc, &json_str).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": summary}))
        })(),

        // ── Sources ──────────────────────────
        "getSources" => svc_data!(svc, get_sources),
        "getSource" => (|| {
            let id = get_str(args, "id")?;
            svc_data!(svc, get_source, &id)
        })(),
        "saveSource" => (|| {
            let json_str = serde_json::to_string(args)?;
            let source: crispy_core::models::Source =
                serde_json::from_str(&json_str).context("Invalid source JSON")?;
            svc_ok!(svc, save_source, &source)
        })(),
        "deleteSource" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_source, &id)
        })(),
        "reorderSources" => (|| {
            let ids = get_str_vec(args, "sourceIds")?;
            svc_ok!(svc, reorder_sources, &ids)
        })(),
        "updateSourceSyncStatus" => (|| {
            let id = get_str(args, "id")?;
            let status = get_str(args, "status")?;
            let error = get_str_opt(args, "error")?;
            let sync_time = args
                .get("syncTime")
                .and_then(|v| v.as_i64())
                .and_then(|ts| chrono::DateTime::from_timestamp(ts, 0))
                .map(|dt| dt.naive_utc());
            svc.update_source_sync_status(&id, &status, error.as_deref(), sync_time)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        _ => return None,
    };
    Some(r)
}
