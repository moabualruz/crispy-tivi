# Crispy-Tivi — Code Standards and Rules

## 1. Core rule set

1. Optimize for **locality of behavior** first.
   - A developer should be able to understand a feature by reading a small set of nearby files.
   - Avoid abstractions that force jumping across the codebase to understand one flow.

2. Optimize for **replaceable boundaries** second.
   - Provider integrations, playback backends, image loading, secure storage, search indexing, and observability must be easy to replace.
   - Most abstraction effort should go there, not into generic UI helpers.

3. Optimize for **stable domain vocabulary** third.
   - Naming and type design must reflect the real product language:
     `Source`, `SourceScope`, `ChannelVariant`, `AggregateChannel`, `PlaybackVariant`, `ResolvedPlaybackSelection`, `EpgProgram`, `RestorationRecord`, `SyncRecord`.

4. Prefer **simple concrete code** inside a feature.
   - Prefer direct readable code over “smart reusable frameworks”.
   - Reuse should happen after duplication proves stable.

---

## 2. Architectural recommendation

Use this paradigm mix:

- **UDF for UI/state**
- **DDD-lite for domain modeling**
- **Adapter + Strategy as the main integration patterns**
- **Facade for orchestration boundaries**
- **Factory only where object creation depends on source type, platform, or capability**
- **Flow/StateFlow for observation**
- **Policy objects for configurable behavior**
- **events only at subsystem boundaries**

### What this means in practice

- UI code is state-in, intents-out
- domain code owns meaning and rules
- adapters isolate platform/provider differences
- strategies own variable decision logic
- facades coordinate multi-step workflows
- factories create typed implementations
- flows expose state changes
- policies hold changeable rules
- events communicate completed transitions, not everything

---

## 3. What to use aggressively

### 3.1 Adapter pattern
This should be everywhere the outside world touches the app.

Use adapters for:
- source providers
- playback backends
- secure storage
- image pipeline
- platform media session
- import/export codecs
- observability sinks

This is the most important pattern in the codebase because your product has two major volatility zones:
- provider families
- platform families

### 3.2 Strategy pattern
Use strategies for any decision logic that will evolve, be tuned, or vary by data quality.

Use strategies for:
- EPG matching
- channel deduplication
- source prioritization
- playback variant selection
- search ranking
- refresh scheduling
- artwork fetch behavior
- merge behavior during import

If a behavior is expected to change over time, put it behind a strategy instead of burying it inside services or repositories.

### 3.3 Facade pattern
Use facades at feature orchestration boundaries only.

Good facades:
- `PlaybackFacade`
- `SyncFacade`
- `SearchFacade`
- `ImportExportFacade`
- `RestorationFacade`

A facade should coordinate multiple lower-level components so feature/viewmodel code does not know too much.

### 3.4 Policy objects
Anything that sounds like a rule, preference, or scheduling decision should be a policy object.

Examples:
- autoplay restore policy
- startup sync policy
- stale data policy
- image cache policy
- source merge policy
- source fallback policy

This is one of the highest-value recommendations for this codebase because a lot of your app behavior is configurable and will change later.

---

## 4. What to avoid overusing

### 4.1 Factories
Use factories only where construction logic is genuinely variable.

Good:
- `SourceAdapterFactory`
- `PlaybackBackendFactory`
- `ImportCodecFactory`

Bad:
- factories for ordinary data classes
- factories just to avoid calling constructors directly

### 4.2 Builders
Use builders only for truly complex construction.

Good:
- complex search query object
- diagnostics bundle
- export package
- playback request with many optional knobs

Bad:
- builders for normal Kotlin DTOs with named parameters

### 4.3 Generic base classes
Do not build the codebase around inheritance trees.

Prefer:
- interfaces
- composition
- small delegates
- strategies
- policies

The app will be easier to evolve if behavior is assembled rather than inherited.

### 4.4 Global event bus
Do not use a big generic event bus.

If events exist:
- they must be typed
- they must have a clear owner
- they must cross a real boundary
- they must not replace normal method calls

---

## 5. DRY recommendation

Use DRY selectively.

### Must be DRY
- design tokens
- ranking formulas
- normalization rules
- sync conflict/upsert rules
- query/index helpers
- error classification
- source capability definitions
- restoration serialization format

### Allowed to repeat
- simple mapping code near a feature
- small screen-specific state transitions
- clear one-off orchestration
- similar but not identical source-specific logic

### Rule
Do not abstract until one of these is true:
- the duplication is already stable
- the duplication causes bugs
- the duplication hides one domain rule that must stay identical

---

## 6. SOLID recommendation

Use SOLID as a pressure test, not as ceremony.

### The parts that matter most here

#### Single responsibility
Most important at:
- repositories
- parsers
- matchers
- state holders
- platform adapters
- sync steps

If a class parses, persists, ranks, emits events, and updates state, split it.

#### Open/closed
Most important at:
- provider integration
- playback integration
- ranking/matching/selection rules
- import/export formats
- observability outputs

These areas should gain new implementations without rewriting stable feature code.

#### Dependency inversion
Most important at:
- feature → repository
- feature → playback
- domain → provider capability
- restoration → persistence
- sync → provider adapter

High-level logic should depend on contracts that match the domain, not infrastructure names.

### Recommendation
Do not force every tiny class through SOLID analysis.
Apply it hardest at module boundaries and volatile subsystems.

---

## 7. Domain-driven recommendation

Use **DDD-lite**, not full enterprise DDD.

### What to do
- define a strict ubiquitous language
- keep bounded contexts explicit
- use domain services for real rules
- keep normalized entities and value objects clean
- separate provider payloads from normalized models

### Bounded contexts that should exist
- Source Ingestion
- Normalization
- Search
- EPG
- Playback
- Sync
- Restoration
- Observability

### Recommendation
Domain services should own rules like:
- EPG matching
- playback selection
- deduplication
- source merge
- source-scoped filtering

Do not let repositories become the place where all business rules go.

---

## 8. State and observation recommendation

Use `StateFlow` for durable observable state and `SharedFlow` only for transient one-off effects when unavoidable.

### Rules
- every non-trivial screen gets one immutable `UiState`
- state holders own state mutation
- no mutable state exposed publicly
- repositories expose domain streams, not UI streams
- player state is exposed as a typed stream
- sync progress is exposed as a typed stream
- restoration availability is exposed as a typed stream

### Important recommendation
Prefer **state-first modeling** over event-first modeling.

Bad default:
- “everything emits events”

Good default:
- “what is the current state?”
- “what action changes it?”
- “what side effect follows?”

Events should exist mostly for:
- subsystem completion
- external integrations
- one-off outputs like navigation or toast/error dispatch

---

## 9. Repository and service recommendation

### Repositories
Repositories should answer:
- what normalized data exists?
- how is it queried?
- how is it refreshed or persisted?

Repositories should not become giant business-rule containers.

### Domain services
Domain services should answer:
- how do we match this?
- how do we rank this?
- how do we pick this?
- how do we merge this?
- how do we restore this?

### Facades
Facades should answer:
- how do we coordinate multiple repositories/services into one feature flow?

### Recommendation
Split code by responsibility like this:
- repositories = access/orchestration of data sources
- services = domain decisions
- facades = multi-step feature orchestration
- state holders = presentation state production

That split is the cleanest fit for your app.

---

## 10. Interface design recommendation

Prefer small capability interfaces.

Good:
- `SourceCatalogReader`
- `SourceSyncRunner`
- `EpgMatcher`
- `PlaybackBackend`
- `SecretStore`
- `SearchIndexer`

Bad:
- `MediaManager`
- `AppService`
- `SourceEngine`
- `DataController`

### Rule
If an interface name is vague, it is probably too big.

---

## 11. File and class size recommendation

### Files
- prefer one main public type per file
- small private helpers are fine in the same file
- avoid giant 800-line kitchen-sink files

### Classes
- state holders should stay focused on one screen/flow
- repositories should stay focused on one domain area
- services should stay focused on one rule family

### Rule of thumb
When a file contains:
- multiple unrelated responsibilities
- several nested model types
- many private helper branches
- both orchestration and rule logic

split it.

---

## 12. Naming recommendation

Use names that reveal role and boundary clearly.

### Suffix guidance
- `...Repository` for normalized data access/orchestration
- `...Service` for domain rules
- `...Strategy` for replaceable decisions
- `...Policy` for configurable rules
- `...Adapter` for external/provider/platform bridge
- `...Facade` for feature orchestration
- `...Factory` for variable creation
- `...UiState` for immutable screen state
- `...Action` for incoming user/system intents
- `...Event` for one-off outward signals
- `...ViewModel` or `...StateHolder` for state production

### Recommendation
Be boring and explicit with names.
This codebase benefits more from obvious names than from elegant short ones.

---

## 13. Error-handling recommendation

Use typed error families and normalize failures early.

### Rules
- provider errors are mapped before leaving provider modules
- platform errors are mapped before leaving platform modules
- feature layers consume normalized error types
- logs contain diagnostic detail
- UI layers receive safe, product-level error information

### Recommendation
Do not use raw exceptions as the main domain language.
Use structured error models at boundaries.

---

## 14. Performance-related code rules

Because this is a media-heavy, multi-source app, performance rules must be part of coding standards.

### Rules
- no eager full-list transformations in hot UI paths
- no parsing or ranking work inside composables
- no synchronous image decoding or large JSON/XML work on main thread
- all heavy matching/ranking/parsing/indexing must happen off main thread
- virtualized surfaces must preserve stable keys
- off-screen work must be cancellable
- memory-heavy caches must be bounded and policy-driven

### Recommendation
Treat performance-sensitive code as architecture, not optimization cleanup.

---

## 15. Documentation recommendation

Every volatile subsystem should have a short local doc explaining:
- purpose
- inputs/outputs
- replacement points
- invariants
- performance assumptions

Prioritize docs for:
- source normalization
- EPG matching
- playback selection
- sync pipeline
- restoration
- search indexing
- import/export

### Recommendation
Write docs where the mental model is expensive, not everywhere.

---

## 16. Testing recommendation

### Test hardest
- strategies
- policies
- facades
- normalization rules
- deduplication
- EPG matching
- playback selection
- restoration decisions
- sync scheduling
- search ranking

### Test less directly
- trivial mappers
- passive DTOs
- obvious wrappers

### Recommendation
If a class contains rules, branch decisions, or fallback behavior, it needs direct tests.

---

## 17. Strong final recommendation

For Crispy-Tivi, the best standards mix is:

- **feature-first modular architecture**
- **UDF for all presentation state**
- **DDD-lite for domain boundaries and naming**
- **Adapter-heavy external integration**
- **Strategy-heavy decision logic**
- **Facade-based orchestration**
- **Policy objects for configurable behavior**
- **StateFlow-centered observation**
- **pragmatic SOLID**
- **pragmatic DRY**
- **composition over inheritance**
- **typed errors and typed contracts**
- **performance rules treated as first-class coding standards**

### In one sentence
Build the app so that **features stay concrete and readable**, while **volatile parts are isolated behind adapters, strategies, facades, and policies**.
