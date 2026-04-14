# Crispy-Tivi — UI/UX Specification

> Note: §8.7 below is the UIUX meaning of "Library" (personal return points) and is authoritative per [decisions.md](decisions.md) D3. SPEC-RAW's VOD meaning of "library" has been renamed to "catalog" in tech-spec.md and platform-behavior.md.

## 1. Purpose

This document defines the user experience, visual behavior, navigation model, interaction behavior, and design-system direction for Crispy-Tivi.

This specification is separate from the technical architecture specification and should be read together with it.

---

## 2. Product UX Goals

The UI/UX should aim for:
- a premium, cinematic, cool-toned media experience
- strong usability from a distance
- fully reliable remote, gamepad, and keyboard navigation
- high information density where IPTV workflows require it
- calm and focused visual hierarchy
- consistency across Android, iOS, desktop, web, phone, tablet, and TV-like environments
- scale-based adaptation instead of mobile-vs-TV workflow divergence

---

## 3. Experience Principles

### 3.1 Same product everywhere
The product should feel like the same application on every target and screen size.

The workflow, structure, hierarchy, and interaction model should stay consistent across:
- Android
- iOS
- desktop
- web
- phones
- tablets
- large-screen/TV-like usage

The UI scales, tunes density, and adjusts spacing, but it does not transform into a separate portrait/mobile paradigm.

### 3.2 Remote-first interaction
All primary flows must work completely and predictably with:
- remote/D-pad
- keyboard
- gamepad

Pointer input is optional enhancement, not a dependency.

### 3.3 Context preservation
Users should remain oriented at all times.
The UI should make it obvious:
- where the user is
- what is selected
- what is focused
- what the next movement/action will do
- what Back will return to

### 3.4 Information before decoration
UI density is allowed where it serves media workflows.
The product should prefer useful context, readable metadata, and strong focus cues over decorative clutter.

### 3.5 Cinematic, not flashy
The visual system should feel like a high-end dark media environment:
- cool
- rich
- controlled
- atmospheric
- content-forward

It should not feel neon, toy-like, or gold-luxury.

---

## 4. Visual Direction

## 4.1 Visual mood
The product mood is:
- dark
- cool-toned
- cinematic
- layered
- polished
- spacious where needed
- dense where useful

### 4.2 Color direction
The base palette should emphasize:
- deep graphite
- ink blue
- slate navy
- cool silver text
- cyan or ice-blue focus energy
- restrained violet secondary energy
- crimson only for urgent/live emphasis

Warm gold or yellow should not be used as a primary accent direction.

### 4.3 Surface language
Surfaces should feel:
- layered
- elevated
- softly separated
- premium
- calm

Use:
- subtle contrast between background and panels
- restrained translucency where appropriate
- clear edge contrast for focusable content
- clear distinction between passive, selected, and focused states

### 4.4 Contrast and readability
The UI should remain readable from distance and on varied display qualities.

Typography, iconography, focus indicators, and metadata density must preserve legibility under:
- TV distance
- laptop/desktop distance
- tablet distance
- phone landscape distance

---

## 5. Design-System UX Direction

## 5.1 Token-driven design system
The UI system shall be driven by reusable tokens and semantic component states.

The UX system should define:
- color roles
- text roles
- spacing scale
- radius/shape scale
- elevation/layering scale
- icon scale
- focus styles
- selection styles
- motion timing and easing
- panel/card variants
- input-state variants

### 5.2 Semantic components
Core reusable component families should include:
- navigation tabs
- rail headers
- poster cards
- channel rows
- guide cells
- metadata chips/badges
- side panels
- dialogs
- settings rows
- toggle controls
- player action controls
- player metadata overlays

### 5.3 Visual states
Every component that can be interacted with should define:
- resting state
- focused state
- selected state
- active state
- disabled state
- loading state
- error state where relevant

Focused state must be visually stronger than selected state.

---

## 6. Navigation Model

## 6.1 Global navigation structure
The primary product destinations should be stable and immediately understandable.

Recommended primary destinations:
- Home
- Live
- Guide
- Movies
- Series
- Search
- Library

Settings and account/source-management access should remain easy to reach without overwhelming primary browsing.

## 6.2 Navigation philosophy
Navigation should feel:
- shallow where possible
- contextual where useful
- predictable under Back
- stable across targets

### 6.3 Entry and return behavior
The UI should preserve user context whenever reasonable.

Examples:
- leaving playback returns to the content/detail context that launched it
- leaving episode playback returns to the proper season/series context
- reopening the app restores the appropriate context according to technical restoration policy

### 6.4 No navigation traps
The UI must avoid:
- dead-end focus regions
- hidden exits
- pointer-only escape routes
- unexpected back-stack jumps

---

## 7. Focus Model

## 7.1 Focus as a first-class UX layer
Focus is not just a technical necessity; it is a core visual and interaction system.

The focused item must always be obvious.

### 7.2 Focus movement
Directional navigation should follow spatial logic.

Movement expectations:
- left/right across peer horizontal items
- up/down across peer vertical items
- explicit transitions between columns, panels, rails, grids, and overlays

### 7.3 Focus persistence
When users return to a surface, focus should restore intelligently when practical.

Examples:
- returning to a channel list restores focus near the previously focused channel
- returning to a movie rail restores the previous item when practical
- leaving and reopening contextual flows should preserve meaningful focus anchors

### 7.4 Focus entry rules
Every complex surface should define:
- where focus lands when entering
- how focus exits
- what happens when the current item disappears or is filtered out

---

## 8. Screen Specifications

## 8.1 Home

### Purpose
The landing screen should provide cinematic discovery plus immediate access to practical IPTV workflows.

### Structure
The home surface should include:
- a featured hero area
- major navigation
- several horizontally browsable content rails
- quick access to live and recent activity
- continuation and return points

### Suggested rail types
- Continue Watching
- Live Now
- Favorite Channels
- Recently Added Movies
- Recently Added Series
- Sports Tonight
- Catch-up
- Trending or Recommended
- Source-specific highlights where useful

### Hero behavior
The hero should communicate:
- a current spotlight item
- the item title and essential metadata
- immediate primary actions
- strong visual atmosphere without clutter

### Home UX goal
The user should feel both:
- invited into the product
- one move away from practical utility

---

## 8.2 Live / Channels

### Purpose
Provide fast and efficient access to live channel browsing.

### Structure
Recommended structure:
- source/group navigation region
- channel list region
- contextual detail region

### Required UX qualities
- rapid movement across channels
- visible current/next context
- easy favorite and source awareness
- strong focus clarity
- low-friction jump from browse to play

### Channel row content
A channel row should be able to show:
- logo
- number where relevant
- name
- current program
- next program
- live/program timing hints
- source or quality badges where relevant

### Context panel
A contextual panel may show:
- larger program information
- source availability
- playback actions
- guide preview
- artwork where available

---

## 8.3 Guide / EPG

### Purpose
Provide dense, fast, timeline-driven program navigation.

### Structure
Recommended guide structure:
- fixed channel column
- horizontal time axis
- scrollable program grid
- optional preview/info region

### UX goals
- dense but readable
- fast movement in both axes
- current-time awareness
- clear current/next understanding
- easy selection into playback or details

### Focus behavior
Focused program cells must clearly indicate:
- title
- time span
- current selection
- immediate next action

### Timeline behavior
The guide should support:
- time-axis browsing
- now-centered orientation where appropriate
- quick jumps
- stable focus and scroll restoration

---

## 8.4 Movies

### Purpose
Provide cinematic library browsing for movie content.

### Structure
The movies area should support:
- featured content
- grouped rails or grids
- source-aware and source-agnostic browsing
- search/filter entry points
- direct details entry

### Metadata priority
Movie browsing should emphasize:
- poster/backdrop
- title
- year
- rating where available
- brief quality/type indicators when useful

---

## 8.5 Series

### Purpose
Provide series browsing with clear hierarchy and continuity.

### Structure
The series area should support:
- series browsing
- series details
- season selection
- episode lists
- resume continuity

### UX goals
- easy season/episode orientation
- strong restoration context
- clear path from series to season to episode to player and back

---

## 8.6 Search

### Purpose
Provide fast, broad, source-aware discovery.

### UX goals
- immediate responsiveness
- strong filtering
- predictable ranking presentation
- clear content-type distinctions
- clear source attribution where relevant

### Search results
Results should support:
- channels
- movies
- series
- episodes where applicable
- source names/groups when useful

### Search interaction
Search must work completely with:
- keyboard
- remote/gamepad
- on-screen input flows where required

---

## 8.7 Library

### Purpose
Provide user-centric return points and personal organization.

### Suggested sections
- Continue Watching
- Favorites
- History
- Saved positions
- Recently Played Channels
- Source-scoped saved content where relevant

---

## 8.8 Settings

### Purpose
Provide configuration without overwhelming primary media workflows.

### Suggested buckets
- Accounts & Sources
- Playback
- Guide & Time
- Library & History
- Appearance
- Accessibility
- Advanced
- Diagnostics where appropriate

### UX goals
- simple hierarchy
- predictable movement
- strong focus behavior
- progressive disclosure for advanced items

---

## 8.9 Onboarding

### Purpose
Ensure users can set up sources and reach a functional synchronized state.

### UX goals
- clear step sequence
- no ambiguity about what is required
- visible progress during initial sync
- clear transition into the main product once ready

This document does not redefine technical gating logic; it defines the user-facing flow expectations.

---

## 9. Player UX

## 9.1 Playback screen purpose
The player should preserve content immersion while exposing clear information and controls.

## 9.2 Layered OSD model
The player OSD should be layered.

### Layer 1 — information layer
Should communicate:
- channel/title
- current item/program
- progress or timing
- next program/item where relevant
- source/quality badges where useful

### Layer 2 — control layer
Should expose:
- play/pause
- seek or restart where applicable
- source switching where available
- subtitles
- audio selection
- quality/options
- guide or related navigation
- favorite/save actions where relevant

### 9.3 OSD goals
- minimal obstruction of the video
- fast comprehension
- clear remote navigation
- strong focus handling
- predictable dismissal and recall

---

## 10. Content Detail UX

## 10.1 Movie details
Movie details should provide:
- clear primary hero region
- poster/backdrop context
- title, year, rating, runtime, genre where available
- primary play/resume action
- source availability context
- related items or more-like-this areas where useful

## 10.2 Series details
Series details should provide:
- series-level summary context
- season navigation
- episode navigation
- continue-watching focus
- clear path into playback and back out again

## 10.3 Live channel details/context
Live channel detail/context should focus on:
- current and next program
- source availability
- stream quality hints where useful
- quick play and quick guide entry

---

## 11. Motion and Transition Direction

### 11.1 Motion goals
Motion should:
- clarify spatial relationships
- reinforce focus transitions
- make layered UI understandable
- remain restrained and calm

### 11.2 Motion style
Preferred motion qualities:
- short
- smooth
- controlled
- subtle depth shifts
- gentle fade/slide emphasis
- no excessive bounce or playful animation

### 11.3 Motion usage
Good motion use:
- card focus elevation
- overlay entry/exit
- contextual panel reveal
- player OSD reveal
- dialog transitions
- navigation transitions that preserve continuity

---

## 12. Typography and Information Density

### 12.1 Typography goals
Typography should be:
- distance-readable
- stable in hierarchy
- restrained in variety
- strong in metadata differentiation

### 12.2 Density model
The product should allow different density levels by surface type:
- lower density on hero and cinematic browsing surfaces
- medium density on details and lists
- higher density on live and guide surfaces

Density should be intentional, not accidental.

---

## 13. Input Parity Requirements

All primary workflows must be fully operable with:
- remote/D-pad
- keyboard
- gamepad

This includes:
- onboarding
- browsing
- playback
- settings
- search
- dialogs
- source management
- restoration-return flows

Pointer input may enhance convenience, but must not unlock exclusive functionality.

---

## 14. Responsiveness Across Screen Sizes

The UI should adapt by:
- scaling
- density tuning
- size-aware spacing
- layout emphasis changes
- container resizing

The UI should not create a separate portrait/mobile-first product identity.

The same product should remain recognizable and functionally aligned on:
- phone landscape
- tablet landscape
- desktop windows
- large-screen TV-like environments
- web

---

## 15. Accessibility UX Direction

Accessibility decisions should support:
- strong focus visibility
- readable contrast
- large hit/focus targets for distance use
- stable motion
- clear hierarchy
- understandable labels and states

Detailed accessibility standards may be expanded later, but these must be considered foundational.

---

## 16. UI/UX Non-Goals

This document does not define:
- exact implementation APIs
- exact state architecture
- exact database or backend design
- exact image pipeline behavior
- exact observability plumbing
- exact source parser behavior

Those belong in technical architecture documentation.
