import { test, expect, Page } from "@playwright/test";
import * as path from "path";
import * as fs from "fs";

/**
 * Manual QA crawl using coordinate-based clicking.
 *
 * Flutter web renders everything into a <flutter-view>,
 * so ARIA selectors don't work in release builds.
 * This test uses pixel coordinates determined from the
 * app's responsive layout.
 *
 * Desktop (1280x900) layout:
 * - Nav rail on left (~56px wide)
 * - Content area fills the rest
 * - Profile screen: centered cards
 */

const REPORT_DIR = path.join(__dirname, "..", "..", "reports");
const SS_DIR = path.join(REPORT_DIR, "screenshots", "manual-crawl");

const logs: string[] = [];
const errors: string[] = [];
const warnings: string[] = [];

function log(msg: string) {
  const ts = new Date().toISOString().slice(11, 23);
  logs.push(`[${ts}] ${msg}`);
}

let ssIdx = 0;
async function ss(page: Page, name: string) {
  ssIdx++;
  const idx = String(ssIdx).padStart(3, "0");
  const vp = page.viewportSize()!;
  const fn = `${idx}-${name}-${vp.width}x${vp.height}.png`;
  fs.mkdirSync(SS_DIR, { recursive: true });
  await page.screenshot({
    path: path.join(SS_DIR, fn),
    fullPage: true,
  });
  log(`Screenshot: ${fn}`);
  return fn;
}

function setupListeners(page: Page) {
  page.on("console", (msg) => {
    const type = msg.type();
    const text = msg.text();
    log(`[console.${type}] ${text}`);
    if (type === "error") errors.push(text);
    if (type === "warning") warnings.push(text);
  });
  page.on("pageerror", (err) => {
    log(`[PAGE_ERROR] ${err.message}`);
    errors.push(`[PAGE_ERROR] ${err.message}`);
  });
}

function writeLogs(viewport: { width: number; height: number } | null) {
  const content = [
    "# Manual Crawl Logs",
    `# Date: ${new Date().toISOString()}`,
    `# Viewport: ${viewport?.width}x${viewport?.height}`,
    "",
    `## Console Errors (${errors.length})`,
    ...errors.map((e) => `- ${e}`),
    "",
    `## Console Warnings (${warnings.length})`,
    ...warnings.map((w) => `- ${w}`),
    "",
    "## Full Log",
    ...logs,
  ].join("\n");
  fs.mkdirSync(REPORT_DIR, { recursive: true });
  fs.writeFileSync(path.join(REPORT_DIR, "manual-crawl-logs.txt"), content);
}

// Desktop layout coordinates (1280x900)
// Nav rail: x=28 (center of 56px rail)
// Nav rail tabs (approx y positions):
// 1. Home      y=80
// 2. Search    y=140
// 3. Live TV   y=200
// 4. Guide     y=260
// 5. Movies    y=320
// 6. Series    y=380
// 7. DVR       y=440
// 8. Favorites y=500
// 9. Settings  y=560
const NAV = {
  home: { x: 28, y: 80 },
  tv: { x: 28, y: 200 },
  guide: { x: 28, y: 260 },
  vods: { x: 28, y: 320 }, // Maps to Movies
  series: { x: 28, y: 380 },
  settings: { x: 28, y: 560 },
};

// Profile selection: Default card center
const PROFILE_DEFAULT = { x: 590, y: 460 };

test.describe("Manual QA Crawl", () => {
  test.setTimeout(300_000);

  test("desktop crawl", async ({ page }) => {
    setupListeners(page);

    // ── Load ────────────────────────────────────
    log("=== LOAD ===");
    await page.goto("/");
    await page.waitForSelector("flutter-view", {
      timeout: 30_000,
    });
    // Wait for Flutter to render
    await page.waitForTimeout(5000);
    await ss(page, "01-app-loaded");

    // ── Profile Selection ───────────────────────
    log("=== PROFILE SELECTION ===");
    await ss(page, "02-profile-screen");

    // Click "Default" profile card by coordinates
    await page.mouse.click(PROFILE_DEFAULT.x, PROFILE_DEFAULT.y);
    log("Clicked Default profile at coords");
    await page.waitForTimeout(3000);
    await ss(page, "03-after-profile-click");

    // Try Enter key as additional attempt
    await page.keyboard.press("Enter");
    await page.waitForTimeout(2000);

    // Try Tab+Enter as fallback
    await page.keyboard.press("Tab");
    await page.waitForTimeout(300);
    await page.keyboard.press("Enter");
    await page.waitForTimeout(3000);
    await ss(page, "04-post-profile-state");

    // ── Home Screen ─────────────────────────────
    log("=== HOME SCREEN ===");
    await ss(page, "05-home-screen");

    // ── Navigate to TV ──────────────────────────
    log("=== NAV: TV ===");
    await page.mouse.click(NAV.tv.x, NAV.tv.y);
    await page.waitForTimeout(2000);
    await ss(page, "06-tv-screen");

    // Try interacting with TV screen — scroll down
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(1000);
    await ss(page, "07-tv-scrolled");

    // ── Navigate to Guide/EPG ───────────────────
    log("=== NAV: GUIDE ===");
    await page.mouse.click(NAV.guide.x, NAV.guide.y);
    await page.waitForTimeout(2000);
    await ss(page, "08-epg-screen");

    // Check EPG filter toggle (top-right area)
    // The new filter icon should be in the app bar
    // App bar actions are typically at x=1200+, y=30
    await page.mouse.click(1180, 30);
    await page.waitForTimeout(1500);
    await ss(page, "09-epg-filter-toggle");

    // ── Navigate to VODs ────────────────────────
    log("=== NAV: VODS ===");
    await page.mouse.click(NAV.vods.x, NAV.vods.y);
    await page.waitForTimeout(2000);
    await ss(page, "10-vods-screen");

    // Try Movies tab (if visible)
    // Tab bar would be below app bar, ~y=100
    await page.mouse.click(200, 100);
    await page.waitForTimeout(1500);
    await ss(page, "11-vods-movies");

    // Try Series tab (next tab)
    await page.mouse.click(350, 100);
    await page.waitForTimeout(1500);
    await ss(page, "12-vods-series");

    // ── Navigate to Settings ────────────────────
    log("=== NAV: SETTINGS ===");
    await page.mouse.click(NAV.settings.x, NAV.settings.y);
    await page.waitForTimeout(2000);
    await ss(page, "13-settings-screen");

    // Scroll through settings
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(1000);
    await ss(page, "14-settings-scrolled");

    // Click various settings items (centered in
    // content area, stacked vertically)
    const settingsX = 640;
    for (let y = 200; y <= 700; y += 80) {
      await page.mouse.click(settingsX, y);
      await page.waitForTimeout(1000);
      await ss(page, `15-settings-item-y${y}`);
      // Press Escape to close any dialog
      await page.keyboard.press("Escape");
      await page.waitForTimeout(500);
    }

    // ── Navigate back to Home ───────────────────
    log("=== NAV: HOME (return) ===");
    await page.mouse.click(NAV.home.x, NAV.home.y);
    await page.waitForTimeout(2000);
    await ss(page, "20-home-return");

    // ── Keyboard Navigation Test ────────────────
    log("=== KEYBOARD NAV ===");

    // Test Tab key navigation
    for (let i = 0; i < 15; i++) {
      await page.keyboard.press("Tab");
      await page.waitForTimeout(200);
    }
    await ss(page, "21-tab-nav");

    // Test arrow key navigation
    for (let i = 0; i < 5; i++) {
      await page.keyboard.press("ArrowDown");
      await page.waitForTimeout(200);
    }
    await ss(page, "22-arrow-nav");

    // Test Enter on focused element
    await page.keyboard.press("Enter");
    await page.waitForTimeout(2000);
    await ss(page, "23-enter-press");

    // Press Escape
    await page.keyboard.press("Escape");
    await page.waitForTimeout(1000);
    await ss(page, "24-after-escape");

    // ── Right-click / Long-press test ───────────
    log("=== CONTEXT MENU ===");

    // Navigate to TV
    await page.mouse.click(NAV.tv.x, NAV.tv.y);
    await page.waitForTimeout(2000);

    // Try right-click in the content area
    await page.mouse.click(640, 400, { button: "right" });
    await page.waitForTimeout(1500);
    await ss(page, "25-right-click-tv");

    // Try long-press (mousedown, wait, mouseup)
    await page.mouse.move(640, 300);
    await page.mouse.down();
    await page.waitForTimeout(1000);
    await page.mouse.up();
    await page.waitForTimeout(1500);
    await ss(page, "26-long-press-tv");

    // ── Resize tests ────────────────────────────
    log("=== RESPONSIVE ===");

    // Mobile viewport
    await page.setViewportSize({ width: 360, height: 800 });
    await page.waitForTimeout(2000);
    await ss(page, "30-mobile-viewport");

    // Tablet viewport
    await page.setViewportSize({ width: 840, height: 600 });
    await page.waitForTimeout(2000);
    await ss(page, "31-tablet-viewport");

    // TV viewport
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.waitForTimeout(2000);
    await ss(page, "32-tv-viewport");

    // Back to desktop
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.waitForTimeout(2000);
    await ss(page, "33-back-to-desktop");

    // ── Final ───────────────────────────────────
    log("=== FINAL ===");
    log(`Total errors: ${errors.length}`);
    log(`Total warnings: ${warnings.length}`);

    writeLogs(page.viewportSize());
  });
});
