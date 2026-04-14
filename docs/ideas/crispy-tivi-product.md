# Crispy Tivi — Product One-Pager

Output of the Phase-3 idea-refine session on 2026-04-14. Pinned here so future sessions start from the product positioning, not from scratch.

## Problem Statement

How might we turn the live-TV subscription the user already pays for into a calm, beautiful, private, cross-platform player that works identically on every screen they own — without ever using the word "IPTV" in the product?

## Recommended Direction

Crispy Tivi is an OSS, privacy-first, zero-account, cross-platform live-TV player for people who already have an IPTV service and just want it to work. The target is the average user with a pulse and a playlist URL — someone who was handed credentials by a relative or provider and doesn't want to deal with TiviMate's config depth, Smarters' upsell nags, or re-configuring the same app on every device they own. The validation audience is power users in r/iptv and HTPC forums, who recommend Crispy to their non-technical family because it's trustworthy, ethical, and the only serious cross-platform entry in the space.

The single-sentence positioning: **"the live-TV player your non-technical uncle can use on every screen he owns, that you can ethically recommend."** The differentiation is doubled up — (a) OSS + privacy-first + zero-account (no telemetry, no signup, no cloud sync, no ads, ever) and (b) true parity across Android, iOS, Windows, macOS, Linux, and Web. No incumbent does both. TiviMate is Android-only and freemium-nagged. IPTVnator is OSS and cross-platform but Electron/Tauri, not Compose/native.

Execution is **depth-first, not breadth-first**. V1 ships the entire feature set from [v1-phase-roadmap.md](../v1-phase-roadmap.md) — foundation, core MVP, late-phase features (subtitles, PiP, background, catch-up, recording, casting, parental, multi-profile), release polish — but **each feature is built to completion before the next one starts**. No stubs, no MVP-of-feature, no half-finished subsystems carrying forward into the next slice. User directive 2026-04-14: *"each part we do, we finish full before moving to the next."*

## Non-negotiable rules (captured from the interview)

- **Name:** Crispy Tivi. The word "Tivi" is fine (reads as a cute TV-ish suffix). The four letters **"IPTV" never appear in any user-facing copy** — not in store listings, not in app strings, not in README marketing sections, not in error messages. Only in internal domain code (`IptvSourceAdapter`, etc.) where the technical term is load-bearing.
- **Distribution strategy:** store-first with aggressive neutral branding. Primary channels = Google Play, Apple App Store, Microsoft Store, Mac App Store. Rename copy everywhere to "live TV player", "your streams", "your channels". Sideload channels (GitHub releases, F-Droid, Flathub) as fallback for store-rejected cases. Accept that store review may flag us regardless — treat each store as a best-effort independent channel.
- **Onboarding:** **credentials-first, hard wall.** No default channels. No Hypnotix-style "try with free TV" demo mode. No curated free-stream list. First launch = "Add your source" screen. If the user doesn't already have a playlist URL or Xtream/Stalker credentials, the app does not help them acquire one. We are a client, not a marketplace.
- **V1 scope:** full [v1-phase-roadmap.md](../v1-phase-roadmap.md), all four phases, no minimal V1. Feature-complete execution, not feature-breadth.
- **Privacy:** zero accounts, zero telemetry, zero analytics, zero crash reporting to any server, zero cloud sync. Non-negotiable. No "optional signup for cloud sync" — the idea of it does not exist in the product.

## Key Assumptions to Validate

- [ ] **Store reviewers accept "Crispy Tivi" with neutral copy.** Open Google Play and Apple App Store submissions as soon as a pre-release build exists and keep testing store-review survival as a running signal. If rejected, fall back to GitHub releases + F-Droid + Flathub + Microsoft Store only. **This is the deadliest assumption** — if stores reject us, the product can only reach power users (who sideload), and the "average joe" target becomes harder.
- [ ] **Average users who've been handed credentials can complete a pure credentials-first onboarding flow without help.** Test: watch 3–5 non-technical people install a pre-release build and try to add a real playlist URL. If they need help, the onboarding copy is the fix, not the scope.
- [ ] **One builder can ship depth-first feature-complete quality on 6 platforms in 12–18 months.** This is the single biggest execution risk. IPTVnator took ~5 years to reach its current state. Mitigations: ruthless feature ordering, reusing architecture work across platforms, accepting that V1 may land in late 2027 rather than 2026.
- [ ] **Power users in r/iptv / HTPC forums will adopt + evangelize an OSS alternative to TiviMate.** Test: post the first pre-release to r/iptv and r/Android_TV and watch response. Realistic target: 50–200 weekly active users in year 1 per the IPTVnator benchmark ([research findings 2026-04-14](open-questions.md)).
- [ ] **"Paste a URL, app auto-detects M3U vs Xtream vs Stalker" is technically reliable.** No incumbent ships this. Unknown whether URL-pattern detection is accurate enough for the average case. Fallback: if auto-detection fails, show a three-field form (base URL + username + password). Test during Phase 2 onboarding work.

## V1 Scope — everything in [v1-phase-roadmap.md](../v1-phase-roadmap.md)

- **Phase 1 Foundation:** build-logic conventions, iOS + wasmJs + Compose Desktop targets added to the conventions, `:core:navigation` (hand-rolled back stack + restoration), `:core:design-system` fresh-from-UIUX tokens + `CrispyLogo` composable, `:core:playback` contract + 4 per-platform backends (Media3 on Android, AVPlayer cinterop on Apple, libmpv JNA on desktop, hls.js externals on Web), `:core:security` + 4 `:platform:security:*` impls, observability contracts, persistence + SQLDelight + FTS5.
- **Phase 2 Core MVP:** onboarding (credentials-first hard wall), source management, live channels, movies, series, guide (EPG via hand-rolled XMLTV streaming parser), search, library (personal return points — Continue Watching, Favorites, History, Saved positions, Recently Played Channels), sync, media session, image pipeline + thumbnail extraction (`:core:image` with javacpp-presets ffmpeg on desktop), restoration, import/export (ZIP of JSONs + passphrase-encrypted secrets), diagnostics.
- **Phase 3 Late-phase:** subtitles (select + style + timing offset), audio track selection, picture-in-picture on all six platforms, background playback policy, catch-up / archive support, recording (local + provider-side where supported), parental controls, **casting** (Google Cast via Play Services SDK + AirPlay via AVPlayer `allowsExternalPlayback` + DLNA via hand-rolled SSDP/SOAP on desktop — new `cast-core` + `platform-cast-*` module family), multi-profile, TV/tablet form-factor refinement, richer provider capabilities.
- **Phase 4 Release polish:** cross-platform parity audit (all features on all 6 platforms), performance tuning (virtualization audit, image pipeline memory, EPG ingestion throughput, cold-start time, long-session memory stability), accessibility pass, diagnostic bundle finalization, release artifacts (AAB + APK, IPA, DMG, MSI, AppImage, deb, rpm, web bundle), per-subsystem README documentation.

## Operating principle (the 2026-04-14 directive)

**Sequential depth, not parallel breadth.** When a feature is on the workbench, it ships complete before anything else starts. No stubs. No MVP-of-feature. No "good enough for now" that carries forward into the next slice. The order in which we build features therefore matters more than anything else — dependencies must be respected strictly, and early features must be built with the assumption that they will be polished, tested, and documented before move-on.

This has implications:

- **The v1-phase-roadmap.md phase structure is correct but incomplete.** Within each phase we need a strict dependency ordering — which feature blocks which. A planning session with [`superpowers:writing-plans`](../orchestrator-start-prompt.md) should produce this ordering before any feature work starts.
- **Parallelization via subagents is discouraged for features** because it breaks the "finish X before Y starts" rule. Parallel subagents are OK only for **independent foundation work** (e.g., write the media3 binding while another subagent writes the libmpv binding — both independent, neither blocks the other).
- **Time budget per feature must include documentation, tests, edge cases, and cross-platform parity — not just "it works on my Linux desktop."** A feature isn't done until it's done on all 6 platforms.

## Not Doing (and why)

- **"Minimal V1" / phased feature rollout** — user explicitly rejected. Every planned feature ships in V1.
- **Default "free TV" content / Hypnotix-style demo mode** — user rejected. No curated channels, no demo playlist. Product is a pure client; content-distribution liability stays out.
- **Any user-visible "IPTV" string** — store-hostile for review + piracy-adjacent brand perception. Brand name "Tivi" is fine; the four letters "IPTV" are not.
- **Cloud sync / accounts / telemetry / analytics / crash reporting to a server** — OSS privacy-first is non-negotiable. No part of the app talks to our servers because there are no servers.
- **Monetization / paid tiers / ads / in-app purchase** — 50–200 active user OSS project, not a product business. Keeps the trust story clean.
- **Helping users acquire credentials (provider marketplace, affiliate links, recommendation list)** — we're a client, not a marketplace. Users bring their own source. The closest we get is a "where do I get a playlist?" link in the help screen pointing to neutral educational material.
- **Post-V1 features we don't know about yet** — explicitly excluded until V1 ships. Per [decisions.md D16](decisions.md), nothing is post-V1, but also nothing new is added to V1 mid-flight either.
- **Word "IPTV" in store listings, copy, README, marketing, or any user-visible string** — replaced with "live TV", "your channels", "your streams", "TV player".

## Open Questions (answer during the planning session, not now)

- What order do we build Phase 1-4 features in? Depth-first completion requires strict dependency ordering. Rough first cut: **foundation → onboarding → playback-core + Android backend → live channels + EPG → iOS backend → desktop backend (libmpv JNA) → web backend (hls.js externals) → movies → series → search → library → restoration → rest of Phase 3**. Needs a planning session with the [writing-plans skill](../orchestrator-start-prompt.md).
- What's the realistic V1 ship target date? 12–18 months is the honest answer but depends on weekly hours available. Needs a velocity assumption.
- What's the minimum onboarding copy that lets a credentials-first user figure out where to paste what? Phase 2 UX task.
- Which 2–3 stores do we submit to first — Google Play, App Store, Mac App Store, Microsoft Store, F-Droid, Flathub? Depends on which platform is completed first.
- Does Crispy Tivi need a type treatment / wordmark alongside the existing C-mark logo? Phase 1 design-system task — branding exists ([branding/](../../branding/)), typography on top of it does not yet.

## Related reading

- [decisions.md](decisions.md) — 19 resolved decisions, authoritative over everything else
- [v1-phase-roadmap.md](../v1-phase-roadmap.md) — full V1 scope by phase
- [code-standards.md](../code-standards.md) — mandatory coding standards
- [monorepo-blueprint.md](../monorepo-blueprint.md) — module graph + boundaries
- [open-questions.md](../open-questions.md) — hand-roll architecture sketches
- [uiux-spec.md](../uiux-spec.md) — visual direction and UX goals
- [branding/README.md](../../branding/README.md) — brand assets and platform icon generation
