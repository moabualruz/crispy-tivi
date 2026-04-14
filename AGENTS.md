# CrispyTivi Project Guidance

- Follow the approved Penpot design as the visual source of truth.
- Follow the message-history v2 spec and approved Penpot file/page before any checked-in screenshot or older repo doc.
- When a repo-local installed Penpot snapshot exists, use `design/docs/penpot-installed-design-system.md` as the Markdown design-system authority for implementation.
- Flutter owns view and view-model only; Rust owns business/domain logic and provider translation.
- Flutter may keep passive presentation-side controller/view-state surfaces only
  when they are thin consumers of Rust-owned runtime snapshots or Rust-owned
  controller outputs.
- Flutter bridge/platform shims are allowed when they are thin transport or
  adapter layers only; they must not become a home for runtime, business,
  provider, or mock logic.
- Flutter must not be the long-term owner of provider setup, import/auth state
  machines, persistence rules, runtime hydration, mock/demo provider logic,
  playback metadata derivation, diagnostics derivation, or Home/runtime
  aggregation.
- If a Flutter presentation/controller surface is still deriving chooser state,
  playback URIs, playable-backend readiness, host-tooling availability, or
  runtime fallback content, treat that as migration debt that must be called
  out explicitly in phase docs until a Rust-owned replacement is active.
- Mock/demo providers, seeded assets, provider catalogs, configured-provider
  state, and hydrated runtime data must be Rust-owned too. Flutter may render
  demo/mock outputs, but it must not author or shape the mock/runtime truth
  outside explicit test-only fixtures.
- For real implementation phases, prefer the existing shared Rust submodule
  crates under `rust/shared/crispy-*` before introducing new Rust dependencies
  or duplicating protocol/business logic in app-local crates.
- Treat the shared Rust crates as the default foundation for:
  M3U parsing, XMLTV parsing, Xtream integration, Stalker integration, catchup
  URL derivation, playlist normalization, stream validation, and media probing.
  Any deviation must be explicitly justified in the docs for the phase.
- Prefer small, reversible diffs.
- No new dependencies unless explicitly requested.
- Keep tests and analysis green before claiming completion.
- Prefer design-faithful implementation over placeholder/spec-card UI.
- At every step, verify the current implementation and plan against the approved Penpot design, active spec, and active requirements for drift or gaps.
- For every implementation pass, build a flat requirement ledger from the
  current user instructions before editing. Track every explicit request as one
  of: `done`, `blocked`, or `superseded by newer user instruction`.
- Do not silently drop any part of a user request. If an item cannot be
  completed in the current pass, call it out explicitly as `blocked` before
  stopping.
- Convert every user-reported drift, gap, or requirement into an explicit
  closure checklist for the current pass. Do not stop until each checklist item
  has been reverified in code, docs, and rendered output or is explicitly
  blocked/escalated.
- When any drift, mismatch, or missing requirement is found and corrected, update
  the governing docs/plans/design docs in the same pass so the same drift does
  not reappear later.
- Any user-requested rule or behavior change must be reflected in both code and
  the governing docs/design docs in the same pass before completion is claimed.
- Treat approved reference images as grounding for composition and chrome behavior, but never let legacy repo screenshots or any main-branch app screenshots override the active Penpot/spec authority.
- Ignore `docs/screenshots/` and any old main-branch app captures completely for v2 rebuild decisions.
- If any drift, mismatch, or missing requirement is found, fix it before claiming phase completion or moving to the next phase.
- Do not describe the project as product-complete when only the UI-first shell,
  mocked flows, or retained presentation baseline is complete. Distinguish
  clearly between UI-first baseline completion and full implementation
  completion.
- Do not start or claim a later phase while an earlier phase remains incomplete.
  Phase order is strict unless the user explicitly overrides it.
- Execution ownership is phase-based.
  One orchestrator owns one phase and stays with that phase until it is fully
  complete, re-audited for drift/gaps, reworked if needed, verified, and
  documented.
- Do not fragment a single phase into partial completion slices across
  multiple orchestrators just to increase activity.
- Parallel domain delivery is allowed only after Phase 6 is fully complete.
  Before that point, do not split work across parallel agents for later-domain
  implementation lanes.
- After Phase 6 is fully complete, independent domain lanes may be delegated to
  parallel agents to accelerate delivery, but only with explicit ownership,
  doc/spec compliance, and no overlap in write scope.
- Allowed parallelism after Phase 6 is:
  one orchestrator per independent phase or one orchestrator per independent
  domain phase, as long as those phases do not conflict in authority, write
  scope, or sequencing.
- Inside a phase, the orchestrator may delegate bounded subwork, but the phase
  is not considered done until that orchestrator has integrated everything,
  rechecked for drift/gaps, rerun verification, and closed the docs for that
  phase.
- Preferred post-Phase-6 parallelization is one active worker per independent
  domain/module write scope, with shared theme/contract/test/doc integration
  files reserved for leader-owned integration unless explicitly reassigned.
- Do not accept large god files, ad hoc aggregator structures, or unreadable mixed-responsibility modules. Keep files small enough to review, split by responsibility, and aligned with DDD, SOLID, LOB, and DRY expectations.
- Flutter code must be organized into clear presentation/view-model/view-state surfaces. Rust code must be organized into clear domain/application/infrastructure surfaces. Do not collapse those responsibilities into single large files for speed.
- When a shared Rust crate or `crispy-ffi` can own a runtime/controller
  concern, do not keep that concern in Flutter as a retained-runtime
  convenience layer. Any temporary Flutter-side runtime/business logic is
  migration debt only and must be removed by the next boundary-correction
  phase; it must never be normalized as acceptable steady-state architecture.
- If a reseted code base is requested, treat all prior implementation as disposable unless it is explicitly re-approved. Do not reuse prior composition assumptions just because the repo is clean.
- Before each stop, verify the changed work on both Linux and web targets with automated smoke coverage appropriate to the change. For UI work, this includes Flutter automated tests plus browser-driven smoke checks using Playwright CLI on the web target whenever the web target exists.
- Web releases must produce the wasm package into `build/web/pkg` via
  `wasm-pack --target no-modules` or the repo's equivalent build script
  `app/flutter/tool/build_web_release_state.sh`, so the runtime can load
  `pkg/crispy_ffi.js` during browser smoke.
- If browser smoke renders and the real-source path reaches real media, keep
  Phase 32 open until Rust default/demo separation and further Rust runtime
  replacement are complete.
- Before each stop, re-read the current turn's user instructions and audit the
  pass against the requirement ledger. If any explicit request is still unmet
  and not marked `blocked` or `superseded`, the pass is not complete.
- Linux verification hygiene is mandatory:
  - before Linux smoke/build work, check for stale `crispy_tivi` and
    `flutter_tester` processes and clear them if they are leftovers from prior
    runs
  - never overlap a manually launched release app window with Linux integration
    smoke/debug runs from the same repo; close the manual app first
  - treat `app/flutter/build/linux/x64/release/bundle/crispy_tivi` as the
    canonical manual-run binary and `app/flutter/build/linux/x64/debug/bundle/crispy_tivi`
    as test-only
  - prefer bounded Linux smoke commands and explicit post-run cleanup so test
    sessions cannot linger indefinitely
  - after Linux smoke/build work, explicitly verify that no stray
    `crispy_tivi` process remains running
  - if a black or hung window is reported while no live `crispy_tivi` process
    remains, treat it as stale desktop/compositor state from an already-dead
    process rather than a still-running app instance
  - if any Linux app window is reported as black or hung, inspect the live
    process list, process state, and the exact binary path first before
    claiming an application regression
  - do not leave behind debug/integration-test app instances between turns
  - Linux integration tests rewrite
    `app/flutter/linux/flutter/ephemeral/generated_config.cmake` to the
    Flutter test-listener target; after any Linux integration-test run, do not
    manually launch the release bundle until the Linux release state has been
    regenerated
  - regenerate Linux release state with
    `app/flutter/tool/restore_linux_release_state.sh` or an equivalent clean
    `flutter build linux` after clearing `linux/flutter/ephemeral`,
    `build/linux`, and `.dart_tool/flutter_build`
  - if a release launch reports
    `FlutterEngineInitialize ... kInvalidArguments` and cannot resolve the
    kernel binary, treat that as Linux managed-build contamination from a test
    listener target first, not as a generic UI/runtime regression
- A phase cannot close on tests alone. It must also pass a visual drift check against Penpot, reference images, and the message-history v2 spec.
- Selection, focus, and active-state styling must be system-level and consistent
  across the app. Do not ship one-off highlight treatments per widget.
- Icon usage must also be system-level and consistent across the app. Do not
  make text carry all structural work when icons should provide scanability,
  hierarchy, utility cues, row markers, chooser cues, and route/supporting
  context.
- Shared icon choices must come from one code authority rather than ad hoc
  per-widget icon picks for the same semantic role.
- Do not pair an icon with a text label when both say the same thing and the
  icon adds no distinct information. Primary navigation and primary action
  controls should stay word-led unless the icon is carrying a separate,
  non-redundant cue.
- The correct icon rule is binary and deliberate:
  use icon-only with accessibility text when the icon fully carries the meaning,
  or use icon+text when the icon adds a useful secondary scan cue. Do not drift
  into random text-only, icon-only, or duplicated icon+text mixes.
- The shared control matrix is also explicit:
  top-level `Home`, `Live`, and `Media` stay icon+text in the primary nav
  cluster; standalone `Search` sits to the left of standalone utility
  `Settings`; player `Back` and player utility controls stay icon-only; the
  `LIVE` state stays icon+text with a live-status dot, not a TV-screen icon.
- Icon sizing and visual weight must also be system-level. Do not let icon size,
  plate size, or icon/text balance drift per widget.
- Icon-only and text-bearing buttons must share the same control heights and be
  rendered through the shared control system instead of mixing `IconButton`
  geometry with unrelated text-button geometry.
- In LTR, the primary nav cluster stays left-aligned and the utility cluster
  stays right-aligned. Mirror that directionally for RTL; do not center the
  primary nav band across the page.
- In-page local navigation follows the same directional rule: left-aligned in
  LTR, right-aligned in RTL. Do not center sidebar/local-nav item content.
- Icon implementation must also be system-level. Repeated shell surfaces must
  consume the shared icon roles/components instead of open-coding raw icon
  plates, gaps, and alignment per widget.
- If the same class of issue appears in more than one place, stop applying
  local patches and move the fix into the shared system/theme/layout/component
  authority first.
- Repo-local HTML preview files must use real icon artwork such as inline SVG,
  not text glyph stand-ins, whenever they depict shell or player chrome.
- Corner radius and control geometry must also be system-level and consistent.
  Do not let buttons, inputs, sidebar selections, info plates, and utility
  controls drift into separate corner languages.
- Backdrop, stage frame, hero chrome, artwork scrims, action controls, settings
  icon plates, and repeated media-card surfaces must also come from shared
  theme/system code rather than local widget literals.
- Artwork handling must also be system-level. Use one shared media-surface
  path for asset-backed mock art, future remote art, loading, and fallback
  behavior instead of raw per-widget asset strings or local `DecorationImage`
  usage.
- When canonical mock content snapshot assets exist, populated route content
  should load from those assets instead of route-local Dart seed constants.
- Production shell/domain/presentation code must use neutral names.
  Reserve `mock`, `fake`, or `asset` prefixes for test fixtures, temporary
  asset-backed repositories, and explicitly non-production sources only.
- Production code must not encode migration history, phase numbers, or plan
  labels in module names, type names, function names, route names, or FFI API
  names. Use domain names that would still make sense after the plans are
  forgotten.
- Do not let temporary data-source naming leak into shared UI, view-model,
  contract, navigation, or domain-shape code that will remain in use after FFI
  integration.
- When planning or implementing post-UI-first runtime phases, ground decisions
  in both:
  - the local study repos under `for_study/`
  - the in-repo shared Rust crates under `rust/shared/`
  Do not treat those sources as optional background reading. Fold concrete
  lessons from them into the active implementation plan before building major
  runtime phases.
- Phase 18 runtime-boundary work must expose stable Flutter repository
  interfaces first and keep temporary asset-backed implementations behind
  those interfaces until Rust-backed replacements are ready.
- The runtime replacement map for contract/content/bootstrap ownership must be
  recorded in the phase docs before Phase 18 can be considered closed.
- Phase 19 source/provider work must expose source registry state through the
  retained runtime repository/bootstrap path. Do not drive Settings-owned
  provider/auth/import behavior from legacy `ShellContent` source cards except
  as explicit test-only or injected fallback scaffolding.
- Seeded asset/mock runtime data must never be the default application boot
  mode once the retained runtime phases are active. Asset-seeded content,
  providers, personalization, and runtime snapshots must be available only
  behind an explicit demo/test flag such as `CRISPY_DEMO_MODE` or explicit test
  repository injection.
- Real-mode runtime hydration must be honest. When a configured provider fails
  to hydrate live, media, search, or playback state, surface a Rust-owned
  provider error or a true empty state. Do not fall back to scaffolded demo,
  fixture, or shell-derived content on the real path.
- Explicit demo mode may use Rust-owned seeded runtime only when the runtime
  profile or source-setup seam requests it deliberately. Demo fallback must
  never be inferred from a failed real provider.
- Real mode, demo mode, and injected test-fixture mode must be explicit startup
  policies owned by one runtime-profile boundary. Do not scatter runtime mode
  selection across app bootstrap defaults or hide test-fixture behavior behind
  implicit seeded startup assumptions.
- Fresh installs must boot into a true first-run state with zero configured
  providers unless persisted real user state exists. Do not mask first run with
  seeded provider lists, seeded personalization, or seeded content shelves.
- Source onboarding must distinguish between:
  - provider catalog metadata used to drive the wizard
  - configured provider instances used to drive active source list/detail
  Do not keep those as one implicit seeded list.
- Provider/controller wiring must preserve real provider kinds on the active
  runtime path. Do not collapse `M3U URL` and `local M3U` into one fake
  presentation type once Phase 27 is active.
- Settings-owned source onboarding/auth/import must render real interactive
  controls with valid field types, provider choices, and provider-specific
  options. Placeholder rows or generic label-only text fields are not acceptable
  on the active runtime path.
- Settings-owned source onboarding/auth/import must use real interactive form
  controls on the active runtime path. Do not ship placeholder field rows or
  decorative `Enter ...` text in place of actual input widgets.
- Settings-owned source onboarding/auth/import/edit/reconnect must run through
  one retained controller/state-machine path. Do not keep wizard progress,
  configured-provider mutation, or provider-mode switching in loose
  view-model-local booleans and field maps once Phase 27 is active.
- Source onboarding action/state transitions must come from a Rust-owned source
  setup snapshot/action boundary once the Rust-boundary correction track is
  active. Flutter may render the wizard and forward intents, but it must not
  keep an app-side source setup controller/state machine as active truth.
- Phase 20 Live TV / EPG work must expose live channel, guide, and selection
  state through the retained live-TV runtime repository/bootstrap path. Do not
  keep the active Live TV route on heuristic group slicing or legacy
  `ShellContent` live-TV browse/guide fields except as explicit injected
  fallback scaffolding for tests.
- Asset-backed retained runtime snapshots must stay deterministic across
  environments. Do not let machine-dependent host capability checks such as
  local ffprobe/ffmpeg availability leak into retained bootstrap assets or
  exact asset-snapshot tests.
- When host-environment diagnostics are required, expose them through a
  separate runtime/helper path instead of mutating the deterministic retained
  asset-backed snapshot.
- Phase 21 Media/Search work must expose movie rails, series rails, series
  detail, search groups, and search-result handoff state through retained
  media/search runtime repositories and the bootstrap path. Do not keep the
  active Media or Search routes on legacy `ShellContent` movie/series/search
  fields except as explicit injected fallback scaffolding for tests.
- Phase 22 playback backend work must keep chooser state real. Source,
  quality, audio, and subtitle selections must come from runtime playback
  metadata and must apply to the retained playback backend, not remain static
  presentation-only labels.
- Playback backend readiness, track/variant selection application, and
  diagnostics derivation must be driven by Rust-owned runtime/controller truth
  once the Rust-boundary correction track is active. Flutter may host the
  player widget surface and thin consumption adapters, but it must not remain
  the long-term owner of playback policy or diagnostics derivation.
- Phase 23 persistence/personalization work must expose startup-route memory,
  continue-watching, recent items, and watchlist/favorite state through the
  retained personalization runtime repository/bootstrap path. Do not keep the
  active Home/Media/player behavior on legacy `ShellContent` rails or route-
  local session memory except as explicit injected fallback scaffolding for
  tests.
- Once retained runtime boundaries exist for a surface, routes and view-models
  must consume those runtime snapshots directly. Do not keep active
  `resolve*Runtime(...)` fallback shaping or legacy shell-content backfill
  logic in presentation code.
- Home must stay runtime-truthful once retained media/live/personalization
  boundaries exist. Do not synthesize hero rails, live-now rails, or continue-
  watching from legacy `ShellContent` or fallback movie collections on the
  active real-runtime path.
- Non-source Settings panels must stay populated from retained runtime and
  diagnostics state rather than `ShellContent` scaffolding once the later
  runtime phases are active.
- Search runtime query/state must survive into presentation. Do not drop the
  retained runtime query and replace it with decorative placeholder-only field
  chrome on the active runtime path.
- Player backend bootstrapping belongs in a retained controller/view-model
  boundary, not widget-local `State` ownership, once the retained playback
  backend phases are active.
- Legacy-content runtime fallback adapters belong in data/bootstrap code only.
  Do not keep legacy-to-runtime fallback factories inside retained domain
  models, and do not build runtime fallback state directly inside routes or
  view-models.
- Do not describe the retained runtime foundation track as “full app done”.
  Even after Phases 18 to 24 are closed, the product remains incomplete until a
  post-foundation audit/completion track proves:
  - every route, widget, wizard, chooser, and empty state is verified in real
    runtime mode
  - explicit demo/test mode is gated and does not leak onto the default boot
    path
  - provider/setup/auth/import flows are runtime/controller-backed end to end
  - real-source/manual validation is complete
- A workflow is not considered wired just because it renders fields, options,
  or seeded data. It is only considered wired when visible state, choices, and
  actions are backed by the retained runtime/controller path in real mode.
- After the retained runtime foundation phases, a full-app audit ledger is
  mandatory before product-completion claims. That ledger must classify every
  major route/widget/workflow as:
  - wired
  - blocked
  - superseded
- Phase 25 must populate a real audit ledger before later repair phases start.
- Phases 26 to 28 may not close on widget rendering alone; they must prove
  runtime/controller ownership on the active real path.
- Phase 29 may not close on automated tests alone; it must include manual
  real-source validation and explicit release-readiness judgment.
- Phase 29 must separate:
  - external source/provider health
  - app runtime/provider integration health
  A healthy real source is not enough to call the app release-ready if the app
  still commits provider setup into local state only or fails to hydrate the
  retained runtime path from that source.
- If Phase 29 closes as `not ready`, do not resume ad hoc implementation.
  Create and follow a documented remediation track first, with explicit phases
  for:
  - provider persistence/import runtime
  - provider-driven runtime hydration
  - Rust boundary correction + source/provider migration + runtime hydration
    migration + real-source in-app proof
  - playback and diagnostics Rust migration + release-readiness rerun
- If that remediation track closes as `not ready`, do not continue with ad hoc
  cleanup inside the closed track. Create and follow a documented follow-on
  blocker-removal track first, with explicit phases for:
  - remaining shared Rust crate activation on the active runtime path
  - release-warning cleanup on the active Rust/FRB path
  - final release-readiness rerun
- If the follow-on cleanup track reaches Phase 39, treat FRB warning debt as a
  verification-gated release-warning cleanup on the active Rust/FRB path. When
  `crispy-ffi` inherits workspace lints in
  `rust/crates/crispy-ffi/Cargo.toml`, do not mark the lane closed until the
  final Linux, web, wasm, browser smoke, and real-source rerun is green.
- Phase 30 must move provider setup/import commits onto retained runtime
  repository persistence. Do not let the source wizard close as if work is
  saved when it only mutated local controller/view-model state.
- Phase 30 real-mode bootstrap must preserve persisted configured providers
  from the retained source repository instead of clearing them back to an empty
  registry on every boot.
- Phase 31 must hydrate retained Home, Live TV, Media, and Search runtime
  snapshots from configured providers on the real boot path. Do not leave real
  boot on "persisted providers but empty runtime" after provider persistence
  exists.
- Phase 31 hydration logic belongs in retained data/bootstrap ownership, not
  in routes or view-models, and unsupported content lanes must stay empty
  rather than showing unrelated demo/runtime shelves.
- If later review shows those retained data/bootstrap layers still own
  provider/runtime business logic in Flutter, stop and create a documented
  boundary-correction track before proceeding.
- Phase 32+ remediation must treat Flutter-owned provider/runtime business
  logic as blocker-class drift, not polish debt. The next allowed lane must
  first move source/provider setup truth, runtime hydration truth,
  playback-metadata truth, diagnostics truth, and mock/demo truth back behind
  Rust-owned boundaries before more feature work or release claims.
- Shared Rust provider-crate activation is not satisfied by Cargo declarations
  alone. It requires all of the following:
  - shared crates are used in the active runtime crate graph
  - Rust emits the runtime/provider/controller truth consumed by Flutter
  - Flutter stops authoring the corresponding business/runtime logic locally
  - phase docs record which Flutter files remain temporary migration shims and
    which were removed
- For broad runtime/design repair phases, audit both:
  - online primary/reference sources as needed
  - the local study repos under `for_study/`
  before implementation, then record the resulting rules in the active phase
  docs in the same pass.
- Mock imagery must be domain-relevant and curated for TV/media context. Do not
  use arbitrary personal, meme, pet, or otherwise off-domain placeholders in
  populated shell mocks.
- Consistent does not mean softer. Do not solve inconsistency by increasing
  rounding until controls become pill-like.
- The fixed shell stage must stay product-sized at `1080p` and must not leave
  oversized dead gutters at larger resolutions. Solve that in the shared stage
  system, not with per-widget scale tweaks.
- Do not place permanent `Back` or `Menu` controls in the global navigation bar unless the user/spec/Penpot explicitly requires them.
- Do not use old-app underline or underscore navigation cues, pill/chip-heavy treatment, or other visibly old-shell cues unless they are explicitly present in Penpot.
- `Sources` belongs under `Settings`, not as a top-level global domain, unless the user explicitly changes that rule.
- `Sources` also must not reappear as a stand-alone Home shortcut or other
  bypass around the Settings-owned source-management flow.
- `Player` is not a top-level global navigation destination.
- These rules apply to the orchestrator and every delegated agent/sub-agent without exception.
- Delegated work must be checked against this file before implementation and before completion claims.
- Final completion claims should make omissions visible by separating:
  - `done`
  - `still open`
  - `blocked`
