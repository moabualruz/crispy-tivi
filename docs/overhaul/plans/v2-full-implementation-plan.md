# V2 Full Implementation Plan

Status: active
Date: 2026-04-12

## Purpose

This document defines the real implementation track that starts **after** the
UI-first baseline is accepted as stable.

The UI-first baseline already provides:

- the retained shell/runtime structure
- the installed design system
- the retained player surface baseline
- retained repository/bootstrap boundaries and runtime scaffolding
- route/view-model structure and verification scaffolding

This plan replaces any implied idea that the product is complete once the UI
baseline is stable.

## Authority

Use this order:

1. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
2. `AGENTS.md`
3. `design/docs/penpot-installed-design-system.md`
4. `docs/overhaul/plans/v2-implementation-reference-study.md`
5. active docs under `docs/overhaul/plans/`
6. approved `design/reference-images/`

## Starting Point

The current branch state is:

- UI-first baseline complete through Phase 16
- retained player UI/design completion complete
- retained runtime foundation phases 18 to 24 complete
- Phase 25 complete
- Phases 26 to 29 not started
- Phase 25 to 29 execution artifacts live in:
  - `docs/overhaul/plans/v2-phase25-audit-ledger.md`
  - `docs/overhaul/plans/v2-phase25-research-notes.md`
  - `docs/overhaul/plans/v2-phase25-repair-order.md`

## Full-Implementation Goals

The full implementation track must deliver:

- real Rust-owned domain/application behavior
- real provider/source translation and syncing
- real persistence and hydration
- real search/catalog behavior
- real playback backend integration
- production-ready Linux/web behavior and hardening
- a full-app audit proving that routes, widgets, workflows, and first-run
  behavior are truthful in both:
  - real runtime mode
  - explicit demo/test mode

## Required Inputs Before Runtime Work

Every full-runtime phase must be grounded in both:

- the local study repos under `for_study/`
- the shared Rust crates under `rust/shared/crispy-*`

The shared Rust crates are not optional convenience libraries. They are the
default implementation foundation for protocol parsing, provider integration,
catchup handling, normalization, stream validation, and guide ingestion.

## Phase Order After UI-First

### Phase 18: runtime contract reset

Output:

- runtime-facing Flutter repository interfaces exist for contract, content,
  and bootstrap loading
- asset-backed implementations sit behind those interfaces
- the exact replacement map from Flutter repository interfaces to Rust-backed
  runtime ownership is documented
- `crispy-iptv-types` is explicitly named as the shared normalized boundary
  vocabulary

Gate:

- runtime-boundary files are explicit and testable
- no ambiguity remains about which asset-backed repositories are temporary
- every current asset-backed repository has an explicit runtime replacement
  owner and crate path
- Phase 18 closure is recorded in
  `docs/overhaul/plans/v2-phase18-runtime-contract-reset.md`

### Phase 19: source/provider registry implementation

Output:

- real source registry
- real provider capability model
- real onboarding/auth/import source flows backed by Rust
- real source health/status data
- typed provider lanes for:
  - M3U URL
  - local M3U
  - Xtream
  - Stalker
- provider catalog metadata separated from configured provider instances so
  first-run can start empty without losing onboarding definitions
- seeded/mock source data only behind explicit demo/test mode, not default boot
- explicit crate usage:
  - `crispy-m3u`
  - `crispy-xtream`
  - `crispy-stalker`
  - `crispy-iptv-tools`
  - `crispy-stream-checker`

Gate:

- asset-backed source/setup flow is replaced by runtime-backed source behavior
- fresh installs boot into true first-run onboarding instead of seeded sources
- source setup/auth/import is no longer fixture-driven

Current branch state:

- complete
- closure recorded in
  `docs/overhaul/plans/v2-phase19-source-provider-registry.md`

### Phase 20: Live TV and EPG implementation

Output:

- real channel lists
- real guide data
- real tune/playable resolution
- real catch-up/archive capability handling
- large-list handling strategy appropriate for real channel scale
- background/worker-friendly guide parsing strategy
- explicit crate usage:
  - `crispy-m3u`
  - `crispy-xmltv`
  - `crispy-catchup`
  - `crispy-iptv-types`

Gate:

- Live TV and guide no longer rely on canonical fake content snapshots
- explicit tune behavior and guide detail rules are preserved under real data

Current branch state:

- complete
- closure recorded in
  `docs/overhaul/plans/v2-phase20-live-tv-epg.md`

### Phase 21: Media and Search implementation

Output:

- retained asset-backed Media/Search runtime snapshots exist in the data/domain
  boundary for later provider-backed replacement
- real movie/series browsing
- real season/episode data
- real search indexing/query behavior
- real domain-detail handoff behavior under runtime data
- explicit provider-backed movie/series sourcing via:
  - `crispy-xtream`
  - `crispy-stalker`
  - `crispy-iptv-types`
  - `crispy-iptv-tools`

Gate:

- Media and Search are no longer fixture-driven
- current UI-first route rules still hold under real data
- active Media and Search routes consume retained media/search runtime snapshots
  through bootstrap/repository boundaries rather than route-local or
  `ShellContent`-local shaping

Current branch state:

- complete
- closure recorded in
  `docs/overhaul/plans/v2-phase21-media-search.md`

### Phase 22: playback backend integration

Output:

- player surface connected to the real playback engine
- real track/source/quality/subtitle switching
- real live/movie/episode playable resolution
- retained player UI kept intact while runtime URL resolution moves to Rust
- playback foundation chosen from the player study, but product UI remains
  CrispyTivi-owned

Gate:

- retained player UI stays intact while backend becomes real
- no fallback to third-party player chrome as product UI

Current branch state:

- complete
- runtime-backed playback targets and real backend video surface are integrated
- runtime-backed chooser catalogs now drive source, quality, audio, and
  subtitle switching through the retained player session/backend path
- current phase notes live in
  `docs/overhaul/plans/v2-phase22-playback-backend.md`

### Phase 23: persistence, resume, and personalization

Output:

- real continue-watching
- real resume position
- real playback/session persistence
- real startup/default preference hydration
- real favorites and recently-viewed persistence where product rules require it

Gate:

- no remaining fake continue-watching or resume behavior
- Rust owns the real business logic and persistence rules

Current branch state:

- complete
- closure recorded in
  `docs/overhaul/plans/v2-phase23-persistence-personalization.md`

### Phase 24: production hardening

Output:

- performance/RAM/CPU verification
- production package hardening
- full regression proof across Linux and web
- release readiness evidence
- runtime source validation and diagnostics path using:
  - `crispy-stream-checker`
  - `crispy-media-probe`

Gate:

- no known blocking regressions
- performance priorities from the full spec are explicitly reverified
- deterministic retained diagnostics/runtime assets remain machine-independent
- host-tool availability checks are split from retained asset-backed runtime
  snapshots

Current branch state:

- complete
- closure recorded in
  `docs/overhaul/plans/v2-phase24-production-hardening.md`

### Phase 25: full app runtime audit

Output:

- full route/widget/workflow audit ledger
- explicit real-mode vs demo/test-mode coverage matrix
- explicit list of remaining mock/default/fallback behavior still visible on
  the active runtime path
- exact repair order for unresolved wiring gaps

Gate:

- every major route and workflow is audited end to end:
  - Home
  - Live TV
  - Media
  - Search
  - Settings
  - Sources/provider setup/auth/import/edit/reconnect
  - Player
- every audited item is marked:
  - wired
  - blocked
  - superseded
- no remaining known runtime/design gap is left undocumented

Current branch state:

- complete

Artifacts:

- `docs/overhaul/plans/v2-phase25-audit-ledger.md`
- `docs/overhaul/plans/v2-phase25-research-notes.md`
- `docs/overhaul/plans/v2-phase25-repair-order.md`

Execution handoff:

- `docs/overhaul/plans/v2-phase25-audit-ledger.md`
- `docs/overhaul/plans/v2-phase25-research-notes.md`
- `docs/overhaul/plans/v2-phase25-repair-order.md`

### Phase 26: demo/test gating and first-run truth

Output:

- seeded/mock/demo runtime data available only behind explicit demo/test flags
- fresh-install behavior verified with zero configured providers
- explicit startup-mode policy for:
  - real runtime
  - demo mode
  - tests

Gate:

- no seeded provider/content/personalization data is reachable on default boot
- demo/test fixtures are usable only through explicit mode selection or
  injected test repositories
- first-run onboarding/startup is verified from a clean install state
- Phase 25 repair order exists first

Current branch state:

- complete
- closure recorded in
  `docs/overhaul/plans/v2-phase26-demo-test-gating.md`

### Phase 27: provider/controller wiring completion

Output:

- provider setup/auth/import/edit/reconnect flows backed by retained runtime
  controllers
- provider-specific typed forms/options validated against runtime/controller
  capabilities
- source status, validation, import progress, and error surfaces backed by real
  runtime/controller state
- provider-controller ownership is explicit even when shared Rust provider
  crates are still pending activation in the runtime crate graph

Gate:

- source onboarding is no longer a design scaffold with typed fields only
- visible provider flows are not driven by placeholder values or fixture-only
  options
- real provider/controller ownership is clear across Flutter and Rust
- if shared Rust provider crates are still pending, the docs record that
  boundary honestly rather than implying full provider execution is complete

Current branch state:

- complete
- closure recorded in
  `docs/overhaul/plans/v2-phase27-provider-controller-wiring.md`

### Phase 28: screen and widget runtime audit closure

Output:

- every retained route/widget audited for runtime/controller ownership
- remaining fallback shaping removed from routes/view-models where runtime
  boundaries already exist
- mock/demo-only behavior fully separated from real runtime behavior

Gate:

- no major screen or widget remains only partially wired on the real runtime
  path
- all known wiring gaps found during the audit are fixed or explicitly blocked
  with owner and rationale
- docs/specs match the repaired runtime truth

Current branch state:

- complete
- closure recorded in
  `docs/overhaul/plans/v2-phase28-screen-widget-runtime-audit.md`

### Phase 29: release-readiness audit and field validation

Output:

- real-source manual validation passes
- release-readiness ledger
- explicit remaining production blockers list or release-ready signoff

Gate:

- real provider/source setup is manually validated
- long-session/player/resume/startup behavior is rechecked under real data
- Linux/web release behavior is revalidated after the audit-track repairs
- product completion is only discussed after this phase closes

Current branch state:

- complete
- outcome: not ready
- blocker ledger recorded in
  `docs/overhaul/plans/v2-phase29-release-blockers.md`

## Post-Phase-29 remediation track

Because Phase 29 closed as `not ready`, the next valid track is:

- Phase 30 provider persistence and import runtime
- Phase 31 provider-driven runtime hydration
- Phase 32 Rust boundary correction + source/provider migration + runtime
  hydration migration + real-source in-app proof
- Phase 35 playback and diagnostics Rust migration + release-readiness rerun

This remediation track is defined in:

- `docs/overhaul/plans/v2-post-phase29-remediation-plan.md`
- `docs/overhaul/plans/v2-phase30-provider-persistence-import-runtime.md`

Current remediation state:

- Phase 30 complete
- Phase 31 complete
- Phase 32 complete
- Phase 35 complete
- remediation track outcome: not ready
- blocker ledger recorded in
  `docs/overhaul/plans/v2-phase35-release-blockers.md`
- follow-on cleanup track documented in
  `docs/overhaul/plans/v2-post-phase35-release-cleanup-plan.md`
- Phase 38 complete
- Phase 39 complete
- cleanup track outcome: ready
- next allowed lane: none inside the current track

## Retained Surfaces

The following are expected to remain and be reused:

- `features/shell/domain/*` model surfaces where they are still valid neutral
  runtime shapes
- `features/shell/presentation/*` route/widget/view-model structure
- shared theme/control/icon/artwork systems
- retained player surface and preview/design docs

## Temporary Surfaces To Replace

The following are explicitly transitional:

- asset-backed bootstrap repositories
- asset-backed contract/content fixtures
- any flow whose behavior is still driven only by fixture JSON rather than Rust
  runtime data
- any screen/workflow that renders but is not yet backed by the retained
  runtime/controller path in real mode

## Anti-Drift Rules For The Full-Implementation Track

- do not rewrite retained presentation code unless the runtime integration
  genuinely requires it
- replace temporary asset-backed repositories behind stable retained interfaces
- do not collapse Flutter into controller/business logic while integrating Rust
- do not accept retained Flutter runtime/business logic as steady-state
  architecture once the Rust-boundary correction track is active
- move mock/demo provider and runtime truth into Rust as part of the same
  correction track; do not keep demo truth authored in Flutter
- do not reimplement provider clients, playlist parsers, XMLTV parsers, catchup
  derivation, or source validation in app-local code when the shared Rust
  crates already cover that responsibility
- do not claim product completion again before Phases 18 to 29 are explicitly
  executed and verified
- do not let environment-dependent diagnostics capability checks mutate
  deterministic retained assets used for bootstrap and exact snapshot tests
