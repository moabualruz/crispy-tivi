# Phase 16: Player Final UI / Design Completion

Status: complete

## Scope

- close the remaining player UI/design lane after the retained player baseline
- finish player control-language verification and design-preview parity
- treat this as a design-completion lane, not backend/player-engine delivery

## Completed in this phase

- player control language was re-audited against the approved study set and the
  current rules in the installed design system
- the back affordance was tightened to a clearer shared icon choice
- the player HTML preview was updated to reflect the retained player language as
  a real design preview rather than a temporary mock
- a dedicated player test path now verifies:
  - transport state
  - chooser overlay state
  - live `LIVE` state treatment
  - expanded-info queue state

## Evidence

- `app/flutter/test/features/shell/player_view_test.dart`
- `design/docs/player-mock-preview.html`
- browser preview capture from the updated design preview

## Not closed by this phase

- real playback backend integration
- provider/media engine integration
- full production implementation planning after the UI-first baseline
