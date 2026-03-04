//! CRUD / database command handlers.

use std::collections::HashMap;

use anyhow::{Context, Result, anyhow};
use serde_json::{Value, json};

use crispy_core::models::*;
use crispy_core::services::CrispyService;

use super::{get_i64, get_str, get_str_vec, ts_to_dt};

/// Handle CRUD commands. Returns `Some(result)` if the
/// command matched, `None` otherwise.
pub(super) fn handle(svc: &CrispyService, cmd: &str, args: &Value) -> Option<Result<Value>> {
    let r = match cmd {
        // ── Channels ────────────────────────────
        "loadChannels" => {
            let data = svc.load_channels().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
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
            let data = svc.get_channels_by_ids(&ids).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
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
            let data = svc.get_favorites(&pid).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
        })(),
        "addFavorite" => (|| {
            let pid = get_str(args, "profileId")?;
            let cid = get_str(args, "channelId")?;
            svc.add_favorite(&pid, &cid).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "removeFavorite" => (|| {
            let pid = get_str(args, "profileId")?;
            let cid = get_str(args, "channelId")?;
            svc.remove_favorite(&pid, &cid)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── VOD Items ──────────────────────────
        "loadVodItems" => {
            let data = svc.load_vod_items().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
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

        // ── VOD Favorites ──────────────────────
        "getVodFavorites" => (|| {
            let pid = get_str(args, "profileId")?;
            let data = svc.get_vod_favorites(&pid).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
        })(),
        "addVodFavorite" => (|| {
            let pid = get_str(args, "profileId")?;
            let vid = get_str(args, "vodItemId")?;
            svc.add_vod_favorite(&pid, &vid)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "removeVodFavorite" => (|| {
            let pid = get_str(args, "profileId")?;
            let vid = get_str(args, "vodItemId")?;
            svc.remove_vod_favorite(&pid, &vid)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Watchlist ──────────────────────────
        "getWatchlistItems" => (|| {
            let pid = get_str(args, "profileId")?;
            let data = svc.get_watchlist_items(&pid).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
        })(),
        "addWatchlistItem" => (|| {
            let pid = get_str(args, "profileId")?;
            let vid = get_str(args, "vodItemId")?;
            svc.add_watchlist_item(&pid, &vid)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "removeWatchlistItem" => (|| {
            let pid = get_str(args, "profileId")?;
            let vid = get_str(args, "vodItemId")?;
            svc.remove_watchlist_item(&pid, &vid)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Categories ─────────────────────────
        "loadCategories" => {
            let data = svc.load_categories().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
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
            let data = svc
                .get_favorite_categories(&pid, &ct)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
        })(),
        "addFavoriteCategory" => (|| {
            let pid = get_str(args, "profileId")?;
            let ct = get_str(args, "categoryType")?;
            let cn = get_str(args, "categoryName")?;
            svc.add_favorite_category(&pid, &ct, &cn)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "removeFavoriteCategory" => (|| {
            let pid = get_str(args, "profileId")?;
            let ct = get_str(args, "categoryType")?;
            let cn = get_str(args, "categoryName")?;
            svc.remove_favorite_category(&pid, &ct, &cn)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Profiles ───────────────────────────
        "loadProfiles" => {
            let data = svc.load_profiles().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
        "saveProfile" => (|| {
            let profile: UserProfile = serde_json::from_value(
                args.get("profile")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing profile"))?,
            )
            .context("Invalid profile")?;
            svc.save_profile(&profile).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteProfile" => (|| {
            let id = get_str(args, "id")?;
            svc.delete_profile(&id).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Profile Source Access ───────────────
        "getSourceAccess" => (|| {
            let pid = get_str(args, "profileId")?;
            let data = svc.get_source_access(&pid).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
        })(),
        "grantSourceAccess" => (|| {
            let pid = get_str(args, "profileId")?;
            let sid = get_str(args, "sourceId")?;
            svc.grant_source_access(&pid, &sid)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "revokeSourceAccess" => (|| {
            let pid = get_str(args, "profileId")?;
            let sid = get_str(args, "sourceId")?;
            svc.revoke_source_access(&pid, &sid)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "setSourceAccess" => (|| {
            let pid = get_str(args, "profileId")?;
            let sids = get_str_vec(args, "sourceIds")?;
            svc.set_source_access(&pid, &sids)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Channel Order ──────────────────────
        "saveChannelOrder" => (|| {
            let pid = get_str(args, "profileId")?;
            let gn = get_str(args, "groupName")?;
            let cids = get_str_vec(args, "channelIds")?;
            svc.save_channel_order(&pid, &gn, &cids)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
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
            svc.reset_channel_order(&pid, &gn)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
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
        "loadEpgEntries" => {
            let data = svc.load_epg_entries().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
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
        "clearEpgEntries" => svc
            .clear_epg_entries()
            .map_err(|e| anyhow!("{e}"))
            .map(|_| json!({"ok": true})),

        // ── Watch History ──────────────────────
        "loadWatchHistory" => {
            let data = svc.load_watch_history().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
        "saveWatchHistory" => (|| {
            let entry: WatchHistory = serde_json::from_value(
                args.get("entry")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing entry"))?,
            )
            .context("Invalid watch history")?;
            svc.save_watch_history(&entry).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteWatchHistory" => (|| {
            let id = get_str(args, "id")?;
            svc.delete_watch_history(&id).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Settings ───────────────────────────
        "getSetting" => (|| {
            let key = get_str(args, "key")?;
            let val = svc.get_setting(&key).map_err(|e| anyhow!("{e}"))?;
            match val {
                Some(v) => Ok(json!({"data": v})),
                None => Ok(json!({"data": null})),
            }
        })(),
        "setSetting" => (|| {
            let key = get_str(args, "key")?;
            let val = get_str(args, "value")?;
            svc.set_setting(&key, &val).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "removeSetting" => (|| {
            let key = get_str(args, "key")?;
            svc.remove_setting(&key).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
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
        "loadRecordings" => {
            let data = svc.load_recordings().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
        "saveRecording" => (|| {
            let rec: Recording = serde_json::from_value(
                args.get("recording")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing recording"))?,
            )
            .context("Invalid recording")?;
            svc.save_recording(&rec).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "updateRecording" => (|| {
            let rec: Recording = serde_json::from_value(
                args.get("recording")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing recording"))?,
            )
            .context("Invalid recording")?;
            svc.save_recording(&rec).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteRecording" => (|| {
            let id = get_str(args, "id")?;
            svc.delete_recording(&id).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Storage Backends ───────────────────
        "loadStorageBackends" => {
            let data = svc.load_storage_backends().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
        "saveStorageBackend" => (|| {
            let backend: StorageBackend = serde_json::from_value(
                args.get("backend")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing backend"))?,
            )
            .context("Invalid storage backend")?;
            svc.save_storage_backend(&backend)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteStorageBackend" => (|| {
            let id = get_str(args, "id")?;
            svc.delete_storage_backend(&id)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Transfer Tasks ─────────────────────
        "loadTransferTasks" => {
            let data = svc.load_transfer_tasks().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
        "saveTransferTask" => (|| {
            let task: TransferTask = serde_json::from_value(
                args.get("task")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing task"))?,
            )
            .context("Invalid transfer task")?;
            svc.save_transfer_task(&task).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "updateTransferTask" => (|| {
            let task: TransferTask = serde_json::from_value(
                args.get("task")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing task"))?,
            )
            .context("Invalid transfer task")?;
            svc.update_transfer_task(&task)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteTransferTask" => (|| {
            let id = get_str(args, "id")?;
            svc.delete_transfer_task(&id).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Saved Layouts ──────────────────────
        "loadSavedLayouts" => {
            let data = svc.load_saved_layouts().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
        "saveSavedLayout" => (|| {
            let layout: SavedLayout = serde_json::from_value(
                args.get("layout")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing layout"))?,
            )
            .context("Invalid layout")?;
            svc.save_saved_layout(&layout).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteSavedLayout" => (|| {
            let id = get_str(args, "id")?;
            svc.delete_saved_layout(&id).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
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
        "loadSearchHistory" => {
            let data = svc.load_search_history().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
        "saveSearchEntry" => (|| {
            let entry: SearchHistory = serde_json::from_value(
                args.get("entry")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing entry"))?,
            )
            .context("Invalid search entry")?;
            svc.save_search_entry(&entry).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteSearchEntry" => (|| {
            let id = get_str(args, "id")?;
            svc.delete_search_entry(&id).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "clearSearchHistory" => svc
            .clear_search_history()
            .map_err(|e| anyhow!("{e}"))
            .map(|_| json!({"ok": true})),

        // ── Reminders ─────────────────────────
        "loadReminders" => {
            let data = svc.load_reminders().map_err(|e| anyhow!("{e}"));
            data.map(|d| json!({"data": d}))
        }
        "saveReminder" => (|| {
            let reminder: Reminder = serde_json::from_value(
                args.get("reminder")
                    .cloned()
                    .ok_or_else(|| anyhow!("Missing reminder"))?,
            )
            .context("Invalid reminder")?;
            svc.save_reminder(&reminder).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "deleteReminder" => (|| {
            let id = get_str(args, "id")?;
            svc.delete_reminder(&id).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "clearFiredReminders" => svc
            .clear_fired_reminders()
            .map_err(|e| anyhow!("{e}"))
            .map(|_| json!({"ok": true})),
        "markReminderFired" => (|| {
            let id = get_str(args, "id")?;
            svc.mark_reminder_fired(&id).map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),

        // ── Bulk ───────────────────────────────
        "clearAll" => svc
            .clear_all()
            .map_err(|e| anyhow!("{e}"))
            .map(|_| json!({"ok": true})),

        // ── Phase 8: Service methods ────────
        "updateVodFavorite" => (|| {
            let item_id = get_str(args, "itemId")?;
            let is_fav = args
                .get("isFavorite")
                .and_then(|v| v.as_bool())
                .ok_or_else(|| anyhow!("Missing bool: isFavorite"))?;
            svc.update_vod_favorite(&item_id, is_fav)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"ok": true}))
        })(),
        "getProfilesForSource" => (|| {
            let sid = get_str(args, "sourceId")?;
            let data = svc
                .get_profiles_for_source(&sid)
                .map_err(|e| anyhow!("{e}"))?;
            Ok(json!({"data": data}))
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

        _ => return None,
    };
    Some(r)
}
