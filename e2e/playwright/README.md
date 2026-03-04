# CrispyTivi Playwright E2E Tests

This directory contains the end-to-end (E2E) testing suite for the CrispyTivi web application using Playwright.

## 🚨 CRITICAL: Execution Sequence 🚨

Because CrispyTivi is a Flutter application backed by a Rust server (`crispy-server`), **both components must be explicitly built and running** before initiating Playwright tests. Failing to follow these steps precisely will result in `net::ERR_CONNECTION_REFUSED` errors during Playwright execution, particularly on Windows, due to IPv4/IPv6 binding issues.

Start from the **root directory** of the CrispyTivi project (`f:/work/crispy-tivi`):

### 1. Start the Rust Backend

The Rust backend is required for the application to hydrate state properly.

```bash
# Terminal 1
cd rust
cargo run -p crispy-server --release
```

### 2. Build the Flutter Web App

Ensure you have the latest compiled static web assets.

```bash
# Terminal 2 (Project Root)
flutter build web --release
```

### 3. Serve the Web App (IPv4 Mode)

You **must** serve the application explicitly over IPv4 with cache disabled to prevent Playwright connection errors. We use `http-server` for this explicit binding target.

```bash
# Terminal 2 (Project Root)
npx -y http-server build/web -p 3000 -a 127.0.0.1 -c-1 --cors
```

### 4. Run the Playwright Suite

Finally, with both processes running, you can execute the E2E suite.

```bash
# Terminal 3
cd e2e/playwright
npx playwright test --workers=4
```

---

## Available NPM Scripts

From within `e2e/playwright/`:

- `npm run test` - Run all test suites
- `npm run test:ui` - Open the interactive Playwright UI
- `npm run test:mobile`, `test:desktop`, `test:tablet` - Run tests against specific viewports
- `npm run report` - Open the generated HTML report for debugging test output
