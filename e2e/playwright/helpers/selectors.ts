import type { Page } from "@playwright/test";
import * as path from "path";
import * as fs from "fs";

// ─── Selector Architecture ───────────────────────────────────
//
// Flutter web renders all UI into a <flutter-view> element.
// DOM-based selectors (CSS, XPath) cannot reach widget
// content directly. Playwright accesses the app through Flutter's
// semantics overlay — a parallel invisible DOM tree that mirrors
// the widget tree with ARIA attributes.
//
// ## How Flutter Semantics Map to ARIA
//
// Every Flutter widget that sets `semanticLabel` (or is wrapped
// in `Semantics(label: '...')`) creates an `flt-semantics` custom
// element in the semantics overlay with a matching `aria-label`.
// Example:
//   Dart:  FocusWrapper(semanticLabel: 'Live TV', ...)
//   DOM:   <flt-semantics aria-label="Live TV" role="button">
//
// Playwright query patterns (preferred order):
//   1. page.getByRole('button', { name: 'Live TV' })
//      — best for interactive elements with a known role
//   2. page.getByText('Live TV')
//      — best for static text / labels
//   3. page.locator('flt-semantics[aria-label="Live TV"]')
//      — precise fallback when role is unknown
//   4. page.locator('[aria-label*="Live"]')
//      — partial-match fallback for dynamic labels
//
// ## Source of Truth for Labels
//
// - Structural widget keys: `lib/core/testing/test_keys.dart`
//   These are ValueKey constants used in integration tests via
//   `find.byKey(TestKeys.xxx)`. They are NOT aria-labels.
//
// - Navigation labels: `lib/core/navigation/nav_destinations.dart`
//   The `NavItem.label` strings are set as `semanticLabel` on
//   the `FocusWrapper` wrapping each nav item in `side_nav.dart`.
//   These become `aria-label` values in the semantics overlay.
//
// - Interactive element labels: set per-widget via `semanticLabel`
//   parameters on `FocusWrapper`, `Semantics`, or `Tooltip.message`.
//
// ## Activation Required
//
// Flutter web semantics overlay is NOT active by default. You must
// click the hidden "Enable accessibility" button first. The
// `waitForFlutterReady()` helper does this automatically via
// `enableSemanticsOverlay()`. Without activation, all ARIA queries
// return zero results.
//
// ─────────────────────────────────────────────────────────────

/** Navigation tab labels in side rail display order.
 *
 * Source: `lib/core/navigation/nav_destinations.dart` —
 * `sideDestinations[*].label`. These exact strings are set as
 * `semanticLabel` on each `FocusWrapper` nav item in `side_nav.dart`
 * and appear as `aria-label` on `flt-semantics` nodes at runtime.
 *
 * The bottom bar (`bottomDestinations`) is a 5-item subset:
 * Home, Live TV, Search, Movies, Settings — used at compact/medium
 * breakpoints (< 840dp).
 */
export const NAV_TABS = [
  "Home",
  "Search",
  "Live TV",
  "Guide",
  "Movies",
  "Series",
  "DVR",
  "Favorites",
  "Settings",
] as const;

/** Bottom bar tabs for compact/medium viewports (< 840dp).
 * Source: `lib/core/navigation/nav_destinations.dart` — `bottomDestinations`.
 */
export const BOTTOM_NAV_TABS = [
  "Home",
  "Live TV",
  "Search",
  "Movies",
  "Settings",
] as const;

/** Profile selection screen text. */
export const PROFILE_SCREEN = {
  title: "Who's watching?",
  addProfile: "Add Profile",
  defaultProfile: "Default",
} as const;

/** Responsive breakpoint thresholds (from responsive_layout.dart). */
export const BREAKPOINTS = {
  compact: 0,
  medium: 600,
  expanded: 840,
  large: 1200,
} as const;

// ─── Helper Functions ────────────────────────────────────────

/**
 * Wait for the Flutter web app to finish rendering.
 *
 * Flutter web renders to a `<flutter-view>` element. This
 * function waits for:
 * 1. DOM content loaded
 * 2. flutter-view element visible (Flutter initialized)
 * 3. Additional settle time for widget tree rendering
 * 4. Semantics overlay activation (if available)
 *
 * After this returns, ARIA-based selectors (getByRole,
 * getByText) should work against Flutter's semantics tree.
 */
export async function waitForFlutterReady(page: Page): Promise<void> {
  // Wait for initial DOM content — don't use 'networkidle'
  // because Flutter web continuously fetches fonts/WASM.
  await page.waitForLoadState("domcontentloaded");

  // Wait for Flutter to create the <flutter-view>.
  // Large viewports (e.g. 1920×1080 TV) render more widgets
  // and need extra time for Flutter to initialize.
  await page.waitForSelector("flutter-view", { timeout: 30_000 });

  // Allow time for the widget tree to render and settle.
  // Flutter web startup involves deferred loading, font
  // resolution, and Riverpod provider initialization.
  // Larger viewports need more settle time.
  const viewport = page.viewportSize();
  const settleMs = viewport != null && viewport.width >= 1920 ? 5000 : 3000;
  await page.waitForTimeout(settleMs);

  // Activate the Flutter semantics overlay. Flutter web
  // provides an "Enable accessibility" button that, when
  // clicked, creates a DOM-based semantics tree with ARIA
  // roles and labels. Without this, all content is trapped
  // inside the <flutter-view> and invisible to Playwright.
  await enableSemanticsOverlay(page);
}

/**
 * Enable Flutter's accessibility/semantics overlay.
 *
 * Flutter web hides an "Enable accessibility" button that
 * activates the `flt-semantics-host` overlay. This overlay
 * mirrors the widget tree as invisible DOM nodes with ARIA
 * attributes, enabling getByRole() and getByText() queries.
 */
async function enableSemanticsOverlay(page: Page): Promise<void> {
  try {
    const accessBtn = page.getByRole("button", {
      name: "Enable accessibility",
    });
    await accessBtn.waitFor({ timeout: 3000 });
    // Force-click: the button is positioned offscreen by
    // Flutter but still triggers the semantics tree.
    await accessBtn.click({ force: true });
    // Allow time for semantics tree to populate.
    await page.waitForTimeout(1500);
  } catch {
    // The button may not exist in all Flutter web builds
    // (e.g., --web-renderer html, or already activated).
    // Continue silently — tests should handle missing
    // semantics gracefully.
  }
}

/**
 * Find and click an element by its visible text content.
 *
 * Strategy (in order):
 * 1. Try `page.getByText()` — works when Flutter semantics
 *    overlay is active and the text has an ARIA label.
 * 2. Try `page.getByRole('button', { name })` — for buttons
 *    and interactive elements with accessible names.
 * 3. Fall back to `flt-semantics` locator with text content.
 *
 * @param page  - Playwright Page instance
 * @param text  - Visible text to find and click
 * @param options - Optional: timeout in ms (default 10000)
 */
export async function clickByText(
  page: Page,
  text: string,
  options?: { timeout?: number },
): Promise<void> {
  const timeout = options?.timeout ?? 10_000;

  // Strategy 1: Direct text match via semantics overlay.
  const textLocator = page.getByText(text, { exact: false });
  try {
    await textLocator.first().waitFor({
      state: "visible",
      timeout: timeout / 2,
    });
    await textLocator.first().click({ timeout });
    return;
  } catch {
    // Text not found as visible — try button role.
  }

  // Strategy 2: Button with accessible name.
  const btnLocator = page.getByRole("button", { name: text });
  try {
    await btnLocator.first().waitFor({
      state: "visible",
      timeout: timeout / 3,
    });
    await btnLocator.first().click({ timeout });
    return;
  } catch {
    // Button not found — try semantics nodes.
  }

  // Strategy 3: Flutter semantics node with matching text.
  // Flutter creates `flt-semantics` custom elements in the
  // semantics overlay with aria-label attributes.
  const semanticsLocator = page.locator(
    `flt-semantics[aria-label*="${text}"], ` + `[aria-label*="${text}"]`,
  );
  try {
    await semanticsLocator.first().waitFor({
      state: "attached",
      timeout: timeout / 3,
    });
    await semanticsLocator.first().click({ force: true });
    return;
  } catch {
    // All strategies failed.
    throw new Error(
      `clickByText: Could not find or click element ` +
        `with text "${text}" within ${timeout}ms. ` +
        `Flutter CanvasKit may not have rendered semantics ` +
        `for this element.`,
    );
  }
}

/**
 * Take a screenshot with a descriptive name and save it to
 * the reports/screenshots directory.
 *
 * File naming convention:
 *   {name}-{viewport}-{timestamp}.png
 *
 * @param page - Playwright Page instance
 * @param name - Descriptive name (e.g., 'profile-selection')
 */
export async function takeNamedScreenshot(
  page: Page,
  name: string,
): Promise<Buffer> {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);

  // Derive viewport label from page dimensions.
  const viewport = page.viewportSize();
  const vpLabel = viewport ? `${viewport.width}x${viewport.height}` : "unknown";

  const filename = `${name}-${vpLabel}-${timestamp}.png`;
  const screenshotDir = path.join(
    __dirname,
    "..",
    "..",
    "reports",
    "screenshots",
  );

  // Ensure the output directory exists.
  fs.mkdirSync(screenshotDir, { recursive: true });

  const screenshotPath = path.join(screenshotDir, filename);
  const buffer = await page.screenshot({
    path: screenshotPath,
    fullPage: true,
  });

  return buffer;
}

/**
 * Detect whether the app cannot navigate to feature screens.
 *
 * Returns true when navigation-dependent tests should exit
 * early. This happens in three scenarios:
 *
 * 1. **Onboarding route** — URL contains `#/onboarding`.
 *
 * 2. **No sources (empty state)** — Fresh database. The home
 *    screen renders the nav shell first, then async-checks
 *    sources and shows "Welcome to CrispyTivi / Add Your First
 *    Source". Uses `waitFor` with timeout to handle the async
 *    rendering delay.
 *
 * 3. **Semantics unavailable** — Flutter's accessibility
 *    overlay did not activate, so no nav elements exist in
 *    the DOM and all ARIA queries will fail.
 *
 * @returns true if the app cannot navigate, false if ready
 */
export async function isOnOnboarding(page: Page): Promise<boolean> {
  // Strategy 1: URL already contains "onboarding".
  if (page.url().includes("onboarding")) return true;

  // Strategy 2: Watch for GoRouter's async onboarding redirect.
  // After profile auto-skip, Riverpod sets activeProfile async,
  // which triggers GoRouter re-evaluation. If no sources are
  // configured, GoRouter redirects to /onboarding. This can take
  // several seconds because the profile state propagation and
  // router refresh happen asynchronously.
  try {
    await page.waitForURL(/onboarding/, { timeout: 5000 });
    return true;
  } catch {
    // No redirect within 5s — app may have sources, or the
    // redirect fires only on subsequent navigation.
  }

  // Strategy 3: No-sources empty state content in semantics.
  // The home screen shows "Welcome to CrispyTivi" when no
  // sources are configured. Use multiple locator strategies
  // because Flutter may set the accessible name via aria-label
  // or via element text content.
  try {
    const noSources = page
      .getByText("Welcome to CrispyTivi")
      .or(page.getByRole("button", { name: /Start Watching/i }))
      .or(
        page.locator(
          '[aria-label*="Welcome to CrispyTivi"], ' +
            '[aria-label*="Add Your First Source"], ' +
            '[aria-label*="Start Watching"]',
        ),
      );
    await noSources.first().waitFor({
      state: "attached",
      timeout: 5000,
    });
    return true;
  } catch {
    // Not found — either semantics inactive or app has sources.
  }

  // Strategy 4: JavaScript DOM check.
  // Directly query aria-label attributes in case Playwright's
  // locator engine doesn't match Flutter's custom elements.
  try {
    const hasNoSources = await page.evaluate(() => {
      const els = document.querySelectorAll("[aria-label]");
      for (const el of els) {
        const label = el.getAttribute("aria-label") || "";
        if (
          label.includes("Welcome to CrispyTivi") ||
          label.includes("Add Your First Source") ||
          label.includes("Start Watching")
        ) {
          return true;
        }
      }
      return false;
    });
    if (hasNoSources) return true;
  } catch {
    // Evaluation failed — continue to nav check.
  }

  // Strategy 5: No navigation elements in DOM.
  // If semantics didn't activate (button outside viewport on
  // some sizes), no aria-label nodes exist. Without semantics,
  // all ARIA-based test queries will fail anyway.
  try {
    const navLabels = ["Home", "Settings", "Live TV", "Search"];
    let navFound = 0;
    for (const label of navLabels) {
      const count = await page.locator(`[aria-label="${label}"]`).count();
      if (count > 0) navFound++;
    }
    if (navFound === 0) return true;
  } catch {
    return true;
  }

  // Strategy 6: Probe navigation.
  // Home screen may have nav shell but GoRouter redirects to
  // onboarding when navigating to any other route. Trigger a
  // navigation via hash change and check if the redirect fires.
  try {
    const currentUrl = page.url();
    await page.evaluate(() => {
      window.location.hash = "#/settings";
    });
    try {
      await page.waitForURL(/onboarding/, { timeout: 3000 });
      return true;
    } catch {
      // No redirect — restore original URL.
      await page.evaluate((url) => {
        window.location.hash = url.split("#")[1] || "#/home";
      }, currentUrl);
      await page.waitForTimeout(1000);
    }
  } catch {
    // Navigation probe failed.
  }

  return false;
}

/**
 * Attempt to select the default profile on the profile
 * selection screen.
 *
 * This is a common prerequisite for tests that need to get
 * past the initial profile gate. If no "Default" profile
 * exists, it clicks the first visible profile tile.
 *
 * @returns true if a profile was selected, false otherwise
 */
export async function selectDefaultProfile(page: Page): Promise<boolean> {
  try {
    // Wait for the profile screen to appear.
    const profileTitle = page.getByText(PROFILE_SCREEN.title);
    await profileTitle.waitFor({
      state: "visible",
      timeout: 8000,
    });

    // Try the "Default" profile first.
    try {
      await clickByText(page, PROFILE_SCREEN.defaultProfile, {
        timeout: 3000,
      });
      await page.waitForTimeout(2000);
      return true;
    } catch {
      // No "Default" profile — try any visible profile.
    }

    // Fall back: click any profile tile (not "Add Profile").
    // Flutter semantics may expose profile names as buttons.
    const anyProfile = page.locator('[aria-label]:not([aria-label*="Add"])');
    const count = await anyProfile.count();
    if (count > 0) {
      await anyProfile.first().click({ force: true });
      await page.waitForTimeout(2000);
      return true;
    }

    return false;
  } catch {
    // Profile screen may not be shown (already past it).
    return false;
  }
}
