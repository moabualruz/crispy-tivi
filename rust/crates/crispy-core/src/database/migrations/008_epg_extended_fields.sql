-- Migration 008: Add extended XMLTV fields to db_epg_entries.
-- Required for existing databases upgrading from version 42.
ALTER TABLE db_epg_entries ADD COLUMN sub_title TEXT;
ALTER TABLE db_epg_entries ADD COLUMN season INTEGER;
ALTER TABLE db_epg_entries ADD COLUMN episode INTEGER;
ALTER TABLE db_epg_entries ADD COLUMN episode_label TEXT;
ALTER TABLE db_epg_entries ADD COLUMN air_date TEXT;
ALTER TABLE db_epg_entries ADD COLUMN content_rating TEXT;
ALTER TABLE db_epg_entries ADD COLUMN star_rating TEXT;
ALTER TABLE db_epg_entries ADD COLUMN directors TEXT;
ALTER TABLE db_epg_entries ADD COLUMN cast_members TEXT;
ALTER TABLE db_epg_entries ADD COLUMN writers TEXT;
ALTER TABLE db_epg_entries ADD COLUMN presenters TEXT;
ALTER TABLE db_epg_entries ADD COLUMN language TEXT;
ALTER TABLE db_epg_entries ADD COLUMN country TEXT;
ALTER TABLE db_epg_entries ADD COLUMN is_rerun INTEGER NOT NULL DEFAULT 0;
ALTER TABLE db_epg_entries ADD COLUMN is_new INTEGER NOT NULL DEFAULT 0;
ALTER TABLE db_epg_entries ADD COLUMN is_premiere INTEGER NOT NULL DEFAULT 0;
ALTER TABLE db_epg_entries ADD COLUMN length_minutes INTEGER;
PRAGMA user_version = 43;
