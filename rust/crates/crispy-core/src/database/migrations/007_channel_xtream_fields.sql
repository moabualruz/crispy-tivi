-- Migration 007: Add Xtream-specific fields to channels.
-- New columns: is_adult, custom_sid, direct_source.
-- These map to Xtream API get_live_streams response fields.

ALTER TABLE db_channels ADD COLUMN is_adult INTEGER NOT NULL DEFAULT 0;
ALTER TABLE db_channels ADD COLUMN custom_sid TEXT;
ALTER TABLE db_channels ADD COLUMN direct_source TEXT;

PRAGMA user_version = 42;
