# Crispy-Tivi — Requirements Index

This folder is the curated project requirements for Crispy-Tivi. Content was copied from `suggestive-context/` via bash; conflicts were pulled into an interview, resolved, and the resolutions applied back into the relevant files. **When any file in this folder contradicts another, [decisions.md](decisions.md) wins.**

## What Crispy-Tivi is

A cross-platform IPTV media application targeting Android, iOS, Windows, macOS, Linux, and Web — all six as first-class V1 targets. Built as a Kotlin Multiplatform monorepo with Compose Multiplatform for Android/iOS/desktop and a Kotlin web target. Supports M3U, Xtream, Stalker sources, XMLTV EPG, live channels, VOD (Movies + Series), with normalized source-agnostic feature workflows, SQLite+SQLDelight persistence, FTS5 search, disk-first image pipeline, and remote/gamepad/keyboard-first navigation.

## Files in this folder

### Resolved decisions (authoritative)
- [decisions.md](decisions.md) — 19 decisions. D1–D15 from the conflict-resolution interview, D16 "nothing is post-V1", D17 "hand-roll policy", D18 "desktop player = libmpv via custom JNA binding", D19 "desktop thumbnails/probe = bytedeco ffmpeg LGPL directly". Supersedes everything else when in conflict.
- [v1-phase-roadmap.md](v1-phase-roadmap.md) — every V1 feature organized by phase (foundation → MVP → late-phase → release polish). Per D16, nothing is post-V1.
- [ideas/crispy-tivi-product.md](ideas/crispy-tivi-product.md) — product one-pager from the 2026-04-14 idea-refine session. Target user, positioning, non-negotiables, V1 scope, Not Doing list, and the *sequential depth not parallel breadth* execution rule.

### Product & architecture
- [tech-spec.md](tech-spec.md) — V1 technical specification plus amendments (from SPEC-RAW.md). §6 now points to monorepo-blueprint.md; §15.3 rewritten as "Catalog"; Amendment B (desktop player) pinned to libmpv via D18.
- [architecture-decisions.md](architecture-decisions.md) — ADR pack (ADR-001..ADR-014). ADR-007 desktop backend bullet downgraded per D14.
- [platform-behavior.md](platform-behavior.md) — Cross-platform behavior requirements (input, navigation, restoration, orientation, lifecycle, playback, secure storage, import/export, diagnostics, performance, web parity, platform responsibilities). §14 "library browsing" renamed to "catalog browsing".

### Data, contracts, persistence
- [data-model.md](data-model.md) — Normalized data model (source/variant/aggregate identity, entity field definitions, relationships, deduplication model, browse model, playback selection, EPG resolution, favorites/history, search projection, restoration records).
- [db-schema-guide.md](db-schema-guide.md) — SQLite/SQLDelight schema drafting direction.
- [contract-api-spec.md](contract-api-spec.md) — Shared contract / interface boundary draft (source adapters, repositories, playback, EPG, search, sync, restoration, image, security, import/export, observability, navigation).

### Code standards
- [code-standards.md](code-standards.md) — Coding standards and architectural paradigm guidance (UDF, DDD-lite, adapter/strategy/facade/policy patterns, DRY/SOLID guidance, state/error/perf rules, naming, testing).

### Monorepo blueprint
- [monorepo-blueprint.md](monorepo-blueprint.md) — Full resolved module layout (§2), module responsibilities, dependency direction, package layout, naming rules.

### UI/UX
- [uiux-spec.md](uiux-spec.md) — UI/UX specification. §8.7 restored — "Library" = personal return points (Continue Watching, Favorites, History, Saved positions, Recently Played Channels).

### Orchestrator workflow
- [orchestrator-start-prompt.md](orchestrator-start-prompt.md) — Full orchestrator prompt (research → brainstorm → plan → execute → verify phases, subagent rules, coding standards).
- [orchestrator-short-prompt.md](orchestrator-short-prompt.md) — Condensed orchestrator prompt.

### Phase-1 research tasks
- [open-questions.md](open-questions.md) — Two items deferred from the interview: shared navigation/state pattern (D13) and desktop playback backend (D14). Both are phase-1 spikes with acceptance criteria.

## Reading order

1. [decisions.md](decisions.md) — what was resolved and how
2. [v1-phase-roadmap.md](v1-phase-roadmap.md) — V1 feature phasing (nothing is post-V1)
3. [tech-spec.md](tech-spec.md) — what we're building
4. [platform-behavior.md](platform-behavior.md) — how it must behave
5. [data-model.md](data-model.md) + [db-schema-guide.md](db-schema-guide.md) — how data flows
6. [contract-api-spec.md](contract-api-spec.md) — shared interfaces
7. [architecture-decisions.md](architecture-decisions.md) — ADRs already made
8. [code-standards.md](code-standards.md) — how to write code
9. [monorepo-blueprint.md](monorepo-blueprint.md) — where code lives
10. [uiux-spec.md](uiux-spec.md) — what users see and feel
11. [orchestrator-start-prompt.md](orchestrator-start-prompt.md) — how to execute work
12. [open-questions.md](open-questions.md) — phase-1 hand-roll architecture sketches + R2 desktop player research
