//! SQL column-list constants for domain model SELECT queries.
//!
//! Each constant matches the positional column order expected by the
//! corresponding `*_from_row` mapping function. Keep constants here
//! and mapping functions in sync.

// ── Channel ─────────────────────────────────────────

/// SELECT column list for `db_channels` (39 columns, positional order).
///
/// Use with `format!("SELECT {CHANNEL_COLUMNS} FROM db_channels ...")`.
/// Column order matches `channel_from_row` index bindings.
pub const CHANNEL_COLUMNS: &str = "id, native_id, name, stream_url, number, \
     channel_group, logo_url, tvg_id, xtream_stream_id, epg_channel_id, \
     tvg_name, is_favorite, user_agent, \
     has_catchup, catchup_days, \
     catchup_type, catchup_source, \
     source_id, added_at, updated_at, is_247, \
     tvg_shift, tvg_language, tvg_country, \
     parent_code, is_radio, tvg_rec, \
     is_adult, custom_sid, direct_source, \
     stalker_cmd, resolved_url, resolved_at, \
     tvg_url, stream_properties_json, vlc_options_json, \
     timeshift, stream_type, thumbnail_url";

// ── VodItem ──────────────────────────────────────────

/// SELECT column list for `db_movies` mapped to `VodItem` fields.
///
/// Column order (0-based):
///   0  id              9  duration_minutes  18  source_id
///   1  name           10  genre             19  cast_names
///   2  stream_url     11  series_id (NULL)  20  director
///   3  type literal   12  season_number     21  genre (compat)
///   4  poster_url     13  episode_number    22  youtube_trailer
///   5  backdrop_url   14  container_ext     23  tmdb_id
///   6  description    15  is_favorite (0)   24  rating_5based
///   7  rating         16  added_at          25  original_name
///   8  year           17  updated_at        26  is_adult
///                                           27  content_rating
///                                           28  native_id
pub const VOD_COLUMNS: &str = "id, name, stream_url, \
     vod_type AS type, \
     poster_url, backdrop_url, \
     description, rating, year, \
     duration_minutes, genre, NULL AS series_id, \
     NULL AS season_number, NULL AS episode_number, \
     container_ext, 0 AS is_favorite, added_at, \
     updated_at, source_id, \
     cast_names, director, genre, \
     youtube_trailer, tmdb_id, rating_5based, \
     original_name, is_adult, content_rating, \
     native_id";

/// Same as [`VOD_COLUMNS`] but qualified with table alias `v.` for JOIN queries.
pub const VOD_COLUMNS_V: &str = "v.id, v.name, v.stream_url, \
     v.vod_type AS type, \
     v.poster_url, v.backdrop_url, \
     v.description, v.rating, v.year, \
     v.duration_minutes, v.genre, NULL AS series_id, \
     NULL AS season_number, NULL AS episode_number, \
     v.container_ext, 0 AS is_favorite, v.added_at, \
     v.updated_at, v.source_id, \
     v.cast_names, v.director, v.genre, \
     v.youtube_trailer, v.tmdb_id, v.rating_5based, \
     v.original_name, v.is_adult, v.content_rating, \
     v.native_id";
