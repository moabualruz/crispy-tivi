# CrispyTivi — Beta Stabilization

## What This Is

CrispyTivi is a cross-platform home media consumption app that unifies IPTV
(Xtream/M3U/Stalker) and locally hosted media servers (Plex, Emby, Jellyfin)
into a single, polished interface. Built with a Rust core (business logic,
data, persistence) and Flutter shell (UI, navigation, theming), it targets
phones, tablets, Android TV, desktop (Windows/macOS/Linux), and web. Currently
in alpha (v0.1.1) with 180+ FFI methods, 1064 Rust tests, and 2110 Flutter
tests.

## Core Value

Every screen and feature works flawlessly with any input method (touch, mouse,
keyboard, D-pad remote) — a user can consume media for hours across any
platform without hitting a single bug.

## Requirements

### Validated

<!-- These capabilities exist in code but are NOT yet stable enough to call "validated". -->

(None yet — existing features are functional but not regression-free)

### Active

- [ ] Player lifecycle is bulletproof — fullscreen enter/exit, mini-player,
      PiP, and video layer cleanup leave no orphaned surfaces or floating video
- [ ] Full keyboard/D-pad/remote navigation on every screen — all interactive
      elements reachable and operable without a pointing device
- [ ] Touch/mouse input works correctly alongside keyboard/remote — no input
      mode conflicts or broken gestures
- [ ] Live TV / IPTV features are regression-free — channel switching, EPG,
      zapping, catch-up, stream resolution all stable
- [ ] VOD / Series browsing and playback is regression-free — navigation,
      metadata, continue watching, series grouping all stable
- [ ] Media source integrations (Plex/Emby/Jellyfin) are reliable — auth,
      library sync, playback, and stream URL resolution all stable
- [ ] Enforced coding patterns prevent regressions — strict CI gates, uniform
      screen/feature architecture, enforced Rust-first logic boundary
- [ ] Test coverage catches real bugs — tests that exercise actual user flows
      and regression scenarios, not just happy-path unit tests
- [ ] Codebase is streamlined — duplicate code removed, consistent patterns
      across all features, clear module boundaries
- [ ] Architecture boundary enforced — Rust owns all business logic/data,
      Dart owns only UI rendering and interaction

### Out of Scope

- Video upscaling / super resolution — spec exists, deferred to post-beta
- New feature development — no new capabilities until existing ones are stable
- Multi-user / account system — single-user is sufficient for beta
- Cloud sync — local-only for beta

## Context

**Current State (Alpha v0.1.1):**
- Rust workspace: 3 crates (crispy-core, crispy-ffi, crispy-server), 21 models,
  21 tables, schema v30, 182+ FFI functions
- Flutter: Clean Architecture + Riverpod, media_kit for playback, CrispyPlayer
  abstraction with HDR (Android) and PiP (iOS) handoff
- Unified multi-source architecture: all content (IPTV + Plex/Emby/Jellyfin)
  flows through db_sources + db_channels/db_vod_items/db_epg_entries with
  source_id filtering
- CacheService wraps CrispyBackend — providers read from CacheService, never
  directly from FFI
- MemoryBackend for testing (pure in-memory, no external deps)

**Known Systemic Issues:**
- Regression cycle: bugs get "fixed" but reappear with different root causes,
  indicating fixes address symptoms not structural causes
- Player lifecycle: exiting fullscreen leaves floating video on top of
  everything; mini-player bar behavior incorrect during navigation
- Input navigation: keyboard/remote/D-pad navigation broken across most
  screens; focus management inconsistent
- Bug reproducibility: issues are hard to describe precisely enough for agents
  to find true root causes; fixes often relocate problems rather than
  eliminating them

**Completed Major Specs:**
- sweep-optimize-2026, unified-multi-source, rust-http-migration,
  rust-dedup-migration, sweep-cleanup-2026, widget dedup, architecture
  hardening, comprehensive audit, sweep-dedup-v2, crispy-player,
  sweep-optimize-v4, player-first-optimization

**Active Spec:**
- competitive-improvement (39 children, 156 tasks) — ongoing feature work

## Constraints

- **Architecture**: Rust core + Flutter shell — Rust owns all business logic
  and data; this boundary must be enforced more strictly (more Dart logic
  migrated to Rust)
- **Platforms**: Must work on Android (phone/tablet/TV), iOS, macOS, Windows,
  Linux, and Web — all from a single codebase
- **Input**: Must be fully operable with keyboard/D-pad/remote (TV-first) AND
  touch/mouse — both input modes simultaneously
- **Quality Bar**: Commercial grade — competes with TiviMate (IPTV) and
  Plex/Jellyfin clients (media servers)
- **Stability**: Zero tolerance for regressions — strict CI gates, automated
  testing, pattern enforcement

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Beta = stability over features | Regression cycle is the #1 problem; adding features on an unstable base compounds it | — Pending |
| More logic to Rust | Dart business logic is harder to test structurally and contributes to regressions | — Pending |
| Full restructuring is acceptable | User willing to redesign/restructure everything if it produces commercial-grade quality | — Pending |
| Keyboard/remote-first navigation | TV is a primary target; if it works with D-pad, it works with everything | — Pending |
| Pause competitive-improvement spec | Stabilization must come before new feature work | — Pending |

---
*Last updated: 2026-03-12 after initialization*
