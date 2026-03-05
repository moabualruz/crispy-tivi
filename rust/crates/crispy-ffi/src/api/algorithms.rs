use super::ms_to_naive;
use anyhow::{Context, Result, anyhow};
use crispy_core::algorithms::watch_progress::{COMPLETION_THRESHOLD, NEXT_EPISODE_THRESHOLD};
use crispy_core::models::{Channel, EpgEntry, VodItem};
use std::collections::HashMap;

// ── Normalize ────────────────────────────────────────

/// Normalize a channel name for fuzzy matching.
#[flutter_rust_bridge::frb(sync)]
pub fn normalize_channel_name(name: String) -> String {
    crispy_core::algorithms::normalize::normalize_name(&name)
}

/// Normalize a stream URL for comparison.
#[flutter_rust_bridge::frb(sync)]
pub fn normalize_stream_url(url: String) -> String {
    crispy_core::algorithms::normalize::normalize_url(&url)
}

/// Try to base64-decode a string. Returns decoded
/// string or the original if not valid base64.
#[flutter_rust_bridge::frb(sync)]
pub fn try_base64_decode(input: String) -> String {
    crispy_core::algorithms::normalize::try_base64_decode(&input)
}

/// Validate a MAC address format.
#[flutter_rust_bridge::frb(sync)]
pub fn validate_mac_address(mac: String) -> bool {
    crispy_core::algorithms::normalize::validate_mac_address(&mac)
}

/// Strip colons from a MAC address.
#[flutter_rust_bridge::frb(sync)]
pub fn mac_to_device_id(mac: String) -> String {
    crispy_core::algorithms::normalize::mac_to_device_id(&mac)
}

/// Guess search domains for channel logo lookup.
#[flutter_rust_bridge::frb(sync)]
pub fn guess_logo_domains(name: String) -> Vec<String> {
    crispy_core::algorithms::normalize::guess_logo_domains(&name)
}

/// Normalize an API base URL to scheme://host[:port].
#[flutter_rust_bridge::frb(sync)]
pub fn normalize_api_base_url(url: String) -> String {
    crispy_core::algorithms::url_normalize::normalize_api_base_url(&url).unwrap_or_else(|e| e)
}

// ── Dedup ────────────────────────────────────────────

/// Detect duplicate channels by normalized stream URL.
/// Input: JSON array of Channel objects.
/// Returns JSON array of DuplicateGroup objects.
pub fn detect_duplicate_channels(json: String) -> Result<String> {
    let channels: Vec<Channel> = serde_json::from_str(&json).context("Invalid channels JSON")?;
    let groups = crispy_core::algorithms::dedup::detect_duplicates(&channels);
    Ok(serde_json::to_string(&groups)?)
}

/// Check if a channel ID is a duplicate.
#[flutter_rust_bridge::frb(sync)]
pub fn is_duplicate(groups_json: String, channel_id: String) -> Result<bool> {
    let groups: Vec<crispy_core::algorithms::dedup::DuplicateGroup> =
        serde_json::from_str(&groups_json).context("Invalid groups JSON")?;
    Ok(crispy_core::algorithms::dedup::is_duplicate(
        &groups,
        &channel_id,
    ))
}

/// Get all duplicate IDs across all groups.
pub fn get_all_duplicate_ids(groups_json: String) -> Result<Vec<String>> {
    let groups: Vec<crispy_core::algorithms::dedup::DuplicateGroup> =
        serde_json::from_str(&groups_json).context("Invalid groups JSON")?;
    Ok(crispy_core::algorithms::dedup::get_all_duplicate_ids(
        &groups,
    ))
}

// ── Sorting ──────────────────────────────────────────

/// Filter and sort a JSON-encoded channel list.
///
/// `channels_json` — JSON array of Channel objects.
/// `params_json`   — JSON-encoded FilterSortParams.
/// Returns JSON array of Channel after filtering and
/// sorting.
pub fn filter_and_sort_channels(channels_json: String, params_json: String) -> String {
    crispy_core::algorithms::sorting::filter_and_sort_channels(&channels_json, &params_json)
}

/// Sort a JSON-encoded list of favourite channels.
///
/// `channels_json` — JSON array of Channel objects.
/// `sort_mode`     — One of `"recentlyAdded"`,
///   `"nameAsc"`, `"nameDesc"`, `"contentType"`.
#[flutter_rust_bridge::frb(sync)]
pub fn sort_favorites(channels_json: String, sort_mode: String) -> String {
    crispy_core::algorithms::sorting::sort_favorites(&channels_json, &sort_mode)
}

// ── Categories ───────────────────────────────────────

/// Sort categories with favourites first.
///
/// `categories_json` — JSON array of category name strings.
/// `favorites_json`  — JSON array of favourite category
///   name strings.
/// Returns JSON array of sorted String.
#[flutter_rust_bridge::frb(sync)]
pub fn sort_categories_with_favorites(categories_json: String, favorites_json: String) -> String {
    crispy_core::algorithms::categories::sort_categories_with_favorites(
        &categories_json,
        &favorites_json,
    )
}

/// Extract unique categories from VOD items filtered by
/// type.
///
/// `items_json` — JSON array of VodItem.
/// `vod_type`   — Type to filter by (e.g. `"movie"`,
///   `"series"`).
/// Returns JSON array of sorted String.
pub fn build_type_categories(items_json: String, vod_type: String) -> String {
    crispy_core::algorithms::categories::build_type_categories(&items_json, &vod_type)
}

/// Build a category ID-to-name map from raw JSON.
/// Returns JSON object {id: name}.
pub fn build_category_map(categories_json: String) -> Result<String> {
    let data: Vec<serde_json::Value> =
        serde_json::from_str(&categories_json).context("Invalid categories JSON")?;
    let map = crispy_core::algorithms::categories::build_category_map(&data);
    Ok(serde_json::to_string(&map)?)
}

// ── Search ───────────────────────────────────────────

/// Search channels, VOD, and EPG.
/// Returns JSON of SearchResults.
pub fn search_content(
    query: String,
    channels_json: String,
    vod_items_json: String,
    epg_entries_json: String,
    filter_json: String,
) -> Result<String> {
    let channels: Vec<Channel> =
        serde_json::from_str(&channels_json).context("Invalid channels JSON")?;
    let vod_items: Vec<VodItem> =
        serde_json::from_str(&vod_items_json).context("Invalid VOD items JSON")?;
    let epg: HashMap<String, Vec<EpgEntry>> =
        serde_json::from_str(&epg_entries_json).context("Invalid EPG entries JSON")?;
    let filter: crispy_core::algorithms::search::SearchFilter =
        serde_json::from_str(&filter_json).context("Invalid filter JSON")?;
    let result =
        crispy_core::algorithms::search::search(&query, &channels, &vod_items, &epg, &filter);
    Ok(serde_json::to_string(&result)?)
}

/// Enrich search results with channel/VOD metadata.
/// Returns JSON array of EnrichedSearchResult.
pub fn enrich_search_results(
    results_json: String,
    channels_json: String,
    vod_items_json: String,
) -> Result<String> {
    let results: crispy_core::algorithms::search::SearchResults =
        serde_json::from_str(&results_json).context("Invalid search results JSON")?;
    let channels: Vec<Channel> =
        serde_json::from_str(&channels_json).context("Invalid channels JSON")?;
    let vod_items: Vec<VodItem> =
        serde_json::from_str(&vod_items_json).context("Invalid VOD items JSON")?;
    let enriched =
        crispy_core::algorithms::search::enrich_search_results(&results, &channels, &vod_items);
    Ok(serde_json::to_string(&enriched)?)
}

// ── Recommendations ──────────────────────────────────

/// Compute recommendation sections from VOD items,
/// channels, and watch history.
/// Returns JSON array of RecommendationSection.
pub fn compute_recommendations(
    vod_items_json: String,
    channels_json: String,
    history_json: String,
    favorite_channel_ids: Vec<String>,
    favorite_vod_ids: Vec<String>,
    max_allowed_rating: i32,
    now_utc_ms: i64,
) -> Result<String> {
    let vod_items: Vec<VodItem> =
        serde_json::from_str(&vod_items_json).context("Invalid VOD items JSON")?;
    let channels: Vec<Channel> =
        serde_json::from_str(&channels_json).context("Invalid channels JSON")?;
    let history: Vec<crispy_core::algorithms::recommendations::WatchSignal> =
        serde_json::from_str(&history_json).context("Invalid history JSON")?;
    let result = crispy_core::algorithms::recommendations::compute_recommendations(
        &vod_items,
        &channels,
        &history,
        &favorite_channel_ids,
        &favorite_vod_ids,
        max_allowed_rating,
        now_utc_ms,
    );
    Ok(serde_json::to_string(&result)?)
}

/// Parse recommendation sections into typed structs.
/// Returns JSON array of TypedRecommendationSection.
pub fn parse_recommendation_sections(sections_json: String) -> Result<String> {
    let sections: Vec<crispy_core::algorithms::recommendations::RecommendationSection> =
        serde_json::from_str(&sections_json).context("Invalid recommendation sections JSON")?;
    let typed = crispy_core::algorithms::recommendations::parse_recommendation_sections(&sections)
        .map_err(|e| anyhow!("{e}"))?;
    Ok(serde_json::to_string(&typed)?)
}

/// Deserialize recommendation sections into
/// fully-merged structs with typed enums and all
/// supplementary fields (poster, category, etc.).
/// Returns JSON array of FullRecommendationSection.
pub fn deserialize_recommendation_sections(sections_json: String) -> Result<String> {
    let sections: Vec<crispy_core::algorithms::recommendations::RecommendationSection> =
        serde_json::from_str(&sections_json).context("Invalid recommendation sections JSON")?;
    let full = crispy_core::algorithms::recommendations::deserialize_full_sections(&sections)
        .map_err(|e| anyhow!("{e}"))?;
    Ok(serde_json::to_string(&full)?)
}

// ── Cloud Sync ───────────────────────────────────────

/// Merge local and cloud backup JSON objects.
/// Returns the merged JSON string.
pub fn merge_cloud_backups(
    local_json: String,
    cloud_json: String,
    current_device_id: String,
) -> Result<String> {
    let local: serde_json::Value =
        serde_json::from_str(&local_json).context("Invalid local JSON")?;
    let cloud: serde_json::Value =
        serde_json::from_str(&cloud_json).context("Invalid cloud JSON")?;
    let result =
        crispy_core::algorithms::cloud_sync::merge_backups(&local, &cloud, &current_device_id);
    Ok(serde_json::to_string(&result)?)
}

// ── PIN ──────────────────────────────────────────────

/// Hash a PIN using SHA-256.
/// Returns 64-char hex hash.
#[flutter_rust_bridge::frb(sync)]
pub fn hash_pin(pin: String) -> String {
    crispy_core::algorithms::pin::hash_pin(&pin)
}

/// Verify a PIN against a stored hash.
#[flutter_rust_bridge::frb(sync)]
pub fn verify_pin(input_pin: String, stored_hash: String) -> bool {
    crispy_core::algorithms::pin::verify_pin(&input_pin, &stored_hash)
}

/// Check if a value looks like a SHA-256 hash.
#[flutter_rust_bridge::frb(sync)]
pub fn is_hashed_pin(value: String) -> bool {
    crispy_core::algorithms::pin::is_hashed_pin(&value)
}

// ── Watch Progress Thresholds ────────────────────────

/// Completion threshold (0.95): items at or above
/// this progress ratio are considered finished.
#[flutter_rust_bridge::frb(sync)]
pub fn completion_threshold() -> f64 {
    COMPLETION_THRESHOLD
}

/// Next-episode threshold (0.90): items at or above
/// this progress ratio trigger next-episode suggestions.
#[flutter_rust_bridge::frb(sync)]
pub fn next_episode_threshold() -> f64 {
    NEXT_EPISODE_THRESHOLD
}

// ── S3 Crypto ───────────────────────────────────────

/// Sign an S3 request using AWS Signature V4.
/// Returns JSON map of headers to add.
#[allow(clippy::too_many_arguments)]
pub fn sign_s3_request(
    method: String,
    path: String,
    now_utc_ms: i64,
    host: String,
    region: String,
    access_key: String,
    secret_key: String,
    extra_headers_json: Option<String>,
) -> Result<String> {
    let now = ms_to_naive(now_utc_ms)?;
    let extra: HashMap<String, String> = match extra_headers_json {
        Some(ref j) => serde_json::from_str(j).context("Invalid extra headers JSON")?,
        None => HashMap::new(),
    };
    let result = crispy_core::algorithms::crypto::sign_s3_request(
        &method,
        &path,
        now,
        &host,
        &region,
        &access_key,
        &secret_key,
        &extra,
    );
    Ok(serde_json::to_string(&result)?)
}

/// Generate a pre-signed URL for an S3 GET request.
/// Returns the full URL string.
#[allow(clippy::too_many_arguments)]
pub fn generate_presigned_url(
    endpoint: String,
    bucket: String,
    object_key: String,
    region: String,
    access_key: String,
    secret_key: String,
    expiry_secs: i64,
    now_utc_ms: i64,
) -> Result<String> {
    let now = ms_to_naive(now_utc_ms)?;
    Ok(crispy_core::algorithms::crypto::generate_presigned_url(
        &endpoint,
        &bucket,
        &object_key,
        &region,
        &access_key,
        &secret_key,
        expiry_secs,
        now,
    ))
}

// ── Timezone ─────────────────────────────────────────

/// Format a timestamp as "HH:MM" in a timezone.
#[flutter_rust_bridge::frb(sync)]
pub fn format_epg_time(timestamp_ms: i64, offset_hours: f64) -> String {
    crispy_core::algorithms::timezone::format_epg_time(timestamp_ms, offset_hours)
}

/// Format a timestamp as "Day DD Mon HH:MM".
#[flutter_rust_bridge::frb(sync)]
pub fn format_epg_datetime(timestamp_ms: i64, offset_hours: f64) -> String {
    crispy_core::algorithms::timezone::format_epg_datetime(timestamp_ms, offset_hours)
}

/// Format duration in minutes as "Xh Ym".
#[flutter_rust_bridge::frb(sync)]
pub fn format_duration_minutes(minutes: i32) -> String {
    crispy_core::algorithms::timezone::format_duration_minutes(minutes)
}

/// Calculate duration between timestamps in minutes.
#[flutter_rust_bridge::frb(sync)]
pub fn duration_between_ms(start_ms: i64, end_ms: i64) -> i32 {
    crispy_core::algorithms::timezone::duration_between_ms(start_ms, end_ms)
}

/// Format a playback position as "HH:MM:SS" or "MM:SS".
///
/// Hours are shown when the total media length (`duration_ms`) is >= 1 hour.
/// The position values are derived from `position_ms`, clamped to zero if
/// negative. All fields are zero-padded to 2 digits.
#[flutter_rust_bridge::frb(sync)]
pub fn format_playback_duration(position_ms: i64, duration_ms: i64) -> String {
    crispy_core::algorithms::timezone::format_playback_duration(position_ms, duration_ms)
}

/// Returns the UTC offset in minutes for the given IANA timezone name
/// at the given epoch millisecond. DST-aware via chrono-tz.
///
/// Returns 0 for "system", "UTC", or unknown timezone names.
#[flutter_rust_bridge::frb(sync)]
pub fn get_timezone_offset_minutes(tz_name: String, epoch_ms: i64) -> i32 {
    crispy_core::algorithms::timezone::get_timezone_offset_minutes(&tz_name, epoch_ms)
}

/// Applies the DST-aware timezone offset to a UTC epoch_ms.
/// Returns adjusted epoch_ms for display purposes.
/// Returns epoch_ms unchanged for "system", "UTC", or unknown timezones.
#[flutter_rust_bridge::frb(sync)]
pub fn apply_timezone_offset(epoch_ms: i64, tz_name: String) -> i64 {
    crispy_core::algorithms::timezone::apply_timezone_offset(epoch_ms, &tz_name)
}

/// Formats epoch_ms as "HH:MM:SS" in the given IANA timezone. DST-aware.
/// Falls back to UTC for "system", "UTC", or unknown timezones.
#[flutter_rust_bridge::frb(sync)]
pub fn format_time_with_seconds(epoch_ms: i64, tz_name: String) -> String {
    crispy_core::algorithms::timezone::format_time_with_seconds(epoch_ms, &tz_name)
}

// ── Watch Progress ──────────────────────────────────

/// Calculate progress ratio from position and duration.
/// Returns clamped 0.0-1.0.
#[flutter_rust_bridge::frb(sync)]
pub fn calculate_watch_progress(position_ms: i64, duration_ms: i64) -> f64 {
    crispy_core::algorithms::watch_progress::calculate_progress(position_ms, duration_ms)
}

/// Filter watch positions for continue watching.
/// Returns JSON array of WatchPositionEntry.
pub fn filter_continue_watching_positions(json: String, limit: usize) -> String {
    crispy_core::algorithms::watch_progress::filter_continue_watching_positions(&json, limit)
}

// ── VOD Sorting / Filter ────────────────────────────

/// Filter VOD items to those added within the last
/// `cutoff_days` days, sorted newest-first.
///
/// `items_json`   — JSON array of VodItem.
/// `cutoff_days`  — number of days to look back.
/// `now_ms`       — current Unix time in milliseconds.
/// Returns JSON array of VodItem.
pub fn filter_recently_added(items_json: String, cutoff_days: u32, now_ms: i64) -> String {
    crispy_core::algorithms::vod_sorting::filter_recently_added(&items_json, cutoff_days, now_ms)
}

// ── Watch History ───────────────────────────────────

/// Computes the current watch streak in consecutive
/// calendar days.
///
/// `timestamps_json` — JSON array of epoch-ms i64 values.
/// `now_ms`          — current time as epoch-ms.
/// Returns streak count as u32.
#[flutter_rust_bridge::frb(sync)]
pub fn compute_watch_streak(timestamps_json: String, now_ms: i64) -> u32 {
    crispy_core::algorithms::watch_history::compute_watch_streak(&timestamps_json, now_ms)
}

/// Computes aggregated viewing statistics for a profile.
///
/// `history_json` — JSON array of watch-history objects.
/// `now_ms`       — current time as epoch-ms.
/// Returns JSON-serialised ProfileStats.
pub fn compute_profile_stats(history_json: String, now_ms: i64) -> String {
    crispy_core::algorithms::watch_history::compute_profile_stats(&history_json, now_ms)
}

/// Merges two WatchHistory JSON arrays, deduplicates by
/// `id` (first occurrence wins), and sorts by
/// `last_watched` descending.
///
/// Returns a JSON array.
pub fn merge_dedup_sort_history(a_json: String, b_json: String) -> String {
    crispy_core::algorithms::watch_history::merge_dedup_sort_history(&a_json, &b_json)
}

/// Filters a WatchHistory JSON array by
/// continue-watching status.
///
/// `history_json` — JSON array of WatchHistory.
/// `filter`       — `"all"`, `"watching"`, or
///   `"completed"`.
/// Returns a JSON array.
pub fn filter_by_cw_status(history_json: String, filter: String) -> String {
    crispy_core::algorithms::watch_history::filter_by_cw_status(&history_json, &filter)
}

/// Returns a JSON array of series IDs whose `updated_at`
/// is within the last `days` days relative to `now_ms`.
///
/// `series_json` — JSON array of objects with `id` and
///   optional `updated_at` epoch-ms.
/// `days`        — look-back window in days.
/// `now_ms`      — current time as epoch-ms.
pub fn series_ids_with_new_episodes(series_json: String, days: u32, now_ms: i64) -> String {
    crispy_core::algorithms::watch_history::series_ids_with_new_episodes(&series_json, days, now_ms)
}

/// Counts in-progress episodes for a given `series_id`.
///
/// `history_json` — JSON array of watch-history-like
///   objects with series_id, media_type, duration_ms,
///   position_ms.
/// `series_id`    — the series to count for.
/// Returns count as usize.
#[flutter_rust_bridge::frb(sync)]
pub fn count_in_progress_episodes(history_json: String, series_id: String) -> usize {
    crispy_core::algorithms::watch_history::count_in_progress_episodes(&history_json, &series_id)
}

// ── Group Icon ──────────────────────────────────────

/// Match a group name to a Material icon identifier.
#[flutter_rust_bridge::frb(sync)]
pub fn match_group_icon(group_name: String) -> String {
    crispy_core::algorithms::group_icon::match_group_icon(&group_name)
}

// ── Search Grouping ─────────────────────────────────

/// Group enriched search results by media type.
/// Returns JSON of GroupedResults.
pub fn group_search_results(
    results_json: String,
    channels_json: String,
    vod_json: String,
    epg_json: String,
) -> String {
    crispy_core::algorithms::search_grouping::group_search_results(
        &results_json,
        &channels_json,
        &vod_json,
        &epg_json,
    )
}

// ── Search (advanced) ───────────────────────────────

/// Search channels by matching live program title.
pub fn search_channels_by_live_program(epg_map_json: String, query: String, now_ms: i64) -> String {
    crispy_core::algorithms::search::search_channels_by_live_program(&epg_map_json, &query, now_ms)
}

/// Merge EPG-matched channel IDs into a base list.
pub fn merge_epg_matched_channels(
    base_json: String,
    all_channels_json: String,
    matched_ids_json: String,
    epg_overrides_json: String,
) -> String {
    crispy_core::algorithms::search::merge_epg_matched_channels(
        &base_json,
        &all_channels_json,
        &matched_ids_json,
        &epg_overrides_json,
    )
}

// ── Categories (search) ─────────────────────────────

/// Build merged/deduped search categories.
#[flutter_rust_bridge::frb(sync)]
pub fn build_search_categories(vod_categories_json: String, channel_groups_json: String) -> String {
    crispy_core::algorithms::categories::build_search_categories(
        &vod_categories_json,
        &channel_groups_json,
    )
}

// ── PIN Lockout ─────────────────────────────────────

/// Check if a PIN lockout is currently active.
#[flutter_rust_bridge::frb(sync)]
pub fn is_lock_active(locked_until_ms: i64, now_ms: i64) -> bool {
    crispy_core::algorithms::pin::is_lock_active(locked_until_ms, now_ms)
}

/// Return ms remaining in a PIN lockout.
#[flutter_rust_bridge::frb(sync)]
pub fn lock_remaining_ms(locked_until_ms: i64, now_ms: i64) -> i64 {
    crispy_core::algorithms::pin::lock_remaining_ms(locked_until_ms, now_ms)
}

// ── Watch History (advanced) ────────────────────────

/// Resolve next episodes for continue-watching.
pub fn resolve_next_episodes(
    entries_json: String,
    vod_items_json: String,
    threshold: f64,
) -> String {
    crispy_core::algorithms::watch_history::resolve_next_episodes(
        &entries_json,
        &vod_items_json,
        threshold,
    )
}

/// Count episodes per season.
#[flutter_rust_bridge::frb(sync)]
pub fn episode_count_by_season(episodes_json: String) -> String {
    crispy_core::algorithms::watch_history::episode_count_by_season(&episodes_json)
}

/// Determine badge kind for a VOD item.
#[flutter_rust_bridge::frb(sync)]
pub fn vod_badge_kind(year: Option<i32>, added_at_ms: Option<i64>, now_ms: i64) -> String {
    crispy_core::algorithms::watch_history::vod_badge_kind(year, added_at_ms, now_ms)
}

// ── VOD Similarity ──────────────────────────────────

/// Find similar VOD items by genre/category overlap.
pub fn similar_vod_items(items_json: String, item_id: String, limit: usize) -> String {
    crispy_core::algorithms::vod_sorting::similar_vod_items(&items_json, &item_id, limit)
}
