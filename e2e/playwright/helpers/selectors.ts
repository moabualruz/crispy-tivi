import { Page } from '@playwright/test';
import * as path from 'path';
import * as fs from 'fs';

// ─── Constants ───────────────────────────────────────────────
// Text labels matching Flutter widget content. These correspond
// to the labels in AppShell._destinations and
// ProfileSelectionScreen in the CrispyTivi codebase.

/** Navigation tab labels in AppShell display order. */
export const NAV_TABS = [
  'Home',
  'Search',
  'Live TV',
  'Guide',
  'Movies',
  'Series',
  'DVR',
  'Favorites',
  'Settings',
] as const;

/** Profile selection screen text. */
export const PROFILE_SCREEN = {
  title: "Who's watching?",
  addProfile: 'Add Profile',
  defaultProfile: 'Default',
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
 * Flutter CanvasKit renders to a `<canvas>` element. This
 * function waits for:
 * 1. DOM content loaded
 * 2. Canvas element visible (CanvasKit initialized)
 * 3. Additional settle time for widget tree rendering
 * 4. Semantics overlay activation (if available)
 *
 * After this returns, ARIA-based selectors (getByRole,
 * getByText) should work against Flutter's semantics tree.
 */
export async function waitForFlutterReady(
  page: Page,
): Promise<void> {
  // Wait for initial DOM content — don't use 'networkidle'
  // because Flutter web continuously fetches fonts/WASM.
  await page.waitForLoadState('domcontentloaded');

  // Wait for Flutter's CanvasKit to create the <canvas>.
  // Large viewports (e.g. 1920×1080 TV) render more widgets
  // and need extra time for CanvasKit to initialize.
  await page.waitForSelector('canvas', { timeout: 30_000 });

  // Allow time for the widget tree to render and settle.
  // Flutter web startup involves deferred loading, font
  // resolution, and Riverpod provider initialization.
  // Larger viewports need more settle time.
  const viewport = page.viewportSize();
  const settleMs =
    viewport != null && viewport.width >= 1920 ? 5000 : 3000;
  await page.waitForTimeout(settleMs);

  // Activate the Flutter semantics overlay. Flutter web
  // provides an "Enable accessibility" button that, when
  // clicked, creates a DOM-based semantics tree with ARIA
  // roles and labels. Without this, all content is trapped
  // inside the <canvas> and invisible to Playwright.
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
async function enableSemanticsOverlay(
  page: Page,
): Promise<void> {
  try {
    const accessBtn = page.getByRole('button', {
      name: 'Enable accessibility',
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
      state: 'visible',
      timeout: timeout / 2,
    });
    await textLocator.first().click({ timeout });
    return;
  } catch {
    // Text not found as visible — try button role.
  }

  // Strategy 2: Button with accessible name.
  const btnLocator = page.getByRole('button', { name: text });
  try {
    await btnLocator.first().waitFor({
      state: 'visible',
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
    `flt-semantics[aria-label*="${text}"], ` +
    `[aria-label*="${text}"]`,
  );
  try {
    await semanticsLocator.first().waitFor({
      state: 'attached',
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
  const timestamp = new Date()
    .toISOString()
    .replace(/[:.]/g, '-')
    .slice(0, 19);

  // Derive viewport label from page dimensions.
  const viewport = page.viewportSize();
  const vpLabel = viewport
    ? `${viewport.width}x${viewport.height}`
    : 'unknown';

  const filename = `${name}-${vpLabel}-${timestamp}.png`;
  const screenshotDir = path.join(
    __dirname,
    '..',
    '..',
    'reports',
    'screenshots',
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
 * Attempt to select the default profile on the profile
 * selection screen.
 *
 * This is a common prerequisite for tests that need to get
 * past the initial profile gate. If no "Default" profile
 * exists, it clicks the first visible profile tile.
 *
 * @returns true if a profile was selected, false otherwise
 */
export async function selectDefaultProfile(
  page: Page,
): Promise<boolean> {
  try {
    // Wait for the profile screen to appear.
    const profileTitle = page.getByText(PROFILE_SCREEN.title);
    await profileTitle.waitFor({
      state: 'visible',
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
    const anyProfile = page.locator(
      '[aria-label]:not([aria-label*="Add"])',
    );
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
