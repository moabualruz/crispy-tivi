# Phase 30: Provider Persistence and Import Runtime

Status: complete
Date: 2026-04-13

## Purpose

Phase 30 moves source setup/import off local-only controller mutation and onto
the retained runtime persistence path.

## Completed in this phase

- added retained source-registry persistence:
  - `SourceRegistryStore`
  - `PersistedSourceRegistryRepository`
- extended retained source-registry contracts with a write path so configured
  providers can be saved and restored across real-mode boots
- added raw source-registry serialization/copy support so persisted configured
  providers stay on the retained runtime boundary instead of being rebuilt from
  presentation-only models
- rewired the real runtime bootstrap to preserve configured providers from the
  retained source repository instead of forcing them back to empty
- rewired the source wizard commit path so closing the wizard persists the
  updated configured-provider snapshot through the retained repository

## Evidence

- retained tests now verify:
  - persisted source-registry save/load round-trip
  - runtime bootstrap preserves configured providers from the retained source
    repository
  - view-model wizard completion commits through the repository path
- verification passed:
  - `flutter analyze`
  - `flutter test test/app/app_bootstrap_test.dart test/features/shell`
  - `timeout 120s flutter test integration_test/main_test.dart -d linux`
  - `app/flutter/tool/restore_linux_release_state.sh`
  - `flutter build linux`
  - `flutter build web`
- built-web browser smoke:
  - `.playwright-cli/phase30-web-smoke.png`
  - `.playwright-cli/page-2026-04-13T10-44-36-890Z.yml`

## Closure rule

Phase 30 closes provider persistence/import runtime only. It does not yet
populate Home, Live TV, Media, or Search from those configured providers; that
belongs to Phase 31.
