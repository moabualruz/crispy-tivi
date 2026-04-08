import { test, expect, type Page } from "@playwright/test";
import * as path from "path";
import * as fs from "fs";
import { filterAppErrors } from "./helpers/error-filter";

/**
 * Live TV & EPG QA Crawl
 * Runs at desktop viewport (1280x900)
 */

const REPORT_DIR = path.join(__dirname, "..", "..", "reports");
const SS_DIR = path.join(REPORT_DIR, "screenshots", "livetv-crawl");

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
  guide: { x: 28, y: 260 },
};

const TV_LIST = {
  firstChannel: { x: 150, y: 200 }, // Approximate center of first channel in list
};

const GUIDE_GRID = {
  firstProgram: { x: 400, y: 200 }, // Approximate center of first program block
};

const PLAYER = {
  centerPlay: { x: 640, y: 450 }, // Center of 1280x900
};

test.describe("Live TV and Guide (EPG)", () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test("navigate and interact with Live Channels and EPG Guide", async ({
    page,
  }) => {
    page.on("console", (msg) => {
      const text = msg.text();
      log(`[console.${msg.type()}] ${text}`);
      if (msg.type() === "error") errors.push(text);
    });

    log("Starting Live TV E2E Test");
    await page.goto("/");

    // 1. Wait for flutter-view
    await page.waitForLoadState("domcontentloaded");
    await page.waitForSelector("flutter-view", { timeout: 30000 });
    await page.waitForTimeout(4000); // Let UI settle
    await ss(page, "01-initial-load");

    // 2. Click Live TV tab
    log("Clicking Live TV Tab");
    await page.mouse.click(NAV.liveTv.x, NAV.liveTv.y);
    await page.waitForTimeout(2000);
    await ss(page, "02-livetv-tab-loaded");

    // 3. Click the first channel
    log("Clicking first channel");
    await page.mouse.click(TV_LIST.firstChannel.x, TV_LIST.firstChannel.y);
    await page.waitForTimeout(2000); // Wait for stream to load
    await ss(page, "03-channel-playback");

    // Esc back to menu
    await page.keyboard.press("Escape");
    await page.waitForTimeout(1000);

    // 4. Click Guide (EPG) tab
    log("Clicking Guide Tab");
    await page.mouse.click(NAV.guide.x, NAV.guide.y);
    await page.waitForTimeout(3000); // EPG can take slightly longer to render grids
    await ss(page, "04-guide-tab-loaded");

    // 5. Navigate the Guide grid
    log("Clicking first program in Guide");
    await page.mouse.click(
      GUIDE_GRID.firstProgram.x,
      GUIDE_GRID.firstProgram.y,
    );
    await page.waitForTimeout(2000); // Typically launches the player immediately
    await ss(page, "05-guide-program-selected");

    // HUD trigger
    await page.mouse.click(PLAYER.centerPlay.x, PLAYER.centerPlay.y);
    await page.waitForTimeout(1000);
    await ss(page, "06-guide-player-hud-visible");

    // Output logs
    const content = [
      "# LiveTV Crawl Logs",
      `## Errors (${errors.length})`,
      ...errors.map((e) => `- ${e}`),
      "",
      "## Full Log",
      ...logs,
    ].join("\n");
    fs.writeFileSync(path.join(REPORT_DIR, "livetv-crawl-logs.txt"), content);

    // Filter out known external/network errors — only assert on real app bugs.
    const appErrors = filterAppErrors(errors);
    expect(appErrors).toHaveLength(0);
  });
});
