-- Migration 001: Initial schema (v36)
-- Creates all base tables, indexes, and sets user_version = 36.
-- Loaded at compile time via include_str! in migration_runner.rs.

-- Channels
CREATE TABLE IF NOT EXISTS db_channels (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    stream_url TEXT NOT NULL,
    number INTEGER,
    channel_group TEXT,
    logo_url TEXT,
    tvg_id TEXT,
    tvg_name TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    user_agent TEXT,
    has_catchup INTEGER NOT NULL DEFAULT 0,
    catchup_days INTEGER NOT NULL DEFAULT 0,
    catchup_type TEXT,
    catchup_source TEXT,
    source_id TEXT,
    added_at INTEGER,
    updated_at INTEGER,
    is_247 INTEGER NOT NULL DEFAULT 0
);

-- VOD items (movies, series episodes)
CREATE TABLE IF NOT EXISTS db_vod_items (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    stream_url TEXT NOT NULL,
    type TEXT NOT NULL,
    poster_url TEXT,
    backdrop_url TEXT,
    description TEXT,
    rating TEXT,
    year INTEGER,
    duration INTEGER,
    category TEXT,
    series_id TEXT,
    season_number INTEGER,
    episode_number INTEGER,
    ext TEXT,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    added_at INTEGER,
    updated_at INTEGER,
    source_id TEXT
);

-- Categories (live, movie, series) per source
CREATE TABLE IF NOT EXISTS db_categories (
    category_type TEXT NOT NULL,
    name TEXT NOT NULL,
    source_id TEXT,
    PRIMARY KEY (category_type, name)
);

-- Sync metadata per source
CREATE TABLE IF NOT EXISTS db_sync_meta (
    source_id TEXT PRIMARY KEY NOT NULL,
    last_sync_time INTEGER NOT NULL
);

-- App settings key-value store
CREATE TABLE IF NOT EXISTS db_settings (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
);

-- EPG programme entries
CREATE TABLE IF NOT EXISTS db_epg_entries (
    channel_id TEXT NOT NULL,
    title TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL,
    description TEXT,
    category TEXT,
    icon_url TEXT,
    source_id TEXT,
    PRIMARY KEY (channel_id, start_time)
);

-- Watch history (position resume + history display)
CREATE TABLE IF NOT EXISTS db_watch_history (
    id TEXT PRIMARY KEY NOT NULL,
    media_type TEXT NOT NULL,
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
    profile_id TEXT,
    source_id TEXT
);

-- User profiles (parental controls, per-profile settings)
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

-- Per-profile live channel favourites
CREATE TABLE IF NOT EXISTS db_user_favorites (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id),
    channel_id TEXT NOT NULL REFERENCES db_channels(id),
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, channel_id)
);

-- Per-profile VOD favourites
CREATE TABLE IF NOT EXISTS db_vod_favorites (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id),
    vod_item_id TEXT NOT NULL REFERENCES db_vod_items(id),
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, vod_item_id)
);

-- Per-profile favourite categories
CREATE TABLE IF NOT EXISTS db_favorite_categories (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id),
    category_type TEXT NOT NULL,
    category_name TEXT NOT NULL,
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, category_type, category_name)
);

-- Per-profile source access control
CREATE TABLE IF NOT EXISTS db_profile_source_access (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id),
    source_id TEXT NOT NULL,
    granted_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, source_id)
);

-- DVR recordings
CREATE TABLE IF NOT EXISTS db_recordings (
    id TEXT PRIMARY KEY NOT NULL,
    channel_id TEXT,
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
    owner_profile_id TEXT,
    is_shared INTEGER NOT NULL DEFAULT 1,
    remote_backend_id TEXT,
    remote_path TEXT
);

-- Cloud storage backends for DVR offload
CREATE TABLE IF NOT EXISTS db_storage_backends (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    config TEXT NOT NULL,
    is_default INTEGER NOT NULL DEFAULT 0
);

-- Transfer tasks for recording offload
CREATE TABLE IF NOT EXISTS db_transfer_tasks (
    id TEXT PRIMARY KEY NOT NULL,
    recording_id TEXT NOT NULL,
    backend_id TEXT NOT NULL,
    direction TEXT NOT NULL,
    status TEXT NOT NULL,
    total_bytes INTEGER NOT NULL DEFAULT 0,
    transferred_bytes INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    error_message TEXT,
    remote_path TEXT
);

-- Saved multi-view layouts
CREATE TABLE IF NOT EXISTS db_saved_layouts (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    layout TEXT NOT NULL,
    streams TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

-- Search history for autocomplete
CREATE TABLE IF NOT EXISTS db_search_history (
    id TEXT PRIMARY KEY NOT NULL,
    query TEXT NOT NULL,
    searched_at INTEGER NOT NULL,
    result_count INTEGER NOT NULL DEFAULT 0
);

-- Per-profile custom channel ordering
CREATE TABLE IF NOT EXISTS db_channel_order (
    profile_id TEXT NOT NULL,
    group_name TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    sort_index INTEGER NOT NULL,
    PRIMARY KEY (profile_id, group_name, channel_id)
);

-- Programme reminders with FK cascade
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

-- Watchlist (want to watch later)
CREATE TABLE IF NOT EXISTS db_watchlist (
    profile_id TEXT NOT NULL REFERENCES db_profiles(id) ON DELETE CASCADE,
    vod_item_id TEXT NOT NULL REFERENCES db_vod_items(id) ON DELETE CASCADE,
    added_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, vod_item_id)
);

-- IPTV / media sources (M3U, Xtream, Stalker)
CREATE TABLE IF NOT EXISTS db_sources (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    source_type TEXT NOT NULL,
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
    updated_at INTEGER
);

-- Adaptive buffer tiers per stream URL hash
CREATE TABLE IF NOT EXISTS db_buffer_tiers (
    url_hash TEXT PRIMARY KEY NOT NULL,
    tier TEXT NOT NULL DEFAULT 'normal',
    updated_at INTEGER NOT NULL
);

-- Video bookmarks (chapter marks / manual saves)
CREATE TABLE IF NOT EXISTS db_bookmarks (
    id TEXT PRIMARY KEY NOT NULL,
    content_id TEXT NOT NULL,
    content_type TEXT NOT NULL,
    position_ms INTEGER NOT NULL,
    label TEXT,
    created_at INTEGER NOT NULL
);

-- Stream health telemetry (stall counts, TTFF, buffer stats)
CREATE TABLE IF NOT EXISTS db_stream_health (
    url_hash TEXT PRIMARY KEY NOT NULL,
    stall_count INTEGER NOT NULL DEFAULT 0,
    buffer_sum REAL NOT NULL DEFAULT 0,
    buffer_samples INTEGER NOT NULL DEFAULT 0,
    ttff_ms INTEGER NOT NULL DEFAULT 0,
    last_seen INTEGER NOT NULL
);

-- EPG channel mappings (auto + manual)
CREATE TABLE IF NOT EXISTS db_epg_mappings (
    channel_id TEXT PRIMARY KEY NOT NULL,
    epg_channel_id TEXT NOT NULL,
    confidence REAL NOT NULL,
    source TEXT NOT NULL,
    locked INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
);

-- Smart channel groups for cross-provider failover
CREATE TABLE IF NOT EXISTS db_smart_groups (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS db_smart_group_members (
    group_id TEXT NOT NULL REFERENCES db_smart_groups(id) ON DELETE CASCADE,
    channel_id TEXT NOT NULL,
    source_id TEXT NOT NULL DEFAULT '',
    priority INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (group_id, channel_id)
);

-- Retry queue for durable async operations
CREATE TABLE IF NOT EXISTS db_retry_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation TEXT NOT NULL,
    payload TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    next_retry_at TEXT NOT NULL,
    max_lifetime TEXT NOT NULL,
    created_at TEXT NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_channels_source ON db_channels (source_id);
CREATE INDEX IF NOT EXISTS idx_channels_tvg ON db_channels (tvg_id);
CREATE INDEX IF NOT EXISTS idx_vod_source ON db_vod_items (source_id);
CREATE INDEX IF NOT EXISTS idx_epg_channel ON db_epg_entries (channel_id);
CREATE INDEX IF NOT EXISTS idx_epg_source ON db_epg_entries (source_id);
CREATE INDEX IF NOT EXISTS idx_source_access ON db_profile_source_access (source_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_profile ON db_watch_history (profile_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_source ON db_watch_history (source_id);
CREATE INDEX IF NOT EXISTS idx_vod_items_series ON db_vod_items (series_id);
CREATE INDEX IF NOT EXISTS idx_reminders_notify ON db_reminders (notify_at);
CREATE INDEX IF NOT EXISTS idx_channel_order_profile ON db_channel_order (profile_id);
CREATE INDEX IF NOT EXISTS idx_categories_source ON db_categories (source_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_content ON db_bookmarks (content_id);
CREATE INDEX IF NOT EXISTS idx_retry_queue_next ON db_retry_queue (next_retry_at);

PRAGMA user_version = 36;
