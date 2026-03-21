--- Migration 006: Add metadata fields to db_vod_items
--- Adds cast, director, genre, youtube_trailer, tmdb_id, rating_5based.

ALTER TABLE db_vod_items ADD COLUMN "cast" TEXT;
ALTER TABLE db_vod_items ADD COLUMN director TEXT;
ALTER TABLE db_vod_items ADD COLUMN genre TEXT;
ALTER TABLE db_vod_items ADD COLUMN youtube_trailer TEXT;
ALTER TABLE db_vod_items ADD COLUMN tmdb_id INTEGER;
ALTER TABLE db_vod_items ADD COLUMN rating_5based REAL;

PRAGMA user_version = 41;
