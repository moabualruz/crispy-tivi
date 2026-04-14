# Crispy-Tivi — API and Contract Specification Draft

## 1. Purpose

This document defines the recommended shared contracts and interface boundaries for Crispy-Tivi.

This is a draft contract map, not a permanently frozen API.

---

## 2. Required Planning Note

The planner and applier of this API/contracts document must **re-research and re-evaluate the final contracts using the most recent project requirements, real implementation pressure, current platform constraints, and up-to-date online research** before hard-committing the final API surface.

This applies especially to:
- Compose Multiplatform/navigation APIs
- platform playback backends
- desktop player backend integration details
- hls.js/web playback capabilities
- secure storage APIs
- import/export requirements
- search/indexing capabilities
- observability APIs

This document should be treated as a high-quality starting draft, not a final immutable contract set.

---

## 3. Contract Design Rules

All contracts should aim for:
- small focused interfaces
- domain-meaningful names
- typed inputs/outputs
- explicit failure semantics
- source-agnostic shared models
- capability separation where behavior differs
- replaceable implementations

Avoid:
- giant “manager” interfaces
- platform leakage into shared contracts
- provider-specific DTOs crossing feature boundaries
- excessively generic APIs with weak semantics

---

## 4. Source Adapter Contracts

## 4.1 SourceAdapter
Purpose:
- ingest and sync one source type

Suggested responsibilities:
- validate source configuration
- fetch source payloads
- parse source payloads
- emit normalized import payloads
- expose source capability metadata

Suggested shape:
- `validate(config): ValidationResult`
- `sync(config, syncContext): SourceSyncResult`
- `capabilities(): SourceCapabilities`

## 4.2 SourceCapabilities
Purpose:
- describe what a source/provider supports

Suggested fields:
- source type
- live supported
- movies supported
- series supported
- XMLTV-compatible external EPG supported
- on-demand EPG supported
- grouping support
- search hints
- authentication type hints
- artwork availability hints

## 4.3 SourceAdapterFactory
Purpose:
- resolve a provider adapter by source type and capability context

Suggested input:
- source type
- runtime/platform context if required

Suggested output:
- `SourceAdapter`

---

## 5. Repository Contracts

## 5.1 SourcesRepository
Purpose:
- source lifecycle and source metadata access

Suggested responsibilities:
- create/update/delete source
- list sources
- enable/disable source
- get source status
- get source capabilities
- request source validation

## 5.2 CatalogRepository
Purpose:
- normalized content browsing access

Suggested responsibilities:
- query live channels
- query movies
- query series
- query source-scoped and aggregate content
- query by source scope
- query by group/category
- query details by normalized IDs

## 5.3 EpgRepository
Purpose:
- EPG program access and schedule resolution

Suggested responsibilities:
- get current/next program
- get schedule window
- resolve normalized channel schedule
- trigger EPG refresh where needed
- inspect mapping/match metadata where diagnostics require it

## 5.4 SearchRepository
Purpose:
- indexed search access

Suggested responsibilities:
- search normalized content
- search with filters
- search by source scope
- search by content type
- maintain or rebuild index where required

## 5.5 HistoryRepository
Purpose:
- playback history and continue-watching access

## 5.6 FavoritesRepository
Purpose:
- favorites management

## 5.7 SettingsRepository
Purpose:
- persisted preferences and app settings

## 5.8 RestorationRepository
Purpose:
- persist and retrieve restoration records

## 5.9 DiagnosticsRepository
Purpose:
- retrieve/export local diagnostics state

---

## 6. Playback Contracts

## 6.1 PlaybackBackend
Purpose:
- one platform/backend-specific player implementation

Suggested responsibilities:
- load selection
- play
- pause
- stop
- seek
- release
- expose current player state stream
- expose playback errors
- expose track metadata where available

Suggested outputs:
- `StateFlow<PlayerState>`
- `Flow<PlayerEvent>` where needed

## 6.2 PlaybackFacade
Purpose:
- orchestrate playback lifecycle above backend level

Suggested responsibilities:
- resolve playback selection
- attach chosen backend
- update history
- update restoration state
- update platform media session
- support source switching
- expose unified playback state

## 6.3 PlaybackSelectionService
Purpose:
- select one playback variant from many candidates

Suggested inputs:
- aggregate entity
- source scope
- source priority policy
- user override if present

Suggested output:
- `ResolvedPlaybackSelection`

## 6.4 PlaybackBackendFactory
Purpose:
- resolve backend implementation by platform/runtime

---

## 7. EPG Contracts

## 7.1 EpgMatcher
Purpose:
- match normalized channels to EPG sources/program data

Suggested responsibilities:
- compute mapping candidates
- resolve runtime match
- expose confidence and strategy used

## 7.2 EpgScheduleResolver
Purpose:
- produce current/next/window schedule from stored and/or on-demand EPG sources

## 7.3 EpgIngestionService
Purpose:
- parse/store/update XMLTV-style and other EPG inputs

---

## 8. Search Contracts

## 8.1 SearchIndexer
Purpose:
- build and update local search index

## 8.2 SearchService
Purpose:
- execute ranked searches across normalized content

Suggested responsibilities:
- tokenize/prepare query
- apply source scope
- apply content-type filters
- apply ranking strategy
- return normalized results

## 8.3 SearchRankingStrategy
Purpose:
- own ranking and tie-break decisions

---

## 9. Sync Contracts

## 9.1 SyncFacade
Purpose:
- orchestrate sync lifecycle across sources and subsystems

Suggested responsibilities:
- onboarding sync
- scheduled refresh
- startup refresh checks
- partial refresh
- diagnostics emission
- stale-state marking

## 9.2 SyncScheduler
Purpose:
- decide whether sync is due

## 9.3 SyncPolicy
Purpose:
- define startup/scheduled refresh rules

## 9.4 SyncObserver
Purpose:
- expose sync progress/state as structured streams

---

## 10. Restoration Contracts

## 10.1 RestorationService
Purpose:
- resolve what state to restore at app launch or flow return

Suggested responsibilities:
- inspect restoration records
- derive launch destination/context
- decide autoplay eligibility
- restore contextual navigation anchors

## 10.2 RestorationPolicy
Purpose:
- define restore/autoplay rules

## 10.3 RestorationRecorder
Purpose:
- write restoration records during relevant lifecycle transitions

---

## 11. Image Contracts

## 11.1 ImageLoaderContract
Purpose:
- load/cancel images by normalized image request

## 11.2 ImagePolicy
Purpose:
- define memory/disk/prefetch/downsample rules

## 11.3 ArtworkResolver
Purpose:
- resolve the best artwork asset for a requested surface

---

## 12. Security Contracts

## 12.1 SecretStore
Purpose:
- store/retrieve/delete source secrets securely

Suggested responsibilities:
- put secret
- get secret
- delete secret
- rotate secret binding if needed

## 12.2 SecretRef
Purpose:
- represent non-plaintext reference from normal persistence into secure storage

---

## 13. Import/Export Contracts

## 13.1 BackupExporter
Purpose:
- create local backup bundle

## 13.2 BackupImporter
Purpose:
- validate and import local backup bundle

## 13.3 BackupFormatCodec
Purpose:
- encode/decode backup payload format

## 13.4 ImportMergePolicy
Purpose:
- control merge vs replace behavior

---

## 14. Observability Contracts

## 14.1 AppLogger
Purpose:
- structured local logs

## 14.2 MetricsRecorder
Purpose:
- local metric emission

## 14.3 TraceRecorder
Purpose:
- correlation and trace spans/events

## 14.4 DiagnosticsBundleExporter
Purpose:
- assemble exportable local diagnostic bundle

---

## 15. Navigation Contracts

## 15.1 AppDestination
Purpose:
- typed destination identity

## 15.2 Navigator
Purpose:
- abstract navigation operations used by state holders

## 15.3 NavigationRestorationAnchor
Purpose:
- represent lightweight route/context restoration payload

---

## 16. Contract Output Models

The following output models should remain shared and stable:

- `ValidationResult`
- `SourceSyncResult`
- `SourceCapabilities`
- `ResolvedPlaybackSelection`
- `PlayerState`
- `PlayerEvent`
- `SearchQuery`
- `SearchResult`
- `ScheduleWindow`
- `RestorationDecision`
- `SyncStatus`
- `SyncProgress`
- `DiagnosticsBundleInfo`

These models should be revisited during implementation planning with current project context.

---

## 17. Required Revalidation by Planner/Applier

Before implementation hard-commit, the planner and applier must revalidate:
- interface size and ownership
- capability splits
- async/state shape
- error/result types
- whether some contracts should merge or split
- whether contracts need platform-specific capability subinterfaces
- whether current platform/runtime/library behavior changes any assumptions

This revalidation must use:
- most recent project requirements
- current codebase realities
- current platform constraints
- current online documentation and ecosystem research
