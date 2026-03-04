import { defineConfig, devices } from "@playwright/test";

/**
 * Playwright configuration for CrispyTivi Flutter web app.
 *
 * Viewport projects match the responsive breakpoints defined in
 * lib/core/widgets/responsive_layout.dart:
 *   compact:  < 600dp   (mobile)
 *   medium:   600-839dp (tablet)
 *   expanded: 840-1199dp (desktop)
 *   large:    >= 1200dp  (TV)
 *
 * The Flutter dev server runs at http://localhost:3000 via:
 *   flutter run -d chrome --web-port 3000
 */
export default defineConfig({
  testDir: "./tests",

  /* Maximum time a test can run (90s for Flutter CanvasKit). */
  timeout: 90_000,

  /* Expect assertions timeout. */
  expect: {
    timeout: 15_000,
  },

  /* Retry failed tests once. */
  retries: 1,

  /* Run tests sequentially — Flutter web shares a single server. */
  fullyParallel: false,

  /* Reporter: HTML report + console list. */
  reporter: [
    ["html", { outputFolder: "../reports/playwright-report" }],
    ["list"],
  ],

  /* Shared settings for all projects. */
  use: {
    /* Flutter web dev server URL. */
    baseURL: "http://127.0.0.1:3000",

    /* Capture screenshot on failure for debugging. */
    screenshot: "only-on-failure",

    /* Collect trace on first retry for post-mortem analysis. */
    trace: "on-first-retry",

    /* Keep video only on failure to save disk space. */
    video: "retain-on-failure",

    /* Increase action timeout for Flutter rendering delays. */
    actionTimeout: 15_000,

    /* Navigation timeout for Flutter CanvasKit WASM loading. */
    navigationTimeout: 60_000,
  },

  /* Viewport projects matching CrispyTivi breakpoints. */
  projects: [
    {
      name: "mobile",
      use: {
        viewport: { width: 360, height: 800 },
        userAgent:
          "Mozilla/5.0 (Linux; Android 13) " +
          "AppleWebKit/537.36 (KHTML, like Gecko) " +
          "Chrome/120.0.0.0 Mobile Safari/537.36",
      },
    },
    {
      name: "tablet",
      use: {
        viewport: { width: 840, height: 600 },
      },
    },
    {
      name: "desktop",
      use: {
        viewport: { width: 1280, height: 900 },
      },
    },
    {
      name: "tv",
      use: {
        viewport: { width: 1920, height: 1080 },
      },
    },
  ],
});
