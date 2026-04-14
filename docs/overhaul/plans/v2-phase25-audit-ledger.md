# Phase 25 Audit Ledger

Status: complete
Date: 2026-04-13

| Area | Surface | Real Mode | Demo/Test Mode | Runtime Owner | Fallback/Scaffold | Impact | Repair Phase | Notes |
|---|---|---|---|---|---|---|---|---|
| App boot | startup mode selection and initial route truth | scaffolded | wired | `CrispyTiviApp`, `RuntimeShellBootstrapRepository`, `PersistedPersonalizationRuntimeRepository` | asset provider catalog and empty runtime snapshots on real boot; explicit demo mode via `CRISPY_DEMO_MODE` | fresh install is cleaner than before, but the default path still presents a largely empty app rather than a fully operational runtime | Phase 26 | Real boot uses runtime mode, but runtime data is still mostly empty while demo mode remains the only populated path |
| Home | hero, live-now, quick access, continue watching | wired | scaffolded | retained media/live/personalization runtime through `ShellViewModel` | explicit empty-state messaging remains when no providers or imported runtime data exist | Home now reflects retained runtime truth instead of shell-content backfill; demo mode remains the only broadly populated content path | Phase 28 | Hero/live/continue-watching no longer synthesize from shell content or fallback movie rails |
| Live TV | channels, guide, selected detail, tune handoff | wired | wired | `LiveTvRuntimeSnapshot`, `ShellViewModel`, `LiveTvPresentationAdapter` | explicit empty-state scaffolds when no real providers/runtime data exist | Live TV now stays on retained runtime truth; empty real-mode is explicit rather than fallback-shaped in presentation | Phase 28 | Active presentation fallback resolution was removed from the shell path |
| Media | movies, series, detail, launch handoff | wired | scaffolded | `MediaRuntimeSnapshot`, `ShellViewModel`, `MediaPresentationAdapter` | explicit empty-state in real mode until real provider data exists | Media now stays on retained runtime truth and no longer relies on active presentation fallback shaping | Phase 28 | Real mode still depends on later provider/data population rather than seeded demo shelves |
| Search | query, groups, results, handoff | wired | scaffolded | `SearchRuntimeSnapshot`, `SearchPresentationAdapter`, `ShellViewModel` | explicit empty-state in real mode until imported/runtime-backed data exists | Search now carries retained runtime query and groups/results into presentation without decorative-only field truth | Phase 28 | Query is no longer dropped by presentation |
| Settings | general/playback/appearance/system content | wired | wired | retained runtime/diagnostics getters in `ShellViewModel` | source setup remains its own retained controller lane; empty catalog messaging when provider metadata is unavailable | non-source settings panels now stay populated in real mode without shell-content scaffolding | Phase 28 | General/Playback/Appearance/System are runtime-derived now |
| Sources | source list/detail, add/edit/auth/import/reconnect | scaffolded | scaffolded | `SourceRegistrySnapshot`, `SourceProviderRegistry`, `ShellViewModel` | local wizard state only; no runtime/controller submit/validate/save path; real mode uses asset provider catalog with zero configured providers | the most visible setup workflow still stops at typed UI scaffolding rather than real provider/controller behavior | Phase 27 | This is the highest-priority functional gap after the audit |
| Player | launch, playback backend, chooser application, resume | wired | scaffolded | `ShellViewModel` session state plus retained `PlayerPlaybackController` | `.test` URI gate and manual real-source validation still deferred to Phase 29 | player backend ownership is no longer widget-local; real-source readiness still needs manual field validation | Phase 28 | Release validation later must include real-source playback/manual checks |
| Cross-cutting | legacy fallback builders in active presentation/bootstrap path | wired | wired | data/bootstrap fallback helpers only | injected fallback scaffolding remains test/bootstrap-only | active presentation no longer resolves retained runtime fallbacks locally | Phase 28 | `resolveLiveTvRuntime`, `resolveMediaRuntime`, and `resolveSearchRuntime` were removed from the active shell path |

## Summary

- The retained runtime foundation plus audit-closure repairs are now in place.
- Real mode now behaves truthfully rather than being backfilled from seeded
  shell-content scaffolds:
  - first-run/settings-sources when no providers exist
  - explicit empty-but-runtime-owned Home, Live TV, Media, and Search states
  - populated non-source Settings panels from retained runtime/diagnostics
- Demo/test mode remains the only broadly populated content path today.
- The highest-priority repair areas are:
  - real-source/provider manual validation
  - long-session playback/startup/resume verification
  - release-readiness reassessment under Phase 29
