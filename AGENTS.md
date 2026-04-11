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
- Consistent does not mean softer. Do not solve inconsistency by increasing
  rounding until controls become pill-like.
- Do not place permanent `Back` or `Menu` controls in the global navigation bar unless the user/spec/Penpot explicitly requires them.
- Do not use old-app underline or underscore navigation cues, pill/chip-heavy treatment, or other visibly old-shell cues unless they are explicitly present in Penpot.
- `Sources` belongs under `Settings`, not as a top-level global domain, unless the user explicitly changes that rule.
- `Player` is not a top-level global navigation destination.
- These rules apply to the orchestrator and every delegated agent/sub-agent without exception.
- Delegated work must be checked against this file before implementation and before completion claims.
