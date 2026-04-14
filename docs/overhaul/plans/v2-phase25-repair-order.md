# Phase 25 Repair Order

Status: complete
Date: 2026-04-13

## Mapping

### Phase 26: demo/test gating and first-run truth

Status: complete

Own:

- startup mode truth
- default real boot with zero seeded providers/content/personalization
- explicit demo/test mode behavior and documentation
- first-run onboarding/startup verification from clean state

Primary findings moved here:

- app boot still relies on mostly empty real runtime while demo mode is the
  only populated path
- demo/test-vs-real truth must be made explicit before deeper wiring work

### Phase 27: provider/controller wiring completion

Status: complete

Own:

- source/provider add/edit/auth/import/reconnect flows
- provider-specific typed validation and submit behavior
- runtime/controller save/status/error ownership
- active use of relevant shared Rust crates for provider lanes

Primary findings moved here:

- source flow is still local UI state with no real controller/persistence path
- configured providers remain absent from real runtime behavior

### Phase 28: screen and widget runtime audit closure

Status: complete

Own:

- Home runtime truth
- Live TV runtime truth on real boot
- Media runtime truth on real boot
- Search runtime/controller truth
- Settings runtime content truth
- Player retained controller/runtime truth
- removal of fallback shaping from routes/view-models where retained runtime
  boundaries exist

Primary findings moved here:

- Home, Live TV, Media, Search, Settings, and Player are still blocked or
  scaffolded on the real runtime path
- legacy fallback builders remain reachable through active presentation flows

Closure notes:

- active presentation fallback resolution was removed from the retained shell
  path
- Home, Search, and non-source Settings now reflect retained runtime truth
  instead of shell-content scaffolding
- player backend ownership moved to a retained playback controller instead of a
  widget-local backend

### Phase 29: release-readiness audit and field validation

Own:

- real-source/provider manual validation
- long-session playback/startup/resume verification
- final blocker list or release-ready signoff

Primary findings moved here:

- player backend is not meaningfully exercised in demo/test mode because asset
  URIs are fenced off with `.test`
- operational truth must be checked under real sources after Phases 26 to 28
  land
