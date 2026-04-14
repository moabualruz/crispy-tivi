# Platform Behavior Specification

## 1. Purpose

This document defines cross-platform behavior requirements for Crispy-Tivi outside of visual/UX design.

It focuses on:
- input and navigation behavior
- playback/system integration behavior
- app lifecycle behavior
- orientation and window behavior
- secure storage behavior
- parity expectations across platforms
- diagnostics and local observability behavior

This is a technical behavior document, not a UI/UX design document.

---

## 2. Supported Platform Families

### Native platforms
- Android
- iOS
- Windows
- macOS
- Linux

### Web platform
- Browser-based web application

---

## 3. Input Model

The application shall treat the following as first-class input modes:
- remote / D-pad style navigation
- gamepad navigation
- keyboard navigation

Pointer input may be supported where appropriate, but it shall not be required for any primary workflow.

---

## 4. Focus and Directional Navigation Behavior

The application shall provide deterministic directional navigation across all primary workflows.

### Required principles
- every primary actionable surface shall be focusable where appropriate
- focus movement shall be spatially predictable
- focus entry and exit for lists, grids, dialogs, overlays, tabs, and player controls shall be explicitly controlled
- no primary workflow may depend on hover-only affordances
- no primary workflow may trap focus unintentionally
- focus shall remain visible and observable at all times during non-pointer navigation

### Required coverage
Directional navigation support shall cover:
- onboarding
- source management
- home/landing flows
- browse flows
- search flows
- guide flows
- details flows
- playback controls
- settings flows
- dialogs and transient overlays

---

## 5. Back Behavior and Navigation Memory

The application shall implement predictable back behavior and restoration.

### Required behavior
- back shall return to the prior logical context rather than forcing unrelated root navigation
- exiting playback shall return to the correct contextual origin where resumable context exists
- contextual origins include movie details, series details, season context, guide context, and channel context
- restoration shall preserve enough data to reconstruct the relevant prior context

### Restoration examples
- leaving a movie returns to that movie’s details context
- leaving an episode returns to the correct season and series context
- reopening while a live channel was active can restore and autoplay that channel according to policy
- reopening after movie or episode playback restores the relevant details context by default
- when no resumable context exists, the app restores its default entry state

---

## 6. Landscape and Window Behavior

The product model is landscape-first across all targets.

### Native devices
On phones and tablets:
- the application shall operate in landscape orientation
- 180-degree landscape rotation shall be supported
- portrait-specific product flow is not required

### Desktop
Desktop windows shall preserve the same product model and should scale rather than reflow into a separate “mobile-style” interaction model.

### Web
The web application shall preserve the same landscape-first workflow model.
Where orientation locking is possible, the application may request or prefer it.
Where the browser does not allow orientation locking, the application shall preserve the same workflow and scaled presentation model as closely as possible.

---

## 7. Layout Scaling Behavior

The application shall use a scaling-oriented product model rather than separate product flows for “mobile” versus “TV” versus “desktop”.

This means:
- the same core workflow structure remains valid across screen sizes
- scaling, density adjustments, and size-class tuning may be applied
- the application does not require a distinct portrait/mobile navigation system
- content hierarchy remains consistent across targets

This document does not define visual breakpoints or layout design; it only defines the technical product behavior model.

---

## 8. Source Onboarding Gate

If no source exists, the application shall require source onboarding before normal content browsing becomes available.

### Required onboarding behavior
- source creation is required
- source validation is required
- initial sync is required
- synchronized data must be persisted locally before normal use begins

The app shall not enter normal browse/play flows until minimum required content state is available locally.

---

## 9. App Lifecycle and Sync Behavior

After onboarding, the app shall support non-blocking sync behavior during normal usage.

### Required lifecycle behavior
- app startup checks whether refresh is due
- refresh runs only when refresh age exceeds configured policy
- refresh is non-blocking after initial onboarding
- persisted data remains browsable while refresh runs
- sync uses UPSERT-style merge behavior to avoid duplication
- partial syncs are supported
- retry/backoff policies are applied for failures

### Lifecycle states
The platform layer shall support explicit handling for:
- foreground entry
- background transition
- normal termination
- crash recovery where applicable
- network loss and recovery

---

## 10. Playback Lifecycle Behavior

The playback subsystem shall define consistent lifecycle behavior across platforms.

### Required playback lifecycle capabilities
- start playback from a resolved selection
- pause and resume
- stop and clear
- switch between available source variants where applicable
- preserve observable playback state
- restore playback context after app relaunch according to policy

### Live playback relaunch policy
If a live channel was the active playback target at the time of app exit or relaunch restoration:
- the app may resume and autoplay that channel
- autoplay policy shall be configurable

### VOD/series relaunch policy
If a movie or episode was the active playback target:
- the app restores the details context by default
- resume playback remains available through restoration state and history

---

## 11. Media Session and System Playback Integration

The application shall integrate with platform playback/session facilities.

### Required capabilities
- expose now-playing metadata
- receive media key or remote command input where supported
- publish playback state to system media-session APIs
- maintain media-session consistency during source switching, playback failure, and resume

### Required behavior domains
- lock-screen/system surface metadata where supported
- remote-control/media-button handling where supported
- headset and controller playback input where supported
- platform interruption handling
- platform audio-focus handling where supported

---

## 12. Background Playback Policy

The system shall define a consistent background playback policy.

The policy shall explicitly determine behavior for:
- app backgrounding during live playback
- app backgrounding during VOD/episode playback
- system interruptions
- playback resume after interruption
- media-session continuity while backgrounded
- resume or stop behavior when platform rules require constraints

Exact user-facing policy remains part of product definition, but the technical architecture shall support these states explicitly.

---

## 13. Search Behavior Across Platforms

The application shall provide the same core search behavior across all targets.

### Required search behavior
- search across all enabled sources
- search within one selected source
- search within a selected subset of sources
- filter by content type
- operate over indexed local data
- preserve source-aware result attribution
- support consistent ranking behavior

Result rendering may vary by surface size, but search logic and scope behavior shall remain consistent.

---

## 14. Multi-Source Browse Behavior

The platform behavior model shall support:
- all-source browse
- single-source browse
- multi-source subset browse

This applies across:
- channel browsing
- catalog browsing (movies + series)
- search
- favorites
- history
- playback preparation
- guide lookup

The application shall preserve source attribution and support source switching where a merged normalized item has multiple playable variants.

---

## 15. Secure Storage Behavior

The application shall use platform-appropriate secure storage for sensitive values.

### Required secure-storage behaviors
- source secrets are stored outside the general app database
- secret retrieval is scoped by source identity
- secret deletion removes secure references
- logs and diagnostics redact sensitive values
- exports define clear secret-handling policy

Non-sensitive metadata may remain in normal persistent storage.

---

## 16. Import and Export Behavior

The application shall support local export and import for backup and migration.

### Required behavior
- export creates a versioned backup package
- import validates version compatibility
- import supports failure reporting
- import supports safe merge or replace modes
- restored state can rebuild app behavior without external hosted services

The platform layer shall provide the necessary file access, pickers, and permissions per platform to support this capability.

---

## 17. Diagnostics and Local Observability Behavior

The application shall provide local observability without requiring external hosted tools.

### Required observability domains
- source import and refresh
- search/indexing
- playback lifecycle
- artwork/image pipeline
- persistence and migration
- restoration state
- platform integration state

### Required observability behavior
- structured logs
- correlation IDs
- local diagnostic storage
- local export of diagnostic bundles
- locally inspectable status or diagnostic surfaces where appropriate

Observability shall remain useful in offline and self-contained scenarios.

---

## 18. Performance Behavior Expectations

The platform layer and runtime behavior shall support efficient operation for:
- large source catalogs
- large EPG datasets
- long-running sessions
- repeated navigation across dense surfaces
- image-heavy browsing
- non-blocking background refresh

### Required performance behavior
- virtualized rendering for large surfaces
- cancellation of off-screen work
- bounded memory strategies for media-heavy assets
- asynchronous parsing and indexing
- non-blocking sync after onboarding
- state restoration without oversized transient memory usage

---

## 19. Web Parity Behavior

The web target shall follow the same core product workflow model as native targets.

### Required parity areas
- source onboarding
- source management
- all-source and scoped-source browsing
- live/VOD/series content model
- search
- favorites/history
- guide behavior
- playback flow where web playback support allows it
- restoration model as far as browser/runtime constraints allow

Where browser/runtime restrictions create limitations, the implementation shall preserve behaviorally equivalent workflow whenever possible.

---

## 20. Platform-Specific Responsibilities

### Android
The Android platform layer is responsible for:
- secure storage integration
- media-session integration
- background playback behavior
- orientation enforcement
- file and network permissions
- app lifecycle restoration hooks

### Apple
The Apple platform layer is responsible for:
- secure storage integration
- media-session/now-playing integration
- interruption handling
- orientation enforcement
- file and network permissions
- app lifecycle restoration hooks

### Desktop
The desktop platform layer is responsible for:
- window lifecycle integration
- file-system integration for import/export
- media backend hosting
- keyboard/gamepad behavior
- local diagnostic storage integration

### Web
The web platform layer is responsible for:
- browser storage integration
- browser playback integration
- file import/export workflows within browser constraints
- orientation preference/lock attempts where supported
- parity-preserving workflow adaptation when browser APIs impose constraints

---

## 21. Non-Goals of This Document

This document does not define:
- visual design
- screen layout
- focus styling
- color system
- animation behavior
- component visual states
- spacing systems
- typography
- interaction copy

Those remain part of the separate UI/UX specification.
