import { test, expect, type Page } from "@playwright/test";
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

import {
  waitForFlutterReady,
  clickByText,
  selectDefaultProfile,
  takeNamedScreenshot,
} from "../helpers/selectors";
import { filterAppErrors } from "./helpers/error-filter";

const DB_PATH =
  process.env.CRISPY_DB_PATH ??
  "/home/mkh/.crispytivi/data/crispy_tivi_v2.sqlite";

const REPORT_DIR = path.join(__dirname, "..", "..", "reports");
const NAV_COORDS: Record<string, [number, number]> = {
  Home: [28, 80],
  Search: [28, 140],
  "Live TV": [28, 200],
  Guide: [28, 260],
  Movies: [28, 320],
  Series: [28, 380],
  DVR: [28, 440],
  Favorites: [28, 500],
  Settings: [28, 560],
};

function sqlValue(sql: string): string {
  return execFileSync("sqlite3", [DB_PATH, sql], { encoding: "utf8" }).trim();
}

function firstSearchToken(value: string): string {
  const token =
    value
      .split(/\s+/)
      .map((part) => part.replace(/[()]/g, "").trim())
      .find((part) => part.length >= 3) ?? value.trim();
  return token;
}

async function navigateTo(page: Page, tab: string): Promise<void> {
  try {
    await clickByText(page, tab, { timeout: 10_000 });
  } catch {
    const coords = NAV_COORDS[tab];
    if (!coords) throw new Error(`No fallback coordinates for tab ${tab}`);
    await page.mouse.click(coords[0], coords[1]);
  }
  await page.waitForTimeout(2500);
}

async function findSearchField(page: Page) {
  try {
    const field = page.getByRole("textbox").first();
    await field.waitFor({ state: "visible", timeout: 5000 });
    return field;
  } catch {
    return page.locator('input, textarea, [aria-label*="Search"]').first();
  }
}

test.describe("Real Source Smoke", () => {
  test.setTimeout(240_000);

  test("guide, movies, series, search, and core navigation stay healthy", async ({
    page,
  }) => {
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    const logLines: string[] = [];

    const movieTitle = sqlValue(
      "select name from db_movies where vod_type='movie' order by added_at desc limit 1;",
    );
    const seriesTitle = sqlValue(
      "select name from db_movies where vod_type='series' order by added_at desc limit 1;",
    );
    const searchToken = firstSearchToken(movieTitle);

    const log = (msg: string) => {
      const ts = new Date().toISOString().slice(11, 23);
      logLines.push(`[${ts}] ${msg}`);
    };

    page.on("console", (msg) => {
      const text = msg.text();
      log(`[console.${msg.type()}] ${text}`);
      if (msg.type() === "error") {
        consoleErrors.push(text);
      }
    });

    page.on("pageerror", (err) => {
      log(`[pageerror] ${err.message}`);
      pageErrors.push(err.message);
    });

    await page.goto("/");
    await waitForFlutterReady(page);
    await selectDefaultProfile(page);
    await page.waitForTimeout(2500);
    await takeNamedScreenshot(page, "real-smoke-home");

    log(`Using movie title: ${movieTitle}`);
    log(`Using series title: ${seriesTitle}`);
    log(`Using search token: ${searchToken}`);

    await navigateTo(page, "Live TV");
    await takeNamedScreenshot(page, "real-smoke-live-tv");

    await navigateTo(page, "Guide");
    await takeNamedScreenshot(page, "real-smoke-guide");

    const guideFilterButton = page.getByRole("button", {
      name: /Showing all channels|Showing EPG channels only/i,
    });
    const guideFilterStart = Date.now();
    try {
      await guideFilterButton.click({ timeout: 10_000 });
    } catch {
      await page.mouse.click(780, 46);
    }
    await page.waitForTimeout(2500);
    log(`Guide filter toggle settled in ${Date.now() - guideFilterStart}ms`);
    await takeNamedScreenshot(page, "real-smoke-guide-filtered");

    // After toggling the expensive EPG-only filter, the app must still
    // respond to a normal route change quickly.
    await navigateTo(page, "Movies");
    const moviesShot = await takeNamedScreenshot(page, "real-smoke-movies");
    expect(moviesShot.length).toBeGreaterThan(100_000);

    await navigateTo(page, "Series");
    const seriesShot = await takeNamedScreenshot(page, "real-smoke-series");
    expect(seriesShot.length).toBeGreaterThan(100_000);

    const seriesInfoResponse = page.waitForResponse(
      (response) =>
        response.url().includes("get_series_info") &&
        response.url().includes("/proxy?url="),
      { timeout: 20_000 },
    );
    try {
      await page.getByText(seriesTitle, { exact: false }).first().click({
        timeout: 5000,
      });
    } catch {
      await page.mouse.click(460, 420);
    }
    const detailResponse = await seriesInfoResponse;
    log(`Series detail response: ${detailResponse.status()} ${detailResponse.url()}`);
    expect(detailResponse.status()).toBe(200);
    await page.waitForTimeout(5000);
    expect(await page.getByText("Failed to load episodes").count()).toBe(0);
    expect(await page.getByText("Retry").count()).toBe(0);
    await takeNamedScreenshot(page, "real-smoke-series-detail");

    await navigateTo(page, "Search");
    const searchField = await findSearchField(page);
    try {
      await searchField.click({ timeout: 10_000 });
      await searchField.fill(searchToken);
    } catch {
      await page.mouse.click(640, 200);
      await page.keyboard.type(searchToken);
    }
    await page.waitForTimeout(3000);
    expect(await page.getByText(/Search failed:/i).count()).toBe(0);
    const searchShot = await takeNamedScreenshot(page, "real-smoke-search");
    expect(searchShot.length).toBeGreaterThan(20_000);

    await navigateTo(page, "Favorites");
    await takeNamedScreenshot(page, "real-smoke-favorites");

    await navigateTo(page, "Settings");
    await takeNamedScreenshot(page, "real-smoke-settings");

    fs.mkdirSync(REPORT_DIR, { recursive: true });
    fs.writeFileSync(
      path.join(REPORT_DIR, "real-source-smoke.log"),
      logLines.join("\n"),
    );

    const filteredConsoleErrors = filterAppErrors(consoleErrors);
    const filteredPageErrors = pageErrors.filter(
      (msg) =>
        msg !== "Error" &&
        !msg.includes("Cannot read properties of null (reading 'toString')"),
    );

    expect(filteredConsoleErrors, `Console errors: ${filteredConsoleErrors.join("\n")}`).toEqual(
      [],
    );
    expect(filteredPageErrors, `Page errors: ${filteredPageErrors.join("\n")}`).toEqual([]);
  });
});
