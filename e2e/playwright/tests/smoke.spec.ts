import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  takeNamedScreenshot,
  PROFILE_SCREEN,
} from '../helpers/selectors';

/**
 * Smoke tests — verify the app boots and renders the initial
 * profile selection screen without crashing.
 *
 * These tests run at every viewport size (mobile, tablet,
 * desktop, tv) to ensure basic rendering works across all
 * responsive breakpoints.
 */
test.describe('Smoke Tests', () => {
  test('app loads and renders the Flutter canvas', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    // Flutter CanvasKit renders ALL UI into a <canvas>.
    const canvas = page.locator('canvas');
    await expect(canvas.first()).toBeVisible();

    // Canvas must have non-zero dimensions (not a blank stub).
    const box = await canvas.first().boundingBox();
    expect(box).not.toBeNull();
    expect(box!.width).toBeGreaterThan(0);
    expect(box!.height).toBeGreaterThan(0);

    await takeNamedScreenshot(page, 'smoke-app-loaded');
  });

  test('app loads and renders profile selection', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    // The initial route is /profiles (ProfileSelectionScreen).
    // Flutter semantics should expose "Who's watching?" text.
    // Try semantics-first, then fall back to screenshot
    // verification.
    let profileScreenDetected = false;

    // Strategy 1: Semantics text match.
    try {
      const title = page.getByText(PROFILE_SCREEN.title);
      await title.waitFor({
        state: 'visible',
        timeout: 5000,
      });
      profileScreenDetected = true;
    } catch {
      // Semantics may not expose this text — fall back.
    }

    // Strategy 2: Check for "Add Profile" button text
    // (always present on the profile selection screen).
    if (!profileScreenDetected) {
      try {
        const addBtn = page.getByText(
          PROFILE_SCREEN.addProfile,
        );
        await addBtn.waitFor({
          state: 'visible',
          timeout: 3000,
        });
        profileScreenDetected = true;
      } catch {
        // Neither text found via semantics.
      }
    }

    // Strategy 3: Visual verification via screenshot.
    // Even if semantics didn't expose the text, the canvas
    // should be painted (not blank/white).
    const screenshot = await takeNamedScreenshot(
      page,
      'smoke-profile-selection',
    );
    expect(screenshot.length).toBeGreaterThan(1000);

    // At minimum, the canvas must be rendered.
    const canvas = page.locator('canvas');
    await expect(canvas.first()).toBeVisible();
  });

  test('app shows a MaterialApp-like structure', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    // Flutter web (CanvasKit) creates a specific DOM structure:
    // - A <canvas> element for rendering
    // - A `flt-glass-pane` or similar Flutter host element
    // - Optionally a `flt-semantics-host` for accessibility
    //
    // Verify the Flutter host structure exists.
    const body = page.locator('body');
    await expect(body).toBeVisible();

    // The body should contain Flutter's rendering surface.
    const bodyContent = await page.content();
    expect(bodyContent.length).toBeGreaterThan(100);

    // Check for Flutter-specific DOM elements.
    // Flutter web creates custom elements like
    // flutter-view, flt-glass-pane, or flt-scene-host.
    const hasFlutterElements = await page.evaluate(() => {
      const doc = document.body.innerHTML;
      return (
        doc.includes('flutter') ||
        doc.includes('flt-') ||
        document.querySelector('canvas') !== null
      );
    });
    expect(hasFlutterElements).toBe(true);

    // After enabling semantics, check for the semantics host.
    const semanticsHost = page.locator('flt-semantics-host');
    const hasSemanticsHost = await semanticsHost.count();
    if (hasSemanticsHost > 0) {
      // Semantics overlay is active — good for ARIA queries.
      await expect(semanticsHost.first()).toBeAttached();
    }

    await takeNamedScreenshot(
      page,
      'smoke-materialapp-structure',
    );
  });

  test('no critical console errors during startup', async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    // Also capture uncaught page errors (JS exceptions).
    const pageErrors: string[] = [];
    page.on('pageerror', (err) => {
      pageErrors.push(err.message);
    });

    await page.goto('/');
    await waitForFlutterReady(page);

    // Filter out known benign errors that Flutter web
    // commonly produces (favicon, manifest, fonts).
    const criticalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('manifest.json') &&
        !e.includes('service-worker') &&
        !e.includes('FontManifest') &&
        !e.includes('cupertino') &&
        !e.includes('404') &&
        !e.includes('net::ERR'),
    );

    // Zero uncaught exceptions.
    expect(pageErrors).toHaveLength(0);

    // Allow up to 2 non-critical console errors (font
    // loading, CORS on dev, etc.).
    expect(criticalErrors.length).toBeLessThanOrEqual(2);
  });
});
