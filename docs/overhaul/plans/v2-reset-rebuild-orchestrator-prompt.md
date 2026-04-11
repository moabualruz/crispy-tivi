# V2 Reset Rebuild Orchestrator Prompt

Use this prompt for the next restart run after discarding the current invalid
implementation.

## Prompt

You are the orchestrator for the CrispyTivi v2 restart rebuild.

You must treat the current implementation as disposable unless it is explicitly
re-approved against the authority stack.

### Authority stack

Follow this order without exception:

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
3. `design/docs/penpot-installed-design-system.md`
4. supporting design docs:
   - `design/docs/design-system.md`
   - `design/docs/app-overhaul-design-system.md`
5. live approved Penpot page only if the installed design docs are missing,
   stale, or explicitly challenged by the user:
   `http://localhost:9001/#/workspace?team-id=ec16cff3-941d-80ee-8007-d90e5af73dda&file-id=ec16cff3-941d-80ee-8007-d9645092a3ee&page-id=ec16cff3-941d-80ee-8007-d9645092a3ef`
6. approved reference images in `design/reference-images/`
7. active v2 plan docs under `docs/overhaul/plans/`

Legacy screenshots under `docs/screenshots/` and any old main-branch app
screenshots are non-authority and must not be used for implementation
decisions.

### Mission

Redo the restart properly from a reseted code base.

The previous run failed because it:

- rebuilt from derived assumptions instead of literal Penpot/spec evidence
- accepted generic TV-shell layouts instead of board-faithful compositions
- collapsed structure into large unreadable mixed-responsibility files
- treated passing tests as a substitute for design compliance
- stopped without cross-target automated smoke verification
- reused old-app shell cues that the user explicitly rejected

Your job is to:

1. re-audit all active docs and plans for drift, gaps, and contradictions
2. fix those docs before implementation
3. reset invalid implementation surfaces again if they conflict with the
   authority stack
4. redo phases 1 to 4 in order
5. produce a design-faithful, mocked, testable shell on Linux and web

### Mandatory architecture rules

- Follow DDD, SOLID, LOB, and DRY expectations throughout.
- No god files.
- No mixed-responsibility modules.
- No giant screen files containing state, routing, data, rendering, and helper
  primitives together.
- Flutter owns only presentation, view-model, view-state, and UI composition.
- Rust owns business/domain logic and provider translation.
- Keep modules small, named clearly, and grouped by responsibility.
- Prefer reversible diffs and incremental verification.

### Mandatory implementation rules

- Do not implement from summarized memory.
- Use the installed design documents directly during implementation.
- Recheck live Penpot only when the design documents are missing, stale,
  contradictory, or explicitly disputed by the user.
- Do not close a phase if any visible drift remains against the installed
  design documents, the reference images, or the chat-history v2 spec.
- Do not count generic placeholder cards or generic Material scaffolds as valid
  progress.
- Do not preserve prior wrong structure out of convenience.
- If the current implementation is wrong, replace it rather than rationalizing
  it.
- Do not use old-app screenshots or old main-branch visuals as input.
- Do not place permanent `Back` or `Menu` controls in the global top bar unless
  the installed design documents explicitly require them.
- Do not use old underline/underscore top-nav cues from the old app.
- Do not use pill/chip-heavy shell chrome unless the installed design documents
  explicitly require it.
- Treat `Sources` as part of `Settings`, not a top-level global domain.
- Do not expose `Player` as a top-level global navigation destination.

### Mandatory verification before each stop

Before any stop, handoff, or completion claim, run verification targeted to the
changed surfaces on both Linux and web:

1. static verification:
   - `flutter analyze`
   - relevant Flutter tests
   - relevant Rust tests
2. Linux target:
   - build or run Linux target
   - execute automated smoke checks for the changed surfaces
3. web target:
   - build or run web target
   - use Playwright CLI to perform browser-driven smoke checks
   - capture screenshots when the work is visual
4. design compliance:
   - compare rendered result against `design/docs/penpot-installed-design-system.md`
   - compare against supporting design docs
   - compare against approved reference images
   - compare against the chat-history v2 spec
   - use live Penpot only if the installed design docs must be refreshed or
     validated

If verification fails, do not stop and do not claim progress. Fix the issue and
re-run verification.

### Phase expectations

#### Phase 1

- pin the installed design-doc/token/layout/windowing authority
- define implementation decomposition rules that prevent god files
- define the minimum token/theme/runtime surfaces needed for both Linux and web

#### Phase 2

- map each route to literal installed design-doc ownership
- define route-by-route composition and visual intent
- define required Flutter module boundaries for each route family
- correct the route model so `Sources` lives under `Settings`
- remove `Player` from top-level navigation
- ban old-app nav cues and unjustified pill/menu/back chrome

#### Phase 3

- define IA, focus, back/menu, and overlay rules
- define explicit component contracts and cross-module boundaries
- make the implementation shape obvious enough that drift is hard to introduce

#### Phase 4

- implement only the mocked shell
- keep Rust mocks and Flutter presentation separated cleanly
- ensure the resulting UI is visually faithful, readable, modular, and testable

### Deliverable

Return only when all of the following are true:

- docs and plans were audited and corrected
- phases 1 to 4 were redone properly
- the implementation is modular and readable
- Linux target is built and smoke-verified
- web target is built/run and smoke-verified with Playwright CLI
- the rendered shell is materially faithful to the installed design documents,
  the reference images, and the message-history v2 spec
