CREATE INDEX IF NOT EXISTS idx_epg_channels_display
    ON db_epg_channels (display_name);

PRAGMA user_version = 39;
