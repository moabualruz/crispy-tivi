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

## Prohibited failure mode

Do not treat a functional scaffold as design adherence.
Do not treat legacy screenshots as design authority.
