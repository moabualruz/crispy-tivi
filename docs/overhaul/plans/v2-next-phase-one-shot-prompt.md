# V2 Next-Phase One-Shot Prompt

Use this prompt for the next implementation patch from the current saved
baseline on `design/app-overhaul-system`.

## Prompt

You are the orchestrator for the next one-shot CrispyTivi v2 shell patch.

Do **not** restart from zero. Do **not** reintroduce old shell assumptions.
Build from the current saved baseline and correct the next set of issues in one
shot.

### Authority stack

Follow this order without exception:

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
3. `design/docs/penpot-installed-design-system.md`
4. supporting design docs:
   - `design/docs/design-system.md`
   - `design/docs/app-overhaul-design-system.md`
5. Phase 18 runtime boundary doc:
   - `docs/overhaul/plans/v2-phase18-runtime-contract-reset.md`
6. Phase 19 source/provider registry doc:
   - `docs/overhaul/plans/v2-phase19-source-provider-registry.md`
7. Phase 20 live TV / EPG doc:
   - `docs/overhaul/plans/v2-phase20-live-tv-epg.md`
8. Phase 21 media / search doc:
   - `docs/overhaul/plans/v2-phase21-media-search.md`
9. Phase 22 playback backend doc:
   - `docs/overhaul/plans/v2-phase22-playback-backend.md`
10. Phase 23 persistence/personalization doc once active:
   - `docs/overhaul/plans/v2-phase23-persistence-personalization.md`
11. Phase 24 production hardening doc once active:
   - `docs/overhaul/plans/v2-phase24-production-hardening.md`
12. Phase 25 full app runtime audit doc once active:
   - `docs/overhaul/plans/v2-phase25-full-app-runtime-audit.md`
13. Phase 26 demo/test gating and first-run truth doc once active:
   - `docs/overhaul/plans/v2-phase26-demo-test-gating.md`
14. Phase 27 provider/controller wiring completion doc once active:
   - `docs/overhaul/plans/v2-phase27-provider-controller-wiring.md`
15. Phase 28 screen/widget runtime audit closure doc once active:
   - `docs/overhaul/plans/v2-phase28-screen-widget-runtime-audit.md`
16. Phase 29 release-readiness audit doc once active:
   - `docs/overhaul/plans/v2-phase29-release-readiness.md`
17. post-Phase-29 remediation track once active:
   - `docs/overhaul/plans/v2-post-phase29-remediation-plan.md`
18. Phase 30 provider persistence/import runtime doc once active:
   - `docs/overhaul/plans/v2-phase30-provider-persistence-import-runtime.md`
19. Phase 31 provider-driven runtime hydration doc once active:
   - `docs/overhaul/plans/v2-phase31-provider-driven-runtime-hydration.md`
17. approved reference images in `design/reference-images/`
18. active v2 plan docs in `docs/overhaul/plans/`

Non-authority:

- `docs/screenshots/`
- any old main-branch app screenshots
- any old shipped-app captures
- any prior mock-shell screenshots
- any previous implementation that drifts from the current installed design
  docs

### Starting state

Assume the current branch already has:

- a saved modular shell baseline
- installed design docs in Markdown
- a dedicated token file:
  - `app/flutter/lib/core/theme/crispy_overhaul_tokens.dart`
- a dedicated shell-role file:
  - `app/flutter/lib/core/theme/crispy_shell_roles.dart`
- Linux build/test/analyze already working

This run is **not** a reset run. It is a focused refinement/systemization run.

### Mission

Execute the next allowed phase or tightly-coupled phase group in one shot.

Do not start or claim any later phase while an earlier phase is still
incomplete unless the user explicitly changes the sequence.
Do not start parallel domain-agent delivery before Phase 6 is fully complete.
After Phase 6 is fully complete, independent domain lanes may run in parallel
agents only when ownership is explicit and write scopes do not overlap.
One orchestrator owns one whole phase. Do not split a phase into partial
progress slices across multiple orchestrators and call that completion.
Do not start a later phase just because an earlier runtime-foundation phase was
marked complete if the active docs still show the next allowed lane is an audit
or gating phase.
If sub-agents are used inside a phase, the orchestrator must stay responsible
for end-to-end closure: re-audit drift/gaps, integrate, rerun verification,
update docs, and only then declare the phase complete.

Your job is to:

1. audit the current implementation against the installed design docs, the v2
   spec, and the reference images
2. audit the active docs/plans for any drift or missing rules exposed by the
   current implementation
3. fix the docs first where they are incomplete
4. fix the implementation in a system-first way, not widget-by-widget guesswork
5. stop only when the targeted patch scope is corrected, verified, and
   documented
6. if the targeted phase is an audit/gating phase, do not downgrade it into a
   small fix pass; produce the audit ledger, repair order, and doc updates the
   phase actually requires
7. if the next allowed lane is Phase 25, do not spend the pass on isolated bug
   fixes; produce the populated audit ledger, research notes, and repair order
   first
8. if the next allowed lane is Phase 26, make runtime mode selection explicit
   and testable before deeper provider/runtime wiring; do not leave demo/test
   gating implied by scattered bootstrap defaults
9. if the next allowed lane is Phase 27, preserve real provider kinds and move
   source setup/auth/import/edit/reconnect onto one retained controller path;
   do not leave wizard progress or configured-provider updates as loose
   view-model-local maps and booleans
10. if the next allowed lane is Phase 29, do not treat it as another internal
    wiring pass; run manual real-source validation, release-readiness checks,
    and blocker triage from the Phase 25 ledger plus the later runtime phases
    before discussing product completion
11. if the active docs show no next allowed lane inside the current track, do
    not invent a Phase 30. Stop and require a newly documented remediation or
    follow-on track first.
12. if a documented post-Phase-29 remediation track exists, use that track as
    the new phase authority instead of stopping at the earlier full-runtime
    closure docs.
13. if the next allowed lane is Phase 30, move source setup/import commits onto
    retained source-registry persistence first; do not leave configured
    providers as local-only controller/view-model mutation and do not clear
    them back to empty on the next real boot.
14. if the next allowed lane is Phase 31, hydrate retained Home, Live TV,
    Media, and Search runtime snapshots from configured providers on real
    boot; do not leave persisted providers wired while those lanes still boot
    empty, and keep unsupported lanes empty instead of showing unrelated demo
    shelves.
15. if the next allowed lane is Phase 32, do not start patching code blindly.
    First produce the Rust-boundary correction map, anti-drift rule updates,
    and the swarm execution plan that moves provider/runtime/controller
    ownership back into Rust. That same phase also owns source/provider
    migration, runtime hydration migration, and the real in-app proof under
    the corrected boundary.
16. if the next allowed lane is Phase 35 or later in the remediation track, do
    not accept retained runtime in Flutter as valid architecture. Those phases
    must delete Flutter-owned business/runtime logic, not just add Rust
    alongside it.
17. if the remediation track through Phase 35 is already marked complete and
    the docs show no next allowed lane, do not invent more work inside that
    track. First document the follow-on blocker-removal track explicitly.
18. if the next allowed lane is Phase 38, activate the remaining shared
    `crispy-xmltv` and `crispy-catchup` crates on the active runtime path
    rather than adding new Flutter-side guide/archive logic.
19. if the next allowed lane is Phase 39, treat it as release-warning cleanup
    plus the final readiness rerun; do not hide residual warning debt behind a
    passing test matrix.
20. if Phase 39 is complete and the active docs show no next allowed lane
    inside the cleanup track, do not invent more cleanup work. Stop and require
    a newly documented track before continuing.

### Mandatory system rules

- Do not solve system problems with one-off widget patches.
- If a drift affects more than one widget, create or extend a shared theme or
  role system to own it.
- Widget-level colors, radii, state styling, and geometry must come from:
  - `crispy_overhaul_tokens.dart`
  - `crispy_shell_roles.dart`
- Do not introduce new scattered literals for shell styling when a shared role
  can own them.
- Do not solve inconsistency by softening everything until controls look like
  pills.
- Do not let scaling rules change the shell’s internal composition from one
  screen size to another.

### Mandatory drift rules

- When you discover a drift or gap and fix it in code, update the active
  docs/plans in the same pass.
- Do not leave known drift unrecorded in the docs.
- Do not claim a fix if the system rule that would prevent recurrence is still
  missing.

### Mandatory architecture rules

- Follow DDD, SOLID, LOB, and DRY.
- No god files.
- No mixed-responsibility modules.
- Flutter owns presentation/view-model/view-state only.
- Rust owns business/domain/provider translation only.
- Prefer small, reviewable modules.

### Patch priorities

Address work in this order unless the active repo state makes another ordering
 strictly necessary:

#### Phase A: docs and system authority

- ensure the installed design docs fully reflect the latest user corrections
- ensure the active plans describe the current system model:
  - shared theme-role authority
  - consistent selection/focus geometry
  - non-pill control language
  - same-look-across-sizes scaling rule
  - shared ownership for backdrop, stage frame, artwork scrims, action
    controls, icon plates, and repeated media-card surfaces
  - domain-relevant populated mock imagery rather than arbitrary placeholders

#### Phase B: theme-role completion

- extend `crispy_shell_roles.dart` until the main shell chrome and repeated
  control types stop carrying duplicated styling logic
- ensure the fixed shell stage extents and shell spacing also come from the
  shared role/system layer rather than private page constants
- migrate repeated widget styling into shared role helpers where justified
- reduce remaining shell-style literals
- ensure populated mock imagery still supports the TV/media illusion rather
  than distracting from it

#### Phase C: scaling and shell fill

- preserve the same internal composition across sizes and windows
- fix readability and shell-fill issues without changing the shell’s internal
  feel from one size to another
- treat scaling as a system problem, not a per-widget workaround

#### Phase D: route fidelity corrections

- fix any remaining route-level IA/visual drift still exposed by the spec or
  installed design docs
- ensure Live TV and Media continue to follow the documented local-nav/content
  ownership model

### Mandatory verification before stopping

Before any stop or completion claim, run:

1. `flutter analyze`
2. relevant Flutter tests
3. relevant Rust tests if touched
4. `flutter build linux`
5. `flutter build web` when visual shell work changed
6. browser-driven web smoke when visual shell work changed
7. Linux smoke verification appropriate to the changed surfaces

Also perform a design review against:

- `design/docs/penpot-installed-design-system.md`
- active v2 plan docs
- approved reference images
- `docs/overhaul/plans/v2-conversation-history-full-spec.md`

If the result still drifts visibly or systemically, do not stop.

### Deliverable

Return only when all of the following are true:

- the relevant docs/plans are updated for every drift fixed in the patch
- the patch uses shared system ownership rather than one-off widget decisions
- the shell remains modular and readable
- Linux build succeeds
- web build and smoke checks succeed when relevant
- the patched area is visually and structurally closer to the installed design
  authority than the starting state
