//! CRUD / database command handlers.

use std::collections::HashMap;

use anyhow::{Context, Result, anyhow};
use serde_json::{Value, json};

use crispy_core::algorithms::permission::{can_delete_recording, can_view_recording};
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
                    svc, &url, false,
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
                    svc, &base_url, &username, &password, &channels, false,
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
                    svc, &base_url, &channels, false,
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

        // ── EPG Mappings ─────────────────────
        "saveEpgMapping" => (|| {
            let mapping: crispy_core::models::EpgMapping = serde_json::from_value(
                args.get("mapping")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing mapping"))?,
            )
            .context("Invalid EPG mapping")?;
            svc_ok!(svc, save_epg_mapping, &mapping)
        })(),
        "getEpgMappings" => svc_data!(svc, get_epg_mappings),
        "lockEpgMapping" => (|| {
            let channel_id = get_str(args, "channelId")?;
            svc_ok!(svc, lock_epg_mapping, &channel_id)
        })(),
        "deleteEpgMapping" => (|| {
            let channel_id = get_str(args, "channelId")?;
            svc_ok!(svc, delete_epg_mapping, &channel_id)
        })(),
        "getPendingEpgSuggestions" => svc_data!(svc, get_pending_epg_suggestions),
        "setChannel247" => (|| {
            let channel_id = get_str(args, "channelId")?;
            let is_247 = args
                .get("is247")
                .and_then(|v| v.as_bool())
                .ok_or_else(|| anyhow!("Missing is247"))?;
            svc_ok!(svc, set_channel_247, &channel_id, is_247)
        })(),

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
        // SECURITY: loadRecordings enforces per-profile visibility.
        // Callers must supply profileId + role; recordings not owned by the
        // profile are filtered out for "view_only" roles.
        "loadRecordings" => (|| {
            let profile_id = get_str(args, "profileId")?;
            let role = get_str(args, "role")?;
            let all: Vec<Recording> = svc.load_recordings().map_err(|e| anyhow!("{e}"))?;
            let visible: Vec<&Recording> = all
                .iter()
                .filter(|rec| {
                    let owner = rec.owner_profile_id.as_deref().unwrap_or("");
                    can_view_recording(&role, owner, &profile_id)
                })
                .collect();
            let data = serde_json::to_value(&visible).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
        })(),
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
        // SECURITY: deleteRecording enforces ownership. Callers must supply
        // profileId + role; deletion is rejected unless can_delete_recording passes.
        "deleteRecording" => (|| {
            let id = get_str(args, "id")?;
            let profile_id = get_str(args, "profileId")?;
            let role = get_str(args, "role")?;
            // Fetch the recording to read its owner before deleting.
            let all: Vec<Recording> = svc.load_recordings().map_err(|e| anyhow!("{e}"))?;
            let rec = all
                .iter()
                .find(|r| r.id == id)
                .ok_or_else(|| anyhow!("Recording not found: {id}"))?;
            let owner = rec.owner_profile_id.as_deref().unwrap_or("");
            if !can_delete_recording(&role, owner, &profile_id) {
                return Err(anyhow!(
                    "Permission denied: role '{role}' cannot delete recording '{id}'"
                ));
            }
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

        // ── Bookmarks ──────────────────────────────
        "loadBookmarks" => (|| {
            let content_id = get_str(args, "contentId")?;
            svc_data!(svc, load_bookmarks, &content_id)
        })(),
        "saveBookmark" => (|| {
            let json_str = get_str(args, "json")?;
            let bm: Bookmark = serde_json::from_str(&json_str).context("Invalid bookmark JSON")?;
            svc.save_bookmark(&bm).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteBookmark" => (|| {
            let id = get_str(args, "id")?;
            svc_ok!(svc, delete_bookmark, &id)
        })(),
        "clearBookmarks" => (|| {
            let content_id = get_str(args, "contentId")?;
            svc_ok!(svc, clear_bookmarks, &content_id)
        })(),

        // ── Stream Health ─────────────────────────
        "recordStreamStall" => (|| {
            let url_hash = get_str(args, "urlHash")?;
            svc_ok!(svc, record_stream_stall, &url_hash)
        })(),
        "recordBufferSample" => (|| {
            let url_hash = get_str(args, "urlHash")?;
            let value = args
                .get("value")
                .and_then(|v| v.as_f64())
                .ok_or_else(|| anyhow!("Missing f64 arg: value"))?;
            svc_ok!(svc, record_buffer_sample, &url_hash, value)
        })(),
        "recordTtff" => (|| {
            let url_hash = get_str(args, "urlHash")?;
            let ttff_ms = get_i64(args, "ttffMs")?;
            svc_ok!(svc, record_ttff, &url_hash, ttff_ms)
        })(),
        "getStreamHealthScore" => (|| {
            let url_hash = get_str(args, "urlHash")?;
            let score = svc_call!(svc, get_stream_health_score, &url_hash)?;
            Ok(json!({"data": score}))
        })(),
        "pruneStreamHealth" => (|| {
            let max = get_i64(args, "maxEntries")?;
            let deleted = svc_call!(svc, prune_stream_health, max)?;
            Ok(json!({"ok": true, "count": deleted}))
        })(),

        // ── Logo Resolver ──────────────────────────
        "resolveChannelLogo" => (|| {
            let name = get_str(args, "name")?;
            let url = svc_call!(svc, resolve_logo, &name)?;
            Ok(json!({"data": url}))
        })(),
        "resolveLogosBatch" => (|| {
            let names = get_str_vec(args, "names")?;
            let results = svc_call!(svc, resolve_logos_batch, &names)?;
            Ok(json!({"data": results}))
        })(),
        "isLogoIndexStale" => (|| {
            let stale = svc_call!(svc, is_logo_index_stale)?;
            Ok(json!({"data": stale}))
        })(),
        "refreshLogoIndex" => (|| {
            let index = tokio::runtime::Handle::current()
                .block_on(crispy_core::services::logo_resolver::fetch_logo_index())
                .map_err(|e| anyhow!("{e}"))?;
            svc.save_logo_index(&index).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        "decodeBlurHash" => (|| {
            let hash = get_str(args, "hash")?;
            let width = args.get("width").and_then(|v| v.as_u64()).unwrap_or(16) as u32;
            let height = args.get("height").and_then(|v| v.as_u64()).unwrap_or(16) as u32;
            let bmp =
                crispy_core::services::logo_resolver::decode_blurhash_to_bmp(&hash, width, height)
                    .map_err(|e| anyhow!("{e}"))?;
            // Return base64-encoded BMP since JSON can't carry raw bytes.
            use base64::Engine;
            let b64 = base64::engine::general_purpose::STANDARD.encode(&bmp);
            Ok(json!({"data": b64}))
        })(),

        // ── Smart Groups ──────────────────────────
        "createSmartGroup" => (|| {
            let name = get_str(args, "name")?;
            let id = svc.create_smart_group(&name).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": id}))
        })(),
        "deleteSmartGroup" => (|| {
            let group_id = get_str(args, "groupId")?;
            svc_ok!(svc, delete_smart_group, &group_id)
        })(),
        "renameSmartGroup" => (|| {
            let group_id = get_str(args, "groupId")?;
            let name = get_str(args, "name")?;
            svc.rename_smart_group(&group_id, &name)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "addSmartGroupMember" => (|| {
            let group_id = get_str(args, "groupId")?;
            let channel_id = get_str(args, "channelId")?;
            let source_id = get_str(args, "sourceId")?;
            let priority = args.get("priority").and_then(|v| v.as_i64()).unwrap_or(0) as i32;
            svc.add_smart_group_member(&group_id, &channel_id, &source_id, priority)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "removeSmartGroupMember" => (|| {
            let group_id = get_str(args, "groupId")?;
            let channel_id = get_str(args, "channelId")?;
            svc.remove_smart_group_member(&group_id, &channel_id)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "reorderSmartGroupMembers" => (|| {
            let group_id = get_str(args, "groupId")?;
            let ordered_json = get_str(args, "orderedChannelIdsJson")?;
            svc.reorder_smart_group_members(&group_id, &ordered_json)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "getSmartGroups" => svc_data!(svc, get_smart_groups_json),
        "getSmartGroupForChannel" => (|| {
            let channel_id = get_str(args, "channelId")?;
            let result = svc
                .get_smart_group_for_channel(&channel_id)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": result}))
        })(),
        "getSmartGroupAlternatives" => (|| {
            let channel_id = get_str(args, "channelId")?;
            let json = svc
                .get_smart_group_alternatives(&channel_id)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": json}))
        })(),
        "detectSmartGroupCandidates" => svc_data!(svc, detect_smart_group_candidates),

        _ => return None,
    };
    Some(r)
}
