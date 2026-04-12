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
- Rust checks only for the Rust work that is actually approved to start
- route layouts visibly match the approved Penpot boards and current reference
  grounding notes

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
- Live TV:
  - Channels keeps group rail, dense channel list, and selected-channel detail
    split
  - Guide keeps selected-channel summary plus preview/matrix separation
- Media:
  - Movies and Series read as different route emphases, not just different
    labels
- Search:
  - route intro and scope copy clearly frame Search as global content handoff
  - result cards stay artwork-backed and media-focused

## Prohibited failure mode

Do not treat a functional scaffold as design adherence.
Do not treat legacy screenshots as design authority.
