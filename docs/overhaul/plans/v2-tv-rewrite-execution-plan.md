# CrispyTivi v2 TV Rewrite Execution Plan

Status: Active
Date: 2026-04-11

## Restart cause

Previous work drifted because it:

1. implemented before the overhaul design was fully grounded
2. treated scaffolding as adherence
3. let derived design guesses replace the authoritative docs
4. reintroduced aggregator-style structural drift
5. let passing tests stand in for design compliance
6. allowed generic shell scaffolding to count as implementation progress
7. allowed oversized mixed-responsibility files and weak boundaries to replace
   disciplined architecture
8. stopped without web-target smoke verification or browser-driven visual checks

## Correct sequence

### Phase 0: reset and re-ground

- remove invalid scaffolds and incorrect restart artifacts
- re-read the authoritative design sources
- treat `docs/overhaul/plans/v2-conversation-history-full-spec.md` as the active
  authority when it conflicts with older restart assumptions
- treat `design/docs/penpot-installed-design-system.md` as the installed visual
  and shell authority for implementation work
- use `design/docs/design-system.md` and
  `design/docs/app-overhaul-design-system.md` as supporting design docs
- ground visual composition against the downloaded Google TV / Apple TV /
  Netflix / YouTube reference set in `design/reference-images/`
- document the restart rules clearly

Phase 0 is now complete for the current restart lane:

- premature Flutter and Rust restart code was removed
- repo baseline was returned to the tracked clean branch placeholders
- active plan/docs were repinned to the installed design authority and its
  pinned baseline
- phase-4 kickoff was explicitly blocked until later reactivation
- restart authority is now repo-visible instead of being implied by deleted code

### Phase 1: overhaul design-system foundations

- installed design docs first
- JSON token verification
- Flutter overhaul token source
- design-doc verification and drift audit
- drift audit against active v2 spec and approved screen language
- verification must include Linux and web target checks for all changed token
  and theme surfaces

### Phase 2: Widgetbook and shell planning

- exact shell specimen list
- exact installed design-doc responsibilities
- route-level visual intent
- route-level composition rules that implementation must follow literally
- file/module decomposition rules for the upcoming implementation so Phase 4
  cannot collapse into god files

Phase 2 planning remains the active shell-planning baseline for the current
restart lane:

- exact shell specimen coverage is documented
- design-doc responsibilities are explicitly mapped
- route-level shell visual intent is documented against the approved baseline
- active phase-2 docs no longer reference stale reboot-era board names

### Phase 3: shell IA, focus, and navigation planning

- top-nav vs local-sidebar behavior
- per-domain local navigation
- focus maps and back/menu rules
- explicit guard against generic placeholder shell composition
- explicit module boundaries for Flutter presentation and Rust domain layers

Phase 3 planning remains the active IA/focus baseline for the current restart
lane:

- shell IA ownership is explicitly documented
- focus-region and route-entry rules are explicitly documented
- back/menu unwind behavior is explicitly documented
- component-focus contracts are explicitly documented
- active phase-3 docs align with the authority stack and pinned shell baseline

### Phase 4: shell implementation

- only after phases 1-3 are complete
- route visuals must match the approved shell boards and route intent before the
  phase can close
- implementation must use the installed design docs directly as the build
  authority
- implementation must preserve readable small modules and explicit
  responsibility boundaries
- verification must include Flutter automated tests, Linux smoke tests, web
  smoke tests, and Playwright CLI browser checks against the built web target

Phase 4 has now been rebuilt for the current restart lane:

- the shell was rebuilt from the empty baseline after the latest reset
- the active runtime follows the installed design docs and approved reference
  images rather than old screenshots or old code
- top-level navigation is limited to Home, Live TV, Media, Search, and
  Settings
- Sources now lives inside Settings
- Player is not top-level navigation
- Linux analyze/tests/builds and web build/browser smoke all pass on the
  rebuilt shell

### Phase 5: technical contracts and shared support

- technical contracts in support of the approved shell
- shared support needed before domain parallelization
- vertical delivery later
- player last

Phase 5 is now complete for the current restart lane:

- Rust owns the canonical shell contract shape in `crispy-ffi`
- Flutter loads the contract from a canonical asset and validates it before
  rendering the shell
- Rust also owns the canonical mock content snapshot shape for populated shell
  route surfaces
- Flutter loads the content snapshot from a canonical asset rather than keeping
  populated route content in local Dart seed files
- retained shell domain/presentation code now keeps neutral production naming;
  only asset-backed fake repositories and fixtures keep explicit source naming
- startup route, top-level domain ordering, settings-group ordering, Live TV
  panel/group ordering, Media panel/scope ordering, and Home quick-access
  ordering are now explicit contract surfaces rather than hidden local runtime
  assumptions
- asset-backed bootstrap resolves contract and content together into one stable
  startup payload

### Phase 6: onboarding/auth/import completion

- complete the shared onboarding/auth/import lane before domain delivery begins
- close the remaining cross-domain foundation work that later domain lanes will
  depend on
- do not begin domain-parallel implementation until this phase is fully
  complete

Phase 6 is now complete for the current restart lane:

- source onboarding/auth/import now exists as a Settings-owned flow rather than
  only static source-health cards
- existing sources open source overview/detail first
- adding a source opens a wizard with explicit ordered steps
- reconnect/auth flows reuse the same wizard lane and can enter at the
  credentials step
- wizard step ordering is contract-owned and validated through the canonical
  shell contract asset
- wizard step copy/content is content-snapshot owned and validated through the
  canonical shell content asset
- source wizard unwind/back safety is view-model owned and verified so backing
  out of the wizard returns to the Settings-owned source overview instead of
  leaving the shell in a detached transient state

### Phase 7: settings completion

Phase 7 is now complete for the current restart lane:

- settings top-level group navigation is verified across General, Playback,
  Sources, Appearance, and System
- Settings search now stays local to the Settings hierarchy, shows explicit
  result activation, and opens the exact leaf only after activation
- exact-leaf Settings activation is view-model owned and keeps the opened leaf
  highlighted inside the grouped Settings hierarchy
- source-management search hits open the correct source detail inside
  Settings-owned Sources rather than escaping into a detached source domain

### Phase 8: live TV completion

Phase 8 is now complete for the current restart lane:

- the Live TV sidebar owns only local subview navigation: `Channels` and
  `Guide`
- Live TV group/category switching now stays inside content rather than
  drifting back into the sidebar
- Channels now keeps a dense left browse pane plus a selected-channel detail
  lane on the right
- focus updates selected-channel metadata only; playback remains on the active
  channel until explicit tune activation
- Guide keeps selected-channel summary plus preview/matrix separation without
  implying retune during browse
- canonical content snapshot and tests now cover the approved Live TV browse
  and guide schema

### Phase 9: EPG / detail overlays completion

Phase 9 is now complete for the current restart lane:

- the Guide subview now renders from canonical `live_tv_guide` row/program
  data instead of relying on placeholder string-table rendering
- selected-channel guide summary remains separate from the matrix
- focused-program detail overlay now shows focused slot, program summary,
  live-edge state, and catch-up/archive affordances above the matrix
- guide browse mode keeps retune/play actions out of the overlay lane
- tests now verify guide overlay behavior and no-tune-action guide browse
  behavior directly

### Phase 10: movies completion

Phase 10 is now complete for the current restart lane:

- movie browsing now leads with film-first emphasis inside Media
- movie detail remains explicit and separate from the shelf rail
- movie playback handoff launches only from movie detail, not directly from
  the shelf lane
- movie-specific tests now verify the detail-to-player-preview handoff

### Phase 11: series completion

Phase 11 is now complete for the current restart lane:

- series browsing now emphasizes season and episode continuity rather than
  reusing movie detail language
- season selection and episode selection stay explicit in the series detail
  lane
- series playback handoff launches from episode selection only
- series-specific tests now verify season/episode handoff behavior

### Phase 12: search completion

Phase 12 is now complete for the current restart lane:

- Search now behaves as a canonical cross-domain content handoff surface
- search results map cleanly into Live TV, Movies, and Series detail intent
- Search remains clearly separated from Settings-local search behavior
- search-specific tests now verify domain-detail handoff copy and selection
  updates

After Phase 6 is fully complete:

- domain delivery may run in parallel agents when the domains are independent
  enough to avoid overlapping write scopes
- one orchestrator owns one whole phase and keeps that phase until full
  closure; partial phase slices do not count as progress toward the next phase
- preferred staffing is one active worker per independent domain/module lane
- each delegated domain lane must have explicit file ownership and must still
  follow the full authority stack, installed design docs, and active spec/docs
- parallelism is an acceleration tool for delivery after the shared foundation
  is closed, not a bypass around phase order or review discipline
- each phase orchestrator must re-audit drift/gaps after implementation,
  rework until the phase is actually clean, rerun verification, and update the
  docs before that phase may close

### Player pre-code design gate

Before **any** player implementation code starts:

1. gather fresh official and non-official player references
2. gather screenshot/image references for:
   - Google TV player / system overlays where relevant
   - Apple TV player / transport / overlay behavior
   - Netflix player / cinematic detail density / OSD
   - YouTube player / OSD / info hierarchy
3. update the player subplan with those references
4. create/recreate Penpot player boards from that player subplan
5. verify those Penpot player boards before any player code is allowed

Player code is blocked until this gate is complete.

## Guardrails

- phase order is strict: do not start or claim a later phase while an earlier
  phase remains incomplete unless the user explicitly changes the sequence
- do not start parallel domain agents before Phase 6 is fully complete
- after Phase 6 is fully complete, parallel domain agents are allowed only for
  independent lanes with explicit ownership and no overlapping write scope
- no design invention beyond the authoritative docs
- no shell code before design-system and shell planning are complete
- no implementation from old screenshots, old app code, or remembered Penpot
  layouts when the installed design docs already define the answer
- no generic Material placeholder work presented as progress
- no phase completion claim if visual drift remains
- no large aggregator/barrel/mod surfaces unless explicitly justified
- no god files or mixed-responsibility modules accepted as phase-complete work
- no stop without Linux and web smoke verification for changed surfaces
