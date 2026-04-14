# Phase 29 Release Blockers

Status: active
Date: 2026-04-13
Outcome: not ready

## Manual validation evidence

- saved Xtream test source was validated directly against the provider API
- authentication succeeded
- live categories were present
- VOD categories were present
- series categories were present
- live stream catalog returned populated results

This proves the external provider account is usable and the remaining blockers
are app/runtime integration blockers, not source-account failures.

## Blockers

### 1. Source setup is still local-state commit, not runtime/provider commit

Owner:
- Flutter retained source/controller lane
- Rust provider/runtime lane

Evidence:
- [source_setup_controller.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/domain/source_setup_controller.dart)
  commits providers by mutating local `SourceProviderRegistry` state only
- no runtime repository call, Rust controller call, or persisted provider write
  exists in the active commit path
- [source_setup_controller_test.dart](/home/mkh/workspace/crispy-tivi/app/flutter/test/features/shell/source_setup_controller_test.dart)
  proves wizard completion as local controller mutation only

Impact:
- real providers cannot be imported into retained runtime state
- add/edit/reconnect/import looks functional but does not make the app
  operational

### 2. Real boot still loads empty runtime snapshots after provider entry

Owner:
- retained runtime/bootstrap lane

Evidence:
- [runtime_shell_bootstrap_repository.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/data/runtime_shell_bootstrap_repository.dart)
  still returns:
  - empty `ShellContentSnapshot`
  - empty configured providers
  - empty personalization runtime
- real mode remains truthful, but it is still mostly empty

Impact:
- even after source entry UI, Home/Live TV/Media/Search do not hydrate from
  real provider data

### 3. Shared Rust provider crates are still not active in the runtime crate graph

Owner:
- Rust runtime/provider lane

Evidence:
- `cargo test` still warns that these patches are unused:
  - `crispy-m3u`
  - `crispy-xmltv`
  - `crispy-xtream`
  - `crispy-stalker`
  - `crispy-catchup`
  - `crispy-iptv-tools`

Impact:
- the app still does not consume the intended shared provider/runtime crates on
  the active real path

### 3b. Flutter still owns too much provider/runtime business logic

Owner:
- Rust/Flutter boundary lane

Evidence:
- source registry semantics, source setup controller truth, runtime hydration,
  playback metadata shaping, diagnostics shaping, and Home aggregation are
  still authored mainly in Flutter
- later audit review showed that both real runtime and mock/demo runtime are
  still shaped in Flutter instead of being emitted by Rust-owned paths

Impact:
- even with more crate activation, the app would still be architecturally
  wrong until Flutter stops owning those business/runtime concerns

### 4. Real-source playback/manual user journey is blocked by the missing import/runtime handoff

Owner:
- end-to-end runtime integration lane

Evidence:
- provider API is healthy, but the app has no verified path from:
  - provider setup
  - validation/import
  - runtime hydration
  - browse surfaces
  - player launch
- no manual in-app proof exists yet for:
  - real provider setup ending in populated Home/Live/Media/Search
  - real player launch from imported live/movie/episode content

Impact:
- product cannot be called release-ready

## Required follow-on

- reopen implementation with a remediation track focused on:
  - real provider persistence/import
  - runtime hydration from configured providers
  - Rust boundary correction plus source/provider migration plus runtime
    hydration plus real-source proof
  - playback/diagnostics Rust migration plus final readiness rerun
