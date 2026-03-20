-- Migration 002: Extend retry_queue with status, max_attempts, and last_error.
--
-- The initial schema (001) created db_retry_queue with a minimal column set.
-- This migration adds the columns required for the durable retry queue feature:
--   - max_attempts  — cap on how many times an operation will be retried
--   - last_error    — human-readable error message from the most recent failure
--   - status        — lifecycle state: pending | processing | completed | failed
--
-- The payload / max_lifetime columns from v1 are left intact so existing rows
-- (if any) are preserved.  New rows use the `operation` column as the JSON
-- descriptor as originally intended.
--
-- A composite index on (status, next_retry_at) is added to make the hot
-- `fetch_due` query efficient.

ALTER TABLE db_retry_queue ADD COLUMN max_attempts INTEGER NOT NULL DEFAULT 5;
ALTER TABLE db_retry_queue ADD COLUMN last_error TEXT;
ALTER TABLE db_retry_queue ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';

-- Drop the v1 single-column index and replace with the composite one used by
-- fetch_due queries.
DROP INDEX IF EXISTS idx_retry_queue_next;
CREATE INDEX IF NOT EXISTS idx_retry_queue_status_next ON db_retry_queue(status, next_retry_at);

PRAGMA user_version = 37;
