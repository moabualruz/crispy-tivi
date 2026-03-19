-- Migration 003: user manual merge/split decisions
-- Persists user-initiated dedup overrides that survive re-syncs.

CREATE TABLE IF NOT EXISTS merge_decisions (
    id          TEXT PRIMARY KEY,
    decision_type TEXT NOT NULL CHECK(decision_type IN ('merge', 'split')),
    content_type  TEXT NOT NULL CHECK(content_type IN ('movie', 'series', 'channel')),
    source_ids    TEXT NOT NULL,   -- JSON array of item IDs being merged/split
    canonical_id  TEXT,            -- For merge: the winning canonical ID
    created_at    TEXT NOT NULL DEFAULT (datetime('now')),
    profile_id    TEXT,            -- Which profile made the decision
    reason        TEXT             -- Optional user note
);

CREATE INDEX IF NOT EXISTS idx_merge_decisions_type
    ON merge_decisions(content_type, decision_type);

CREATE INDEX IF NOT EXISTS idx_merge_decisions_source
    ON merge_decisions(source_ids);

PRAGMA user_version = 38;
