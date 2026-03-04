import { test, expect, Page } from "@playwright/test";
import * as path from "path";
import * as fs from "fs";

/**
 * VOD & Media Servers QA Crawl
 * Runs at desktop viewport (1280x900)
 */

const REPORT_DIR = path.join(__dirname, "..", "..", "reports");
const SS_DIR = path.join(REPORT_DIR, "screenshots", "vod-crawl");

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
  movies: { x: 28, y: 320 },
  series: { x: 28, y: 380 },
};

// Assuming the first VOD poster card is horizontally offset by the rail + padding,
// and vertically positioned after the top app bar / hero image.
const VOD_LIST = {
  firstItem: { x: 300, y: 500 }, // Approximate center of first poster card in the first row
};

const PLAYER = {
  centerPlay: { x: 640, y: 450 }, // Center of 1280x900
};

test.describe("VOD and Media Servers", () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test("navigate and interact with VODs", async ({ page }) => {
    page.on("console", (msg) => {
      const text = msg.text();
      log(`[console.${msg.type()}] ${text}`);
      if (msg.type() === "error") errors.push(text);
    });

    log("Starting VOD E2E Test");
    await page.goto("/");

    // 1. Wait for canvas
    await page.waitForLoadState("domcontentloaded");
    await page.waitForSelector("canvas", { timeout: 30000 });
    await page.waitForTimeout(4000); // Let UI settle
    await ss(page, "01-initial-load");

    // 2. Click Movies tab
    log("Clicking Movies Tab");
    await page.mouse.click(NAV.movies.x, NAV.movies.y);
    await page.waitForTimeout(2000);
    await ss(page, "02-movies-tab-loaded");

    // 3. Hover the first VOD item (Netflix-style expansion)
    log("Hovering first VOD item");
    await page.mouse.move(VOD_LIST.firstItem.x, VOD_LIST.firstItem.y);
    await page.waitForTimeout(1000); // Wait for hover animation
    await ss(page, "03-movies-hover-preview");

    // 4. Click the first VOD item
    log("Clicking first VOD item");
    await page.mouse.click(VOD_LIST.firstItem.x, VOD_LIST.firstItem.y);
    await page.waitForTimeout(2000); // Wait for details/player screen to load
    await ss(page, "04-movies-detail-or-player");

    // If it opens a player, try clicking center to trigger HUD
    await page.mouse.click(PLAYER.centerPlay.x, PLAYER.centerPlay.y);
    await page.waitForTimeout(1000);
    await ss(page, "05-player-hud-visible");

    // Attempt to go back
    await page.keyboard.press("Escape");
    await page.waitForTimeout(1000);
    await ss(page, "06-back-pressed");

    // 5. Click Series tab
    log("Clicking Series Tab");
    await page.mouse.click(NAV.series.x, NAV.series.y);
    await page.waitForTimeout(2000);
    await ss(page, "07-series-tab-loaded");

    // Write logs
    const content = [
      "# VOD Crawl Logs",
      `## Errors (${errors.length})`,
      ...errors.map((e) => `- ${e}`),
      "",
      "## Full Log",
      ...logs,
    ].join("\n");
    fs.writeFileSync(path.join(REPORT_DIR, "vod-crawl-logs.txt"), content);

    // Expect no critical connection errors
    expect(
      errors.filter((e) => e.includes("ERR_CONNECTION_REFUSED")),
    ).toHaveLength(0);
  });
});
