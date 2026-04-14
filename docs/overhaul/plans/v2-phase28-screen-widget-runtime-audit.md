# Phase 28: Screen and Widget Runtime Audit Closure

Status: complete
Date: 2026-04-13

## Purpose

Phase 28 closes the audit findings from Phase 25 by repairing the remaining
route/widget/runtime mismatches.

## Required outcomes

- major screens/widgets are fully wired on the real runtime path
- demo/test-only behavior is clearly gated and does not leak into real mode
- fallback shaping is removed from routes/view-models where retained runtime
  boundaries already exist
- every repaired runtime/design gap is reflected in the governing docs

## Closure rules

Phase 28 is complete only when:

- no major user-facing route/widget remains only partially wired in real mode
- the audit ledger from Phase 25 is either resolved or explicitly blocked with
  owner/rationale
- code, docs, and rendered behavior agree

## Completed in this phase

- removed active presentation fallback shaping from the retained shell path:
  `ShellPage` and `ShellViewModel` now consume retained runtime snapshots
  directly instead of resolving legacy runtime backfills in presentation
- made `Home` runtime-truthful:
  - hero derives from retained media runtime
  - live-now derives from retained live runtime
  - continue watching derives from retained personalization only
  - real-mode empty states are explicit instead of being backfilled from shell
    content
- carried retained search query truth through presentation so the visible
  search field reflects the active runtime query rather than decorative
  placeholder-only copy
- replaced non-source Settings panel population from `ShellContent` scaffolds
  with retained runtime/diagnostics-backed rows
- moved player backend bootstrapping out of widget-local state and onto a
  retained playback controller owned by the shell view-model
- updated the audit ledger, repair order, execution docs, test spec, and
  global rules so these runtime-truth boundaries cannot drift back

## Evidence

- targeted runtime-truth tests were added first and failed on the Phase 25
  findings before repair
- retained shell tests now cover:
  - runtime-truthful empty Home behavior
  - runtime-truthful Search query rendering
  - runtime-backed non-source Settings panels
  - retained player playback-controller ownership
- final verification for this phase is recorded through:
  - `flutter analyze`
  - retained shell Flutter tests
  - Linux integration smoke
  - Linux release-state regeneration
  - Linux release build
  - web build
  - browser-driven built-web smoke
