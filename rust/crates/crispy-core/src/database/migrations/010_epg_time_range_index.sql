-- Migration 010: Composite index for fast EPG time-range queries.
-- Accelerates the hot path: get_epgs_for_channels(ids, start, end).
CREATE INDEX IF NOT EXISTS idx_epg_channel_time
ON db_epg_entries (channel_id, start_time, end_time);
