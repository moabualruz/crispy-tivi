# CrispyTivi v2 Rewrite Initial RALPLAN-DR (Short Mode)

Date: 2026-04-10
Status: Not started
Mode: `ralplan` short

## Grounding

This draft is grounded in current repo reality:

- `app/flutter/lib/` is effectively empty on this branch (`.gitkeep` only).
- Flutter package and tooling exist in `app/flutter/pubspec.yaml`.
- Rust workspace exists in `rust/Cargo.toml`.
- Shared IPTV crates already exist under `rust/shared/`.
- Flutter-token authority and Widgetbook/Penpot parity are already documented in:
  - `design/docs/design-system.md`
  - `design/docs/app-overhaul-design-system.md`
- Structural audit hooks already exist but are misaligned with the v2 branch shape:
  - `scripts/dart/audit_ddd_solid_dry.sh`
  - `scripts/rust/audit_ddd_solid_dry.sh`

## RALPLAN-DR

### Principles

1. Performance before purity. Every primary screen must adopt the same fake-scroll/windowed primitives from day 1, with bounded visible work and no domain-specific scrolling exceptions.
2. Flutter stays MV-only. Dart owns rendering, focus, layout, route state, and presentation mapping only; Rust FFI owns controller, business, domain orchestration, source/provider translation, and canonical contracts.
3. Shell first, verticals second. Deliver a fully navigable shell/stub app for all planned screens before implementing real domain behavior, then fill one vertical at a time.
4. TV-first interaction is canonical. Remote, keyboard, and gamepad all resolve through one canonical input action model, and layouts scale from canonical `1920x1080` instead of reflowing per screen.
5. Shared contracts beat local convenience. Search, details, navigation state, and later player entry all target canonical cross-domain shapes instead of provider- or screen-specific ad hoc models.

### Top Decision Drivers

1. Keep navigation, rendering, and large-catalog browsing fast and bounded on TV-class hardware.
2. Prevent architectural backslide by enforcing the Flutter MV / Rust orchestration split from the first scaffold.
3. Avoid rewrite churn by standardizing shell, windowing, input, and detail-state contracts before vertical feature delivery begins.

### Viable Options

#### Option A: Shell-first staged-kernel rewrite

Define one shared Flutter shell/runtime, one shared windowing/focus/input primitive layer, and one minimal Rust canonical contract kernel first. Build all screen stubs on those primitives, then implement real verticals in order, with player held behind a later investigation gate.

Pros:

- Fits the empty `app/flutter/lib/` branch reality.
- Best aligns with the required shell-first rollout and single primitive system.
- Lets Rust contracts mature with real vertical evidence instead of freezing the full superset too early.
- Reduces the risk of per-screen focus and scrolling divergence.

Cons:

- Requires discipline to keep shell code from accreting placeholder business logic.
- Needs up-front agreement on canonical action model, detail focus state, and stub data shapes.

#### Option B: Context-first domain rewrite

Define most bounded contexts and canonical contracts in Rust up front, then let Flutter screens arrive afterward once domain surfaces are stable.

Pros:

- Gives strong backend/domain clarity early.
- May reduce later contract rewrites inside Rust.

Cons:

- Conflicts with the requirement for a full navigable shell first.
- Delays proof that shared TV primitives actually work across all screens.
- Increases the chance that Flutter later has to bend around backend-first abstractions that were never exercised by real focus/layout behavior.

#### Option C: Vertical-first pilot rewrite

Pick one slice, such as Live TV or Settings, and implement it end to end before standardizing the rest of the app.

Pros:

- Fastest way to get one real workflow working.
- Produces concrete evidence sooner for one bounded context.

Cons:

- Directly conflicts with the requirement to stub the full shell before vertical delivery.
- High risk of inventing one-off focus, navigation, and list primitives that other screens cannot reuse cleanly.
- Makes later canonical Search/detail-state handoff harder to normalize.

### Chosen Option

Option A: shell-first staged-kernel rewrite.

### Why Chosen

Option A best matches the branch state and the stated constraints:

- `app/flutter/lib/` being empty makes a clean shell/runtime scaffold practical now.
- Existing design docs already support Widgetbook-from-start and Flutter-token authority.
- Existing Rust shared IPTV crates allow the rewrite to start from a real provider-adjacent foundation without forcing full provider orchestration design on day 1.
- The player-last rule is easier to preserve when shell/runtime contracts are established before playback complexity is introduced.

## Concise Execution-Plan Recommendations

1. Establish the v2 doc-and-layout contract first.
   Write or tighten rewrite planning artifacts under `docs/overhaul/plans/` for:
   - package and crate layout
   - bounded-context boundaries
   - canonical input action model
   - fake-scroll/windowed primitive contract
   - scale-bucket rules from `1920x1080`

2. Treat `app/flutter/lib/` as a shell-runtime foundation phase, not a feature phase.
   Initial Flutter directories should be organized around:
   - `core/theme/`
   - `core/widgets/`
   - `core/navigation/`
   - `core/input/`
   - `core/windowing/`
   - `features/app_shell/`
   - bounded-context feature folders only after the shared runtime contracts exist

3. Reserve Rust crate work for canonical contracts and orchestration seams, not ad hoc Flutter rescue logic.
   Start from `rust/Cargo.toml` and existing `rust/shared/` crates, then add v2-specific crates under `rust/crates/` only when the canonical kernel is defined:
   - source/provider registry contracts
   - shared catalog/metadata contracts
   - playback-session contracts
   - search/detail-state handoff contracts
   - FFI-facing view-model translation outputs

4. Realign quality gates before implementation becomes deep.
   The current audit scripts target the wrong locations for this branch shape:
   - `scripts/dart/audit_ddd_solid_dry.sh` still assumes `lib/`
   - `scripts/rust/audit_ddd_solid_dry.sh` defaults to a non-existent `rust/crates/crispy-core/src`
   These should be adapted early so MV/DDD/SOLID/DRY checks become valid guards for the rewrite instead of stale theater.

5. Start Widgetbook and token parity immediately with the shell primitives.
   Use:
   - `design/docs/design-system.md`
   - `design/docs/app-overhaul-design-system.md`
   - `app/flutter/pubspec.yaml`
   to ensure tokens originate in Flutter first, Widgetbook stories exist for shared primitives early, and Penpot mirrors rather than leads.

6. Sequence delivery by dependency, not by excitement.
   Recommended execution order after the shell is navigable:
   - App Shell
   - Settings
   - Shared Source/Provider Registry
   - Live TV
   - Media
   - Search
   - Shared Playback Session hardening
   - Player investigation subplan
   - Player implementation last

## ADR Seed

### Decision

Adopt a shell-first CrispyTivi v2 rewrite in which Flutter owns only TV-first view/runtime concerns and Rust FFI owns controller, business, domain orchestration, and provider translation.

### Drivers

- performance-first TV browsing across large datasets
- strict Flutter MV-only boundary
- one shared shell/runtime before vertical delivery

### Alternatives Considered

- backend/context-first rewrite before shell proof
- vertical-first pilot rewrite before shared shell/runtime standardization

### Why This Decision Wins

It is the best fit for an empty Flutter rewrite branch, the existing Rust shared crate base, the requirement for common day-1 windowing primitives, and the requirement that Search/detail state and later Player entry target canonical domain shapes.

### Consequences

- More upfront design work on shell/runtime contracts.
- Early audit-script and test-harness realignment is mandatory.
- Stub screens must remain behavior-light so Dart does not absorb business logic.
- Player remains intentionally deferred and must not become a backdoor architecture driver.

### Follow-ups

- define the canonical input action matrix
- define the day-1 windowing primitive API surface
- define the minimal Rust canonical kernel and optional capability modules
- define canonical detail/focus state for Search and domain handoff
- create a dedicated player investigation plan before player work starts

## Acceptance Criteria For This Initial Plan

- Principles reflect the stated performance, architecture, and shell-first priorities.
- Decision drivers are limited to the three forces most likely to change structure.
- Options are all viable but clearly bounded.
- The chosen option preserves the player-last gate.
- Repo-grounded recommendations reference real checked-in paths only.
- ADR seed is ready to expand into a fuller consensus artifact without changing direction.
