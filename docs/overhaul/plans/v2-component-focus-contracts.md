# V2 Component Focus Contracts

Status: Phase-3 redone
Date: 2026-04-11

## Top-bar global navigation

- horizontal traversal only
- focused state must be room-scale readable
- activation changes global domain only
- no local-route behavior in this component

## Sidebar local navigation

- vertical traversal only
- only exists for domains with persistent local navigation
- activation changes local/domain surface only
- does not change global domain

## Hero/header surface

- first major content anchor
- may receive focus if interactive, otherwise acts as a visible content start marker

## Windowed list

- vertical focus traversal
- bounded visible window only
- focus movement does not imply side effects

## Windowed rail

- horizontal focus traversal
- escape up/down to sibling regions
- bounded visible window only

## Windowed grid

- two-dimensional traversal
- row/column movement stays within the active content region until edge escape

## Search entry

- owns query initiation
- does not imply a persistent sidebar
- hands focus to results after explicit entry/submit action

## Overlay/modal surface

- focus trap while active
- Back dismisses first
- Menu is local to the overlay if used

## Placeholder/gated surfaces

- must not pretend final behavior exists
- focus behavior should remain explicit and minimal

## Completion note

Phase 3 component-focus planning is complete for the current branch state:

- major shell focusable surfaces have explicit contracts
- component contracts align with IA ownership and route focus rules
- placeholder/gated behavior remains explicitly non-final
- implementation review must reject focus styling or surface treatment that does
  not read clearly at TV distance
