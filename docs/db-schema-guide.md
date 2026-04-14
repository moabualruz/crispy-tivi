# Crispy-Tivi — Database Schema Drafting Guide

## 1. Purpose

This document provides a schema drafting direction for Crispy-Tivi based on the normalized data model.

This is intentionally a **drafting guide**, not a hard-committed final schema.

---

## 2. Required Planning Note

The planner and applier of the schema must **re-research and re-evaluate the final schema using the most recent project requirements, real data behavior in the codebase, current SQLDelight/SQLite constraints, current feature needs, and current online research** before hard-committing the schema.

This applies especially to:
- indexing strategy
- FTS design
- UPSERT conflict rules
- aggregate vs source-scoped entity layout
- EPG storage volume
- search tokenization
- restoration persistence
- import/export payload persistence
- image/cache metadata persistence

This document should be treated as a schema-direction guide, not as a frozen SQL contract.

---

## 3. Schema Design Principles

The schema should aim for:
- normalized core entities
- explicit source provenance
- support for both source-scoped and aggregate identities
- fast local browse/search
- explicit indexing where query patterns justify it
- scalable EPG storage
- replaceable/tunable matching logic
- safe migrations over time

Avoid:
- baking UI-specific assumptions into the schema
- hard-binding XMLTV matches at parse time
- storing secrets in plaintext
- storing giant opaque blobs when structured columns are better
- premature over-normalization where query/read patterns become painful

---

## 4. Recommended Table Families

The schema should likely include families of tables such as:

### 4.1 Source tables
Purpose:
- source metadata
- source state
- source configuration references
- sync state

Likely tables:
- `sources`
- `source_status`
- `source_sync_records`

### 4.2 Grouping tables
Purpose:
- source-scoped groups/categories

Likely tables:
- `source_groups`

### 4.3 Live channel tables
Purpose:
- source-scoped channels
- aggregate channel identity
- channel-to-variant mapping

Likely tables:
- `channel_variants`
- `aggregate_channels`
- `aggregate_channel_variants`

### 4.4 Movie tables
Likely tables:
- `movie_variants`
- `aggregate_movies`
- `aggregate_movie_variants`

### 4.5 Series tables
Likely tables:
- `series_variants`
- `aggregate_series`
- `aggregate_series_variants`
- `season_variants`
- `aggregate_seasons`
- `aggregate_season_variants`
- `episode_variants`
- `aggregate_episodes`
- `aggregate_episode_variants`

### 4.6 Playback-related tables
Purpose:
- source-backed playable variants
- optional playback metadata

Likely tables:
- `playback_variants`

### 4.7 EPG tables
Purpose:
- parsed XMLTV/on-demand normalized program data
- mapping candidates
- match refinement

Likely tables:
- `epg_programs`
- `epg_channels`
- `epg_mapping_candidates`

### 4.8 Search/indexing tables
Purpose:
- FTS-backed search projections

Likely tables:
- one or more FTS5-backed virtual tables
- search metadata/projection tables where helpful

### 4.9 User-state tables
Purpose:
- favorites
- history
- restoration
- settings

Likely tables:
- `favorites`
- `history_entries`
- `restoration_records`
- `settings`

### 4.10 Artwork/cache tables
Purpose:
- image metadata
- cache coordination
- fetch status

Likely tables:
- `artwork_assets`

### 4.11 Import/export metadata tables
Optional, if useful:
- `backup_metadata`
- import history or schema metadata tables

### 4.12 Diagnostics/support tables
Optional, where persistent local diagnostics justify it:
- sync diagnostics
- source health snapshots
- index rebuild metadata

---

## 5. Recommended Identity Approach

The schema should preserve at least these identity levels:

- source identity
- source-scoped normalized entity identity
- aggregate identity

This likely means aggregate tables plus source-variant tables plus mapping tables.

Do not collapse everything into a single flat “media item” table unless real implementation evidence proves that superior.

---

## 6. EPG Drafting Recommendation

EPG storage should be designed around:
- large volume
- time-window queries
- runtime/query-time matching
- future refinement of matching logic

Recommended direction:
- store program rows independently
- store EPG channel metadata independently
- store mapping candidates independently
- resolve program binding to normalized channels at runtime/query time

Do not hard-commit a schema that permanently binds XMLTV rows to final channels during ingest unless implementation research proves that better.

---

## 7. Search Drafting Recommendation

The search layer should likely use SQLite FTS5.

Recommended direction:
- one or more indexed search projection tables
- searchable text fields derived from normalized content
- ranking metadata stored separately where useful
- source scope and content type filterability preserved

The exact FTS schema should be revalidated against:
- search requirements
- tokenizer behavior
- query patterns
- performance during large imports

---

## 8. Sync and UPSERT Recommendation

The schema should support safe UPSERT-based refresh behavior.

Recommended direction:
- stable uniqueness constraints
- explicit conflict targets
- per-entity upsert semantics
- sync timestamps and sync-domain metadata

Conflict rules should be defined only after validating:
- actual uniqueness rules per provider family
- deduplication semantics
- aggregate merge rules
- update frequency and field volatility

---

## 9. Restoration and History Recommendation

The schema should persist enough lightweight but durable state to support:
- navigation restoration
- playback restoration
- continue watching
- channel relaunch behavior
- contextual return flows

Recommended direction:
- restoration records remain separate from generic history
- history persists source/variant context where relevant
- restoration payloads store IDs and small context structures, not large serialized UI blobs

---

## 10. Artwork and Cache Recommendation

The schema should track artwork metadata and fetch status, but avoid turning the DB into a binary asset store unless there is a very strong implementation reason.

Recommended direction:
- store remote URLs
- cache keys
- fetch status
- size/type hints
- last fetch timestamps
- optional quality hints

Actual binary caching should remain filesystem/disk-cache managed unless revalidation suggests otherwise.

---

## 11. Settings and Secrets Recommendation

Settings may be stored in normal persistence.

Secrets should not be stored as plaintext in the main database.

Recommended direction:
- store secure secret references in DB
- bind actual secret material to platform secure storage

---

## 12. Indexing Guidance

Likely needed indexes include:
- source ID indexes
- aggregate ID indexes
- group/category indexes
- content-type indexes
- start/end time indexes for EPG
- source scope lookup indexes
- history/favorites lookup indexes
- sync timestamp indexes

The exact index set must be tuned after validating real query patterns.

Do not over-index before measuring import cost and query benefit.

---

## 13. Migration Guidance

Schema evolution is expected.

The schema design should support:
- explicit migration ownership
- forward versioning
- backup/export compatibility
- reindex/rebuild paths where needed
- safe recovery if one subsystem’s derived data must be rebuilt

Derived/indexed/search-heavy tables should be designed so they can be rebuilt rather than treated as irreplaceable source-of-truth data.

---

## 14. Suggested Drafting Workflow

The planner/applier should draft the schema in this order:

1. core source tables
2. source-scoped content variant tables
3. aggregate content tables and mappings
4. favorites/history/restoration/settings
5. EPG program + mapping tables
6. search/index tables
7. sync/diagnostic metadata tables
8. artwork/cache metadata tables
9. indexes and conflict rules
10. migration/version strategy

This order reduces the chance of premature optimization and makes the identity model clear before derived systems are layered in.

---

## 15. Required Revalidation by Planner/Applier

Before final schema commit, the planner and applier must revalidate:
- actual entity cardinalities
- source-specific identity stability
- aggregate merge rules
- EPG storage volume and query behavior
- import/update write patterns
- FTS performance and tokenizer behavior
- index overhead
- SQLDelight ergonomics
- backup/export requirements
- current project needs and current online research

The final schema should be treated as an implementation-informed decision, not a direct mechanical transcription of this draft guide.
