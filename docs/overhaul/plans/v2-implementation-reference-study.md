# V2 Implementation Reference Study

Status: active
Date: 2026-04-12

## Purpose

Record the non-visual implementation lessons from the local study set and map
them onto the post-UI-first runtime phases.

This document exists so later phases do not drift into ad hoc provider,
playback, playlist, EPG, or persistence architecture when there is already
useful grounding in:

- `for_study/*`
- `rust/shared/crispy-*`

## Authority

Use this order:

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
3. `design/docs/penpot-installed-design-system.md`
4. this file
5. the active implementation phase docs

## Local Study Set

Studied repos:

- `for_study/Megacubo`
- `for_study/hypnotix`
- `for_study/iptvnator`
- `for_study/player-ui-study/media-kit`
- `for_study/player-ui-study/chewie`
- `for_study/player-ui-study/rein_player`
- `for_study/player-ui-study/fvp`

Studied in-repo Rust shared crates:

- `rust/shared/crispy-iptv-types`
- `rust/shared/crispy-m3u`
- `rust/shared/crispy-xmltv`
- `rust/shared/crispy-xtream`
- `rust/shared/crispy-stalker`
- `rust/shared/crispy-catchup`
- `rust/shared/crispy-iptv-tools`
- `rust/shared/crispy-stream-checker`
- `rust/shared/crispy-media-probe`

## Strongest Lessons By Reference

### Megacubo

Take:

- setup wizard as a real first-run lane, not a buried settings form
- list import and list management as a first-class product surface
- quick search and search-mode switching as a global utility, not just a page
- continue-watching and history as product features, not debug concepts
- transmission/source switching as a direct playback affordance

Do not take:

- community-mode assumptions as a product requirement
- overly broad menu sprawl

Use in CrispyTivi:

- Phase 19 must make source onboarding/import an explicit runtime-backed flow
- Phase 23 must treat history/resume/continue-watching as real product data
- Phase 22 must preserve explicit source/quality/audio/subtitle switching in
  the retained player UI

### Hypnotix

Take:

- provider simplicity
- explicit provider-type split:
  - M3U URL
  - local M3U
  - Xtream
- clear warning that the app does not provide content
- direct live/movies/series framing from one provider domain

Do not take:

- overly flat provider management without richer health/capability modeling

Use in CrispyTivi:

- Phase 19 source registry should keep provider setup legible and typed
- provider capabilities must be explicit instead of hidden in UI conditionals

### IPTVnator

Take:

- data-source abstraction with environment-specific implementations
- feature/facade split instead of giant route stores
- DB-first strategy for desktop-class runtime flows
- dedicated Xtream and Stalker lanes instead of flattening everything into M3U
- EPG worker/background parsing mindset
- favorites and recently-viewed as explicit persisted features
- virtual scrolling and large-list handling for real channel scale
- mock servers and deterministic fixture environments for provider testing

Do not take:

- Electron-specific assumptions
- framework-specific store choices as direct prescriptions for Flutter

Use in CrispyTivi:

- Phase 18 needs retained Flutter repository interfaces with replaceable Rust
  FFI-backed implementations
- Phase 19-21 should stay provider/domain-sliced rather than one giant
  "catalog service"
- Phase 20 must plan for worker/background parsing and large-list virtualization
- Phase 23 must include favorites, history, and resume as real persisted data
- later test phases should use deterministic provider fixtures and mock servers

### media-kit / chewie / rein_player / fvp

Take:

- custom-player-UI-first architecture
- track/quality/subtitle/source switching
- queue and next/previous semantics
- desktop-grade playback seriousness
- extensibility for screenshots, diagnostics, and richer track control

Use in CrispyTivi:

- Phase 22 must connect the retained player UI to a real playback backend while
  keeping CrispyTivi chrome authoritative

## Shared Rust Crate Responsibilities

### `crispy-iptv-types`

Use as the shared protocol-neutral vocabulary across the runtime phases.

Mandatory use:

- canonical normalized playlist/channel/EPG/VOD/stream shapes inside Rust
- conversion boundary between protocol-specific crates and FFI-facing app models

### `crispy-m3u`

Use for:

- M3U import
- local/remote playlist parsing
- preserving IPTV metadata such as logos, groups, catchup fields, and extras

### `crispy-xmltv`

Use for:

- XMLTV ingestion
- compressed guide parsing
- EPG transformation into app/runtime guide models

### `crispy-xtream`

Use for:

- Xtream authentication
- live/VOD/series category and item loading
- short/full EPG fetches
- XMLTV URL acquisition

### `crispy-stalker`

Use for:

- MAG/Stalker authentication
- portal content retrieval
- stream URL resolution

### `crispy-catchup`

Use for:

- archive and timeshift URL derivation
- catchup capability interpretation under real guide data

### `crispy-iptv-tools`

Use for:

- normalization
- deduplication
- merge policies
- URL cleanup/sanitization
- pre-persistence data shaping

### `crispy-stream-checker`

Use for:

- source validation
- imported stream QA
- source health/status checks

### `crispy-media-probe`

Use for:

- stream metadata probing
- screenshot generation for QA/support tooling
- richer media diagnostics where allowed

## Phase Enrichment

### Phase 18: runtime contract reset

Must produce:

- retained Flutter repository interfaces that are runtime-oriented, not
  asset-oriented
- explicit Rust FFI adapters backed by `crispy-iptv-types` as the canonical
  shared vocabulary
- replacement map for every current asset-backed repository

Take from IPTVnator:

- data-source abstraction
- facade/feature separation

### Phase 19: source/provider registry implementation

Must produce:

- typed source registry for:
  - M3U URL
  - local M3U
  - Xtream
  - Stalker
- capability model per source:
  - live
  - movies
  - series
  - EPG
  - catchup
  - search
  - subtitles/tracks where known
- Rust-backed auth/import/refresh status and error surfaces

Use:

- `crispy-m3u`
- `crispy-xtream`
- `crispy-stalker`
- `crispy-iptv-tools`
- `crispy-stream-checker`

### Phase 20: Live TV and EPG implementation

Must produce:

- real channel registry and group/category views
- virtualized or windowed large-list rendering strategy
- background/worker-friendly EPG parsing and merge flow
- explicit tune and guide-detail behavior under real data
- catchup/archive derivation via Rust

Use:

- `crispy-m3u`
- `crispy-xmltv`
- `crispy-catchup`
- `crispy-iptv-types`

Take from IPTVnator:

- large-list discipline
- dedicated EPG flow
- background parsing mindset

### Phase 21: Media and Search implementation

Must produce:

- real movies/series catalogs
- series seasons/episodes from provider-backed data
- unified search that respects provider capabilities and type-specific results
- favorites/recently-viewed domain hooks needed by later persistence work

Use:

- `crispy-xtream`
- `crispy-stalker`
- `crispy-iptv-types`
- `crispy-iptv-tools`

### Phase 22: playback backend integration

Must produce:

- retained player UI connected to real playback
- source switching, quality switching, audio/subtitle switching
- live/movie/episode playback from real runtime URLs

Use:

- Rust provider/runtime layers for playable URL resolution
- Flutter playback backend selected from the player study

### Phase 23: persistence, resume, and personalization

Must produce:

- real continue-watching
- real resume position
- favorites
- recent items/history
- startup hydration and default preference loading

Take from Megacubo and IPTVnator:

- continue-watching/history as explicit product surfaces
- favorites and recently-viewed as persisted runtime data

### Phase 24: production hardening

Must produce:

- runtime validation of imported sources
- stream health/support tooling
- performance verification on large lists and guide data
- release-hardening evidence for Linux and web

Use:

- `crispy-stream-checker`
- `crispy-media-probe`

### Phase 25 to Phase 29: post-foundation audit/completion track

Must produce:

- a full route/widget/workflow audit grounded in real runtime truth
- explicit demo/test-mode gating rules
- provider/setup/auth/import behavior validated against real controller/runtime
  ownership
- release-readiness judgment based on real-source/manual validation, not only
  retained fixture/runtime layers

Take from local study repos:

- Megacubo:
  - setup/history/truthfulness on real user state
- Hypnotix:
  - simpler provider entry framing and first-run clarity
- IPTVnator:
  - source-management/runtime truth, large-list handling, and operational app
    expectations

The post-foundation audit/completion track must also maintain:

- `docs/overhaul/plans/v2-phase25-research-notes.md`
    expectations

## Hard Rules

- Do not reimplement provider clients already covered by the shared Rust crates
  unless a documented gap in those crates forces it.
- Do not parse M3U, XMLTV, Xtream, or Stalker data in Flutter.
- Do not push playlist normalization, catchup derivation, or source validation
  into Dart view-model code.
- Do not treat the shared Rust crates as optional convenience dependencies; they
  are the default implementation path for the full-runtime phases.
- If a full-runtime phase chooses not to use one of the relevant shared crates,
  the phase doc must record the reason explicitly before implementation starts.
