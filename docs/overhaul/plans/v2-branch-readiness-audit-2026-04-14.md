# Branch Readiness Audit

Status: active
Date: 2026-04-14

## Purpose

This audit records the concrete blockers still present on the branch after the
Rust-boundary correction and fake-runtime cleanup work. It is the current
reference for what still prevents the branch from being treated as a fully real,
working product.

## Findings

### 1. Source setup still manufactures provider health/import truth instead of proving it

Severity: high

Code:

- [controller.rs](/home/mkh/workspace/crispy-tivi/rust/crates/crispy-ffi/src/source_runtime/controller.rs:159)
- [controller.rs](/home/mkh/workspace/crispy-tivi/rust/crates/crispy-ffi/src/source_runtime/controller.rs:175)
- [source_registry.rs](/home/mkh/workspace/crispy-tivi/rust/crates/crispy-ffi/src/source_runtime/source_registry.rs:329)

What is wrong:

- source setup commit still builds configured-provider status from field
  presence and wizard mode
- `Healthy`, `Complete`, and `Ready` can be produced without a real auth,
  validation, or import execution step
- this makes the provider list look operational earlier than it really is

What should be addressed:

- move source validation/auth/import into explicit Rust application services
- commit only persisted intent/config at setup time
- derive health/auth/import state from actual execution results, not field
  presence heuristics

### 2. Runtime hydration still collapses each domain to the first ready provider

Severity: high

Code:

- [runtime.rs](/home/mkh/workspace/crispy-tivi/rust/crates/crispy-ffi/src/source_runtime/runtime.rs:88)
- [runtime.rs](/home/mkh/workspace/crispy-tivi/rust/crates/crispy-ffi/src/source_runtime/runtime.rs:2775)

What is wrong:

- Live TV is chosen from the first configured provider that supports
  `live_tv`
- Media is chosen from the first configured provider that supports both
  `movies` and `series`
- this blocks a real multi-provider product shape where users may combine
  sources or have separate live and VOD providers

What should be addressed:

- add Rust-owned aggregation/priority rules across configured providers
- make domain hydration merge or rank provider outputs intentionally instead of
  stopping at `.find(...)`
- expose explicit provider-selection policy in runtime metadata

### 3. Demo-mode detection is still encoded as a string note in the registry snapshot

Severity: medium

Code:

- [source_registry.rs](/home/mkh/workspace/crispy-tivi/rust/crates/crispy-ffi/src/source_runtime/source_registry.rs:143)
- [runtime.rs](/home/mkh/workspace/crispy-tivi/rust/crates/crispy-ffi/src/source_runtime/runtime.rs:104)

What is wrong:

- demo/runtime policy is currently inferred by checking whether
  `registry_notes` contains a specific string
- this is brittle and mixes product/runtime policy with descriptive notes

What should be addressed:

- replace the string-sentinel check with an explicit Rust-owned mode field
  or enum on the source/runtime snapshot boundary
- keep notes descriptive only, not behavioral

### 4. Real-source proof stops at hydration and route render, not verified playback

Severity: medium

Code:

- [real_source_boot_test.dart](/home/mkh/workspace/crispy-tivi/app/flutter/integration_local/real_source_boot_test.dart:15)

What is wrong:

- the local real-source proof now correctly proves real provider-backed boot,
  live, media, and search hydration
- it still does not prove that in-app playback actually starts successfully on
  the real provider path

What should be addressed:

- add a real-source playback proof that launches player from a real provider
  item/channel and verifies backend session readiness beyond route render
- keep credentials out of tracked fixtures and logs while doing so

## Current judgment

This branch is materially better than before:

- real mode no longer silently fabricates demo runtime when provider hydration
  fails
- explicit demo mode stays Rust-owned
- persisted real provider boot is proven

But it is not yet a fully real working product because the findings above still
affect correctness and product confidence.
