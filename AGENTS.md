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
- When any drift, mismatch, or missing requirement is found and corrected, update
  the governing docs/plans/design docs in the same pass so the same drift does
  not reappear later.
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
- A phase cannot close on tests alone. It must also pass a visual drift check against Penpot, reference images, and the message-history v2 spec.
- Selection, focus, and active-state styling must be system-level and consistent
  across the app. Do not ship one-off highlight treatments per widget.
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
