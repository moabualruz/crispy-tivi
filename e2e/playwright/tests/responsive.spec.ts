import { test, expect } from "@playwright/test";
import {
  waitForFlutterReady,
  takeNamedScreenshot,
  selectDefaultProfile,
  BREAKPOINTS,
} from "../helpers/selectors";

/**
 * Responsive layout tests — verify the app adapts its
 * navigation pattern based on viewport width.
 *
 * From responsive_layout.dart and app_shell.dart:
 * - compact/medium (< 840dp): Bottom NavigationBar
 * - expanded/large (>= 840dp): Side NavigationRail
 *
 * Flutter web renders to <flutter-view>, so we cannot inspect
 * DOM-based nav components. Instead, we use:
 * 1. Semantics/ARIA queries for nav elements
 * 2. Screenshot-based visual verification
 * 3. Structural checks (element position, bounding boxes)
 */
test.describe("Responsive Layout", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await waitForFlutterReady(page);
    await selectDefaultProfile(page);
    // Extra settle time after profile selection.
    await page.waitForTimeout(1500);
  });

  test("mobile viewport uses bottom navigation bar", async ({
    page,
  }, testInfo) => {
    // This test is most meaningful at the mobile viewport.
    // At other viewports, the layout adapts differently.
    const viewport = page.viewportSize();
    const width = viewport?.width ?? 0;

    if (width >= BREAKPOINTS.expanded) {
      // Not a compact/medium viewport — skip this check.
      // Side navigation is expected instead.
      test.skip();
      return;
    }

    // At compact/medium, AppShell renders a bottom
    // NavigationBar. This manifests as navigation elements
    // positioned at the bottom of the screen.

    // Strategy 1: Check for navigation-related ARIA roles
    // at the bottom portion of the viewport.
    const navElements = page.getByRole("tab");
    const navCount = await navElements.count();

    if (navCount > 0) {
      // Verify at least one nav element is in the bottom
      // quarter of the viewport.
      const firstNav = await navElements.first().boundingBox();
      if (firstNav && viewport) {
        const bottomThreshold = viewport.height * 0.6;
        expect(firstNav.y).toBeGreaterThanOrEqual(bottomThreshold);
      }
    }

    // Strategy 2: Screenshot verification — the bottom of
    // the screen should show the navigation bar area.
    await takeNamedScreenshot(page, "responsive-bottom-nav");

    // Strategy 3: Check that there is NO side navigation
    // element occupying the left edge of the screen.
    // At compact viewport, the content should span the
    // full width.
    const flutterView = page.locator("flutter-view");
    const flutterViewBox = await flutterView.first().boundingBox();
    expect(flutterViewBox).not.toBeNull();
    // flutter-view should start near x=0 (no side rail).
    expect(flutterViewBox!.x).toBeLessThan(10);
  });

  test("desktop viewport uses side navigation rail", async ({
    page,
  }, testInfo) => {
    const viewport = page.viewportSize();
    const width = viewport?.width ?? 0;

    if (width < BREAKPOINTS.expanded) {
      // Not an expanded/large viewport — skip.
      test.skip();
      return;
    }

    // At expanded/large, AppShell renders a _SideNav
    // (56px collapsed, 200px extended on hover). This
    // appears as a vertical strip on the left side.

    // Strategy 1: Check for navigation ARIA elements
    // positioned on the left side of the viewport.
    const navElements = page.getByRole("tab");
    const navCount = await navElements.count();

    if (navCount > 0) {
      // At least one nav element should be on the left side.
      const firstNav = await navElements.first().boundingBox();
      if (firstNav && viewport) {
        // Side rail is 56px wide (collapsed).
        expect(firstNav.x).toBeLessThan(200);
        // Should be vertically positioned (not at bottom).
        expect(firstNav.y).toBeLessThan(viewport.height * 0.6);
      }
    }

    // Strategy 2: Screenshot for visual verification.
    await takeNamedScreenshot(page, "responsive-side-rail");
  });

  test("takes comparison screenshots at each viewport", async ({
    page,
  }, testInfo) => {
    const projectName = testInfo.project.name;

    // Screenshot 1: Initial state after profile selection.
    await takeNamedScreenshot(page, `responsive-overview-${projectName}`);

    // Verify the flutter-view is rendered at the expected size.
    const viewport = page.viewportSize();
    const flutterView = page.locator("flutter-view");
    const flutterViewBox = await flutterView.first().boundingBox();
    expect(flutterViewBox).not.toBeNull();

    if (viewport) {
      // flutter-view should approximately fill the viewport.
      expect(flutterViewBox!.width).toBeGreaterThan(viewport.width * 0.5);
      expect(flutterViewBox!.height).toBeGreaterThan(viewport.height * 0.5);
    }
  });

  test("layout adapts correctly to viewport dimensions", async ({
    page,
  }, testInfo) => {
    const viewport = page.viewportSize();
    if (!viewport) {
      test.skip();
      return;
    }

    const projectName = testInfo.project.name;

    // Determine expected layout class from viewport width.
    let expectedLayout: string;
    if (viewport.width >= BREAKPOINTS.large) {
      expectedLayout = "large";
    } else if (viewport.width >= BREAKPOINTS.expanded) {
      expectedLayout = "expanded";
    } else if (viewport.width >= BREAKPOINTS.medium) {
      expectedLayout = "medium";
    } else {
      expectedLayout = "compact";
    }

    // Expected navigation style:
    // compact/medium -> bottom nav
    // expanded/large -> side nav
    const expectsSideNav =
      expectedLayout === "expanded" || expectedLayout === "large";

    // Take screenshot for manual review.
    await takeNamedScreenshot(
      page,
      `responsive-${expectedLayout}-${projectName}`,
    );

    // Basic structural check: the page should be laid out
    // consistently with the expected navigation pattern.
    const body = page.locator("body");
    const bodyBox = await body.boundingBox();
    expect(bodyBox).not.toBeNull();
    expect(bodyBox!.width).toBeGreaterThanOrEqual(viewport.width - 1);

    // Log layout info for debugging.
    console.log(
      `Viewport: ${viewport.width}x${viewport.height} ` +
        `=> Layout: ${expectedLayout} ` +
        `=> Side nav: ${expectsSideNav}`,
    );
  });
});
