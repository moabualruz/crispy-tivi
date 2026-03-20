-- Migration 004: credential encryption marker column
-- Adds `credentials_encrypted` flag to db_sources so the service layer
-- can detect and migrate any pre-existing plaintext credentials on first run.
-- Schema note: encrypted values are Base64(nonce || ciphertext || GCM-tag)
-- stored in the existing TEXT columns — no column type change needed.

ALTER TABLE db_sources
    ADD COLUMN credentials_encrypted INTEGER NOT NULL DEFAULT 0;

PRAGMA user_version = 39;
