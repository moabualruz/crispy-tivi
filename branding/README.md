# Crispy Tivi — Branding Assets

This directory holds the master brand assets for Crispy Tivi. Everything here is source-of-truth; per-platform app icons (Android adaptive, iOS app icon set, macOS iconsets, Windows .ico, Linux .desktop .png) are **generated from these sources**, not committed separately, to keep the asset set compact.

The assets were pulled from the deprecated Flutter branch (`origin/main`) where the brand mark was originally designed. Flutter is dead per [decisions.md D8](../docs/decisions.md), but the brand mark is good — silver-on-charcoal palette, satellite dish + play triangle + C monogram — so we kept it and dropped everything else.

## The mark

The logo is a **C** (for Crispy) with a **play triangle** cutout and a **satellite dish** on the upper right of the letter. Reads as "Crispy" + "media player" + "broadcast signal" in one glyph.

Palette:
- Foreground: near-white silver (`#E2E4E8` approximate) or pure black (monochrome)
- Background (icon variants): deep charcoal (`#1F2226` approximate)

Lines up with [uiux-spec.md §4.2](../docs/uiux-spec.md) — "deep graphite, ink blue, slate navy, cool silver text". No gold/yellow. No neon. Crimson reserved for live/urgent emphasis only (not used in the mark).

## Files

| File | Size | Colorspace | Use for |
|---|---|---|---|
| `logo.svg` | 4.2 KB | Single-path vector, `fill:#000000` | **Master source.** Load as a Compose `ImageVector`, runtime-tint with any design-system color token. This is what `:core:design-system` consumes. |
| `logo.png` | 47 KB | Black on transparent (1024×1024) | Light-background contexts (white or pale surfaces). Rare — most surfaces in the app are dark. |
| `logo-silver.png` | 31 KB | Silver on transparent (1024×1024) | Dark-background UI contexts. The default in-app logo render. |
| `logo-fullbleed.png` | 50 KB | Silver on charcoal, edge-to-edge (1024×1024) | iOS full-bleed app icon template, splash screens, launch surfaces. iOS auto-masks this with a rounded rectangle. |
| `logo-grayscale.png` | 56 KB | Silver on charcoal squircle (1024×1024) | Android adaptive icon foreground source, Android legacy icon source, macOS / Windows / Linux standalone app-icon generator input. Includes the pre-rounded squircle background that looks correct on platforms without their own icon masking. |

The `.svg` is authoritative. All four `.png` files can be regenerated from it by re-rendering against the appropriate background template.

## Why four PNGs when we have an SVG?

Because each platform's app-icon pipeline wants a slightly different input:

- **iOS app-icon set** (`.appiconset/Contents.json` + multiple sizes) wants a **full-bleed** square that iOS will mask itself. → use `logo-fullbleed.png`
- **Android adaptive icon** wants a foreground layer (logo) on a separate background layer. → foreground comes from `logo-silver.png` (transparent), background is a solid charcoal fill defined in Compose MP resources.
- **macOS .iconset / Windows .ico / Linux .png** want a pre-composed square icon with built-in corners. → use `logo-grayscale.png`.
- **In-app UI** (splash, empty states, about screen) → tint `logo.svg` at runtime from a Compose color token so it follows theme changes.

## Generating per-platform icons from the master SVG

When it's time to wire up app icons for real (phase 1 foundation work in `:app:android` / `:app:ios` / `:app:desktop`), use a build-time generator rather than committing a huge icon set.

**Recommended tooling** (all run from the same `logo.svg` master):

- **Android**: the AGP KMP plugin supports resource generation from vector drawables directly; drop `logo.svg` into `:app:android/src/main/res/drawable/` as a vector drawable and declare it in `AndroidManifest.xml` as the app icon. Adaptive icon layers can reference the same vector.
- **iOS**: use a script that renders `logo.svg` at the 15-odd sizes iOS demands (`Icon-App-20x20@1x.png` through `Icon-App-1024x1024@1x.png`) and writes them into `:app:ios/iosApp/Assets.xcassets/AppIcon.appiconset/`. `rsvg-convert` + `sips` or `librsvg` in a Gradle task does this in ~1 second.
- **Desktop**: Compose Desktop's `compose.desktop.application.nativeDistributions` has per-OS `iconFile` settings. One `.png` per OS is enough; render from `logo.svg` at 1024×1024 at build time and feed into the `.icns` / `.ico` / `.png` fields.
- **Web**: favicon.ico + web-app-manifest icons. Both rendered at build time from `logo.svg`.

**Do NOT** commit a full icon set for each platform. It bloats the repo, duplicates the source of truth, and drifts from the master SVG whenever someone tweaks the mark.

## Using the logo in-app

In `:core:design-system` (once it exists), expose a single `CrispyLogo` composable that:

1. Loads `logo.svg` as a Compose MP `ImageVector` via the Compose Resources API
2. Accepts a tint color from the design-system color tokens (default = `colors.text.onSurface`)
3. Returns a `Painter` that can be used anywhere with a single call site

```kotlin
@Composable
fun CrispyLogo(
    modifier: Modifier = Modifier,
    tint: Color = LocalCrispyColors.current.text.onSurface,
) {
    Image(
        painter = painterResource(Res.drawable.logo),
        contentDescription = stringResource(Res.string.app_name),
        modifier = modifier,
        colorFilter = ColorFilter.tint(tint),
    )
}
```

Feature modules consume `CrispyLogo` — they never reach for the raw files in this directory.

## Updating the brand

If the mark ever changes:

1. Edit `logo.svg` only
2. Regenerate the four PNG variants from the new SVG (scripted — no manual PNG editing)
3. Bump the commit, trigger the per-platform icon regeneration in `:app:*` modules
4. Verify in each app bundle that the new icon shipped
5. Update this README if the palette or semantics change
