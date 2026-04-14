# Crispy-Tivi — Monorepo Module and Package Blueprint

> Note: §2 and §3.3 below are the resolved layout from the interview. See [decisions.md](decisions.md) D1, D2, D4–D7, D10.

## 1. Purpose

This document defines the recommended monorepo module structure and package layout conventions for Crispy-Tivi.

The goal is to make implementation start with:
- clear ownership
- predictable dependency direction
- stable boundaries
- replaceable volatile subsystems
- minimal package sprawl

---

## 2. Top-Level Module Layout

Authoritative module list for the starting monorepo graph. The layout follows the canonical Now-in-Android grouping: modules are organized into top-level role directories (`app/`, `core/`, `feature/`, `domain/`, `data/`, `provider/`, `platform/{player,security,observability}/`, `test/`) with each module flat inside its group. Gradle paths use `:` separators.

### App shells (`:app:*`)
- `:app:android`
- `:app:ios`
- `:app:desktop`
- `:app:web`

### Core shared subsystems (`:core:*`)
- `:core:design-system`
- `:core:navigation`
- `:core:epg`
- `:core:playback`
- `:core:image`
- `:core:security`
- `:core:export-import`

### Feature modules (`:feature:*`)
- `:feature:home`
- `:feature:live`
- `:feature:guide`
- `:feature:movies`
- `:feature:series`
- `:feature:search`
- `:feature:library`
- `:feature:sources`
- `:feature:settings`
- `:feature:player`
- `:feature:onboarding`

### Domain layer (`:domain:*`)
- `:domain:model`
- `:domain:services`
- `:domain:policies`

### Data layer (`:data:*`)
- `:data:contracts`
- `:data:repositories`
- `:data:normalization`
- `:data:search`
- `:data:sync`
- `:data:restoration`
- `:data:observability`

### Provider adapters (`:provider:*`)
- `:provider:contracts`
- `:provider:m3u`
- `:provider:xtream`
- `:provider:stalker`

### Platform integration (`:platform:{subsystem}:{target}`)

Playback:
- `:platform:player:android`
- `:platform:player:apple` (covers iOS and macOS)
- `:platform:player:desktop` (covers Windows + Linux; macOS uses `:platform:player:apple`; backend pending R2 research)
- `:platform:player:web`

Secure storage:
- `:platform:security:android` (Android Keystore)
- `:platform:security:apple` (iOS + macOS Keychain)
- `:platform:security:desktop` (Windows DPAPI + Linux libsecret; macOS uses `:platform:security:apple`)
- `:platform:security:web` (Web Crypto + IndexedDB encrypted blob)

Observability:
- `:platform:observability:android`
- `:platform:observability:apple`
- `:platform:observability:desktop`
- `:platform:observability:web`

### Test support (`:test:*`)
- `:test:fixtures`
- `:test:contracts`

This is the committed layout. Modules may be merged or split per §9 "Initial Merge/Split Guidance" if real implementation pressure shows a better boundary.

---

## 3. Module Responsibilities

## 3.1 App modules

### `:app:android`
Responsible for:
- Android app entry
- dependency graph assembly
- Android activity/window lifecycle integration
- Android-specific platform wiring

### `:app:ios`
Responsible for:
- iOS app entry
- app graph assembly
- iOS lifecycle integration
- Apple-specific app bootstrap

### `:app:desktop`
Responsible for:
- desktop window/bootstrap
- dependency graph assembly
- desktop integration wiring

### `:app:web`
Responsible for:
- web app entry
- browser bootstrapping
- web dependency graph assembly

App modules should not contain business logic.

---

## 3.2 Design and navigation modules

### `:core:design-system`
Responsible for:
- design tokens
- semantic styling contracts
- shared component primitives
- reusable visual building blocks

### `:core:navigation`
Responsible for:
- destination definitions
- route typing
- navigation helpers
- restoration-aware navigation support

This module should not own feature logic.

---

## 3.3 Feature modules

Each feature module owns:
- feature route/screen composition
- feature state holder/viewmodel
- feature UI models
- feature-specific orchestration
- feature tests

Feature modules:
- `:feature:home` — landing screen, hero, content rails
- `:feature:live` — live channel browsing (live + channels surface)
- `:feature:guide` — EPG/Guide timeline and grid
- `:feature:movies` — movie catalog browsing and details
- `:feature:series` — series/season/episode catalog browsing and details
- `:feature:search` — cross-source search and filtering
- `:feature:library` — personal return points: Continue Watching, Favorites, History, Saved positions, Recently Played Channels
- `:feature:sources` — source management (add/edit/remove/validate/enable/disable)
- `:feature:settings` — application configuration
- `:feature:player` — playback surface, OSD, controls
- `:feature:onboarding` — required first-run source setup and initial sync

Feature modules should depend on contracts and domain services, not on platform implementations.

---

## 3.4 Domain modules

### `:domain:model`
Owns:
- normalized entities
- value objects
- identifiers
- enums
- sealed domain result types

### `:domain:services`
Owns:
- matchers
- selectors
- rankers
- deduplicators
- merge logic
- other domain rules

### `:domain:policies`
Owns:
- configurable policies
- restore/autoplay rules
- source priority rules
- refresh scheduling rules
- image policy structures
- merge policy structures

---

## 3.5 Data modules

### `:data:contracts`
Owns:
- repository interfaces
- storage contracts
- search contracts
- restoration contracts
- sync contracts
- observability contracts

### `:data:repositories`
Owns:
- repository implementations
- orchestration of DB + providers + cache
- normalized query pipelines

### `:data:normalization`
Owns:
- provider payload normalization into domain models
- aggregate/source-scoped model transformations
- merge pipelines

### `:data:search`
Owns:
- search indexing
- search query execution
- ranking orchestration

### `:data:sync`
Owns:
- sync pipelines
- upsert orchestration
- scheduled refresh logic
- source sync status tracking

### `:data:restoration`
Owns:
- restoration record persistence
- restoration resolution
- navigation/playback context rehydration

### `:data:observability`
Owns:
- log schema helpers
- metric/tracing helpers
- diagnostic bundle assembly

---

## 3.6 Provider modules

### `:provider:contracts`
Owns:
- source adapter interfaces
- provider capability definitions
- provider DTO boundary contracts
- parser/result contracts

### `:provider:m3u`
Owns:
- M3U/M3U8 source ingestion
- M3U-specific normalization inputs

### `:provider:xtream`
Owns:
- Xtream source ingestion
- Xtream-specific metadata and EPG retrieval integration

### `:provider:stalker`
Owns:
- Stalker source ingestion
- portal-specific metadata integration

Future providers should follow the same pattern:
- `:provider:jellyfin`
- `provider-...`

---

## 3.7 Shared subsystem modules

### `:core:epg`
Owns:
- EPG program model helpers
- XMLTV ingestion support
- runtime matching orchestration
- normalized schedule resolution

### `:core:playback`
Owns:
- shared player contract
- playback resolution models
- playback facade contracts
- backend selection interfaces

### `:core:image`
Owns:
- image request model
- image cache policy contracts
- image pipeline interfaces

### `:core:security`
Owns:
- secret store contracts
- secret reference model
- security-related abstractions

### `:core:export-import`
Owns:
- backup model
- import/export format contracts
- bundle versioning helpers
- merge/replace policy contracts

---

## 3.8 Platform integration modules

### Playback
- `:platform:player:android`
- `:platform:player:apple`
- `:platform:player:desktop`
- `:platform:player:web`

These modules implement playback-core contracts.

### Security
- `:platform:security:android` — Android Keystore
- `:platform:security:apple` — iOS and macOS Keychain (shared)
- `:platform:security:desktop` — Windows DPAPI, Linux libsecret (macOS uses `:platform:security:apple`)
- `:platform:security:web` — Web Crypto + IndexedDB encrypted blob

These modules implement security-core contracts.

### Observability
- `:platform:observability:android`
- `:platform:observability:apple`
- `:platform:observability:desktop`
- `:platform:observability:web`

These modules implement data-observability/platform logging contracts.

---

## 4. Dependency Direction

Preferred dependency direction:

- app modules depend on feature modules and platform implementations
- feature modules depend on:
  - design-system
  - navigation-core
  - domain-model
  - domain-services
  - domain-policies
  - data-contracts
- data-repositories depend on:
  - data-contracts
  - domain-model
  - domain-services
  - provider-contracts
  - provider implementations
  - epg-core
  - search/data modules where relevant
- platform modules implement shared contracts and are wired only by app modules

Rules:
- no feature module depends on app modules
- no domain module depends on platform modules
- no UI module depends on raw provider payloads
- no platform module leaks platform types upward into shared feature code

---

## 5. Recommended Package Layout Inside Modules

Use predictable packages.

Example for a feature module such as `:feature:live`:

- `feature.live.route`
- `feature.live.screen`
- `feature.live.state`
- `feature.live.model`
- `feature.live.action`
- `feature.live.event`
- `feature.live.viewmodel`
- `feature.live.mapper`
- `feature.live.test`

Example for a provider module such as `:provider:m3u`:

- `provider.m3u.api`
- `provider.m3u.parser`
- `provider.m3u.model`
- `provider.m3u.mapper`
- `provider.m3u.adapter`
- `provider.m3u.test`

Example for playback desktop:

- `platform.player.desktop.backend`
- `platform.player.desktop.vlc`
- `platform.player.desktop.mapper`
- `platform.player.desktop.session`
- `platform.player.desktop.test`

---

## 6. Recommended File Shapes

For a feature screen:
- `LiveRoute.kt`
- `LiveScreen.kt`
- `LiveViewModel.kt`
- `LiveUiState.kt`
- `LiveAction.kt`
- `LiveEvent.kt`
- `LiveUiModel.kt`

For a provider:
- `M3uSourceAdapter.kt`
- `M3uParser.kt`
- `M3uChannelMapper.kt`
- `M3uImportModels.kt`

For a strategy:
- `EpgMatchingStrategy.kt`
- `AliasAwareMatchingStrategy.kt`
- `CompositeEpgMatchingStrategy.kt`

For a facade:
- `PlaybackFacade.kt`
- `SyncFacade.kt`

For a policy:
- `AutoplayRestorePolicy.kt`
- `RefreshSchedulingPolicy.kt`

---

## 7. Keep These Boundaries Explicit

### UI boundary
UI modules consume:
- normalized UI models
- state flows
- typed actions/callbacks

UI modules must not consume:
- provider DTOs
- raw SQL entities
- platform-specific service APIs directly

### Data boundary
Data modules own:
- provider orchestration
- DB orchestration
- sync orchestration
- normalization

### Domain boundary
Domain modules own:
- naming
- rule logic
- selection
- matching
- ranking
- merge semantics

### Platform boundary
Platform modules own:
- media sessions
- secure storage
- platform playback backends
- browser/native system integration

---

## 8. Package Naming Rules

- keep package names boring and explicit
- avoid vague names like `manager`, `utils`, `helpers`, `common` unless narrowly scoped
- use role-based names:
  - `adapter`
  - `strategy`
  - `policy`
  - `facade`
  - `repository`
  - `model`
  - `state`
  - `screen`
  - `route`
  - `mapper`

Avoid dumping unrelated code into:
- `util`
- `misc`
- `core.common`
- `shared`

---

## 9. Initial Merge/Split Guidance

It is acceptable to start with fewer modules if needed, but only if the ownership boundaries remain clear.

Safe early merges:
- `:domain:services` + `:domain:policies`
- `:data:search` + `:data:repositories`
- `:data:restoration` + `:data:repositories`
- `:core:epg` inside `:domain:services` if still small

Unsafe early merges:
- provider modules merged into feature modules
- platform modules merged into shared domain modules
- feature UI merged into app modules
- raw source parsing merged into UI or navigation modules

---

## 10. Required Follow-Up by Planner/Applier

The planner and applier of this blueprint must validate and refine the final module graph against:
- actual feature pressure inside the project
- actual Gradle/KMP source-set constraints
- the latest Compose Multiplatform module ergonomics
- the latest platform integration realities discovered during implementation
- the latest project-specific requirements and code growth patterns

This blueprint is the recommended starting structure, not a frozen final topology.
