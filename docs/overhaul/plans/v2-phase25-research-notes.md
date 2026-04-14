# Phase 25 Research Notes

Status: complete
Date: 2026-04-13

## Sources

### Online references

- IPTVnator website:
  - https://4gray.github.io/iptvnator/
- Megacubo website / help index:
  - https://megacubo.tv/en/english/
- Hypnotix upstream repo:
  - https://github.com/linuxmint/hypnotix

### Local study repos

- `for_study/Megacubo`
- `for_study/hypnotix`
- `for_study/iptvnator`
- `for_study/player-ui-study/media-kit`
- `for_study/player-ui-study/chewie`
- `for_study/player-ui-study/rein_player`
- `for_study/player-ui-study/fvp`

## Repair classes

### Startup and first-run truth

Findings:

- Megacubo explicitly frames startup around setup wizard, preferences, and
  adding the first list before normal viewing.
- IPTVnator’s product framing emphasizes adding playlists, EPG, and settings as
  first-class operational flows rather than empty placeholder screens.
- Hypnotix keeps provider types explicit from the start: M3U URL, Xtream API,
  and local M3U playlist.

Rules:

- CrispyTivi real mode must boot truthfully from zero configured providers.
- Demo/test mode may stay populated, but only behind explicit gating.
- First-run startup must lead into operational provider setup, not blank route
  shells that imply the app is wired when it is not.

### Provider setup and runtime ownership

Findings:

- IPTVnator and Hypnotix both treat provider/playlist entry as a real product
  workflow with explicit typed entry paths.
- Megacubo’s documentation emphasizes setup, adding lists, and troubleshooting
  as operational parts of the product, not decorative UI.

Rules:

- Provider setup/auth/import/edit/reconnect must be controller-backed and
  operational.
- Typed fields alone are insufficient; validation, submit, state changes, and
  error handling must come from retained runtime/controller ownership.
- Provider catalog metadata and configured providers must remain separate.

### Route and widget runtime truth

Findings:

- IPTVnator’s feature language ties playlists, EPG, favorites/history, search,
  and settings directly to operational app behavior.
- Megacubo’s quick-start language ties setup, adding IPTV lists, and watching
  into one coherent flow.

Rules:

- A route cannot count as wired just because it renders a polished layout.
- Home, Live TV, Media, Search, Settings, Sources, and Player must each have a
  named runtime/controller owner on the real path.
- Any fallback shaping left reachable from routes/view-models must be treated
  as audit debt and removed in the repair phases.

### Demo/test gating

Findings:

- Hypnotix ships a default provider, but that pattern conflicts with the active
  CrispyTivi rule that real mode must start from zero configured providers.
- IPTVnator and Megacubo both make clear that the app does not provide content;
  user-provided sources are the truth path.

Rules:

- CrispyTivi must not ship seeded providers/content/personalization on the
  default real boot path.
- Demo/test fixtures are allowed only through explicit mode selection or test
  injection.
- Demo/test assets must not be mistaken for proof that real runtime is wired.

### Release readiness and manual validation

Findings:

- IPTVnator highlights operational areas like add playlist, settings, EPG, and
  playlists as visible, testable product surfaces.
- Megacubo’s docs emphasize troubleshooting and operational behavior under real
  use, not only nominal happy paths.

Rules:

- Final release readiness must include manual validation with real providers and
  playable sources.
- Player/resume/startup/provider flows must be judged on repaired real-runtime
  behavior, not on scaffolded demo flows.
- Automated tests remain necessary but cannot replace real-source validation.
