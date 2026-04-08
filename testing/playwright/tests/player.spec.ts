import { test, expect, type Page } from "@playwright/test";
import * as path from "path";
import * as fs from "fs";
import { filterAppErrors } from "./helpers/error-filter";

/**
 * Player & OSD QA Crawl
 * Runs at desktop viewport (1280x900)
 */

const REPORT_DIR = path.join(__dirname, "..", "..", "reports");
const SS_DIR = path.join(REPORT_DIR, "screenshots", "player-crawl");

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
  liveTv: { x: 28, y: 200 },
};

const TV_LIST = {
  firstChannel: { x: 150, y: 200 }, // Approximate center of first channel in list
};

// Player OSD Controls (Bottom Bar & Right Overlays)
const PLAYER_OSD = {
  centerFocus: { x: 640, y: 450 }, // Invokes HUD
  playPause: { x: 640, y: 800 }, // Central bottom
  subtitlesBtn: { x: 1150, y: 800 }, // Bottom right cluster
  audioBtn: { x: 1200, y: 800 },
  settingsBtn: { x: 1250, y: 800 },

  // Settings submenu overlay (typically right side of screen)
  submenuItem1: { x: 1100, y: 300 },
};

test.describe("Video Player and OSD", () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test("navigate to player and interact with OSD submenus", async ({
    page,
  }) => {
    page.on("console", (msg) => {
      const text = msg.text();
      log(`[console.${msg.type()}] ${text}`);
      if (msg.type() === "error") errors.push(text);
    });

    log("Starting Player E2E Test");
    await page.goto("/");

    // 1. Wait for flutter-view & start playback via LiveTV
    await page.waitForLoadState("domcontentloaded");
    await page.waitForSelector("flutter-view", { timeout: 30000 });
    await page.waitForTimeout(4000);

    log("Navigating to Live TV");
    await page.mouse.click(NAV.liveTv.x, NAV.liveTv.y);
    await page.waitForTimeout(2000);

    log("Clicking to start channel playback");
    await page.mouse.click(TV_LIST.firstChannel.x, TV_LIST.firstChannel.y);
    await page.waitForTimeout(3000); // Wait for initialization
    await ss(page, "01-player-loaded");

    // 2. Invoke HUD
    log("Invoking Player HUD");
    await page.mouse.click(PLAYER_OSD.centerFocus.x, PLAYER_OSD.centerFocus.y);
    await page.waitForTimeout(500);
    await ss(page, "02-player-hud-visible");

    // 3. Toggle Play/Pause
    log("Clicking Play/Pause");
    await page.mouse.click(PLAYER_OSD.playPause.x, PLAYER_OSD.playPause.y);
    await page.waitForTimeout(1000);
    await ss(page, "03-player-paused");

    // Restore HUD (sometimes it hides on activity)
    await page.mouse.click(PLAYER_OSD.centerFocus.x, PLAYER_OSD.centerFocus.y);
    await page.waitForTimeout(500);

    // 4. Open Audio Submenu
    log("Clicking Audio Submenu");
    await page.mouse.click(PLAYER_OSD.audioBtn.x, PLAYER_OSD.audioBtn.y);
    await page.waitForTimeout(1000);
    await ss(page, "04-audio-submenu-open");

    // Close submenu
    await page.keyboard.press("Escape");
    await page.waitForTimeout(500);

    // 5. Open Settings Submenu
    log("Clicking Player Settings (Overflow) Submenu");
    await page.mouse.click(PLAYER_OSD.centerFocus.x, PLAYER_OSD.centerFocus.y);
    await page.waitForTimeout(500);
    // Overflow menu is typically the second to last icon on Web
    await page.mouse.click(
      PLAYER_OSD.settingsBtn.x - 50,
      PLAYER_OSD.settingsBtn.y,
    );
    await page.waitForTimeout(1000);
    await ss(page, "05-settings-submenu-open");

    // Click inside the submenu (e.g. hitting the PiP button if available)
    log("Clicking inside Submenu item");
    await page.mouse.click(
      PLAYER_OSD.submenuItem1.x,
      PLAYER_OSD.submenuItem1.y,
    );
    await page.waitForTimeout(1000);
    await ss(page, "06-submenu-interaction");

    // Close submenu
    await page.keyboard.press("Escape");
    await page.waitForTimeout(500);

    // 6. Test Web HTML5 Fullscreen Parity
    log("Clicking Fullscreen Toggle");
    await page.mouse.click(PLAYER_OSD.centerFocus.x, PLAYER_OSD.centerFocus.y);
    await page.waitForTimeout(500);
    // Fullscreen is the rightmost button on the Web OSD (order: 6)
    await page.mouse.click(PLAYER_OSD.settingsBtn.x, PLAYER_OSD.settingsBtn.y);
    await page.waitForTimeout(1000);
    await ss(page, "07-fullscreen-toggled");

    // Output logs
    const content = [
      "# Player Crawl Logs",
      `## Errors (${errors.length})`,
      ...errors.map((e) => `- ${e}`),
      "",
      "## Full Log",
      ...logs,
    ].join("\n");
    fs.writeFileSync(path.join(REPORT_DIR, "player-crawl-logs.txt"), content);

    // Filter out known external/network errors — only assert on real app bugs.
    const appErrors = filterAppErrors(errors);
    expect(appErrors).toHaveLength(0);
  });
});
