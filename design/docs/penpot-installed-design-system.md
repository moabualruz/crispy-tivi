# CrispyTivi Installed Design System

Status: Active Markdown design authority
Date: 2026-04-11

Active shell palette choice:

- `Smoked Stone`
- glassy effects are approved only as restrained translucent grouped chrome
- do not use strong tinted washes or loud neon-like edge effects

## Purpose

This file is the installed design authority for the v2 restart lane.

Implementation must use this file directly. It exists so the rebuild can stop
depending on repeated live design-tool reads.

Code authority for design values:

- `app/flutter/lib/core/theme/crispy_overhaul_tokens.dart`
- `app/flutter/lib/core/theme/crispy_shell_roles.dart`

Implementation rule:

- widget-level colors, radii, and state geometry must flow from those theme
  files rather than being redefined ad hoc inside widget files
- production shell code must keep neutral naming
- reserve `mock`, `fake`, or `asset` naming for fixture files, test harnesses,
  and temporary asset-backed repositories only
- shared shell domain models, contract parsers, navigation, view-models,
  routes, and widgets must not keep `mock_*` names once they are the retained
  runtime path
- shared shell backdrop, stage frame, action controls, artwork scrims, icon
  plates, and repeated media-card surfaces must also be defined there rather
  than repeated inside route/widget files
- repeated hero/shelf art framing should also come from shared role-owned media
  surfaces rather than widget-local image treatment
- media artwork must be source-agnostic at the system layer so the same shell
  rendering path can handle repo assets now and remote provider artwork later
- populated mock route content should come from canonical content snapshot
  assets rather than local Dart seed constants when that support exists

If another doc, mock, screenshot, or remembered layout conflicts with this
file, this file wins unless the user explicitly changes it.

## Authority Order

Use this order:

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
3. this file: `design/docs/penpot-installed-design-system.md`
4. approved reference images in `design/reference-images/`
5. active v2 plan docs in `docs/overhaul/plans/`

Non-authority:

- `docs/screenshots/`
- any old main-branch app screenshots
- any old shipped-app captures
- any prior mock-shell screenshots
- any previous implementation that drifts from this file

## Installed Design Baseline

Pinned approved design set:

- page id: `ec16cff3-941d-80ee-8007-d9645092a3ef`
- page name: `Page 1`
- token set name: `CrispyTivi vNext`
- token count: `25`
- approved board count: `14`

Approved board set:

1. `FOUNDATION - vNext Tokens`
2. `FOUNDATION - Layout and Windowing`
3. `COMPONENT - Navigation and Focus Controls`
4. `COMPONENT - Surfaces and Widget Feel`
5. `SCREEN - Home Shell`
6. `SCREEN - Settings and Sources Flow`
7. `SCREEN - Live TV Channels`
8. `SCREEN - Live TV Guide`
9. `SCREEN - Media Browse and Detail`
10. `SCREEN - Search and Handoff`
11. `FEATURE - Source Selection and Health`
12. `FEATURE - Favorites, History, and Recommendations`
13. `FEATURE - Mock Player and Full Player Gate`
14. `PATTERN - Left and Right Menus`

## Design Direction

Behavior direction:

- modern Google TV / Android TV shell behavior
- Apple TV restraint for focus, scale, depth, and motion
- Netflix / YouTube clarity for media details and playback information density

Visual direction:

- restrained dark TV shell
- content-first composition
- low clutter
- room-readable type
- controlled elevation separation
- no decorative gradient-first styling
- no game-UI or neon treatment
- avoid cold blue-black palettes as the dominant shell identity
- preferred shell palette is `Smoked Stone`
- fallback explored families are warm graphite, soft olive-neutral, and
  cinema-ember
- palette direction stays derived from Google TV / Apple TV / Netflix mood
  without matching them literally
- shell chrome should borrow clearer Google TV / Apple TV markers:
  - softer grouped top-nav treatment
  - translucent dock-like shells where justified
  - warmer panel tinting instead of flat black stacking
  - utility-menu rows with icons, chevrons, and clear active sections
  - populated mocks should feel like a real entertainment surface rather than a
    design-demo board
  - hero art and shelves should use domain-relevant media imagery, not
    arbitrary personal or meme-like photos

## Anti-Drift Rules

These are hard constraints:

- ignore `docs/screenshots/` completely
- ignore all old main-branch app visuals completely
- do not reuse old underline or underscore top-nav markers
- do not place permanent `Back` in the global top bar
- do not place permanent `Menu` in the global top bar
- do not use pills ever
- do not use chip-heavy shell chrome
- do not expose `Sources` as a top-level global domain
- do not surface `Sources` as a stand-alone Home shortcut or quick-access
  destination; access to source management stays within `Settings`
- `Settings` search stays local to the grouped Settings hierarchy and must use
  explicit result activation before opening an exact leaf
- exact-leaf Settings activation must remain view-model/system owned so search,
  open state, highlight, and unwind behavior do not drift into widget-local
  state
- do not expose `Player` as a top-level global navigation destination
- do not use generic placeholder card walls as a substitute for real layout
- do not use generic Material scaffolding as a substitute for board-faithful UI
- do not leave major shell surfaces as empty color blocks when mock assets
  are available
- do not populate the shell with arbitrary non-media mock imagery that breaks
  the TV-product illusion; mock assets must be intentionally curated or
  generated for entertainment/product context
- populated mock assets must remain visibly legible inside the actual crop and
  scrim treatment used by the shell; “asset exists but reads like an empty
  block” is still drift
- artwork loading/fallback behavior must also be shared so missing or delayed
  media does not collapse individual routes into ad hoc placeholders
- artwork regions may use restrained title-safe overlays to preserve readable
  occupancy inside TV viewing distance and dark-shell treatments
- do not use decorative blue or red overlay washes on artwork unless they
  encode clear, relevant information
- do not leave oversized dead gutters around the scaled `1920x1080` stage
- do not leave the fixed shell stage so small that the product reads like a
  centered demo at `1080p`
- route and widget chrome must inherit the active token palette
- old hardcoded color literals from prior palettes are drift and must be
  removed when touched
- the area outside the scaled stage must carry intentional ambient backdrop,
  not empty black side gutters
- when a drift or requirement gap is corrected in code, the governing design
  docs and active plans must be updated in the same pass
- selected, focused, and active states must come from one shared visual system;
  one-off per-widget highlight shapes are drift
- interactive control corners must also come from one shared system; buttons,
  inputs, sidebar selections, utility controls, and info plates must not drift
  into unrelated radius values
- do not solve radius inconsistency by increasing rounding until controls read
  like pills; the control corner language must stay restrained and clearly
  rectangular

## Token System

### Surface colors

- `void`: `#0E0E10`
- `panel`: `#18191D`
- `raised`: `#23252B`
- `glass`: `#CC23252B`

### Accent colors

- `focus`: `#DCE2EA`
- `brand`: `#8DA4C7`
- `brandSoft`: `#B6C3D8`
- `actionBlue`: `#8DA4C7`

Palette note:

- `Smoked Stone` is now the selected active shell palette
- shell surfaces stay neutral and must not introduce strong blue or red
  decorative treatments over imagery

### Semantic colors

- `success`: `#22C55E`
- `warning`: `#C9A56A`
- `danger`: `#B85A54`

### Text colors

- `primary`: `#F5F5F7`
- `secondary`: `#C2C7D0`
- `muted`: `#7D8591`

### Spacing

- `hairline`: `2px`
- `compact`: `6px`
- `small`: `10px`
- `medium`: `18px`
- `large`: `28px`
- `section`: `44px`
- `screen`: `64px`

### Radius

- `sharp`: `2px`
- `card`: `6px`
- `sheet`: `10px`
- `pill`: `999px`
- `control`: `10px`

Note:

- the `pill` token exists in the token set
- it is not approved for shell chrome
- its existence does not justify pills anywhere in the UI
- the active shell uses one primary control radius family
- use `control` for interactive shell controls and utility/info plates
- use `sheet` for major surface containers
- use `card` only for dense media/list cards where a tighter corner is
  explicitly justified
- `control` is intentionally restrained and must not look pill-like at common
  control heights

### Motion

- `focus`: `120ms`
- `panel`: `220ms`
- `page`: `360ms`

## Layout System

### TV layout rule

- the app scales and does not reflow
- same composition regardless of screen size or resolution
- use scale buckets, not responsive rearrangement
- safe-area adjustments only where required
- keep the canonical stage visually full; the shell should not read like a
  small centered demo surrounded by dead space

### Canonical viewport

- `1920x1080` at `1x`

Derived scale buckets:

- `720p`
- `1080p`
- `1440p`
- `4K`

Bucket rule:

- do not use raw continuous scaling as the only viewport policy
- scale handling must preserve the same visual composition across screen sizes
  and window sizes
- buckets must not materially change the shell feel from one size to another
- `1080p` must not look tiny
- `4K` must not show oversized empty shell gutters
- current implementation uses one fixed virtual shell stage and one internal
  metric set; only presentation scale changes
- current implementation uses a product-sized virtual shell stage of
  `1440x810`; shell spacing and sidebar extents come from shared shell-role
  constants rather than per-widget scale tuning

### Split ratio rule

The `1/3 + 2/3` split is optical, not mathematically exact.

Approved ranges:

- side panel target: `32%` to `36%`
- content target: `64%` to `68%`

### Geometry rule

- windowed surfaces use fixed or bucketed extents by surface type
- primary browse surfaces must be index-addressable
- do not use arbitrary content-driven relayout for primary browse surfaces
- clamp and truncate variable content instead of relaying out the shell

## Windowed Primitive System

Every screen must use the same fake-scroll or windowed primitive system from
day 1.

Mandatory supported surface types:

1. vertical lists
2. horizontal rails
3. poster grids
4. channel list + detail split
5. `1/3 + 2/3` side-panel/content layouts
6. modal menus
7. wizard step lists and forms
8. search mixed-result layouts
9. EPG timeline/list hybrid placeholder
10. player-adjacent overlay placeholder

Not allowed:

- normal scroll as a temporary shell exception
- screen-specific one-off browse mechanics

## Input and Focus Model

All raw devices map into one canonical action model.

Devices:

- remote controls
- keyboards
- gamepads

Canonical actions:

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
- page jump when justified
- tab or subview switch
- details/info
- favorite
- search

Rules:

- no ambiguous diagonal movement
- every focusable region defines enter rules
- every focusable region defines exit rules
- focus movement never starts playback by itself
- Flutter owns directional focus runtime
- Rust may suggest semantic target ids only

## Shell Architecture

### Global shell rule

- top bar = global/domain navigation only
- side panel = current-domain local navigation only
- content pane = active surface
- overlays = modal flows above content

### Global top navigation

Approved top-level destinations:

1. Home
2. Live TV
3. Media
4. Search

Global top navigation owns only:

- app/domain switching
- global entry points

Global top navigation does not own:

- permanent back action
- permanent menu action
- domain-local categories
- settings subsection navigation
- wizard steps
- player destination
- sources destination
- settings destination in the main nav group

Right-side utility/profile area owns:

- profile entry
- settings entry
- time and utility indicators

Visual markers:

- top navigation should read closer to a grouped shell control than to a row
  of isolated outlined buttons
- active route state should be obvious at distance without using the rejected
  old underline cue
- shell grouping must not use pills
- active selector geometry must share the same corner language and inset rhythm
  as the surrounding control
- settings/profile affordances should sit on the right side of the LTR shell,
  separate from the main content-domain navigation group

### Side panel existence

Sidebar exists only when the active domain has persistent local navigation:

- Live TV
- Media
- Settings

Sidebar does not exist by default for:

- Home
- Search

### Content pane ownership

The content pane owns:

- route title and route context
- hero, summary, or utility surface
- domain-specific lists, rails, grids, forms, or detail states
- route-local back behavior
- route-local menu behavior if justified

## Route Specifications

### Home

Purpose:

- default startup surface
- real hub, not a marketing splash

Sections:

- Continue Watching
- Live Now
- Media Spotlight
- Recent Sources
- Recommended / Trending placeholder
- Quick Access to Search
- Quick Access to Settings
- Quick Access to Series
- Quick Access to Live TV Guide
- Resume Setup if setup incomplete

Rules:

- content-led
- no local sidebar by default
- quick access is inside content, not in global nav
- home hero and primary rails should use populated mock imagery so the opening
  shell reads like a real product surface
- artwork uses neutral readability scrims plus meaningful metadata only
- decorative color washes over hero or rail artwork are not allowed

### Live TV

Local subviews:

1. Channels
2. Guide

Behavior:

- information-dense but remote-safe
- local subview nav only in side panel
- group/category switching lives in content, not the sidebar
- browse and quick-play live in content
- focus updates metadata and overlays
- focus does not start playback
- explicit activation changes playback
- selected-channel detail may change without retuning the active stream

#### Channels

- channels live in the left browse pane
- group rail lives in content above the detail lane
- main area shows quick-play and selected-channel context
- category named `All` filters out nothing

#### Guide

- local subview nav only in side panel
- group rail stays in content
- category named `All`
- optional toggle to show channels without EPG
- normal state shows `3-5` rows around selection
- EPG-focus state expands to `6-9` rows
- active stream keeps playing while browsing
- no retune until explicit activation
- selected channel summary stays separate from the guide matrix
- focused program detail overlay sits above the matrix and shows:
  - focused slot
  - program title and summary
  - live-edge state
  - duration
  - catch-up/archive affordances
- the matrix itself must come from canonical guide-row/program data rather than
  placeholder string tables

### Media

Local subviews:

1. Movies
2. Series

Behavior:

- poster and rail-driven
- focused item clearly separates from passive neighbors
- detail state remains in domain, not in a fake external route
- mock media surfaces should use poster/backdrop imagery rather than abstract
  placeholder blocks wherever assets are available

#### Movie detail

Primary action:

- Play / Resume

Secondary hierarchy:

- Trailer if available
- More Info / Source Options if justified
- Favorite / Mark Watched / Related

#### Series detail

- season picker if needed
- episode selection list
- selecting episode goes directly to player later
- no separate episode detail page

### Search

Purpose:

- one global search entry point
- grouped results across media and live domains/resources

Behavior:

- query-first
- one unified search container
- distinct result templates per result type
- handoff to canonical owning surface

Global search does not behave like settings search.

Rules:

- global search should search Live TV and Media domain content
- settings search remains local to Settings and opens exact settings leaves
- do not present Settings as a first-class result group in the global search
  shell unless the user changes that rule

Not allowed:

- search-owned duplicate detail routes

Episode search hits:

- go to series detail
- season and episode focused
- no direct player launch by default

### Settings

Purpose:

- grouped utility hierarchy
- should read closer to Google TV settings than to a media hub

Top-level groups:

1. General
2. Playback
3. Sources
4. Appearance
5. System

Internal deeper areas may include:

- Source Detail
- Import Wizard
- Auth / Connection Wizard
- Remote / Inputs
- Data / Storage
- Diagnostics / About
- Experimental / Developer hidden deeper

Rules:

- Settings owns source management
- Settings uses persistent local navigation
- source management is part of the grouped hierarchy, not a separate global app
- settings content should read like a utility menu, not like a hero/detail
  screen
- use clearer utility markers:
  - section titles
  - row icons
  - row chevrons or destination markers
  - concise right-side current values
  - calmer panel contrast with stable list rhythm

#### Sources flow

1. `Sources` opens source list
2. selecting existing source opens source overview/detail
3. adding source opens import/auth/validation wizard
4. wizard steps stay inside the Settings hierarchy
5. success returns to source overview with health/capability summary
6. advanced options stay behind secondary action

Source wizard rules:

- wizard step order is:
  - Source Type
  - Connection
  - Credentials
  - Import
  - Finish
- reconnect/auth-needed flows may enter the wizard at `Credentials`
- backing out of the first wizard step returns to the Settings-owned source
  overview/list
- backing out of later wizard steps returns to the previous wizard step rather
  than ejecting the user out of Settings
- sensitive credential-bearing steps must remain non-restorable until validated

### Player

Rules:

- player is last
- mock player exists only as a handoff proof if needed
- player is not top-level navigation
- player must not read like a normal shell destination

Pre-player gate must define:

- live switching inside player
- episode switching inside player
- OSD layouts by media type
- chooser UX for quality/audio/subtitle/source
- overlay policies
- back behavior from player states

## Back and Menu

### Back

- Back is contextual
- Back belongs to the active content or flow context
- Back is not a permanent global top-bar control
- Back dismisses overlays before route/domain unwind

### Menu

- Menu is route-local or overlay-local only
- Menu must be explicit and justified
- Menu is not a permanent global top-bar control
- Menu must not replace Back
- Menu must not hide global domain switching

## Source Selection Policy

Default browse behavior:

- merged canonical catalog by default when many active sources exist
- source scope/filter available locally where needed
- the shell does not force source-first browsing

Preferred source policy may consider:

- user preference
- prior successful playback
- source health
- content completeness
- quality/capability match
- language/region fit
- latency/local bias when otherwise equal

## Startup and Restore

Startup:

- first screen is Home
- startup target configurable later, default is Home

Restore may later include:

- active domain and subview
- selected category or filter
- focused item id
- open detail state id
- search query and focused result
- settings leaf path

Do not auto-restore unsafe wizard steps without validation.

## Implementation Rules

- use this file before coding
- do not infer missing structure from old code
- do not infer missing structure from old screenshots
- if a rendered result reintroduces old-app cues, reject it
- if a rendered result contradicts this file, reject it

## Verification Rules

Before any stop or completion claim:

1. `flutter analyze`
2. relevant Flutter tests
3. relevant Rust tests
4. Linux target build/run smoke
5. web target build/run smoke
6. browser-driven verification on web
7. visual review against this file and approved reference images

## Update Rule

If the user changes the design direction again, update this file first.
