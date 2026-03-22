-- Migration 001: Consolidated initial schema (v36)
-- All tables, indexes, FK constraints, and CHECK constraints.
-- Absorbs former migrations 001-010 into a single clean schema.
-- Data is disposable (IPTV sources re-sync on startup).

PRAGMA foreign_keys = ON;

-- ── IPTV / media sources ────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_sources (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    source_type TEXT NOT NULL CHECK (source_type IN ('m3u', 'xtream', 'stalker', 'jellyfin', 'emby', 'plex')),
    url TEXT NOT NULL,
    username TEXT,
    password TEXT,
    access_token TEXT,
    device_id TEXT,
    user_id TEXT,
    mac_address TEXT,
    epg_url TEXT,
    user_agent TEXT,
    refresh_interval_minutes INTEGER NOT NULL DEFAULT 60,
    accept_self_signed INTEGER NOT NULL DEFAULT 0,
    enabled INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,
    last_sync_time INTEGER,
    last_sync_status TEXT,
    last_sync_error TEXT,
    created_at INTEGER,
    updated_at INTEGER,
    credentials_encrypted INTEGER NOT NULL DEFAULT 0
);

-- ── User profiles ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_profiles (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    avatar_index INTEGER NOT NULL DEFAULT 0,
    pin TEXT,
    is_child INTEGER NOT NULL DEFAULT 0,
    pin_version INTEGER NOT NULL DEFAULT 0,
    max_allowed_rating INTEGER NOT NULL DEFAULT 4,
    role INTEGER NOT NULL DEFAULT 1,
    dvr_permission INTEGER NOT NULL DEFAULT 2,
    dvr_quota_mb INTEGER
);

-- ── Channels ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_channels (
    id TEXT PRIMARY KEY NOT NULL,
    native_id TEXT NOT NULL,
    name TEXT NOT NULL,
    stream_url TEXT NOT NULL,
    number INTEGER,
    channel_group TEXT,
    logo_url TEXT,
    tvg_id TEXT,
    epg_channel_id TEXT,
    tvg_name TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    user_agent TEXT,
    has_catchup INTEGER NOT NULL DEFAULT 0,
    catchup_days INTEGER NOT NULL DEFAULT 0,
    catchup_type TEXT,
    catchup_source TEXT,
    source_id TEXT REFERENCES db_sources(id) ON DELETE CASCADE,
    added_at INTEGER,
    updated_at INTEGER,
    is_247 INTEGER NOT NULL DEFAULT 0,
    tvg_shift REAL,
    tvg_language TEXT,
    tvg_country TEXT,
    parent_code TEXT,
    is_radio INTEGER NOT NULL DEFAULT 0,
    tvg_rec TEXT,
    is_adult INTEGER NOT NULL DEFAULT 0,
    custom_sid TEXT,
    direct_source TEXT,
    stalker_cmd TEXT,
    resolved_url TEXT,
    resolved_at INTEGER,
    UNIQUE (source_id, native_id)
);

-- ── Stream URLs (multi-URL per channel) ─────────────────────
CREATE TABLE IF NOT EXISTS db_stream_urls (
    channel_id TEXT NOT NULL REFERENCES db_channels(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 0,
    label TEXT,
    PRIMARY KEY (channel_id, url)
);

-- ── Categories ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_categories (
    id TEXT PRIMARY KEY NOT NULL,
    category_type TEXT NOT NULL,
    name TEXT NOT NULL,
    source_id TEXT REFERENCES db_sources(id) ON DELETE CASCADE,
    provider_id TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    UNIQUE (category_type, name, source_id)
);

-- ── Channel-to-Category junction ────────────────────────────
CREATE TABLE IF NOT EXISTS db_channel_categories (
    channel_id TEXT NOT NULL REFERENCES db_channels(id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES db_categories(id) ON DELETE CASCADE,
    PRIMARY KEY (channel_id, category_id)
);

-- ── EPG channels (XMLTV channel metadata) ───────────────────
CREATE TABLE IF NOT EXISTS db_epg_channels (
    xmltv_id TEXT NOT NULL,
    source_id TEXT NOT NULL REFERENCES db_sources(id) ON DELETE CASCADE,
    display_name TEXT,
    icon_url TEXT,
    url TEXT,
    display_names_json TEXT,
    PRIMARY KEY (xmltv_id, source_id)
);

-- ── Sync metadata ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_sync_meta (
    source_id TEXT PRIMARY KEY NOT NULL REFERENCES db_sources(id) ON DELETE CASCADE,
    last_sync_time INTEGER NOT NULL
);

-- ── App settings ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_settings (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
);

-- ── EPG programme entries ───────────────────────────────────
-- PK: (source_id, epg_channel_id, start_time)
-- xmltv_id kept for backward compat with EPG facade
CREATE TABLE IF NOT EXISTS db_epg_entries (
    epg_channel_id TEXT NOT NULL,
    xmltv_id TEXT,
    title TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL,
    description TEXT,
    category TEXT,
    icon_url TEXT,
    source_id TEXT REFERENCES db_sources(id) ON DELETE CASCADE,
    is_placeholder INTEGER NOT NULL DEFAULT 0,
    sub_title TEXT,
    season INTEGER,
    episode INTEGER,
    episode_label TEXT,
    air_date TEXT,
    content_rating TEXT,
    star_rating TEXT,
    credits_json TEXT,
    language TEXT,
    country TEXT,
    is_rerun INTEGER NOT NULL DEFAULT 0,
    is_new INTEGER NOT NULL DEFAULT 0,
    is_premiere INTEGER NOT NULL DEFAULT 0,
    length_minutes INTEGER,
    PRIMARY KEY (source_id, epg_channel_id, start_time),
    CHECK (end_time > start_time)
);

-- ── Movies ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_movies (
    id TEXT PRIMARY KEY NOT NULL,
    source_id TEXT NOT NULL REFERENCES db_sources(id) ON DELETE CASCADE,
    native_id TEXT NOT NULL,
    name TEXT NOT NULL,
    original_name TEXT,
    poster_url TEXT,
    backdrop_url TEXT,
    description TEXT,
    stream_url TEXT,
    container_ext TEXT,
    stalker_cmd TEXT,
    resolved_url TEXT,
    resolved_at INTEGER,
    year INTEGER,
    duration_minutes INTEGER,
    rating TEXT,
    rating_5based REAL,
    content_rating TEXT,
    genre TEXT,
    youtube_trailer TEXT,
    tmdb_id INTEGER,
    cast_names TEXT,
    director TEXT,
    is_adult INTEGER NOT NULL DEFAULT 0,
    added_at INTEGER,
    updated_at INTEGER,
    UNIQUE (source_id, native_id)
);

-- ── Series ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_series (
    id TEXT PRIMARY KEY NOT NULL,
    source_id TEXT NOT NULL REFERENCES db_sources(id) ON DELETE CASCADE,
    native_id TEXT NOT NULL,
    name TEXT NOT NULL,
    original_name TEXT,
    poster_url TEXT,
    backdrop_url TEXT,
    description TEXT,
    year INTEGER,
    genre TEXT,
    content_rating TEXT,
    rating TEXT,
    rating_5based REAL,
    youtube_trailer TEXT,
    tmdb_id INTEGER,
    cast_names TEXT,
    director TEXT,
    is_adult INTEGER NOT NULL DEFAULT 0,
    added_at INTEGER,
    updated_at INTEGER,
    UNIQUE (source_id, native_id)
);

-- ── Seasons ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_seasons (
    id TEXT PRIMARY KEY NOT NULL,
    series_id TEXT NOT NULL REFERENCES db_series(id) ON DELETE CASCADE,
    season_number INTEGER NOT NULL,
    name TEXT,
    poster_url TEXT,
    episode_count INTEGER,
    air_date TEXT,
    UNIQUE (series_id, season_number)
);

-- ── Episodes ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_episodes (
    id TEXT PRIMARY KEY NOT NULL,
    season_id TEXT NOT NULL REFERENCES db_seasons(id) ON DELETE CASCADE,
    source_id TEXT NOT NULL REFERENCES db_sources(id) ON DELETE CASCADE,
    native_id TEXT NOT NULL,
    episode_number INTEGER NOT NULL,
    name TEXT,
    description TEXT,
    poster_url TEXT,
    stream_url TEXT,
    container_ext TEXT,
    stalker_cmd TEXT,
    resolved_url TEXT,
    resolved_at INTEGER,
    duration_minutes INTEGER,
    air_date TEXT,
    rating TEXT,
    content_rating TEXT,
    tmdb_id INTEGER,
    added_at INTEGER,
    updated_at INTEGER,
    UNIQUE (season_id, episode_number)
);

-- ── VOD-to-Category junction ────────────────────────────────
CREATE TABLE IF NOT EXISTS db_vod_categories (
    content_id TEXT NOT NULL,
    content_type TEXT NOT NULL CHECK (content_type IN ('movie', 'series')),
    category_id TEXT NOT NULL REFERENCES db_categories(id) ON DELETE CASCADE,
    PRIMARY KEY (content_id, content_type, category_id)
);

-- ── Watch history ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_watch_history (
    id TEXT PRIMARY KEY NOT NULL,
    content_id TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('channel', 'movie', 'episode')),
    name TEXT NOT NULL,
    stream_url TEXT NOT NULL,
    poster_url TEXT,
    position_ms INTEGER NOT NULL DEFAULT 0,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    last_watched INTEGER NOT NULL,
    series_id TEXT,
    season_number INTEGER,
    episode_number INTEGER,
    device_id TEXT,
    device_name TEXT,
    series_poster_url TEXT,
    profile_id TEXT REFERENCES db_profiles(id) ON DELETE CASCADE,
    source_id TEXT REFERENCES db_sources(id) ON DELETE SET NULL
);

-- ── Per-profile live channel favourites ─────────────────────
CREATE TABLE IF NOT EXISTS db_user_favorites (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id) ON DELETE CASCADE,
    channel_id TEXT NOT NULL REFERENCES db_channels(id) ON DELETE CASCADE,
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, channel_id)
);

-- ── Per-profile VOD favourites ──────────────────────────────
CREATE TABLE IF NOT EXISTS db_vod_favorites (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id) ON DELETE CASCADE,
    content_id TEXT NOT NULL,
    content_type TEXT NOT NULL CHECK (content_type IN ('movie', 'series')),
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, content_id, content_type)
);

-- ── Per-profile favourite categories ────────────────────────
CREATE TABLE IF NOT EXISTS db_favorite_categories (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id) ON DELETE CASCADE,
    category_type TEXT NOT NULL,
    category_name TEXT NOT NULL,
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, category_type, category_name)
);

-- ── Per-profile source access ───────────────────────────────
CREATE TABLE IF NOT EXISTS db_profile_source_access (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id) ON DELETE CASCADE,
    source_id TEXT NOT NULL REFERENCES db_sources(id) ON DELETE CASCADE,
    granted_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, source_id)
);

-- ── DVR recordings ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_recordings (
    id TEXT PRIMARY KEY NOT NULL,
    channel_id TEXT REFERENCES db_channels(id) ON DELETE SET NULL,
    channel_name TEXT NOT NULL,
    channel_logo_url TEXT,
    program_name TEXT NOT NULL,
    stream_url TEXT,
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL,
    status TEXT NOT NULL,
    file_path TEXT,
    file_size_bytes INTEGER,
    is_recurring INTEGER NOT NULL DEFAULT 0,
    recur_days INTEGER NOT NULL DEFAULT 0,
    owner_profile_id TEXT REFERENCES db_profiles(id) ON DELETE SET NULL,
    is_shared INTEGER NOT NULL DEFAULT 1,
    remote_backend_id TEXT,
    remote_path TEXT,
    CHECK (end_time > start_time)
);

-- ── Cloud storage backends ──────────────────────────────────
CREATE TABLE IF NOT EXISTS db_storage_backends (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    config TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0
);

-- ── Transfer tasks ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_transfer_tasks (
    id TEXT PRIMARY KEY NOT NULL,
    recording_id TEXT NOT NULL REFERENCES db_recordings(id) ON DELETE CASCADE,
    backend_id TEXT NOT NULL REFERENCES db_storage_backends(id) ON DELETE CASCADE,
    direction TEXT NOT NULL,
    status TEXT NOT NULL,
    total_bytes INTEGER NOT NULL DEFAULT 0,
    transferred_bytes INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    error_message TEXT,
    remote_path TEXT
);

-- ── Saved multi-view layouts ────────────────────────────────
CREATE TABLE IF NOT EXISTS db_saved_layouts (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    layout TEXT NOT NULL,
    streams TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

-- ── Search history ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_search_history (
    id TEXT PRIMARY KEY NOT NULL,
    query TEXT NOT NULL,
    searched_at INTEGER NOT NULL,
    result_count INTEGER NOT NULL DEFAULT 0
);

-- ── Per-profile channel ordering ────────────────────────────
CREATE TABLE IF NOT EXISTS db_channel_order (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id) ON DELETE CASCADE,
    group_name TEXT NOT NULL,
    channel_id TEXT NOT NULL REFERENCES db_channels(id) ON DELETE CASCADE,
    sort_index INTEGER NOT NULL,
    PRIMARY KEY (profile_id, group_name, channel_id)
);

-- ── Programme reminders ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_reminders (
    id TEXT PRIMARY KEY NOT NULL,
    program_name TEXT NOT NULL,
    channel_name TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    notify_at INTEGER NOT NULL,
    fired INTEGER NOT NULL DEFAULT 0,
    profile_id TEXT REFERENCES db_profiles(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL
);

-- ── Watchlist ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_watchlist (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id) ON DELETE CASCADE,
    content_id TEXT NOT NULL,
    content_type TEXT NOT NULL CHECK (content_type IN ('movie', 'series')),
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, content_id, content_type)
);

-- ── Adaptive buffer tiers ───────────────────────────────────
CREATE TABLE IF NOT EXISTS db_buffer_tiers (
    url_hash TEXT PRIMARY KEY NOT NULL,
    tier TEXT NOT NULL DEFAULT 'normal',
    updated_at INTEGER NOT NULL
);

-- ── Video bookmarks ─────────────────────────────────────────
-- Polymorphic content_id — no FK (TTL cleanup instead)
CREATE TABLE IF NOT EXISTS db_bookmarks (
    id TEXT PRIMARY KEY NOT NULL,
    content_id TEXT NOT NULL,
    content_type TEXT NOT NULL,
    position_ms INTEGER NOT NULL,
    label TEXT,
    created_at INTEGER NOT NULL
);

-- ── Stream health telemetry ─────────────────────────────────
CREATE TABLE IF NOT EXISTS db_stream_health (
    url_hash TEXT PRIMARY KEY NOT NULL,
    stall_count INTEGER NOT NULL DEFAULT 0,
    buffer_sum REAL NOT NULL DEFAULT 0,
    buffer_samples INTEGER NOT NULL DEFAULT 0,
    ttff_ms INTEGER NOT NULL DEFAULT 0,
    last_seen INTEGER NOT NULL
);

-- ── EPG channel mappings ────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_epg_mappings (
    channel_id TEXT PRIMARY KEY NOT NULL,
    epg_channel_id TEXT NOT NULL,
    confidence REAL NOT NULL CHECK (confidence BETWEEN 0.0 AND 1.0),
    match_method TEXT NOT NULL,
    epg_source_id TEXT,
    locked INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
);

-- ── Smart channel groups ────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_smart_groups (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS db_smart_group_members (
    group_id TEXT NOT NULL REFERENCES db_smart_groups(id) ON DELETE CASCADE,
    channel_id TEXT NOT NULL REFERENCES db_channels(id) ON DELETE CASCADE,
    source_id TEXT,
    priority INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (group_id, channel_id)
);

-- ── Retry queue ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_retry_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation TEXT NOT NULL,
    payload TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    next_retry_at TEXT NOT NULL,
    max_lifetime TEXT NOT NULL,
    created_at TEXT NOT NULL,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    last_error TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
);

-- ── Merge decisions ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS merge_decisions (
    id TEXT PRIMARY KEY,
    decision_type TEXT NOT NULL CHECK (decision_type IN ('merge', 'split')),
    content_type TEXT NOT NULL CHECK (content_type IN ('movie', 'series', 'channel')),
    source_ids TEXT NOT NULL,
    canonical_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    profile_id TEXT,
    reason TEXT
);

-- ═══════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════

-- Channels
CREATE INDEX IF NOT EXISTS idx_channels_source ON db_channels (source_id);
CREATE INDEX IF NOT EXISTS idx_channels_tvg ON db_channels (tvg_id);
CREATE INDEX IF NOT EXISTS idx_channels_epg_channel ON db_channels (epg_channel_id);
CREATE INDEX IF NOT EXISTS idx_channels_native ON db_channels (source_id, native_id);

-- Stream URLs
CREATE INDEX IF NOT EXISTS idx_stream_urls_channel ON db_stream_urls (channel_id);

-- Movies
CREATE INDEX IF NOT EXISTS idx_movies_source ON db_movies (source_id);
CREATE INDEX IF NOT EXISTS idx_movies_native ON db_movies (source_id, native_id);
CREATE INDEX IF NOT EXISTS idx_movies_name ON db_movies (name);

-- Series
CREATE INDEX IF NOT EXISTS idx_series_source ON db_series (source_id);
CREATE INDEX IF NOT EXISTS idx_series_native ON db_series (source_id, native_id);
CREATE INDEX IF NOT EXISTS idx_series_name ON db_series (name);

-- Seasons
CREATE INDEX IF NOT EXISTS idx_seasons_series ON db_seasons (series_id);

-- Episodes
CREATE INDEX IF NOT EXISTS idx_episodes_season ON db_episodes (season_id);
CREATE INDEX IF NOT EXISTS idx_episodes_source ON db_episodes (source_id);

-- EPG — primary lookup paths
CREATE INDEX IF NOT EXISTS idx_epg_channel ON db_epg_entries (epg_channel_id);
CREATE INDEX IF NOT EXISTS idx_epg_source ON db_epg_entries (source_id);
CREATE INDEX IF NOT EXISTS idx_epg_channel_time ON db_epg_entries (epg_channel_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_epg_xmltv_time ON db_epg_entries (xmltv_id, start_time, end_time) WHERE xmltv_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_epg_real_coverage ON db_epg_entries (epg_channel_id, end_time) WHERE is_placeholder = 0;

-- EPG channels
CREATE INDEX IF NOT EXISTS idx_epg_channels_source ON db_epg_channels (source_id);

-- Categories
CREATE INDEX IF NOT EXISTS idx_categories_source ON db_categories (source_id);
CREATE INDEX IF NOT EXISTS idx_categories_type_source ON db_categories (category_type, source_id);

-- Channel categories junction
CREATE INDEX IF NOT EXISTS idx_channel_categories_cat ON db_channel_categories (category_id);

-- VOD categories junction
CREATE INDEX IF NOT EXISTS idx_vod_categories_cat ON db_vod_categories (category_id);
CREATE INDEX IF NOT EXISTS idx_vod_categories_content ON db_vod_categories (content_id, content_type);

-- Source access
CREATE INDEX IF NOT EXISTS idx_source_access ON db_profile_source_access (source_id);

-- Watch history
CREATE INDEX IF NOT EXISTS idx_watch_history_profile ON db_watch_history (profile_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_source ON db_watch_history (source_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_content ON db_watch_history (content_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_profile_source ON db_watch_history (profile_id, source_id);

-- Channel order
CREATE INDEX IF NOT EXISTS idx_channel_order_profile ON db_channel_order (profile_id);

-- Reminders
CREATE INDEX IF NOT EXISTS idx_reminders_notify ON db_reminders (notify_at);

-- Bookmarks
CREATE INDEX IF NOT EXISTS idx_bookmarks_content ON db_bookmarks (content_id);

-- Retry queue
CREATE INDEX IF NOT EXISTS idx_retry_queue_status_next ON db_retry_queue (status, next_retry_at);

-- Merge decisions
CREATE INDEX IF NOT EXISTS idx_merge_decisions_type ON merge_decisions (content_type, decision_type);
CREATE INDEX IF NOT EXISTS idx_merge_decisions_source ON merge_decisions (source_ids);

PRAGMA user_version = 36;
