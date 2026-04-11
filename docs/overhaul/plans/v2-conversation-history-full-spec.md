# CrispyTivi v2 Full Spec

Status: Conversation-history authority
Date: 2026-04-11

## Authority

This specification is based only on the conversation history in this thread:

- direct user requirements
- direct user clarifications
- recommended answers explicitly approved by the user

This document is not derived from checked-in project docs. If any project doc
conflicts with this file, this file is the authority for this v2 planning lane
until the user changes it.

## Purpose

Define CrispyTivi v2 from scratch on a clean branch as a TV-first application
with:

- a fake-scroll/windowed shell from day 1
- minimum RAM and CPU footprint as the highest technical priority
- Flutter limited to `View` and `ViewModel`
- Rust FFI owning controller/business/domain orchestration and provider
  translation
- a fully navigable stubbed app for the whole experience before vertical
  implementation proceeds
- one vertical delivered fully before moving to the next

This document is intended to remove ambiguity from the v2 direction. Where a
later phase is intentionally deferred, the deferment itself is specified here
as a rule, not left as an unknown.

## Non-Negotiable Priority Order

The implementation order of engineering principles is:

1. performance / RAM / CPU contract
2. TDD
3. DDD boundaries
4. SOLID
5. LOB (Localization of Behaviour)
6. DRY

Additional hard rules:

7. no provider-native leakage into Flutter
8. Flutter MV only, with no controller/business logic
9. fake-scroll/windowed primitives mandatory on every screen
10. scale-not-reflow TV layout
11. player implemented last after dedicated investigation/subplan

## Core Product Direction

### Overall

- v2 is a rewrite from scratch on a clean branch
- Flutter contains only view and view-model concerns
- all controller/business/domain behavior lives in Rust behind FFI
- the app must remain runnable at all stages
- planning scope covers the full app, all screens, and all flows
- delivery scope proceeds one vertical at a time

### First Development Focus

The first development focus is:

1. fake-scroll/windowed app
2. minimum footprint on RAM and CPU
3. then Rust controllers and hydration behavior
4. then full vertical completion one domain at a time

## Delivery Model

### Planning Scope

The plan must cover:

- the full app
- all pages
- all flows
- the whole navigable experience
- all primary domains
- all primary modal, menu, and wizard behaviors

### Delivery Scope

Actual delivery proceeds one vertical at a time.

Meaning:

- the shell and full stubbed app come first
- then one domain is taken to full completion before moving to the next
- example: Live must be completed end-to-end before moving to the next real
  vertical

### Delivery Order

The approved delivery order is:

1. app shell + global navigation + all-page stubs
2. onboarding/auth/import flows
3. settings
4. live TV
5. EPG / detail overlays
6. movies
7. series
8. search
9. player

Clarification:

- full player implementation is still last
- a mock player may exist earlier only to validate source/playable contract
  handoff
- onboarding/auth/import are later treated as part of the Settings domain, but
  their implementation priority stays ahead of the rest of Settings work
- source management belongs under Settings and is not a top-level global domain
- Player is not a top-level global navigation destination

## Architecture

## Flutter / Rust Boundary

### Flutter Owns

- widgets
- screens
- layout
- rendering
- motion
- focus traversal runtime
- pixel geometry
- input routing from canonical input actions into UI behavior
- local ephemeral UI state
- viewport/window metrics
- selection state
- modal open/closed state
- form draft state
- animation triggers
- debounced text input before FFI call
- ViewModel presentation mapping from canonical Rust outputs

### Flutter Does Not Own

- controllers
- business logic
- use-case orchestration
- provider translation
- pagination strategy
- filtering business logic
- sorting business logic
- recommendation logic
- playback decision logic
- source/variant resolution logic
- resume policy
- directional focus graph ownership by Rust

### Rust Owns

- controller layer
- business rules
- domain orchestration
- provider translation
- canonical source capability contracts
- canonical domain objects
- canonical identity resolution
- source registry/context
- duplicate merge behavior
- preferred source behavior
- search/domain backends
- source syncing and hydration
- persistence-heavy flows
- source status/health
- canonical playable resolution

### Rust May Do

- use URL internally as a temporary matching hint during sync, variant lookup,
  or EPG/source linking

### Rust Must Not Do

- use URL as canonical identity after intended target resolution
- own directional focus traversal
- own pixel navigation graph

## Domain Model

### Bounded Contexts

Approved bounded contexts:

1. App Shell
2. Settings
3. Live TV
4. Media (VOD)
5. Search
6. Player
7. Shared Catalog / Metadata
8. Shared Playback Session
9. Shared Source / Provider Registry
10. Shared Recommendations / Continue Watching later if needed

### Settings Domain

Settings includes internally:

- onboarding
- authentication
- import flows

But these are not exposed as separate top-level user-facing domains.

### Live TV Domain

EPG belongs inside Live TV, not as its own bounded context.

### Media Domain

Movies and Series are inside one bounded context: `Media`.

Inside `Media`, separate aggregates must exist:

- `Movie`
- `Series`
- `Season`
- `Episode`

Shared services inside `Media` can include:

- artwork
- resume
- discovery
- playable resolution
- related items

### Search Domain

Search is a separate bounded context.

Reason:

- search UX
- search ranking
- search history
- search filters
- search result composition

can evolve separately from catalog ownership.

## Provider / Source Model

### Source Abstraction Rule

Domains must never depend on raw:

- Xtream
- M3U
- Stalker
- Jellyfin
- Plex

or any other provider-native payload shape.

Domains depend only on canonical source capability contracts.

Provider adapters map provider-native data into canonical aggregates.

The source registry/context decides which adapter resolves each request.

The player also consumes canonical media envelopes, never provider-native
payloads.

### Provider Quirk Rule

Domain objects must not carry provider-extension bags.

Allowed:

- provider-native raw payloads in infra/debug/import inspection layers only

Not allowed:

- provider-specific escape hatches inside canonical domain objects or Flutter
  VM contracts

### Multi-Source Rule

The Rust side and database must support:

- multiple active resources of the same type
- multiple active resources of different types
- all being active at the same time

### Duplicate Rule

Default UI behavior:

- one canonical item card/row by default
- detail page exposes available source variants
- search may later show grouped source counts

Duplicates should not be shown separately by default.

## Canonical Identity

The identity strategy is:

- app-wide stable `EntityId`
- source-local `SourceItemId`
- playable `PlayableId`

Hard rules:

- never use URL as identity
- resume/history/favorites bind to canonical entity + source context
- catchup URLs, resolved commands, and mirrors are not identities

## Source Capability Contract

The approved source capability map is a superset contract.

Each source adapter must explicitly declare:

- supported capabilities
- unsupported capabilities
- unavailable reason for unsupported capabilities

Unsupported capability must not be represented by:

- missing method
- exception probing

It must be represented by an explicit capability object with unavailable
reason.

### Capability Areas

#### 1. Source Lifecycle

- add / import / configure source
- authenticate / check access
- refresh / reimport / remove
- cancel long sync/import
- health / diagnostics / status

#### 2. Structure Browse

- sections / types
- categories / groups
- item lists
- category visibility preferences

#### 3. Item Retrieval

- details
- artwork / logo
- seasons / episodes
- EPG
- current / now / next

#### 4. Playback Resolution

- playable media resolution
- variants / qualities
- catchup / archive / timeshift
- request headers / auth hints
- download / record flags

#### 5. User-State Hooks

- favorites
- recent / history
- continue watching / resume
- rating / likes / hidden if supported

#### 6. Discovery

- search
- recommendations
- trending
- community features if the source supports them

#### 7. Control / Support

- remote-control hooks
- options schema
- performance/cache hints

### Source Setup Input Modes

The source setup flow must support:

- M3U URL
- M3U file/path
- Xtream credentials
- Stalker portal credentials / device params
- future generic custom provider connector slot
- demo/fake source for shell/testing

### Source Validation

Wizard validation rules:

- progressive validation per step
- explicit network/source validation, not every keystroke
- back without data loss
- entered drafts remain local until commit/apply
- capability summary shown before final save

### Source Health Statuses

Approved source statuses:

- healthy
- degraded
- auth-needed
- unreachable
- syncing
- disabled
- unsupported-capability for specific feature only

### Partial Sync Visibility

Partial data may be visible before full completion only if contract integrity is
preserved.

Rules:

- source marked `syncing`
- completed sections may be browsed
- incomplete sections hidden or explicitly labeled
- no fake fully-ready impression

## Canonical Media Envelope

Before player phase, every domain launch path must produce one normalized
canonical envelope for playback.

The approved rule is:

- one shared media envelope for all launch paths
- same groups everywhere
- relevant groups populated for each media type
- irrelevant groups are `null`

### Envelope Groups

1. `what_it_is`
2. `how_to_open_it`
3. `where_to_start`
4. `what_user_sees`
5. `live_context`
6. `series_context`
7. `tracks_and_media`
8. `player_capabilities`
9. `navigation_without_exit`
10. `safety_and_resolution`

### Group Intent

#### `what_it_is`

- live / movie / series / episode / radio / trailer
- playable item ids
- provider kind
- parent context

#### `how_to_open_it`

- one or more candidate sources
- transport hint
- request needs
- direct / resolved / command-derived source
- external-player fallback permission

#### `where_to_start`

- live edge / absolute start / resume point
- known duration
- session/history identity

#### `what_user_sees`

- title
- subtitle
- description
- logo
- poster
- backdrop
- thumb
- badges

#### `live_context`

- channel identity / number
- EPG lookup keys
- current / next programs
- catchup/archive availability
- previous / next channel candidates

#### `series_context`

- series / season / episode identity
- next / previous episode candidates
- autoplay-next rules
- continue-watching identity

#### `tracks_and_media`

- audio tracks
- subtitle tracks
- codec/container/bitrate/lang if known
- multi-audio / multi-subtitle capability

#### `player_capabilities`

- pause / seek / trickplay
- timeshift
- channel switching in player
- episode switching in player
- cast / PiP / aspect-ratio changes
- OSD details / stats / media analysis

#### `navigation_without_exit`

- siblings user can jump to without leaving player
- live channel surf candidates
- series episode surf candidates
- future related/up-next candidates

#### `safety_and_resolution`

- source freshness
- resolved timestamp
- retry policy
- fallback candidates
- unsupported reasons

## Design Direction

## Explicit Anti-Drift Clarifications

The following are hard constraints from the conversation and must override any
older repo assumptions:

- ignore `docs/screenshots/` completely for v2 rebuild decisions
- ignore any old main-branch app screenshots or old shipped-app visuals
- do not reuse old-shell navigation cues such as the small underline/underscore
  marker from the old app
- do not use pill/chip-heavy shell treatment unless Penpot explicitly shows it
- do not put permanent `Back` or `Menu` controls into the global top
  navigation bar
- `Back` belongs to the active content or flow context, not global chrome
- `Menu` must be explicit, justified, and route-local if it exists at all
- `Sources` is part of the Settings domain hierarchy, not a top-level global
  domain
- `Player` is not a top-level global navigation item

## Behavioral Reference Direction

### Google TV / Android TV Influence

Use recent Google TV / Android TV behavior for:

- home shell entrance
- top navigation semantics
- local sidebar semantics
- settings behavior
- wizard behavior
- modal/menu focus behavior
- back-stack behavior
- home composition

Do not clone:

- exact branding
- exact assets
- exact colors

### Apple TV Influence

Use Apple TV feel for widget-level visuals and motion:

- restrained depth
- smooth scale/focus lift
- soft but crisp glow
- subtle parallax where cheap
- dense, clean typography
- premium timing
- low clutter
- strong artwork framing
- no gaudy neon/game UI effects

### Netflix + YouTube Influence

Use Netflix + YouTube influence for:

- movie/series details pages
- player information density
- player control information
- OSD clarity
- action hierarchy
- continue/resume affordances
- metadata readability
- episodic progression cues

## Layout System

### TV Layout Rule

The app scales and does not reflow.

Hard rules:

- same composition regardless of screen size/resolution
- scaling buckets or scale factors
- no responsive rearrangement for TV shell
- safe-area adjustments only where required

### Canonical Viewport

Canonical design viewport:

- `1920x1080` at `1x`

Derived scale buckets:

- `720p`
- `1080p`
- `1440p`
- `4K`
- later ultrawide if needed

### Split Ratio Rule

The `1/3 + 2/3` rule is optical, not mathematically exact.

Approved tokenized ranges:

- side panel target: `32%` to `36%`
- content target: `64%` to `68%`

The ratio is stable by surface type and not hand-tuned per screen.

### Geometry Rule

Windowed surfaces use:

- fixed extents or bucketed extents by surface type

Not allowed for primary browse surfaces:

- arbitrary dynamic row heights
- content-driven relayout of browse cells

Allowed:

- naturally sized detail panels

Rules:

- lists and grids must be index-addressable without measuring the full dataset
- variable content is clamped/truncated instead of relaid out

## Windowed Primitive System

Every screen must use the same windowed/fake-scroll primitive system from day
1.

Mandatory supported surface types in shell phase:

1. vertical lists
2. horizontal rails
3. poster grids
4. channel list + detail split
5. 1/3 side panel + 2/3 content layouts
6. modal menus
7. wizard step lists/forms
8. search mixed-result layouts
9. EPG timeline/list hybrid placeholder
10. player-adjacent overlays placeholder

No screen may use normal scroll mechanics as a temporary exception.

## Navigation and Input

## Canonical Input Model

All raw devices map into one canonical input action model.

Raw devices must not drive UI directly.

Devices:

- remote controls
- keyboards
- gamepads

### Canonical Actions

- up
- down
- left
- right
- primary/select
- back
- menu/options
- play/pause
- next
- previous
- seek forward
- seek backward
- channel up
- channel down
- page/rail jump if needed
- tab/subview switch
- details/info
- favorite
- search

### Navigation Deliverables

Planning and implementation must include:

- global input action matrix
- device mapping matrix
- per-screen focus map
- per-component focus contract
- back/menu behavior table
- visual navigation diagrams for major screens

### Global Navigation Rules

- diagonal/ambiguous moves are forbidden unless explicitly designed
- every focusable surface must define enter rules
- every focusable surface must define exit rules
- every screen must define button movement behavior
- navigation maps must be drawn and implemented in detail

### Focus Ownership

- Flutter always owns focus traversal/runtime
- Rust may suggest semantic target ids only
- Rust never owns directional focus graph

## Startup and Restore

### Initial Startup

First screen after startup:

- Home shell

It is a real hub, not a marketing screen.

### Startup Preference

Default:

- startup target configurable in settings
- default value is `Home shell`

Later supported:

- exact resume to the precise route/location where user left the app
- not only domain/category resume

### Deep Link / Exact Route Restore

Restore includes:

- active domain / subview
- selected category / filter scope
- focused item id
- open detail state id
- search query + selected result scope
- settings leaf path
- player origin context only
- modal/wizard step only when safe

### Wizard Restore Safety

Do not auto-restore into the middle of these without validation:

- auth credential entry
- destructive source management
- import confirmation/finalization
- steps dependent on expired temp validation
- sensitive secret-bearing steps

## Screen Specifications

## Home Shell

### Purpose

Home is the shell hub and default startup surface.

### Sections

- Continue Watching
- Live Now
- Media Spotlight
- Recent Sources
- Recommended / Trending placeholder
- Quick Access to Search
- Quick Access to Settings
- Quick Access to Sources
- Resume Setup if setup incomplete

### Data Ownership

Home rails are shell-owned projections fed by domain/query services.

Home is not a second source of truth.

## Top Navigation

Top navigation owns:

- app/domain switching
- global entry points

It does not own:

- permanent back actions
- permanent menu actions
- local category navigation
- domain-local filters

Approved top-level global destinations:

- Home
- Live TV
- Media
- Search
- Settings

## Side Panel

Side panel owns:

- current-domain local navigation
- filters
- categories
- settings sections
- wizard steps

## Content Pane

Content pane owns:

- active domain surface
- dominant visual/interactive area

## Overlays

Overlays:

- do not replace domain navigation
- sit above content
- are separate modal flows

## Settings

### Top-Level UX Groups

User-facing top-level groups:

- General
- Playback
- Sources
- Appearance
- System

### Internal Subareas

These may exist internally, but not as top-level clutter:

- Source Detail
- Import Wizard
- Auth / Connection Wizard
- Remote / Inputs
- Data / Storage
- Diagnostics / About
- Experimental / Developer hidden deeper

### Settings Search

Search hit activation must:

- open exact setting leaf
- inside grouped settings hierarchy
- with local highlight/scroll/focus

### Settings Source Flow

Flow:

1. `Sources` opens source list
2. select existing source => source overview/detail
3. add source => wizard chosen by source type
4. auth/import/validation embedded in wizard steps
5. success returns to source overview with health/capability summary
6. source-specific advanced options hidden behind secondary action

`Sources` is reached through `Settings`, not as a separate top-level global
domain.

## Live TV

## Live TV Browse Structure

Live TV default browse behavior:

- category/group list in side panel
- channel list in browse pane
- inline detail/EPG companion behavior in content area
- quick play available
- archive/catchup affordance where capable

## Channels Subview

Structure:

- category and channels behave like wizard-step selection flow
- category named `All` filters out nothing
- channels are on the left pane
- main view is for quick play and selected channel EPG overlay on video

### Focus/Playback Rule

- focus movement updates selection, metadata, and overlays
- focus movement does not start playback
- playback changes only on explicit activation

## Guide Subview

Structure:

- category/group list in side panel
- category named `All`
- radio/toggle for showing all channels even without EPG
- main view is for quick play and selected channel EPG overlay on video

### Normal Guide State

- `3-5` rows of EPG around selection

### EPG-Focus State

- when user moves focus inside EPG programs/grid
- video area shrinks
- EPG expands
- `6-9` rows of EPG become visible

### Guide Browsing Rule

- active stream keeps playing while browsing guide
- focused program/channel updates overlay metadata only
- no retune until explicit activate

### Guide Activation Rules

- current/future live program => tune channel
- past program with catchup => open catchup playback
- past program without catchup => details/info only
- alternate action may open details/options sheet

## Live TV Remote Numeric Rule

Displayed channel numbers are:

- scoped to the current active ordering/filter/view
- not global entity ids

Numeric channel selection uses current scoped order.

Later:

- user-defined persistent channel numbering may be added

Not now:

- no persistent numbering in first-phase model

## Live TV Favorites Ordering

Favorites are global canonical by default, but Live has extra behavior:

- favorited channels rise to the top of ordering
- favorited groups rise to the top of ordering
- groups do not have to appear in canonical favorites view to affect ordering

This special rise-to-top behavior applies only to Live.

It does not apply to Media by default.

## Media (VOD)

## Browse Structure

Media default pattern:

- side panel: categories / filters / source scope as needed
- main area: rails or grids by subview
- focus/activate opens detail state in same domain surface
- detail state may use 1/3 info + 2/3 artwork/actions/content lists

## Movie Detail

Movies have one detail page.

Primary action:

- Play / Resume

Action hierarchy:

- Play / Resume
- Trailer if available
- More Info / Source Options if needed
- secondary actions like favorite, mark watched, related

Source/provider/debug actions stay lower.

No shell-phase trailer/background autoplay.

## Series Detail

Series have one detail page.

Behavior:

- season picker if any
- episode selection list
- selecting episode goes directly to player
- no separate episode detail page

Series playback requirement:

- player must later receive series context
- player must later support episode navigation without exiting

## Search

### Scope

- one global search entry point in top nav
- default search spans active domains/resources
- results grouped by domain/source/type
- user can narrow scope/filter without leaving search

### Search Rendering

- unified search container
- separate result templates per domain/type

Examples:

- Live
- Movie
- Series
- Episode
- Settings result
- Source result

### Search Activation

Search activation must:

- navigate to canonical domain surface
- focus selected item
- open its detail state/view there

Not allowed:

- duplicate search-owned detail route

### Episode Search Hits

Series episode search hit activation:

- goes to series detail
- season/episode focused
- not direct player launch by default

Quick-play may exist only as explicit affordance later.

## Mock Player and Final Player

## Mock Player Rule

Mock player is allowed before full player phase only to validate:

- source data object handoff
- playable URL presence
- playable contract shape
- origin/context handoff

Mock player is not allowed to become accidental real player scope.

## Full Player Rule

The player is not only media playback.

It is a full playback environment with:

- OSD
- channel switching
- media controls
- media analysis
- same-type media switching without exit
- series episode switching without exit

Because the full use cases were not fully known at planning time, full player
work is intentionally last.

This is not an unknown. It is a deliberate gate.

## Player Gate

Before player implementation, a dedicated player investigation and subplan must
define:

- live switching inside player
- episode switching inside player
- movie up-next behavior
- OSD layouts by media type
- quality/audio/subtitle/source chooser UX
- casting/PiP/miniplayer policy
- stats/media-analysis overlays
- resume/autoplay/next-item policies
- back behavior from player states
- playback performance budgets
- external-player fallback policy
- DRM/protected stream handling

## Source Selection Policy

### Default Browse Behavior

When many active sources exist:

- domain shows merged canonical catalog by default
- source scope/filter available in side panel
- user can pivot to single source view in `Sources` or domain filters
- shell must not force source-first browsing

### Preferred Source Policy

Preferred source decision may consider:

- user pinned preference
- prior successful playback
- source health
- content completeness
- quality/capability match
- language/region fit
- lower latency or local source bias if equal

Flutter must not hardcode provider-brand preference.

### Source Chooser Visibility

Show source/variant chooser when:

- preferred source failed recently
- quality/capability differs materially
- language/region differs
- user explicitly asks for source options
- ambiguity/high-risk fallback is marked

Do not show chooser when one clear preferred variant exists and user has no
override reason.

## Health, Diagnostics, and User Visibility

### Normal User Visibility

Normal UI should show:

- simple health badges
- friendly failure reasons

### Advanced/System Visibility

Advanced/System surfaces can show:

- per-source health
- last sync
- capabilities
- cache/storage
- benchmark info

Developer/experimental details remain deeper.

## Favorites, History, Recommendations

### Favorites

- global canonical favorites by default
- optional source/variant preference beneath favorite item

### Continue Watching

- real earlier than recommendations

### Recommendations

- placeholder during early shell/stub phase
- real later once history and source contracts justify it

## Localization

Non-negotiable localization rules:

- all user-facing strings localized from day 1
- no hardcoded UI copy in widgets/viewmodels except test fixtures
- provider/source raw strings may display only as content data
- layout must survive longest expected translations within scale buckets

## Design System, Tokens, Widgetbook

### Token Authority

- Flutter tokens are authoritative
- Penpot mirrors Flutter token names/values
- design and implementation use tokenized spacing/radius/type/motion/elevation
- no arbitrary feature-widget visual constants unless intentionally local or
  promoted

### Widgetbook Rule

Widgetbook starts from the beginning.

Rules:

- annotate widgets properly as work proceeds
- fixture-backed use cases where stable
- provider-heavy widgets may defer only with concrete reason

## Motion System

### Motion Hierarchy

- shell/nav motion: restrained Google TV / Android TV style
- focused widget motion: Apple TV premium feel
- detail/player overlays: Netflix + YouTube directness
- one shared motion token system
- no per-screen improvisation

### Low-End / Stress Mode

Low-end or stress mode must:

- keep same layout
- keep same mechanics
- reduce duration
- reduce blur
- reduce parallax
- reduce shadows
- reduce layered opacity effects
- never switch to alternate UX path

Performance mode:

- selectable in settings
- later auto-triggerable by heuristics

## Performance Contract

Every screen must obey:

- bounded widget count independent of dataset size
- bounded image decode/prefetch budget
- no unbounded streams/listeners per row
- no per-item timers
- no full-list rebuild on focus move
- stable item extents where possible
- deterministic prefetch window
- expensive sort/filter/search outside Flutter UI layer
- id-addressable collections, not copied lists
- instrumentation hooks for frame time, row count, cache size, hydration
  latency

### Primitive Acceptance Gates

- target `60fps` on reference `1080p` TV hardware
- `10k+` item dataset support for list/rail/grid
- no full materialization for those datasets
- focus move must not trigger full-list rebuild
- idle shell CPU near zero without active playback
- memory stays flat after repeated navigation loops
- visible widget count bounded to viewport + overscan only
- image/cache budgets measurable and capped
- stress dataset + benchmark harness required before vertical rollout

## TDD and Verification

### TDD Definition

- behavior/domain work: Rust tests first
- Flutter shell/windowing work: widget/VM/focus tests first when behavior can
  be locked
- visual shell stubs: snapshot/golden/integration before refactor, not
  necessarily before first sketch
- no cleanup/refactor without regression coverage
- performance-sensitive primitives need benchmark/assertion harness early

### Hard Verification Categories

- contract tests
- primitive behavior tests
- navigation/focus tests
- performance assertions
- integration flows
- visual/widgetbook/golden coverage
- later player scenario matrix

## Required Early Integration Flows

1. app startup -> Home shell
2. top-nav domain switch
3. Settings top-level group navigation
4. source wizard entry/back safety
5. search -> canonical domain detail handoff
6. Live TV channels subview navigation
7. Live TV guide subview navigation
8. mock player launch from movie detail
9. mock player launch from series episode selection

## AGENTS / Governance Requirements

The future AGENTS guidance for this v2 lane must include:

- priority order exactly as approved
- Flutter MV only
- no Flutter controller/business logic
- no provider-native leakage into Flutter
- mandatory fake-scroll/windowed primitives on every screen
- scale-not-reflow TV layout
- canonical input action model
- required per-screen navigation spec before implementation
- required per-component focus contract
- Widgetbook from start
- player-last investigation gate

## Final Scope Statement

This specification defines:

- the architecture split
- the delivery order
- the design direction
- the layout model
- the navigation/input model
- the domain boundaries
- the source contract expectations
- the screen behaviors
- the performance contract
- the testing contract
- the governance rules

The only intentionally deferred area is full player implementation, and that
deferral is itself fully specified by the player gate and required subplan
outputs above.
