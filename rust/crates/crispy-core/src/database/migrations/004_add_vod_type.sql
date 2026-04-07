-- Migration 004: add vod_type discriminator to db_movies
-- Series items (item_type = 'series') are stored in db_movies alongside
-- movies. Previously the column was missing and VOD_COLUMNS hardcoded
-- 'movie' AS type, so series were invisible. This migration adds the
-- column and back-fills existing rows with 'movie' as the default.

ALTER TABLE db_movies ADD COLUMN vod_type TEXT NOT NULL DEFAULT 'movie';

-- Index for fast type-filtered queries used by get_vod_page / get_vod_count.
CREATE INDEX IF NOT EXISTS idx_movies_vod_type ON db_movies (vod_type);

PRAGMA user_version = 40;
