-- Migration 009: Add extended VOD item fields.
-- New columns: original_name, is_adult, content_rating.
-- Maps to Xtream API get_vod_streams/get_vod_info response fields.

ALTER TABLE db_vod_items ADD COLUMN original_name TEXT;
ALTER TABLE db_vod_items ADD COLUMN is_adult INTEGER NOT NULL DEFAULT 0;
ALTER TABLE db_vod_items ADD COLUMN content_rating TEXT;

PRAGMA user_version = 44;
