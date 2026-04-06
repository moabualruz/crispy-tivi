use std::collections::HashMap;

use crate::algorithms::normalize::EPG_FORMAT;
use crate::models::{Channel, EpgEntry, Movie, Source, UserProfile, VodItem, WatchHistory};
use crate::services::CrispyService;

/// Open a fresh in-memory service for testing.
pub fn make_service() -> CrispyService {
    CrispyService::open_in_memory().expect("open in-memory")
}

/// Create a service pre-seeded with common test sources and a
/// default channel.  Use in tests that insert child rows
/// (channels, VOD, EPG, recordings) referencing source/channel FKs.
pub fn make_service_with_fixtures() -> CrispyService {
    let svc = make_service();
    for (id, name) in [
        ("src1", "Test Source 1"),
        ("src_a", "Test Source A"),
        ("src_b", "Test Source B"),
        ("src_c", "Test Source C"),
        ("src2", "Test Source 2"),
        ("src3", "Test Source 3"),
        ("s1", "Source 1"),
        ("s2", "Source 2"),
        ("s3", "Source 3"),
        ("_placeholder", "Placeholder"),
    ] {
        svc.save_source(&make_source(id, name, "m3u"))
            .expect("seed test source");
    }
    svc
}

/// Parse a datetime string in EPG_FORMAT (`"%Y-%m-%d %H:%M:%S"`) format.
pub fn parse_dt(s: &str) -> chrono::NaiveDateTime {
    chrono::NaiveDateTime::parse_from_str(s, EPG_FORMAT).unwrap()
}

pub fn make_channel(id: &str, name: &str) -> Channel {
    Channel {
        id: id.to_string(),
        native_id: id.to_string(),
        name: name.to_string(),
        stream_url: format!("http://example.com/{id}"),
        number: Some(1),
        channel_group: Some("News".to_string()),
        logo_url: None,
        tvg_id: None,
        xtream_stream_id: None,
        epg_channel_id: None,
        tvg_name: None,
        is_favorite: false,
        user_agent: None,
        has_catchup: false,
        catchup_days: 0,
        catchup_type: None,
        catchup_source: None,
        resolution: None,
        source_id: None,
        added_at: None,
        updated_at: None,
        is_247: false,
        tvg_shift: None,
        tvg_language: None,
        tvg_country: None,
        parent_code: None,
        is_radio: false,
        tvg_rec: None,
        is_adult: false,
        custom_sid: None,
        direct_source: None,
        stalker_cmd: None,
        resolved_url: None,
        resolved_at: None,
        tvg_url: None,
        stream_properties_json: None,
        vlc_options_json: None,
        timeshift: None,
        stream_type: None,
        thumbnail_url: None,
    }
}

pub fn make_movie(id: &str, name: &str) -> Movie {
    Movie {
        id: id.to_string(),
        source_id: String::new(),
        native_id: id.to_string(),
        name: name.to_string(),
        stream_url: Some(format!("http://example.com/movie/{id}")),
        ..Movie::default()
    }
}

pub fn make_profile(id: &str, name: &str) -> UserProfile {
    UserProfile {
        id: id.to_string(),
        name: name.to_string(),
        avatar_index: 0,
        pin: None,
        is_child: false,
        pin_version: 0,
        max_allowed_rating: 4,
        role: 1,
        dvr_permission: 2,
        dvr_quota_mb: None,
    }
}

pub fn make_vod_item(id: &str, name: &str) -> VodItem {
    VodItem {
        id: id.to_string(),
        native_id: id.to_string(),
        name: name.to_string(),
        stream_url: format!("http://example.com/vod/{id}"),
        item_type: "movie".to_string(),
        poster_url: None,
        backdrop_url: None,
        description: None,
        rating: None,
        year: None,
        duration: None,
        category: None,
        series_id: None,
        season_number: None,
        episode_number: None,
        ext: None,
        is_favorite: false,
        added_at: None,
        updated_at: None,
        source_id: None,
        cast: None,
        director: None,
        genre: None,
        youtube_trailer: None,
        tmdb_id: None,
        rating_5based: None,
        original_name: None,
        is_adult: false,
        content_rating: None,
    }
}

pub fn make_source(id: &str, name: &str, source_type: &str) -> Source {
    Source {
        id: id.to_string(),
        name: name.to_string(),
        source_type: crate::value_objects::SourceType::try_from(source_type).unwrap_or_default(),
        url: format!("http://example.com/{id}"),
        username: None,
        password: None,
        access_token: None,
        device_id: None,
        user_id: None,
        mac_address: None,
        epg_url: None,
        user_agent: None,
        refresh_interval_minutes: 60,
        accept_self_signed: false,
        enabled: true,
        sort_order: 0,
        last_sync_time: None,
        last_sync_status: None,
        last_sync_error: None,
        created_at: None,
        updated_at: None,
        credentials_encrypted: false,
        deleted_at: None,
        epg_etag: None,
        epg_last_modified: None,
    }
}

pub fn make_watch_entry(id: &str, name: &str) -> WatchHistory {
    WatchHistory {
        id: id.to_string(),
        media_type: "movie".to_string(),
        name: name.to_string(),
        stream_url: format!("http://example.com/{id}"),
        poster_url: None,
        series_poster_url: None,
        position_ms: 0,
        duration_ms: 3600000,
        last_watched: parse_dt("2025-01-15 12:00:00"),
        series_id: None,
        season_number: None,
        episode_number: None,
        device_id: None,
        device_name: None,
        profile_id: None,
        source_id: None,
    }
}

/// Create a source and persist it. Convenience for tests that need a valid
/// source FK before inserting channels or EPG entries.
pub fn make_source_and_save(svc: &CrispyService, id: &str) {
    svc.save_source(&make_source(id, id, "m3u"))
        .expect("save test source");
}

/// Insert a single EPG entry directly into the service's SQLite store.
/// `start_offset` and `end_offset` are seconds relative to Unix epoch 0 for
/// determinism (tests should not depend on the current wall clock).
pub fn insert_test_epg_entry(
    svc: &CrispyService,
    epg_channel_id: &str,
    source_id: &str,
    title: &str,
    start_offset: i64,
    end_offset: i64,
) {
    use chrono::DateTime;
    let entry = EpgEntry {
        epg_channel_id: epg_channel_id.to_string(),
        title: title.to_string(),
        start_time: DateTime::from_timestamp(start_offset, 0)
            .expect("valid start timestamp")
            .naive_utc(),
        end_time: DateTime::from_timestamp(end_offset, 0)
            .expect("valid end timestamp")
            .naive_utc(),
        source_id: Some(source_id.to_string()),
        ..EpgEntry::default()
    };
    let mut map = HashMap::new();
    map.insert(epg_channel_id.to_string(), vec![entry]);
    svc.save_epg_entries(&map).expect("save test epg entry");
}

pub fn make_episode_entry(
    id: &str,
    stream_url: &str,
    series_id: &str,
    pos_ms: i64,
    dur_ms: i64,
    last_watched_str: &str,
) -> WatchHistory {
    WatchHistory {
        id: id.to_string(),
        media_type: "episode".to_string(),
        name: format!("Ep {id}"),
        stream_url: stream_url.to_string(),
        poster_url: None,
        position_ms: pos_ms,
        duration_ms: dur_ms,
        last_watched: parse_dt(last_watched_str),
        series_id: Some(series_id.to_string()),
        season_number: Some(1),
        episode_number: Some(1),
        device_id: None,
        device_name: None,
        series_poster_url: None,
        profile_id: None,
        source_id: None,
    }
}
