# Phase 25: Full App Runtime Audit

Status: complete
Date: 2026-04-13

## Purpose

Phase 25 starts the post-foundation audit track. Phases 18 to 24 established
retained runtime boundaries and backend wiring, but they do not prove that the
whole app is truthful and fully wired on the active real-runtime path.

This phase exists to produce that truth map before more completion claims are
made.

## Required audit scope

The phase must audit every major user-facing area in both:

- real runtime mode
- explicit demo/test mode

Minimum audit surface:

- Home
- Live TV
- Media
- Search
- Settings
- Sources/provider setup/auth/import/edit/reconnect
- Player

## Required outputs

- one flat audit ledger for all major routes/widgets/workflows
- exact state per item:
  - wired
  - blocked
  - superseded
- explicit distinction between:
  - runtime/controller-backed behavior
  - demo/test-only behavior
  - fallback/scaffold behavior still visible on the real path
- exact repair order for unresolved items
- explicit research notes for each major repair class grounded in:
  - online primary/reference sources where needed
  - the local study repos under `for_study/`

## Required audit dimensions

Each audited item must be checked for all of the following:

- visual/render correctness
- focus/navigation/unwind correctness
- real runtime/controller ownership
- demo/test-mode behavior
- first-run/empty-state truthfulness
- fallback/scaffold leakage
- docs/spec alignment

## Required artifact shape

The audit ledger must capture at least:

- screen/route/widget/workflow name
- real-mode state:
  - wired
  - blocked
  - scaffolded
- demo/test-mode state:
  - wired
  - blocked
  - scaffolded
- controller/runtime owner
- fallback/scaffold owner if any
- user-visible impact
- repair phase target:
  - Phase 26
  - Phase 27
  - Phase 28
  - Phase 29

## Closure rules

Phase 25 is complete only when:

- the audit ledger exists in the docs
- no known runtime/design gap found during the audit is left undocumented
- the next repair phases are decomposed from the audit results rather than
  guessed ad hoc
- a research-notes artifact exists for the major repair classes so later
  implementation phases are grounded before rewrites start
- the audit ledger is populated from actual audit work, not only created as an
  empty template

Artifacts produced:

- `docs/overhaul/plans/v2-phase25-audit-ledger.md`
- `docs/overhaul/plans/v2-phase25-research-notes.md`
- `docs/overhaul/plans/v2-phase25-repair-order.md`

## Notes

- This phase may uncover large rewrites.
- That is expected and does not count as drift if the docs are updated first.
