# Normalized Data Model Specification

## 1. Purpose

This document defines the normalized internal data model for Crispy-Tivi.

The goals of the normalized model are:
- source-agnostic feature workflows
- source-aware browse and filter behavior
- stable IDs and relationships
- support for multi-source coexistence
- support for aggregate and source-scoped views
- support for live, movies, series, EPG, search, playback, favorites, and history

---

## 2. Modeling Principles

### 2.1 Source-agnostic UI model
Provider-specific payloads shall not flow directly into feature/UI-facing logic.

### 2.2 Source-aware provenance
Every normalized item shall preserve source provenance and source-specific variant linkage.

### 2.3 Aggregate-first capability
The model shall support both:
- source-scoped item identity
- aggregate normalized identity across sources

### 2.4 Stable relationships
The model shall define stable parent/child relationships for:
- source hierarchies
- content hierarchies
- EPG relationships
- playback variants
- browse structures

---

## 3. Core Identity Model

The system shall use multiple identity layers.

### 3.1 Raw source identity
Represents the provider-native identity of an imported entity.

Examples:
- M3U channel URL entry ID
- Xtream stream ID
- Stalker channel ID
- future provider-native IDs

### 3.2 Source-scoped normalized identity
Represents a normalized entity inside one source scope.

Examples:
- one channel inside one source
- one movie inside one source
- one series inside one source

### 3.3 Aggregate identity
Represents a merged identity across multiple equivalent source-scoped entities.

Examples:
- one normalized channel composed from multiple source variants
- one normalized movie composed from multiple source variants
- one normalized series composed from multiple source variants

---

## 4. Primary Entities

## 4.1 Source
Represents one configured provider endpoint or imported provider dataset.

Fields:
- `sourceId`
- `sourceType` (`M3U`, `XTREAM`, `STALKER`, future)
- `sourceName`
- `sourceDisplayName`
- `sourceEnabled`
- `sourcePriority`
- `sourceCreatedAt`
- `sourceUpdatedAt`
- `lastSyncAt`
- `lastSuccessfulSyncAt`
- `lastEpgSyncAt`
- `sourceStatus`
- `sourceRegion`
- `sourceLanguage`
- `sourceConfigRef`
- `secretRef`
- `diagnosticState`

### Notes
- multiple sources of the same type are allowed
- source identity is always preserved

---

## 4.2 Source Scope
Represents the active source selection scope used by browse/search/playback.

Fields:
- `scopeType` (`ALL`, `ONE`, `SUBSET`)
- `selectedSourceIds`

### Notes
- this is a runtime orchestration model
- it is not necessarily persisted as a top-level table, but should exist as a normalized concept

---

## 4.3 Source Group
Represents a provider-specific or normalized grouping under a source.

Fields:
- `groupId`
- `sourceId`
- `groupType` (`LIVE_GROUP`, `MOVIE_GROUP`, `SERIES_GROUP`, future)
- `providerGroupKey`
- `groupName`
- `groupDisplayName`
- `groupOrder`
- `groupMetadata`

### Notes
- groups may be provider-defined
- future normalization may introduce synthetic groups
- group identity remains source-aware

---

## 4.4 Content Type
Normalized content-type partition.

Enum values:
- `LIVE`
- `MOVIE`
- `SERIES`

---

## 4.5 Channel Variant
Represents one source-specific live channel variant.

Fields:
- `channelVariantId`
- `sourceId`
- `providerItemId`
- `aggregateChannelId` nullable
- `sourceGroupId`
- `canonicalName`
- `displayName`
- `alternateNames`
- `number`
- `logoRef`
- `streamRef`
- `language`
- `region`
- `qualityHints`
- `drmHints`
- `providerMetadata`
- `sortKey`
- `playbackAvailability`
- `epgMatchHints`

### Notes
- one source may have one or more variants for semantically similar channels
- variants remain directly playable

---

## 4.6 Aggregate Channel
Represents a merged channel across one or more source-specific variants.

Fields:
- `aggregateChannelId`
- `canonicalName`
- `displayName`
- `normalizedAliases`
- `logoRef`
- `contentType` = `LIVE`
- `preferredVariantPolicy`
- `mergedVariantCount`
- `dedupConfidence`
- `region`
- `language`

### Relationships
- one aggregate channel → many channel variants
- one aggregate channel → one logical EPG presentation target

---

## 4.7 Movie Variant
Represents one source-specific movie entry.

Fields:
- `movieVariantId`
- `sourceId`
- `providerItemId`
- `aggregateMovieId` nullable
- `sourceGroupId`
- `canonicalTitle`
- `displayTitle`
- `originalTitle`
- `year`
- `rating`
- `genres`
- `summary`
- `posterRef`
- `backdropRef`
- `streamRef`
- `duration`
- `language`
- `providerMetadata`
- `playbackAvailability`

---

## 4.8 Aggregate Movie
Represents a merged movie identity across one or more source-specific variants.

Fields:
- `aggregateMovieId`
- `canonicalTitle`
- `displayTitle`
- `originalTitle`
- `year`
- `rating`
- `genres`
- `summary`
- `posterRef`
- `backdropRef`
- `variantCount`
- `dedupConfidence`

---

## 4.9 Series Variant
Represents one source-specific series entry.

Fields:
- `seriesVariantId`
- `sourceId`
- `providerItemId`
- `aggregateSeriesId` nullable
- `sourceGroupId`
- `canonicalTitle`
- `displayTitle`
- `originalTitle`
- `year`
- `rating`
- `genres`
- `summary`
- `posterRef`
- `backdropRef`
- `providerMetadata`

---

## 4.10 Aggregate Series
Represents a merged series identity across one or more source variants.

Fields:
- `aggregateSeriesId`
- `canonicalTitle`
- `displayTitle`
- `originalTitle`
- `year`
- `rating`
- `genres`
- `summary`
- `posterRef`
- `backdropRef`
- `variantCount`
- `dedupConfidence`

---

## 4.11 Season Variant
Represents one source-specific season under a series variant.

Fields:
- `seasonVariantId`
- `sourceId`
- `seriesVariantId`
- `aggregateSeasonId` nullable
- `seasonNumber`
- `displayName`
- `posterRef`
- `providerMetadata`

---

## 4.12 Aggregate Season
Represents a merged season identity.

Fields:
- `aggregateSeasonId`
- `aggregateSeriesId`
- `seasonNumber`
- `displayName`
- `variantCount`

---

## 4.13 Episode Variant
Represents one source-specific episode.

Fields:
- `episodeVariantId`
- `sourceId`
- `seriesVariantId`
- `seasonVariantId`
- `aggregateEpisodeId` nullable
- `episodeNumber`
- `seasonNumber`
- `canonicalTitle`
- `displayTitle`
- `summary`
- `thumbnailRef`
- `duration`
- `rating`
- `streamRef`
- `providerMetadata`
- `playbackAvailability`

---

## 4.14 Aggregate Episode
Represents a merged episode identity.

Fields:
- `aggregateEpisodeId`
- `aggregateSeriesId`
- `aggregateSeasonId`
- `seasonNumber`
- `episodeNumber`
- `canonicalTitle`
- `displayTitle`
- `summary`
- `thumbnailRef`
- `duration`
- `rating`
- `variantCount`
- `dedupConfidence`

---

## 4.15 Artwork Asset
Represents normalized artwork/logos/images.

Fields:
- `artworkId`
- `artworkType` (`LOGO`, `POSTER`, `BACKDROP`, `THUMBNAIL`, future)
- `remoteUrl`
- `cacheKey`
- `mimeType`
- `width`
- `height`
- `dominantColorHint`
- `lastFetchedAt`
- `fetchStatus`

### Notes
- image pipeline operates on these references
- feature layers should not depend directly on raw remote URLs when avoidable

---

## 4.16 Playback Variant
Represents a concrete playable source-backed media variant.

Fields:
- `playbackVariantId`
- `sourceId`
- `contentKind` (`LIVE`, `MOVIE`, `EPISODE`)
- `parentEntityId`
- `streamRef`
- `protocolHints`
- `qualityHints`
- `audioHints`
- `subtitleHints`
- `drmHints`
- `providerMetadata`
- `availabilityState`
- `priorityWithinSource`

### Notes
- this is the unit used by the player backend
- aggregate content may resolve to multiple playback variants

---

## 4.17 EPG Program
Represents one normalized guide program entry.

Fields:
- `programId`
- `epgSourceId`
- `title`
- `subtitle`
- `description`
- `startAt`
- `endAt`
- `categories`
- `rating`
- `artworkRef`
- `providerMetadata`
- `matchStatus`

### Notes
- program rows are stored independently from final channel binding
- runtime matching resolves programs to normalized channels

---

## 4.18 EPG Channel Mapping Candidate
Represents a mapping candidate between EPG channel data and normalized channels.

Fields:
- `mappingCandidateId`
- `aggregateChannelId`
- `epgSourceId`
- `epgChannelKey`
- `matchScore`
- `matchStrategy`
- `isApproved`
- `lastEvaluatedAt`

### Notes
- allows iterative refinement of runtime matching
- supports diagnostics and tuning

---

## 4.19 Favorite
Represents a persisted favorite relationship.

Fields:
- `favoriteId`
- `favoriteKind` (`CHANNEL`, `MOVIE`, `SERIES`, `EPISODE`)
- `targetAggregateId`
- `targetVariantId` nullable
- `sourceScopeMode`
- `createdAt`
- `favoriteMetadata`

### Notes
- favorites may target aggregate identity by default
- source-specific favorites can still be supported when needed

---

## 4.20 History Entry
Represents recently viewed content or playback history.

Fields:
- `historyId`
- `historyKind` (`CHANNEL`, `MOVIE`, `EPISODE`)
- `targetAggregateId`
- `targetVariantId` nullable
- `sourceId` nullable
- `lastPlayedAt`
- `playheadPosition`
- `completionState`
- `resumeEligible`
- `historyMetadata`

---

## 4.21 App Setting
Represents persisted application configuration.

Fields:
- `settingKey`
- `settingValue`
- `settingType`
- `settingScope` (`GLOBAL`, `SOURCE`, `DEVICE`, future)
- `updatedAt`

---

## 4.22 Sync Record
Represents sync lifecycle metadata for a source or subsystem.

Fields:
- `syncRecordId`
- `sourceId`
- `syncDomain` (`CATALOG`, `EPG`, `ARTWORK`, `FULL`, future)
- `startedAt`
- `finishedAt`
- `resultState`
- `insertCount`
- `updateCount`
- `errorCount`
- `syncCursor`
- `diagnosticRef`

---

## 4.23 Search Document
Represents the indexed search projection of a normalized entity.

Fields:
- `searchDocumentId`
- `entityKind`
- `aggregateId`
- `sourceIds`
- `title`
- `alternateNames`
- `description`
- `genres`
- `categories`
- `rating`
- `contentType`
- `ftsPayload`
- `rankBoosts`

### Notes
- logical model only; implementation may materialize this differently

---

## 4.24 Restoration Record
Represents durable navigation/playback restoration state.

Fields:
- `restorationId`
- `restorationKind` (`HOME`, `CHANNEL`, `MOVIE`, `SERIES`, `SEASON`, `EPISODE`)
- `aggregateId` nullable
- `variantId` nullable
- `sourceScope`
- `navigationPath`
- `resumePolicy`
- `autoplayEligible`
- `savedAt`

---

## 5. Relationships

### 5.1 Source relationships
- one source → many source groups
- one source → many channel/movie/series variants
- one source → many playback variants
- one source → many sync records

### 5.2 Aggregate relationships
- one aggregate channel → many channel variants
- one aggregate movie → many movie variants
- one aggregate series → many series variants
- one aggregate season → many season variants
- one aggregate episode → many episode variants

### 5.3 Content hierarchy
- one aggregate series → many aggregate seasons
- one aggregate season → many aggregate episodes

### 5.4 Playback relationships
- one aggregate entity → many playback variants
- one playback variant → one source
- one playback variant → one source-backed item

### 5.5 EPG relationships
- one aggregate channel → zero or many mapping candidates
- runtime resolution determines active program set

---

## 6. Deduplication Model

## 6.1 Separate-source mode
When browsing inside a source-scoped view:
- items remain separate by source
- provider attribution is explicit
- no aggregate merge is required for presentation

## 6.2 Aggregate mode
When browsing inside multi-source or all-source views:
- equivalent source-scoped entities may map into one aggregate entity
- source variants remain attached beneath the aggregate entity
- playback can choose or switch among variants

## 6.3 Deduplication signals
Deduplication may consider:
- canonical title/name normalization
- alternate names
- source metadata
- numbering
- region/language
- provider IDs where cross-provider equivalence is known
- runtime/manual tuning metadata

---

## 7. Browse Model

The browse system shall support these dimensions simultaneously:
- source scope
- content type
- group/category
- favorites
- history
- search results

A browse result item should be representable through normalized view projections such as:
- `BrowseSection`
- `BrowseGroup`
- `BrowseItem`
- `PlayableSelection`
- `ProgramPreview`

These projections are UI-facing but remain derived from normalized entities rather than provider-family payloads.

---

## 8. Playback Selection Model

When a user selects a normalized aggregate item:
1. resolve candidate playback variants
2. apply source scope constraints
3. apply priority rules
4. produce a `ResolvedPlaybackSelection`

### ResolvedPlaybackSelection
Fields:
- `contentKind`
- `aggregateId`
- `selectedVariantId`
- `availableVariantIds`
- `sourceIds`
- `selectionReason`
- `isFallbackSelection`

This model enables:
- default source choice
- manual source switching
- diagnostics about why a source was selected

---

## 9. EPG Resolution Model

For XMLTV-like EPG:
- programs are parsed into independent program storage
- channel matching occurs at runtime/query time

For on-demand provider EPG:
- provider responses are normalized into the same program projection layer

### Logical output model
`ResolvedProgramSchedule`
- `aggregateChannelId`
- `currentProgram`
- `nextProgram`
- `programWindow`
- `resolutionStrategy`
- `confidence`

---

## 10. Favorites and History Policy

### Favorites
Default policy:
- favorites attach to aggregate identity when available
- source-specific favorite metadata may be retained when needed

### History
History should retain:
- normalized target identity
- source/variant used
- playhead position
- time of last playback

This supports:
- merged browse/history views
- source-aware resume and diagnostics

---

## 11. Search Model

Search should index normalized aggregate entities by default, while retaining source-awareness.

Search result projection should support:
- aggregate result identity
- representative artwork/title
- content type
- source count
- available source list
- score/ranking information
- optional source-scoped expansion

---

## 12. Import and Export Model

Export/import payloads shall preserve:
- sources
- source configuration metadata
- favorites
- history
- settings
- restoration records
- sync metadata where useful

Export/import may omit large derived caches if rebuilding them is cheaper than transporting them.

---

## 13. Versioning
The normalized data model shall be explicitly versioned.

Versioning shall apply to:
- database schema
- export/import payloads
- restoration payloads
- deduplication rules where persisted
- diagnostic schemas where relevant

---

## 14. Non-Goals of This Document

This document does not define:
- exact SQL schema
- exact repository APIs
- exact search tokenizer implementation
- exact UI layout projections
- exact network payload parsing per provider family
