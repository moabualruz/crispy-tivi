# IPTV App — V1 Technical Specification

> Note: §6 (Monorepo Structure) now points to monorepo-blueprint.md. §15.3 (Library) has been rewritten as "Catalog" and scoped to feature-movies + feature-series. The "library" noun elsewhere in this file has been renamed to "catalog". See [decisions.md](decisions.md) D1–D3 for rationale.

## 1. Purpose

Build a cross-platform IPTV media application that provides:

- IPTV source ingestion and management
- live channel browsing
- VOD and series browsing
- EPG support
- remote media playback
- shared product behavior across platforms
- a maintainable monorepo with strong code sharing

This specification covers technical scope only.
UI/UX requirements are intentionally excluded and will be defined in a separate specification.

---

## 2. V1 Product Targets

### V1 targets (all first-class, all ship together — see [decisions.md](decisions.md) D9, D15)
- Android
- iOS
- Windows
- macOS
- Linux
- Web

### Delivery strategy
- Android, iOS, and desktop are built with Kotlin Multiplatform and Compose Multiplatform
- Web is delivered as a full web application via the Kotlin web target
- All targets live in one monorepo and ship in V1

---

## 3. Technical Goals

The V1 system should aim for:

- shared domain logic across all targets
- shared design-system-capable UI foundation across Android, iOS, and desktop
- consistent application behavior across platforms
- reliable playback of remote IPTV media
- responsive operation with large provider datasets
- clear modularity for future expansion
- straightforward development and release workflow from one repository

---

## 4. High-Level Architecture

The application is organized around:

- shared core modules for domain, data, parsing, state, and reusable features
- platform application modules for Android, iOS, desktop, and web
- platform-specific playback integrations behind a shared player contract
- local persistence for fast browsing and offline-tolerant cached behavior
- network services for source refresh, EPG ingestion, and media metadata loading

### Architectural principles
- domain logic is shared wherever practical
- playback is exposed through a common abstraction
- provider/source handling is normalized into internal models
- feature modules remain isolated and testable
- platform-specific integrations are explicit and bounded

---

## 5. Technology Stack

### Primary language
- Kotlin

### UI framework
- Compose Multiplatform for Android, iOS, and desktop

### Web target
- Kotlin web target as a full web app
- hls.js for web playback integration

### Build system
- Gradle with Kotlin DSL

### Concurrency and reactivity
- Kotlin Coroutines
- Flow / StateFlow

### Serialization
- kotlinx.serialization

### Database
- SQLite as the storage engine
- SQLDelight as the Kotlin multiplatform database layer

### Networking
- Kotlin multiplatform HTTP stack such as Ktor

---

## 6. Monorepo Structure

See [monorepo-blueprint.md](monorepo-blueprint.md) for the authoritative module graph (resolved per [decisions.md](decisions.md) D1, D2, D4–D7, D10). SPEC-RAW's earlier coarse `core-*` layout is superseded.

---

## 7. Supported Content Types

V1 supports all of the following from launch:

- live channels
- VOD
- series

The internal data model must support these as first-class content types.

---

## 8. Supported Source Types

V1 supports:

- M3U / M3U8 sources
- Xtream sources
- Stalker sources
- XMLTV EPG sources

### Source management capabilities
The application should support:

- add source
- edit source
- remove source
- refresh source
- validate source
- enable/disable source
- authenticate source where needed
- persist source configuration and credentials

### Source normalization
All provider types should be normalized into shared internal models for:

- channels
- groups/categories
- movies
- series
- episodes where applicable
- logos/posters/artwork references
- source identities and refresh metadata

---

## 9. EPG Requirements

V1 includes full EPG capability.

### Required capabilities
- XMLTV ingestion
- channel-to-program mapping
- current program resolution
- next program resolution
- schedule browsing by channel
- time-based program browsing
- cached EPG browsing
- timezone-aware program handling

### EPG data handling
The system should support:

- source-specific channel matching
- normalized channel identifiers
- partial EPG availability
- refresh and replacement of outdated EPG data
- efficient lookup for current/next and schedule views

---

## 10. Playback Requirements

Playback is a core V1 capability.

### Shared playback contract
A shared player API must be defined for use by shared features and shared state.

The player contract should support:

- load media item
- load live channel
- play
- pause
- stop
- seek where applicable
- observe playback state
- observe buffering state
- observe playback position
- observe playback errors
- expose duration where applicable
- expose subtitle/audio track options where available
- expose media metadata relevant to playback state

### Platform playback implementations

#### Android
- native Android playback backend
- expected direction: Media3 / ExoPlayer

#### Apple platforms
- native Apple playback backend
- expected direction: AVPlayer / AVFoundation

#### Desktop
- dedicated desktop playback backend behind the shared player contract
- final implementation to be pinned after focused player-backend research

#### Web
- HLS-capable web playback using hls.js
- web playback should support live and media catalog playback where stream compatibility allows

### Playback session behavior
The playback layer should support:

- switching between items/channels
- observable state updates for the rest of the app
- integration with metadata needed by browse/play flows
- error propagation into app state
- future extension for track selection, subtitles, quality options, PiP, and background media features

---

## 11. Data Model Requirements

The system should define shared internal models for at least:

- source
- source credentials/configuration
- source refresh state
- channel
- channel group/category
- movie
- series
- season
- episode
- EPG program
- playback item
- favorite
- watch history item
- app settings
- cache metadata
- artwork/logo metadata
- search result entities

These models should be platform-agnostic and serializable.

---

## 12. Persistence Requirements

Local persistence is required for fast loading, cache reuse, and resilient browsing.

### Storage engine
- SQLite

### Persistence layer
- SQLDelight

### Persisted data
The database should support storage for:

- provider/source definitions
- source auth/configuration data
- channels
- groups/categories
- VOD/catalog entities
- EPG data
- favorites
- watch history
- recent searches
- settings
- refresh metadata
- cache references

### Persistence goals
- fast local queries for browse screens
- reliable migrations
- deterministic schema management
- support for large imported datasets
- easy reuse from shared Kotlin code

---

## 13. Networking Requirements

The networking layer should support:

- remote playlist retrieval
- remote EPG retrieval
- provider API calls
- authenticated requests
- redirects
- retries
- timeouts
- cancellation
- refresh workflows
- efficient large-response handling

### Network data workflows
The app should support:

- source bootstrap and validation
- refresh of provider catalogs
- refresh of EPG feeds
- retrieval of playback URLs and related metadata where provider type requires it

---

## 14. State Management Requirements

A shared application state architecture is required.

### State scope
The shared state system should support:

- source selection and source lifecycle state
- browse state for channels, groups, VOD, and series
- EPG time and schedule state
- favorites and history state
- search and filter state
- playback state
- loading/error states
- settings state

### Technical direction
The state model should be:

- reactive
- testable
- deterministic
- suitable for shared feature logic
- compatible with Compose-based UI consumption across targets

A concrete navigation/state pattern will be pinned separately, but V1 expects a shared state contract and feature-oriented state ownership.

---

## 15. Feature Requirements

### 15.1 Source Management
The app should support:
- source creation
- source editing
- source deletion
- source refresh
- source validation
- source credential handling
- source status reporting

### 15.2 Channels
The app should support:
- all channels listing
- grouping/categories
- source association
- favorites
- search/filtering
- current/next program association
- channel logo metadata where available

### 15.3 Catalog (Movies and Series)
The app should support catalog browsing through dedicated Movies and Series destinations:
- movies browsing (owned by `:feature:movies`)
- series browsing (owned by `:feature:series`)
- season/episode navigation where applicable (owned by `:feature:series`)
- artwork metadata where available
- source-aware content organization
- favorites and search/filtering integration

The term "Library" is reserved for the personal return-points destination (Continue Watching, Favorites, History, Saved positions, Recently Played Channels) owned by `:feature:library`. See [decisions.md](decisions.md) D3 and UIUX-SPEC §8.7.

### 15.4 EPG
The app should support:
- current/next program lookup
- schedule browsing
- channel-program association
- timeline-capable EPG data access

### 15.5 Search
The app should support searching across:
- channels
- movies
- series
- categories/groups where practical

### 15.6 Favorites and History
The app should support:
- favorites management
- recent playback history
- persisted history/favorites across sessions

---

## 16. Performance Requirements

The technical design should support responsive behavior with:

- large M3U playlists
- multiple providers
- large EPG datasets
- image-rich data sets
- long session lifetimes
- frequent source refreshes

### Performance goals
- non-blocking parsing and refresh
- efficient local querying
- scalable list/timeline data access
- stable playback state propagation
- efficient cache usage
- responsive browsing after initial import

---

## 17. Caching Requirements

The system should cache data needed for responsive browsing and reduced repeated work.

### Cache scope
The cache strategy should include:

- normalized source data
- EPG data
- image/artwork references and metadata
- refresh timestamps
- derived lookup structures where useful
- recent browse/playback context where useful

### Cache goals
- faster startup after initial sync
- reduced repeated parsing
- smoother operation during temporary network instability
- support for stale-aware browsing

---

## 18. Security and Credential Handling

The system should support secure handling of:

- provider usernames
- passwords
- tokens
- authenticated endpoint configuration

### Security goals
- platform-appropriate secure storage where available
- restricted exposure of credentials in logs and debug outputs
- clear credential update and invalidation flows

---

## 19. Logging and Diagnostics

The application should provide structured diagnostics for:

- source refresh lifecycle
- parsing results
- normalization/import counts
- EPG ingestion results
- database operations and failures
- playback state transitions
- playback failures
- network failures

### Logging goals
- useful development diagnostics
- clear production troubleshooting signals
- support for future diagnostic export/reporting

---

## 20. Testing Requirements

### Shared logic tests
V1 should include tests for:

- M3U parsing
- Xtream mapping/parsing
- Stalker mapping/parsing
- XMLTV parsing
- source validation logic
- data normalization
- EPG matching
- search/filter logic
- favorites/history behavior
- shared state and controller logic

### Persistence tests
V1 should include tests for:
- schema correctness
- migrations
- repository behavior
- large-dataset query behavior where practical

### Platform integration tests
V1 should include targeted integration testing for:
- Android playback integration
- iOS playback integration
- desktop playback integration
- web playback integration at the browser/player level where practical

---

## 21. V1 Late-Phase Features

> **Reclassified by [decisions.md](decisions.md) D16.** Formerly titled "Extensibility Requirements" and understood as post-V1. Now understood as V1 features that ship in the late phase of V1 (see [v1-phase-roadmap.md](v1-phase-roadmap.md) Phase 3). Nothing in this list is post-V1.

Every item below ships in V1:

- richer provider capabilities — Phase 3
- catch-up and archive support — Phase 3
- recording (local + provider-side where supported) — Phase 3
- subtitle controls (select + style + timing offset) — Phase 3
- audio-track controls — Phase 3
- picture-in-picture (all six platforms) — Phase 3
- background playback — Phase 2 (core MVP) and Phase 3 (policy refinement)
- casting (Google Cast + Apple AirPlay + DLNA fallback; see [open-questions.md](open-questions.md) R6) — Phase 3
- parental controls — Phase 3
- tablet / TV form-factor refinement — Phase 3 (baseline responsiveness is Phase 1)
- sync / export / import — already Phase 2 per SPEC Amendment K and [decisions.md](decisions.md) D12
- richer account management (multi-profile) — Phase 3

---

## 22. V1 Architecture Decisions Already Pinned

The following decisions are considered pinned for V1:

- Kotlin Multiplatform monorepo
- Compose Multiplatform for Android, iOS, and desktop
- full web target
- hls.js for web playback
- SQLite as storage engine
- SQLDelight as persistence layer
- support for M3U, Xtream, and Stalker
- support for live, VOD, and series
- full EPG support
- shared player API with platform-specific implementations

---

## 23. Technical Questions Still To Be Pinned

These remain active technical decisions inside the V1 architecture:

### 23.1 Desktop playback backend
A final desktop player backend needs to be selected after focused research and implementation tradeoff review.

### 23.2 Shared navigation/state pattern
A concrete technical pattern should be pinned for:
- shared navigation model
- feature state ownership
- controller/viewmodel boundaries
- app-wide versus feature-local state

### 23.3 Kotlin media implementation research
Research should confirm the strongest implementation patterns in Kotlin/Compose ecosystems for:
- TS stream playback
- HLS stream playback
- remote media playback
- shared media-state coordination across platforms

---

## 24. Out of Scope for This Specification

This document does not define:

- visual design language
- layout behavior
- interaction patterns
- navigation UX
- branding
- theming rules
- accessibility UX details
- motion/animation rules
- screen-by-screen UX requirements

These will be defined separately in the UI/UX specification.

---

## Amendment — Technical Requirements Addendum

### A. Scope Boundary
This technical specification defines architecture, data, platform, performance, and implementation requirements only.

Interaction design, visual design, navigation UX, layout behavior, component behavior, motion, accessibility UX, and all other user-experience decisions are defined in a separate UI/UX specification and are out of scope for this document.

---

### B. Terminology Standardization
The specification shall use standard engineering terminology.

For performance and rendering requirements, the preferred terms are:
- virtualized rendering
- windowed rendering
- lazy composition
- viewport-based composition

These terms describe the requirement that large surfaces render only the visible region plus a controlled buffer, rather than composing full datasets.

---

### C. Design System Architecture
The design system shall be centrally configurable and token-driven.

All visual and interaction primitives shall be defined through reusable system-level tokens and semantic component definitions rather than hard-coded values inside feature views or widgets.

This includes, at minimum:
- color tokens
- typography tokens
- spacing tokens
- sizing tokens
- shape/radius tokens
- elevation/depth tokens
- border and divider tokens
- interaction tokens
- focus tokens
- selection tokens
- motion tokens
- component-variant tokens

Feature screens and reusable components shall consume semantic design tokens rather than embedding raw values directly.

The design system architecture shall support future global edits and re-theming with minimal feature-level code changes.

---

### D. Rendering and Collection Performance
All large or potentially unbounded collections shall use virtualized and windowed rendering.

The application shall use lazy composition and viewport-based rendering for data-dense surfaces, including but not limited to:
- channel lists
- category/group lists
- content rails
- posters/grids
- search results
- history/favorites lists
- EPG channel rows
- EPG timeline/program cells
- settings collections where scalable list behavior is beneficial

The rendering model shall aim to minimize:
- memory usage during navigation
- CPU usage during scrolling
- composition of off-screen content
- unnecessary image loading
- unnecessary layout/recomposition work

For timeline and guide-like surfaces, the system shall support both vertical and horizontal windowing where applicable.

---

### E. Source-Agnostic UI and Workflow Model
UI-facing workflows, feature logic, and view models shall operate on normalized internal content models rather than provider-specific source formats.

The application shall treat provider families such as:
- M3U
- Xtream
- Stalker
- future sources such as Jellyfin or similar integrations

as backend/data-layer concerns.

Provider-specific formats shall be normalized into shared internal models before reaching UI-facing feature flows.

The normalized model shall support, at minimum:
- source
- source grouping metadata
- content type
- live channel
- movie
- series
- season
- episode
- program/EPG item
- artwork/logo metadata
- playback item
- favorites/history entities

This requirement ensures that feature workflows and UI models remain stable as additional source types are added over time.

---

### F. Source as a First-Class Organizational Dimension
Source identity shall remain a first-class grouping and filtering dimension throughout the application.

The architecture shall support source-aware browsing and filtering while preserving source-agnostic UI workflows.

The system shall support:
- browsing across all enabled sources
- browsing within a single selected source
- browsing within an arbitrary subset of selected sources
- filtering sources in or out dynamically
- preserving source attribution on normalized content
- exposing source name as a super-grouping dimension above content type and subgroup/category levels

Source-aware organization shall support hierarchies such as:
- All Sources
- One Source
- Multiple Selected Sources

Within any active source scope, the system shall support normalized content partitions such as:
- Live
- Movies
- Series

and then subgroup/category navigation beneath those normalized partitions.

---

### G. Multi-Source Capability
The system shall support multiple configured sources concurrently.

This includes:
- multiple sources of the same provider type
- multiple sources of different provider types
- multiple accounts/endpoints active at the same time
- mixed-source browsing across enabled sources
- selective source inclusion/exclusion
- source-level filtering without breaking normalized feature workflows

Examples of supported concurrent configurations include:
- multiple M3U sources
- multiple Xtream sources
- multiple Stalker sources
- mixed M3U + Xtream + Stalker configurations
- future mixed-source configurations that may include additional provider families

This requirement applies across all relevant browse, search, favorites, history, and playback preparation workflows.

---

### H. Shared Browse Model Across Sources
The technical browse model shall support a consistent navigation structure across mixed-source datasets.

The system shall allow browsing by:
- source scope
- content type
- subgroup/category
- favorites
- history
- search results
- other normalized feature views

Browse orchestration shall support both:
- aggregate views spanning multiple sources
- scoped views limited to one or more chosen sources

The browse architecture shall not require feature flows to branch by provider family in order to render or navigate core content structures.

---

### I. Data and Backend Responsibility Boundary
Backend/data-layer adapters are responsible for:
- ingesting provider-specific payloads
- authenticating with provider-specific systems
- parsing provider-specific structures
- mapping provider-specific group/category structures
- normalizing provider-specific content into shared entities
- preserving source attribution and grouping metadata

UI-facing layers are responsible for:
- consuming normalized models
- rendering normalized feature flows
- applying source-aware filtering and grouping
- remaining independent from provider-specific implementation details

---

### J. Compose Implementation Guidance
The technical implementation shall favor configurable design-system primitives and efficient lazy rendering patterns supported by Compose. Android’s Compose guidance explicitly supports custom design systems and lazy lists/grids, which aligns with the requirements above. :contentReference[oaicite:0]{index=0}



## Amendment — Final Technical Requirements Addendum

### A. Scope Boundary
This technical specification defines architecture, data, platform, persistence, playback, performance, observability, and implementation requirements only.

Interaction design, visual design, layout behavior, component behavior, motion, accessibility UX, navigation UX, and all other user-experience decisions are defined in a separate UI/UX specification and are out of scope for this document.

---

### B. Desktop Playback Backend

> **Superseded by [decisions.md](decisions.md) D14.** The desktop playback backend is a phase-1 research task. libVLC/vlcj is one candidate alongside JavaFX MediaPlayer, JavaCV/FFmpeg, and mpv bindings. Until the research lands, `:platform:player:desktop` is a stub that fails fast. The rest of this section remains as the *acceptance criteria* for whichever backend is chosen.

The desktop playback implementation shall remain isolated behind the shared player API so the backend can be replaced or supplemented later without changing feature-layer workflows.

The desktop player integration shall support, at minimum:
- remote URL playback
- local file playback where applicable
- live stream playback
- subtitle integration
- playback state observation
- error propagation
- fullscreen support
- track and media metadata access where available

---

### C. Shared Navigation and State Restoration
The application shall use a shared navigation and state-restoration architecture designed around **navigation memory**, **persistent restoration**, and **minimal transient state storage**.

The system shall preserve enough state to restore the user back to the correct context after:
- screen recreation
- app recreation
- normal app relaunch
- process death where platform support allows restoration through persisted state

The system shall support restoring:
- screen stack context
- selected content item context
- selected season/episode context
- selected source/filter context
- selected channel context
- player context
- browse context

Required restoration behaviors include:
- exiting a movie player returns to that movie’s details context
- exiting an episode player returns to the correct series/season/episode details context
- reopening the app while a live channel was previously active restores that channel and may autoplay it according to app policy
- reopening the app after movie or series playback restores the content details context rather than forcing immediate autoplay
- reopening the app without resumable context restores the default application entry state

The state model shall distinguish between:
- transient UI state
- navigation/back-stack state
- durable feature state
- durable playback context

Only the minimum state required for restoration shall be stored in saveable platform state containers. Larger or durable restoration state shall be rehydrated from local persistent storage.

---

### D. Search Architecture
The application shall provide full-featured indexed search across normalized content.

Search shall support:
- channels
- live content
- movies
- series
- seasons and episodes where applicable
- source names
- groups/categories
- EPG program titles where indexed
- aliases and alternate names where available

The search layer shall use **SQLite FTS5** as the full-text indexing mechanism.

Search shall support:
- full-text matching
- phrase matching
- prefix matching
- boolean filtering where applicable
- ranking by relevance
- ranking boosts by field importance
- source filtering
- content-type filtering
- live/VOD/series filtering
- optional quality/rating-based secondary ordering where applicable

Ranking shall prioritize:
- textual relevance first
- exact/phrase matches above loose matches
- title and canonical-name fields above secondary metadata
- source/filter constraints
- content quality signals such as rating/popularity as secondary tie-breakers where available

Search shall operate across:
- all enabled sources
- a single selected source
- any selected subset of sources

---

### E. Deduplication, Channel Identity, and Multi-Source Playback
The system shall support both **separate-source views** and **merged aggregate views**.

When content is viewed under source-filtered scopes, source items remain separate and preserve source identity.

When content is viewed under aggregate multi-source scopes, equivalent items may be merged into unified normalized entries.

For live channels:
- equivalent channels may map to one normalized channel entry in aggregate views
- the player model shall remain aware of all available backing sources for that normalized channel
- the user shall be able to switch playback source when multiple playable source variants are available for the same normalized channel

For EPG:
- one normalized channel should resolve to one logical EPG result at presentation time
- XMLTV-style EPG data shall be parsed and indexed independently from playback items
- XMLTV matching shall occur at runtime or query time rather than being permanently hard-bound at parse time
- source-provided on-demand EPG, such as Xtream or Stalker per-channel program retrieval, may be fetched on demand and integrated into the same normalized EPG presentation layer

The system shall support iterative refinement of EPG matching logic without requiring a full source re-import.

---

### F. Sync and Refresh Policy
If no source is configured, the application shall require onboarding into source setup before normal content browsing is available.

Initial source onboarding shall require:
- source creation
- source validation
- initial data sync
- local persistence of the synchronized result

Normal application use shall begin only after the initial required content state is fully synchronized and saved.

After onboarding, the application shall support scheduled and opportunistic refresh without blocking normal use.

Refresh behavior shall include:
- startup refresh checks
- scheduled refresh execution
- refresh only when last-sync age exceeds configured policy
- non-blocking refresh during normal app usage
- UPSERT-based persistence to avoid duplication
- partial refresh support
- retry and backoff behavior
- stale-state awareness

The refresh pipeline shall distinguish between:
- source metadata refresh
- catalog/content refresh
- EPG refresh
- artwork refresh
- playback URL refresh where provider type requires it

---

### G. Image and Artwork Pipeline
The application shall use a **disk-first image pipeline** optimized for media-heavy workloads and bounded memory use.

The image system shall support:
- artwork and logo loading from remote URLs
- disk caching
- bounded in-memory caching
- request cancellation for off-screen items
- image downsampling/resizing
- placeholder/fallback handling
- broken image recovery
- lazy loading tied to viewport visibility
- optional nearby-item prefetching with strict limits

The image pipeline shall minimize:
- RAM growth during long sessions
- decoding of oversized assets
- loading of off-screen artwork
- repeated network fetches for frequently reused artwork

The implementation may use a multiplatform-capable image loader with configurable cache policy.

---

### H. Error Model
The application shall define a normalized error model spanning:
- source validation errors
- source authentication errors
- parsing/import errors
- EPG matching errors
- artwork loading errors
- search/indexing errors
- playback preparation errors
- playback runtime errors
- sync/refresh errors
- persistence errors

Errors shall be classified at minimum by:
- severity
- recoverability
- source scope
- affected feature domain
- user-safe message
- diagnostic payload

The system shall support:
- user-visible actionable errors
- internal diagnostic detail
- retryable operation metadata
- structured logging of failures
- source health/state indicators

---

### I. Media Session, Background Playback, and System Controls
The application shall integrate with platform media session and system playback infrastructure.

Required capabilities include:
- now-playing metadata publication
- media key handling
- remote control command handling
- lock-screen or system-surface playback integration where supported
- headset/controller/media-button support where supported
- consistent player state propagation into platform media session APIs

Platform-specific implementations shall support:
- Android `MediaSession`
- Apple now-playing and remote-command infrastructure
- desktop media-session integration where feasible by platform

The playback subsystem shall also define:
- interruption handling
- resume policy
- focus-loss policy
- background playback policy
- autoplay resume policy after app relaunch

---

### J. Credential and Secret Handling
Credentials and tokens shall not be stored in plaintext inside the general application database.

Sensitive values shall be stored using platform-appropriate secure storage mechanisms.

At minimum:
- Android implementations shall use Keystore-backed protection
- Apple implementations shall use Keychain-backed protection

The application shall support:
- secure credential update
- secure credential deletion
- redaction of secrets from logs
- separation of durable source metadata from secret material

The database may store non-sensitive source metadata and stable identifiers needed to rebind secure secrets stored outside the database.

---

### K. Export and Import
The application shall support full export and import of app state for Crispy-Tivi to Crispy-Tivi migration and backup.

The backup format may be:
- a ZIP containing multiple JSON documents, or
- a single JSON document, or
- another documented local backup container format

The format shall be versioned.

Export/import scope shall support, at minimum:
- sources
- source metadata
- source filter/group configuration
- favorites
- history
- settings
- normalized content cache metadata where appropriate
- EPG-related configuration
- app preferences

The system shall define a clear policy for secrets during export/import, including whether secrets are:
- excluded,
- separately protected,
- or included only in encrypted form.

Import shall support:
- validation
- schema-version checks
- partial failure reporting
- safe merge or replace modes

---

### L. Web Parity and Orientation Policy
The web target shall aim for functional parity in feature workflow, product behavior, and content model with native targets.

The web application shall follow the same core workflow model as Android, iOS, and desktop, including:
- source management
- multi-source browsing
- live/VOD/series support
- search
- favorites/history
- EPG flows
- playback flows where supported by the web playback stack

The application product model shall remain **landscape-first across all targets**.

On phones and tablets, the native application shall enforce landscape-oriented operation and support 180-degree rotation between landscape orientations.

The application shall use a scaled layout model rather than a separate portrait/mobile reflow model.

For web:
- the application shall prefer landscape presentation
- orientation locking may be applied where browser support allows
- the product shall still preserve the same workflow and visual scaling model when hard orientation lock is not available

---

### M. Observability and Local Diagnostics
The application shall provide full local observability without requiring external hosted services.

Observability shall cover:
- logs
- metrics
- traces
- import/sync diagnostics
- search/index diagnostics
- playback diagnostics
- cache diagnostics
- source-health diagnostics

The observability model shall use structured event schemas and support local export/storage.

The system shall support:
- local diagnostic log files
- traceable operation IDs
- correlation between logs, metrics, and traces
- optional OTLP-compatible export paths for future use
- development-mode inspection surfaces
- local debug/diagnostic views inside the application where appropriate

Observability shall remain useful even when entirely local-only.

---

### N. Multiple Concurrent Sources
The system shall support multiple configured sources concurrently, including:
- multiple sources of the same provider family
- multiple sources of different provider families
- simultaneous browsing across all enabled sources
- selective source inclusion/exclusion
- source-specific and cross-source views
- source attribution on normalized items
- player awareness of multiple playable source variants for one normalized channel or item

This requirement applies across:
- browse
- search
- favorites
- history
- playback preparation
- EPG resolution
- export/import
- sync and diagnostics
