# Test Spec: CrispyTivi v2 TV Rewrite

Status: Active
Date: 2026-04-11

## Verification order

### Phase 1: design-system verification first

Required evidence before implementation:

- `docs/overhaul/plans/v2-conversation-history-full-spec.md` has been applied as the
  active authority
- live approved Penpot manifest is the active visual authority
- Phase 0 reset is complete and code has returned to clean-baseline placeholders
- overhaul token source exists in Flutter
- overhaul token JSON parses and matches the approved token families
- Penpot publish/read-back succeeds for the overhaul design-system artifacts
- Penpot artifacts visibly match the shell IA rules from the spec
- Widgetbook shell specimen plan exists
- legacy screenshots have been explicitly excluded as visual authority

### Phase 2: shell-planning verification

Required evidence:

- shell IA document exists
- focus/navigation rules exist
- Widgetbook specimen plan maps back to Penpot boards
- route-level composition rules are explicit enough that the shell cannot be
  rebuilt from generic shared placeholder patterns

### Phase 3: implementation verification

Only after the above:

- `flutter analyze`
- `flutter test`
- Linux integration entrypoint
- after any Linux integration test run, regenerate Linux release state before
  manual launch or final Linux handoff so the managed Linux Flutter config is
  restored from the test-listener target back to `lib/main.dart`
- Rust checks only for the Rust work that is actually approved to start
- route layouts visibly match the approved Penpot boards and current reference
  grounding notes

### Linux managed-build hygiene

Required evidence whenever Linux integration tests were part of the pass:

- `app/flutter/linux/flutter/ephemeral/generated_config.cmake` does not point
  at a Flutter test-listener target during final manual-run or handoff state
- final Linux release state was regenerated with
  `app/flutter/tool/restore_linux_release_state.sh` or equivalent clean
  `flutter build linux` after clearing Linux managed build outputs
- direct terminal launch of the final Linux release bundle does not report
  `FlutterEngineInitialize ... kInvalidArguments` or kernel-binary resolution
  failure

### Phase 5: technical-contract verification

Required evidence:

- Rust shell contract shape exists and round-trips
- canonical shell contract asset exists in Flutter
- canonical mock content snapshot asset exists in Flutter
- Flutter validates and loads the shell contract before rendering
- Flutter validates and loads the mock content snapshot before rendering the
  populated route surfaces
- asset-backed bootstrap must settle into the shell runtime; loading must not
  loop indefinitely after successful contract/content resolution
- Flutter tests verify the bootstrap repository resolves contract and content
  together into one startup payload
- startup route and approved ordering come from the contract rather than hidden
  local defaults
- Flutter tests verify that `Sources` stays under `Settings` in the contract
  layer and that `Player` is not a top-level route
- shared artwork rendering is source-agnostic so moving from mock assets to
  remote provider art does not require route-by-route widget rewrites

### Phase 6: onboarding/auth/import verification

Required evidence:

- source onboarding/auth/import exists as a Settings-owned flow, not only as
  static source-health cards
- canonical shell contract asset defines source wizard step ordering
- canonical content snapshot asset defines source detail data and source wizard
  step copy/content
- Flutter validates and loads those Phase 6 source-flow surfaces before
  rendering the Settings Sources lane
- Flutter tests verify source wizard entry and back safety:
  - add source enters the wizard from Settings
  - reconnect/auth-needed can enter the wizard at the credentials lane
  - back from the first wizard step returns to source overview/list
  - back from later steps returns to the previous wizard step

### Phase 18: runtime contract reset

Required evidence:

- Flutter exposes retained repository interfaces for contract, content, and
  bootstrap loading
- asset-backed implementations remain behind those interfaces
- app bootstrap depends on the interface type rather than a concrete asset
  repository
- the runtime replacement map is documented for contract/content/bootstrap
  ownership
- the shared Rust crate ownership map is documented for the later runtime swap

### Phase 19: source/provider registry implementation

Required evidence:

- Rust owns a typed source/provider registry schema and JSON producer
- Flutter exposes a retained `SourceRegistryRepository`
- bootstrap resolves contract, content, and source registry together
- the main runtime path for Settings-owned provider/auth/import behavior comes
  from the source registry, not `ShellContentSnapshot.source_health_items`
- injected shell tests may use a legacy-content fallback only when no source
  registry is supplied explicitly
- the active source wizard renders real interactive form controls for the step
  field set; placeholder text rows are not acceptable runtime behavior
- typed provider lanes exist for:
  - `M3U URL`
  - `local M3U`
  - `Xtream`
  - `Stalker`
- default application boot is non-seeded first-run unless an explicit demo/test
  mode is enabled
- provider catalog metadata remains available even when configured providers are
  empty so first-run onboarding can stay real
- onboarding/auth/import step ordering and copy are validated through the
  runtime source registry contract
- Phase 19 closure is recorded in
  `docs/overhaul/plans/v2-phase19-source-provider-registry.md`

### Phase 20: Live TV and EPG implementation

Required evidence:

- Rust owns a typed live-TV runtime schema and JSON producer
- Flutter exposes a retained `LiveTvRuntimeRepository`
- bootstrap resolves contract, content, source registry, and live-TV runtime
  together
- the main runtime path for Live TV browse groups, guide rows, selected-detail
  state, and player-launch metadata comes from the live-TV runtime, not
  `ShellContentSnapshot.liveTvBrowse` / `liveTvGuide` heuristics
- injected shell tests may use a legacy-content live-TV fallback only when no
  live-TV runtime is supplied explicitly
- legacy-content live-TV fallback construction must live in data/bootstrap
  helpers, not in retained domain models, routes, or view-models
- Phase 20 closure is recorded in
  `docs/overhaul/plans/v2-phase20-live-tv-epg.md`

### Phase 21: Media and Search implementation

Required evidence:

- Rust owns typed media and search runtime schemas plus JSON producers
- Flutter exposes retained `MediaRuntimeRepository` and
  `SearchRuntimeRepository`
- bootstrap resolves contract, content, source registry, live-TV runtime,
  media runtime, and search runtime together
- the main runtime path for Media movie rails, series rails, series detail, and
  Search groups/results/handoff state comes from retained runtime snapshots,
  not legacy `ShellContentSnapshot` movie/series/search fields
- injected shell tests may use legacy-content Media/Search fallback only when
  no media/search runtime is supplied explicitly
- legacy-content Media/Search fallback construction lives in data/bootstrap
  helpers, not in retained domain models, routes, or view-models
- Phase 21 closure is recorded in
  `docs/overhaul/plans/v2-phase21-media-search.md`

### Phase 22: playback backend integration

Required evidence:

- Flutter initializes the chosen playback backend before app startup
- retained player UI renders a real playback surface without replacing
  CrispyTivi-owned player chrome
- Live TV and Media player launches resolve from retained runtime playback
  metadata, not hardcoded presentation URLs
- runtime playback metadata exists in both Rust schema and Flutter
  asset-backed runtime snapshots for:
  - live channels
  - movie items
  - series items
  - episode items
- Linux integration smoke passes after Linux release state is restored
- Linux and web builds pass with the playback backend dependencies enabled
- chooser state for source, quality, audio, and subtitles must be runtime-fed
  and backend-applied rather than decorative/static-only before Phase 22 can
  close

### Phase 23: persistence, resume, and personalization

Required evidence:

- persisted personalization runtime exists for Linux and web
- startup route hydration, continue watching, recent/history, and favorites
  are runtime-backed rather than decorative-only
- retained persistence behavior is test-covered and documented

### Phase 24: production hardening

Required evidence:

- retained diagnostics runtime exists and is visible in the retained shell
- Rust diagnostics/runtime validation uses shared crates rather than app-local
  duplicate logic where the shared crates already cover the behavior
- deterministic retained diagnostics asset exactly matches the retained Rust
  diagnostics producer
- host-environment tool availability checks are separated from deterministic
  retained asset-backed diagnostics snapshots
- large-list laziness is test-covered for Live TV scale
- `cargo test`
- `flutter analyze`
- retained Flutter suite
- `flutter test integration_test/main_test.dart -d linux`
- Linux release state regeneration with
  `app/flutter/tool/restore_linux_release_state.sh`
- `flutter build linux`
- `flutter build web`
- browser-driven Playwright smoke against the built web app

### Phase 25: full app runtime audit

Required evidence:

- explicit route/widget/workflow audit ledger exists for:
  - real runtime mode
  - explicit demo/test mode
- audit covers at least:
  - Home
  - Live TV
  - Media
  - Search
  - Settings
  - provider setup/auth/import/edit/reconnect
  - Player
- every audited item is marked as:
  - wired
  - blocked
  - superseded
- Phase 25 evidence is invalid if it omits either real runtime mode or explicit
  demo/test mode

### Phase 26: demo/test gating and first-run truth

Required evidence:

- default boot path contains zero seeded providers/content/personalization
- explicit demo/test mode still reproduces seeded demo behavior when enabled
- first-run onboarding/startup is tested from a clean install state
- runtime mode selection is explicit and testable rather than being implied by
  scattered app-bootstrap defaults
- injected test repositories/fixtures can override the startup profile without
  toggling demo mode globally

### Phase 27: provider/controller wiring completion

Required evidence:

- provider wizard fields, option sets, validation, and submit behavior are
  runtime/controller-backed rather than decorative
- provider-specific states are verified for at least:
  - M3U URL
  - local M3U
  - Xtream
  - Stalker
- source status/health/import/error states are no longer scaffold-only
- add/edit/reconnect/import all commit through the retained controller path and
  visibly update configured-provider state

### Phase 28: screen and widget runtime audit closure

Required evidence:

- remaining fallback shaping is removed from routes/view-models where retained
  runtime/controller boundaries exist
- major screens/widgets are reverified after audit repairs in both real mode
  and explicit demo/test mode
- docs/specs are updated for every repaired runtime/design gap
- Home does not synthesize hero/live/continue-watching from legacy shell
  content or fallback movie collections on the active runtime path
- Search carries retained runtime query truth into the visible field state
- non-source Settings panels remain populated from retained runtime/diagnostics
  truth rather than shell-content scaffolding
- player backend ownership is retained-controller/view-model owned rather than
  widget-local

### Phase 29: release-readiness audit and field validation

Required evidence:

- real-source/provider manual validation is recorded
- long-session playback/resume/startup/provider flows are rechecked after the
  audit-track fixes
- Linux and web release behavior are revalidated after Phases 25 to 28
  complete
- Phase 29 evidence is invalid if it lacks manual real-source validation
- Phase 29 must end with an explicit readiness judgment:
  - ready
  - not ready with blocker ledger
- provider-account health and app-runtime health must be evaluated separately
  so a healthy external source does not get misreported as an app-ready state

### Post-Phase-29 remediation track

Required evidence for the remediation phases:

- Phase 30 proves provider setup/import commits through retained runtime
  repositories rather than local-only controller mutation
- Phase 30 proves real boot preserves persisted configured providers from the
  retained source repository rather than clearing them back to empty
- Phase 31 proves configured providers hydrate retained Home/Live TV/Media/
  Search runtime state on real boot
- Phase 31 also proves unsupported lanes remain empty instead of showing
  unrelated demo/runtime shelves after hydration
- Phase 32 proves the current Flutter-owned runtime/provider logic is fully
  mapped as migration debt, moves provider/controller truth into Rust, moves
  Home/Live TV/Media/Search runtime hydration and mock/demo generation into
  Rust, and records the real in-app source-to-player journey under that
  corrected boundary; this phase is now complete
- Phase 35 proves playback metadata and diagnostics derivation are Rust-owned
  and reruns the full release-readiness judgment after the remediation phases
  land; this phase is now complete, and the refreshed not-ready blockers are
  recorded in `docs/overhaul/plans/v2-phase35-release-blockers.md`
- If those blockers remain, the next valid work is the documented cleanup track
  in `docs/overhaul/plans/v2-post-phase35-release-cleanup-plan.md`, starting
  with Phase 38 shared XMLTV/catchup activation. Phase 38 and Phase 39 are now
  complete, the cleanup track outcome is `ready`, and no next allowed lane
  remains inside the current track.

### Phase 7+: domain-route verification

Required evidence as each independent domain lane completes:

- Settings:
  - grouped utility sections show clear section headers/summaries
  - source flow keeps visible Settings ownership cues while switching between
    list/detail/wizard states
  - Settings search shows local results first, then opens the exact leaf only
    after explicit result activation
  - exact Settings search activation highlights the opened leaf inside the same
    grouped hierarchy instead of jumping into a detached search surface
- Live TV:
  - Channels keeps local subview nav in the sidebar, group rail in content,
    and dense channel-list/detail split
  - Live TV focus changes selected-channel metadata only; playback changes only
    on explicit activation
  - Guide keeps local subview nav separate from in-content group switching and
    preserves selected-channel summary plus preview/matrix separation
  - compact guide preview panes remain scrollable/navigable and do not collapse
    hidden rows into `+N more` summary text
  - Guide detail overlays come from canonical guide-row/program data and show
    focused slot, live-edge state, and catch-up/archive affordances
  - Guide browse mode does not expose tune/play action chrome
- Media:
  - Movies and Series read as different route emphases, not just different
    labels
  - Movie detail exposes a movie-specific launch handoff that opens a mock
    player preview from the detail surface, not from the shelf rail
  - Series detail exposes explicit season selection, episode selection, and
    episode-to-player handoff
- Search:
  - route intro and scope copy clearly frame Search as global content handoff
  - result cards stay artwork-backed and media-focused
  - selecting search results updates the owning-domain handoff panel rather
    than behaving like a detached utility list
- Player gate:
  - no player implementation code starts before the repo-local player gate is
    complete
  - the installed design docs must define live switching, episode switching,
  OSD states, chooser overlays, and player back behavior before Phase 14
    may begin
- Player implementation:
  - Phase 14 verifies the retained player baseline:
    - movie detail opens the retained player surface rather than a mock dialog
    - series episode launch opens player and allows in-player episode switching
    - Live TV explicit tune action opens player and allows in-player channel
      switching
    - player chooser overlays exist for audio, subtitles, quality, and source
    - Back unwinds chooser, then expanded info, then player exit
  - Phase 16 verifies final player UI/design completion:
    - OSD and chooser language are fully re-audited against the approved study
      set and current user requirements
    - player iconography, control semantics, and HTML player preview evidence
      are aligned with the final approved player language
    - dedicated player-route tests exist in addition to broader shell tests

### Phase 15: UI-first integration / hardening verification

Required evidence:

- Rust tests green from the actual Rust workspace
- Flutter analyze green
- retained-shell Flutter test suite green
- Linux integration smoke green
- Linux release state restored after Linux integration smoke
- Linux release build green
- web build green
- browser-driven web smoke evidence from the built web target

### Phase 17: full implementation planning / execution reset

Required evidence:

- explicit post-UI-first implementation phase order exists
- runtime contract replacement path is defined
- real provider/source/playback/persistence phases are explicitly named
- Phase 23 must verify persisted startup-route hydration, continue-watching,
  recent/history, and player resume updates through the retained runtime
  personalization boundary rather than fixture-only rails
- docs no longer imply that UI-first completion equals product completion
- docs explicitly define the post-Phase-24 audit/completion track before
  product completion is discussed again

## Prohibited failure mode

Do not treat a functional scaffold as design adherence.
Do not treat legacy screenshots as design authority.
