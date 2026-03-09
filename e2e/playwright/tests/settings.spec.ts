import { test, expect, Page } from "@playwright/test";
import * as path from "path";
import * as fs from "fs";
import { filterAppErrors } from "./helpers/error-filter";

/**
 * Settings & Submenu Configuration QA Crawl
 * Runs at desktop viewport (1280x900)
 */

const REPORT_DIR = path.join(__dirname, "..", "..", "reports");
const SS_DIR = path.join(REPORT_DIR, "screenshots", "settings-crawl");

const logs: string[] = [];
const errors: string[] = [];

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

// Coordinates based on 1280x900 desktop layout
const NAV = {
  settings: { x: 28, y: 560 }, // Bottom of rail
};

// Settings Screen Structure (Vertical List usually)
const SETTINGS_MENU = {
  general: { x: 300, y: 150 },
  player: { x: 300, y: 250 },
  stream: { x: 300, y: 350 },

  // Example sub-items inside expanded menus
  toggleSwitch: { x: 800, y: 250 }, // Generic position for a right-aligned toggle switch
};

test.describe("Settings Configurations", () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test("navigate and manipulate settings submenus", async ({ page }) => {
    page.on("console", (msg) => {
      const text = msg.text();
      log(`[console.${msg.type()}] ${text}`);
      if (msg.type() === "error") errors.push(text);
    });

    log("Starting Settings E2E Test");
    await page.goto("/");

    // 1. Wait for flutter-view
    await page.waitForLoadState("domcontentloaded");
    await page.waitForSelector("flutter-view", { timeout: 30000 });
    await page.waitForTimeout(4000);
    await ss(page, "01-initial-load");

    // 2. Open Settings Tab
    log("Clicking Settings Tab");
    await page.mouse.click(NAV.settings.x, NAV.settings.y);
    await page.waitForTimeout(2000);
    await ss(page, "02-settings-loaded");

    // 3. Open Player Settings Submenu
    log("Clicking Player Settings Category");
    await page.mouse.click(SETTINGS_MENU.player.x, SETTINGS_MENU.player.y);
    await page.waitForTimeout(1000); // Allow animation or page transition
    await ss(page, "03-player-settings-submenu");

    // 4. Try interacting with a toggle switch (Hardware Decoding)
    log("Toggling a switch in Player settings");
    await page.mouse.click(
      SETTINGS_MENU.toggleSwitch.x,
      SETTINGS_MENU.toggleSwitch.y,
    );
    await page.waitForTimeout(1000);
    await ss(page, "04-player-setting-toggled");

    // 5. Open Stream Settings Submenu
    log("Switching to Stream Settings Category");
    await page.mouse.click(SETTINGS_MENU.stream.x, SETTINGS_MENU.stream.y);
    await page.waitForTimeout(1000);
    await ss(page, "05-stream-settings-submenu");

    // Write logs
    const content = [
      "# Settings Crawl Logs",
      `## Errors (${errors.length})`,
      ...errors.map((e) => `- ${e}`),
      "",
      "## Full Log",
      ...logs,
    ].join("\n");
    fs.writeFileSync(path.join(REPORT_DIR, "settings-crawl-logs.txt"), content);

    // Filter out known external/network errors — only assert on real app bugs.
    const appErrors = filterAppErrors(errors);
    expect(appErrors).toHaveLength(0);
  });
});
