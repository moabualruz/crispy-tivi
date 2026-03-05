import { test, expect, Page } from '@playwright/test';
import {
  waitForFlutterReady,
  takeNamedScreenshot,
  clickByText,
  selectDefaultProfile,
  NAV_TABS,
} from '../helpers/selectors';
import * as path from 'path';
import * as fs from 'fs';

/**
 * Comprehensive QA crawl — navigates every screen,
 * captures screenshots, logs console messages, and
 * records errors for analysis.
 *
 * Runs at desktop viewport (1280x900) for maximum
 * coverage of sidebar + content area.
 */

const LOG_DIR = path.join(
  __dirname, '..', '..', 'reports',
);
const SCREENSHOT_DIR = path.join(
  LOG_DIR, 'screenshots', 'crawl',
);

// Collect all logs and errors globally
const allLogs: string[] = [];
const allErrors: string[] = [];
const allWarnings: string[] = [];

function logMsg(msg: string) {
  const ts = new Date().toISOString().slice(11, 23);
  allLogs.push(`[${ts}] ${msg}`);
}

/**
 * Setup console and error listeners on a page.
 */
function setupListeners(page: Page) {
  page.on('console', (msg) => {
    const type = msg.type();
    const text = msg.text();
    logMsg(`[console.${type}] ${text}`);
    if (type === 'error') {
      allErrors.push(text);
    }
    if (type === 'warning') {
      allWarnings.push(text);
    }
  });

  page.on('pageerror', (err) => {
    const msg = `[PAGE_ERROR] ${err.message}`;
    logMsg(msg);
    allErrors.push(msg);
  });
}

/**
 * Save a screenshot with sequential naming.
 */
let screenshotIndex = 0;
async function screenshot(
  page: Page,
  name: string,
): Promise<string> {
  screenshotIndex++;
  const idx = String(screenshotIndex).padStart(3, '0');
  const viewport = page.viewportSize();
  const vpLabel = viewport
    ? `${viewport.width}x${viewport.height}`
    : 'unknown';
  const filename = `${idx}-${name}-${vpLabel}.png`;
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
  const filepath = path.join(SCREENSHOT_DIR, filename);
  await page.screenshot({ path: filepath, fullPage: true });
  logMsg(`Screenshot: ${filename}`);
  return filepath;
}

/**
 * Try clicking text, return true if successful.
 */
async function tryClick(
  page: Page,
  text: string,
  timeoutMs = 5000,
): Promise<boolean> {
  try {
    await clickByText(page, text, { timeout: timeoutMs });
    await page.waitForTimeout(1500);
    return true;
  } catch {
    logMsg(`Click failed: "${text}"`);
    return false;
  }
}

/**
 * Try clicking by aria-label.
 */
async function tryClickAria(
  page: Page,
  label: string,
  timeoutMs = 5000,
): Promise<boolean> {
  try {
    const loc = page.locator(
      `[aria-label="${label}"], ` +
      `flt-semantics[aria-label="${label}"]`,
    );
    await loc.first().waitFor({
      state: 'attached',
      timeout: timeoutMs,
    });
    await loc.first().click({ force: true });
    await page.waitForTimeout(1500);
    return true;
  } catch {
    logMsg(`Aria click failed: "${label}"`);
    return false;
  }
}

// Only run at desktop viewport for comprehensive crawl
test.describe('Comprehensive QA Crawl', () => {
  test.setTimeout(300_000); // 5 minutes

  test(
    'full app crawl with screenshots and logs',
    async ({ page }) => {
      setupListeners(page);

      // ── 1. App Load ──────────────────────────────
      logMsg('=== Phase 1: App Load ===');
      await page.goto('/');
      await waitForFlutterReady(page);
      await screenshot(page, 'app-loaded');

      // Verify flutter-view renders
      const flutterView = page.locator('flutter-view');
      await expect(flutterView.first()).toBeVisible();
      logMsg('flutter-view visible: OK');

      // ── 2. Profile Selection ─────────────────────
      logMsg('=== Phase 2: Profile Selection ===');
      await screenshot(page, 'profile-selection');

      // Check for profile screen elements
      const hasProfileTitle = await page
        .getByText("Who's watching?")
        .isVisible()
        .catch(() => false);
      logMsg(`Profile title visible: ${hasProfileTitle}`);

      // Look for Add Profile button
      const hasAddProfile = await page
        .getByText('Add Profile')
        .isVisible()
        .catch(() => false);
      logMsg(`Add Profile visible: ${hasAddProfile}`);

      // Check profile items
      const profileItems = await page
        .locator(
          '[aria-label*="Profile"], ' +
          '[aria-label="Default"]',
        )
        .count()
        .catch(() => 0);
      logMsg(`Profile items found: ${profileItems}`);

      // Select default profile
      const profileSelected =
        await selectDefaultProfile(page);
      logMsg(`Profile selected: ${profileSelected}`);
      await page.waitForTimeout(2000);
      await screenshot(page, 'after-profile-select');

      // ── 3. Home Screen ───────────────────────────
      logMsg('=== Phase 3: Home Screen ===');
      await screenshot(page, 'home-screen');

      // Check for home screen sections
      for (const section of [
        'Continue Watching',
        'Recent Channels',
        'Your Favorites',
        'Recommended',
        'Latest',
      ]) {
        const visible = await page
          .getByText(section)
          .first()
          .isVisible()
          .catch(() => false);
        logMsg(`Home section "${section}": ${visible}`);
      }

      // ── 4. Navigate All Tabs ─────────────────────
      logMsg('=== Phase 4: Navigation Tabs ===');
      for (const tab of NAV_TABS) {
        logMsg(`--- Navigating to: ${tab} ---`);
        const clicked = await tryClick(page, tab);
        if (!clicked) {
          // Try aria-label approach for nav rail
          await tryClickAria(page, tab);
        }
        await page.waitForTimeout(2000);
        await screenshot(
          page,
          `tab-${tab.toLowerCase()}`,
        );

        // Tab-specific checks
        if (tab === 'Live TV') {
          await checkTvScreen(page);
        } else if (tab === 'Guide') {
          await checkEpgScreen(page);
        } else if (tab === 'Movies' || tab === 'Series') {
          await checkVodScreen(page, tab);
        } else if (tab === 'Settings') {
          await checkSettingsScreen(page);
        }
      }

      // ── 5. Settings Deep Dive ────────────────────
      logMsg('=== Phase 5: Settings Deep Dive ===');
      await tryClick(page, 'Settings');
      await page.waitForTimeout(1500);

      // Try each settings section
      for (const settingItem of [
        'Playlists',
        'Appearance',
        'Playback',
        'EPG',
        'General',
        'About',
      ]) {
        const clicked = await tryClick(
          page,
          settingItem,
          3000,
        );
        if (clicked) {
          await screenshot(
            page,
            `settings-${settingItem.toLowerCase()}`,
          );
          logMsg(
            `Settings section "${settingItem}": ` +
            `visible`,
          );
        }
      }

      // Try "Add Playlist" / "Add Source"
      for (const addBtn of [
        'Add Playlist',
        'Add Source',
        'Add M3U Playlist',
        'Connect Xtream',
        'Add XMLTV Source',
      ]) {
        const vis = await page
          .getByText(addBtn)
          .first()
          .isVisible()
          .catch(() => false);
        if (vis) {
          logMsg(`Settings button "${addBtn}": found`);
          await tryClick(page, addBtn, 3000);
          await screenshot(
            page,
            `settings-${addBtn
              .toLowerCase()
              .replace(/\s+/g, '-')}`,
          );
          // Close modal/dialog if opened
          await page.keyboard.press('Escape');
          await page.waitForTimeout(500);
        }
      }

      // ── 6. Try context menus ─────────────────────
      logMsg('=== Phase 6: Context Menu Tests ===');

      // Navigate to Live TV tab for channel context menu
      await tryClick(page, 'Live TV') ||
        await tryClickAria(page, 'Live TV');
      await page.waitForTimeout(2000);

      // Try right-click / long-press on any channel
      const channelItem = page.locator(
        '[aria-label*="channel"], ' +
        '[aria-label*="Channel"]',
      );
      const channelCount = await channelItem
        .count()
        .catch(() => 0);
      logMsg(`Channel items found: ${channelCount}`);

      if (channelCount > 0) {
        await channelItem
          .first()
          .click({ button: 'right' })
          .catch(() => {});
        await page.waitForTimeout(1500);
        await screenshot(page, 'channel-context-menu');
      }

      // ── 7. Responsive checks ─────────────────────
      logMsg('=== Phase 7: Responsive Layout ===');

      // Check nav rail vs bottom bar
      const navRail = await page
        .locator(
          '[aria-label*="navigation"], ' +
          'flt-semantics[aria-label*="navigation"]',
        )
        .count()
        .catch(() => 0);
      logMsg(`Navigation elements: ${navRail}`);

      // Check for sidebar visibility
      const viewport = page.viewportSize();
      logMsg(
        `Viewport: ${viewport?.width}x` +
        `${viewport?.height}`,
      );

      // ── 8. Keyboard Navigation ───────────────────
      logMsg('=== Phase 8: Keyboard Navigation ===');

      // Tab through elements
      for (let i = 0; i < 10; i++) {
        await page.keyboard.press('Tab');
        await page.waitForTimeout(200);
      }
      await screenshot(page, 'keyboard-tab-focus');

      // Try arrow keys (for TV-style navigation)
      for (const key of [
        'ArrowDown',
        'ArrowDown',
        'ArrowRight',
        'ArrowRight',
        'Enter',
      ]) {
        await page.keyboard.press(key);
        await page.waitForTimeout(300);
      }
      await screenshot(page, 'keyboard-arrow-nav');

      // ── 9. Check for empty states ────────────────
      logMsg('=== Phase 9: Empty States ===');

      // Navigate to Movies to check empty state
      await tryClick(page, 'Movies') ||
        await tryClickAria(page, 'Movies');
      await page.waitForTimeout(2000);
      await screenshot(page, 'movies-state');

      // Check for "no content" messages
      for (const emptyText of [
        'No channels',
        'No content',
        'Add a playlist',
        'No sources',
        'No favorites',
        'Nothing to show',
      ]) {
        const vis = await page
          .getByText(emptyText)
          .first()
          .isVisible()
          .catch(() => false);
        if (vis) {
          logMsg(`Empty state "${emptyText}": visible`);
        }
      }

      // Navigate to Guide/EPG
      await tryClick(page, 'Guide') ||
        await tryClickAria(page, 'Guide');
      await page.waitForTimeout(2000);
      await screenshot(page, 'epg-state');

      // ── 10. Final state ──────────────────────────
      logMsg('=== Phase 10: Final Summary ===');
      await screenshot(page, 'final-state');

      // Write logs to file
      const logContent = [
        '# Comprehensive Crawl Logs',
        `# Date: ${new Date().toISOString()}`,
        `# Viewport: ${viewport?.width}x${viewport?.height}`,
        '',
        `## Console Errors (${allErrors.length})`,
        ...allErrors.map((e) => `- ${e}`),
        '',
        `## Console Warnings (${allWarnings.length})`,
        ...allWarnings.map((w) => `- ${w}`),
        '',
        '## Full Log',
        ...allLogs,
      ].join('\n');

      fs.mkdirSync(LOG_DIR, { recursive: true });
      fs.writeFileSync(
        path.join(LOG_DIR, 'crawl-logs.txt'),
        logContent,
      );

      logMsg(
        `Total errors: ${allErrors.length}, ` +
        `warnings: ${allWarnings.length}`,
      );
    },
  );
});

// ── Tab-specific check functions ───────────────────

async function checkTvScreen(page: Page) {
  logMsg('Checking TV screen...');

  // Look for channel list elements
  const hasGroups = await page
    .getByText('All')
    .first()
    .isVisible()
    .catch(() => false);
  logMsg(`TV groups sidebar: ${hasGroups}`);

  // Check search field
  const hasSearch = await page
    .locator('input, [aria-label*="Search"]')
    .count()
    .catch(() => 0);
  logMsg(`TV search inputs: ${hasSearch}`);

  await screenshot(page, 'tv-detail');
}

async function checkEpgScreen(page: Page) {
  logMsg('Checking EPG/Guide screen...');

  // Look for EPG timeline elements
  const hasTimeline = await page
    .getByText('Now')
    .first()
    .isVisible()
    .catch(() => false);
  logMsg(`EPG "Now" marker: ${hasTimeline}`);

  // Check for filter toggle (new feature)
  const hasFilter = await page
    .locator(
      '[aria-label*="filter"], ' +
      '[aria-label*="Filter"], ' +
      '[aria-label*="EPG"]',
    )
    .count()
    .catch(() => 0);
  logMsg(`EPG filter elements: ${hasFilter}`);

  // Check for day/week toggle
  const hasDayWeek = await page
    .getByText('Day')
    .first()
    .isVisible()
    .catch(() => false);
  logMsg(`EPG Day/Week toggle: ${hasDayWeek}`);

  await screenshot(page, 'epg-detail');
}

async function checkVodScreen(page: Page, kind: string) {
  logMsg(`Checking VOD screen (${kind})...`);

  // Check for poster cards
  const posterCards = await page
    .locator(
      '[aria-label*="movie"], ' +
      '[aria-label*="Movie"], ' +
      '[aria-label*="series"], ' +
      '[aria-label*="Series"]',
    )
    .count()
    .catch(() => 0);
  logMsg(`VOD poster cards: ${posterCards}`);
}

async function checkSettingsScreen(page: Page) {
  logMsg('Checking Settings screen...');

  // Look for key settings sections
  for (const section of [
    'Player',
    'Theme',
    'Language',
    'External Player',
    'Data',
    'Cache',
  ]) {
    const vis = await page
      .getByText(section)
      .first()
      .isVisible()
      .catch(() => false);
    if (vis) {
      logMsg(`Settings "${section}": visible`);
    }
  }

  await screenshot(page, 'settings-detail');
}
