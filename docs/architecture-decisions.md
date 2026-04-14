# ADR Pack — Architecture Decision Records

## ADR-001 — Monorepo and Shared Platform Strategy

### Status
Accepted

### Context
The product targets Android, iOS, Windows, macOS, Linux, and Web.
The product requires:
- shared technical architecture
- shared business logic
- shared normalized content models
- maintainable multi-platform delivery
- source-agnostic UI-facing workflows

### Decision
Use a single monorepo containing:
- shared core modules
- shared feature modules
- shared design-system modules
- platform application modules
- platform-specific playback integrations
- shared test and tooling modules

### Consequences
Benefits:
- shared architecture and implementation conventions
- easier cross-platform consistency
- centralized build and dependency management
- lower friction for shared features and normalization logic

Tradeoffs:
- build graph complexity increases over time
- platform boundaries must be intentionally maintained
- CI pipelines must be designed carefully to avoid unnecessary work

---

## ADR-002 — UI Technology and Platform Delivery Model

### Status
Accepted

### Context
The product requires:
- shared technical implementation across Android, iOS, and desktop
- web as a full target
- source-agnostic workflows
- landscape-first product behavior
- future-proof design-system implementation

### Decision
Use:
- Kotlin Multiplatform
- Compose Multiplatform for Android, iOS, and desktop
- Kotlin web target for web delivery
- shared domain/state/data modules across all targets

### Consequences
Benefits:
- large amount of shared application code
- shared rendering/runtime model across native targets
- unified design-system implementation path
- simpler product consistency across targets

Tradeoffs:
- desktop remains JVM-based
- some platform-specific integrations still require explicit adaptation
- web remains a target with its own runtime constraints

---

## ADR-003 — Source Normalization Strategy

### Status
Accepted

### Context
The product must support:
- M3U
- Xtream
- Stalker
- future provider families
- multiple concurrent sources
- mixed-source browsing
- source-aware filtering
- source-agnostic UI workflows

### Decision
All provider-specific inputs shall be parsed by backend/data-layer adapters and normalized into shared internal entities before they reach feature flows or UI-facing models.

The UI-facing architecture shall not depend on provider-family-specific payload structures.

### Consequences
Benefits:
- easier feature reuse
- simpler cross-source search and browse flows
- lower coupling between features and provider families
- easier future provider additions

Tradeoffs:
- normalization layer becomes a core complexity center
- provider-specific edge cases must be preserved carefully in metadata
- debugging may require both normalized and raw-source inspection tooling

---

## ADR-004 — Source as First-Class Organizational Dimension

### Status
Accepted

### Context
Users must be able to:
- browse all enabled sources together
- browse one source only
- browse any selected subset of sources
- use source as a filter and grouping axis
- mix same-type and different-type sources concurrently

### Decision
Source shall be preserved as a first-class organizational dimension across the application.

The browse/search/playback model shall support:
- aggregate all-source views
- single-source views
- arbitrary multi-source views

Source shall exist above normalized content-type partitions such as:
- Live
- Movies
- Series

### Consequences
Benefits:
- preserves user mental model of imported providers
- supports power-user workflows
- enables cross-source aggregation without losing provenance
- supports source-based diagnostics and playback switching

Tradeoffs:
- browse orchestration grows more complex
- filter state becomes more important
- deduplication rules must preserve source attribution

---

## ADR-005 — Persistence Engine

### Status
Accepted

### Context
The product needs:
- local durable persistence
- schema control
- indexing
- full-text search
- offline-tolerant cached browsing
- cross-platform support
- large imported datasets

### Decision
Use:
- SQLite as storage engine
- SQLDelight as database access and schema layer

### Consequences
Benefits:
- explicit schema ownership
- deterministic migrations
- efficient local querying
- compatibility with FTS and UPSERT workflows
- good fit for normalized, indexed data

Tradeoffs:
- database schema and indexing require careful tuning
- repository boundaries must stay disciplined
- source imports must be optimized to avoid long write bursts

---

## ADR-006 — Search Backend

### Status
Accepted

### Context
The product requires:
- full-featured search
- multi-source search
- source filtering
- content-type filtering
- phrase/prefix matching
- ranking and indexing over large local datasets

### Decision
Use SQLite FTS-backed indexed local search as the primary search implementation.

Search shall operate over normalized entities and support ranking with weighted field relevance plus secondary ordering signals.

### Consequences
Benefits:
- fast local search
- deterministic offline-capable behavior
- full control over ranking and filtering rules
- easy integration with normalized data model

Tradeoffs:
- ranking strategy must be tuned over time
- indexing pipelines must stay synchronized with content updates
- search quality depends heavily on normalization quality

---

## ADR-007 — Playback Architecture

### Status
Accepted

### Context
Playback must be:
- remote-media capable
- IPTV-capable
- cross-platform
- state-observable
- decoupled from provider-family specifics
- reusable by shared feature flows

### Decision
Define a shared player contract and implement platform-specific backends behind it.

V1 direction:
- Android: native Android player backend (Media3 / ExoPlayer)
- Apple: native Apple player backend (AVPlayer / AVFoundation) — shared iOS + macOS module
- Desktop: **libmpv via a hand-rolled JNA binding** (LGPL v2.1+, dynamic link, `mpv_render_context` OpenGL integrated with Skiko's `DirectContext`). Pinned by [decisions.md](decisions.md) D18. Thumbnail extraction + stream probing use a separate `org.bytedeco:ffmpeg 8.0.1-1.5.13` LGPL-build dependency in `:core:image` and `:core:playback` per D19 — not libmpv.
- Web: hls.js-backed web playback integration in a dedicated `:platform:player:web` module

### Consequences
Benefits:
- shared feature logic can remain playback-backend agnostic
- platform-appropriate playback stacks can evolve independently
- future backend replacement remains possible

Tradeoffs:
- behavior parity needs deliberate testing
- some advanced playback features will vary by platform
- media-session integration must be implemented per platform

---

## ADR-008 — EPG Matching Strategy

### Status
Accepted

### Context
EPG sources differ by provider family:
- XMLTV tends to be parsed as a large standalone dataset
- Xtream and Stalker may expose per-channel or provider-specific EPG retrieval patterns
- matching strategies evolve over time and often need tuning

### Decision
EPG data shall be ingested and stored independently from final playback-item binding.

For XMLTV-style sources:
- parse and index the EPG dataset into its own tables
- perform channel matching at runtime/query time rather than permanently binding at import time

For source-provided EPG:
- allow on-demand retrieval and normalization into the same presentation layer

One normalized channel should resolve to one logical EPG presentation result.

### Consequences
Benefits:
- matching logic can improve without full data re-import
- provider-specific EPG strategies can coexist
- EPG debugging and tuning remain possible over time

Tradeoffs:
- runtime matching becomes a critical performance-sensitive path
- matching confidence and fallback rules need good diagnostics
- source-specific metadata must be preserved carefully

---

## ADR-009 — Sync and Refresh Policy

### Status
Accepted

### Context
The product requires:
- forced onboarding when no source exists
- non-blocking refresh after onboarding
- scheduled refresh
- startup refresh checks
- deduplicating writes
- stale awareness

### Decision
Use a two-phase content lifecycle:

1. Initial onboarding sync:
- mandatory before normal app usage
- validates source
- imports minimum required data
- persists synchronized state

2. Ongoing refresh:
- scheduled and opportunistic
- non-blocking during normal use
- executed only when refresh age exceeds policy
- UPSERT-based persistence
- partial refresh-capable

### Consequences
Benefits:
- predictable first-run experience
- avoids duplicate content writes
- supports large catalogs without blocking normal use after onboarding
- aligns well with local-cache-first architecture

Tradeoffs:
- refresh scheduling and backoff must be tuned
- source-specific pipelines may differ significantly
- stale-state reporting becomes important

---

## ADR-010 — Image Pipeline Policy

### Status
Accepted

### Context
The product is media-heavy and must avoid excessive RAM use during:
- browsing
- long sessions
- dense poster/logo surfaces
- guide navigation

### Decision
Use a disk-first image pipeline with:
- bounded memory cache
- aggressive viewport-driven loading
- request cancellation for off-screen items
- downsampling/resizing before presentation
- reusable placeholders and fallback assets

### Consequences
Benefits:
- better memory stability
- lower repeated network cost
- better behavior on low-memory devices
- suitable for large image-rich catalogs

Tradeoffs:
- image quality/latency tradeoffs must be tuned
- prefetching must remain conservative
- cache invalidation needs clear policy

---

## ADR-011 — Design System Architecture

### Status
Accepted

### Context
The product requires:
- long-term tweakability
- centralized theming
- configurable interaction styling
- future-proof global edits
- no hard-coded widget-level styling

### Decision
The design system shall be token-driven and centrally configurable.

Feature components shall consume semantic tokens and component variants rather than raw hard-coded visual values.

### Consequences
Benefits:
- future redesigns become cheaper
- feature teams do not duplicate styling logic
- theme evolution can remain centralized
- easier consistency across platforms

Tradeoffs:
- token taxonomy must be designed carefully
- semantic token layering adds up-front architecture work
- design-system governance becomes important

---

## ADR-012 — Rendering Strategy for Large Surfaces

### Status
Accepted

### Context
The product includes large or unbounded surfaces such as:
- channel lists
- guide/timeline grids
- poster rails
- search results
- history/favorites
- mixed-source aggregated views

### Decision
All large surfaces shall use virtualized/windowed rendering and lazy composition.

Guide-like surfaces shall support both vertical and horizontal windowing.

### Consequences
Benefits:
- better CPU usage
- better memory behavior
- scalable navigation across large datasets
- smoother long-session performance

Tradeoffs:
- list/grid abstraction complexity increases
- state restoration across virtualized surfaces must be handled intentionally
- image prefetch/focus behavior needs careful tuning

---

## ADR-013 — Navigation Restoration Strategy

### Status
Accepted

### Context
The product requires navigation memory such as:
- return from player to movie details
- return from episode player to season context
- app relaunch back into live playback context
- default-home fallback when no resumable context applies

### Decision
Use a layered restoration model:
- lightweight saveable state for minimal navigation anchors
- durable persisted restoration records for playback and browse context
- local database-backed restoration for heavyweight state

### Consequences
Benefits:
- avoids storing large state blobs in ephemeral UI state
- survives app recreation more reliably
- supports deep contextual restoration

Tradeoffs:
- restoration logic becomes a core feature
- requires careful versioning of restoration payloads
- edge cases must be well-tested across platforms

---

## ADR-014 — Observability Model

### Status
Accepted

### Context
The product requires:
- local-only observability
- logs
- metrics
- traces
- diagnostics without hosted external tooling

### Decision
Implement structured local observability with:
- structured logs
- local metrics
- trace/correlation IDs
- local diagnostic export capability
- optional future-compatible export pathways

### Consequences
Benefits:
- strong local debugging story
- privacy-friendly diagnostics
- easier import/sync/playback troubleshooting

Tradeoffs:
- local retention and rotation policies must be defined
- observability schemas must remain stable
- diagnostic tooling adds implementation effort
