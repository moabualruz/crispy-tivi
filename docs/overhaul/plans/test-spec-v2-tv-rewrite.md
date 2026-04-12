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
  - movie detail opens the retained player surface rather than a mock dialog
  - series episode launch opens player and allows in-player episode switching
  - Live TV explicit tune action opens player and allows in-player channel
    switching
  - player chooser overlays exist for audio, subtitles, quality, and source
  - Back unwinds chooser, then expanded info, then player exit

## Prohibited failure mode

Do not treat a functional scaffold as design adherence.
Do not treat legacy screenshots as design authority.
