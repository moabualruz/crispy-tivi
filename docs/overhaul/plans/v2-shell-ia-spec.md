# V2 Shell IA Spec

Status: Phase-3 redone
Date: 2026-04-11

## Purpose

Define the shell information architecture before any implementation begins so
the overhaul layout rule cannot drift.

## Global shell rule

- top bar = global/domain navigation
- sidebar = current-domain local navigation only
- content pane = active surface
- overlays = modal flows above content
- global top bar does not carry permanent `Back` or `Menu` controls
- `Sources` is not a top-level global domain
- `Player` is not a top-level global domain

## Global/domain navigation

The top bar owns only these domains:

1. Home
2. Live TV
3. Media
4. Search

No domain switch belongs in the sidebar.

Settings is entered from the right-side utility/profile area, not the primary
domain-nav group.

## Domain-local navigation model

### Home

- default local navigation: none
- content owns the shell emphasis
- home content sections:
  - Continue Watching
  - Live Now
  - Media Spotlight
  - Recent Sources
  - Recommended / Trending placeholder
  - Quick access to Search / Settings / Sources

### Live TV

- local navigation is required
- local surfaces:
  - Channels
  - Guide
- Live TV groups/categories are content-owned browse controls, not sidebar-owned
  domain navigation

### Media

- local navigation is required
- local surfaces:
  - Movies
  - Series
- Media scope/filter browsing belongs inside the content area unless a
  dedicated temporary panel is justified

### Search

- default local navigation: none
- local filtering/source scope may appear inside content or as a temporary
  local panel, but Search is still one global domain

### Settings

- local navigation is required
- local surfaces:
  - General
  - Playback
  - Sources
  - Appearance
  - System
- source list, import, and source detail live under the Settings hierarchy

## When the sidebar exists

Sidebar exists only when the active domain has persistent local navigation:

- Live TV
- Media
- Settings

Sidebar does not exist by default for:

- Home
- Search

## Content-pane ownership

The content pane owns:

- route title/header
- active hero/summary surface
- domain-specific rails, lists, grids, or forms
- route summaries and status panels
- overlays anchored above the active surface

## Non-goals

- global navigation in the sidebar
- sidebar always visible on every route
- shell routes that collapse the content pane into a generic card wall
- old-app underline nav treatment, pills, chip-heavy chrome, or permanent right-side
  global controls
- one-off sidebar-only selection indicators that do not match the app-wide
  active-state system

## Completion note

Phase 3 shell IA planning is complete for the current branch state:

- global vs local navigation ownership is explicit
- sidebar existence rules are explicit per domain
- content-pane ownership is explicit
- active IA docs align with the pinned shell planning and full spec
- any rendered shell that collapses back into a generic card wall fails this
  phase contract
- when IA/navigation drift is corrected in code, the active IA/spec docs must be
  corrected in the same pass
