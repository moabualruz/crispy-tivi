# CrispyTivi Project Guidance

- Follow the approved Penpot design as the visual source of truth.
- Follow the message-history v2 spec and approved Penpot file/page before any checked-in screenshot or older repo doc.
- When a repo-local installed Penpot snapshot exists, use `design/docs/penpot-installed-design-system.md` as the Markdown design-system authority for implementation.
- Flutter owns view and view-model only; Rust owns business/domain logic and provider translation.
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
- If a reseted code base is requested, treat all prior implementation as disposable unless it is explicitly re-approved. Do not reuse prior composition assumptions just because the repo is clean.
- Before each stop, verify the changed work on both Linux and web targets with automated smoke coverage appropriate to the change. For UI work, this includes Flutter automated tests plus browser-driven smoke checks using Playwright CLI on the web target whenever the web target exists.
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
- Do not let temporary data-source naming leak into shared UI, view-model,
  contract, navigation, or domain-shape code that will remain in use after FFI
  integration.
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
