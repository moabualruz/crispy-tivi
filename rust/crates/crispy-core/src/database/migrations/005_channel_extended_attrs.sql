-- Migration 005: Add extended M3U attributes to channels.
-- New columns: tvg_shift, tvg_language, tvg_country, parent_code, is_radio, tvg_rec.

ALTER TABLE db_channels ADD COLUMN tvg_shift REAL;
ALTER TABLE db_channels ADD COLUMN tvg_language TEXT;
ALTER TABLE db_channels ADD COLUMN tvg_country TEXT;
ALTER TABLE db_channels ADD COLUMN parent_code TEXT;
ALTER TABLE db_channels ADD COLUMN is_radio INTEGER NOT NULL DEFAULT 0;
ALTER TABLE db_channels ADD COLUMN tvg_rec TEXT;

PRAGMA user_version = 40;
