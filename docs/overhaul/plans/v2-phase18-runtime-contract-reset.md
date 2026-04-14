# V2 Phase 18 Runtime Contract Reset

Status: complete
Date: 2026-04-12

## Purpose

Replace ambiguous asset-backed assumptions with explicit runtime-facing
repository interfaces and a clear replacement map, while keeping retained
presentation code neutral.

## Authority

Use this order:

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
3. `design/docs/penpot-installed-design-system.md`
4. `docs/overhaul/plans/v2-implementation-reference-study.md`
5. active implementation phase docs

## Phase 18 output

### Retained Flutter repository interfaces

The retained Flutter runtime boundary is now explicitly interface-based:

- `ShellContractRepository`
- `ShellContentRepository`
- `ShellBootstrapRepository`

The asset-backed implementations sit behind those interfaces:

- `AssetShellContractRepository`
- `AssetShellContentRepository`
- `AssetShellBootstrapRepository`

The Flutter app now depends on the interface type for bootstrap wiring instead
of a concrete asset class.

### Exact replacement map

| Current retained interface | Temporary implementation | Future runtime replacement |
| --- | --- | --- |
| `ShellContractRepository` | `AssetShellContractRepository` | Rust FFI-backed contract repository using `crispy-ffi` plus `crispy-iptv-types` as the normalized boundary vocabulary |
| `ShellContentRepository` | `AssetShellContentRepository` | Rust FFI-backed content repository fed by `crispy-iptv-types`, `crispy-iptv-tools`, `crispy-m3u`, `crispy-xmltv`, `crispy-xtream`, `crispy-stalker`, and `crispy-catchup` as applicable |
| `ShellBootstrapRepository` | `AssetShellBootstrapRepository` | Rust-backed runtime bootstrap coordinator that resolves contract + content and hands retained Flutter presentation the settled runtime snapshot |

### Exact crate ownership

- `crispy-ffi`
  - FFI boundary structs and runtime contract serialization surface
  - bridge point for Flutter-facing retained repositories
- `crispy-iptv-types`
  - canonical normalized vocabulary for playlist/channel/EPG/VOD/source/runtime shapes
- `crispy-m3u`
  - M3U parsing and playlist import
- `crispy-xmltv`
  - EPG/XMLTV ingestion
- `crispy-xtream`
  - Xtream provider auth and catalog loading
- `crispy-stalker`
  - Stalker provider auth and catalog loading
- `crispy-catchup`
  - archive/timeshift derivation
- `crispy-iptv-tools`
  - normalization, deduplication, merge, cleanup, and shaping
- `crispy-stream-checker`
  - source validation and health checks
- `crispy-media-probe`
  - diagnostics and stream probing when needed

### What Phase 18 guarantees

- Flutter presentation code no longer depends directly on asset classes for
  bootstrap wiring.
- Runtime-boundary ownership is explicit in docs and code.
- Asset-backed repositories are now clearly temporary implementations behind
  retained interfaces.
- The later Rust runtime can replace repository internals without changing the
  retained presentation layer contract.
- The phase references the shared Rust crate stack instead of leaving runtime
  ownership implicit.

## Drift corrected in this phase

- fixed the missing runtime-boundary file reference in the one-shot prompt
- removed the app bootstrap hard-wiring to the concrete asset bootstrap class
- made the runtime replacement path explicit instead of implied by asset naming
- added an injected-bootstrap test path so the app can be exercised against a
  non-asset runtime repository

