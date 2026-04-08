# CrispyTivi E2E Testing Guide

This directory manages the overarching End-to-End (E2E) testing capabilities for CrispyTivi across all our deployment targets.

We do not rely on a single fully-automated bash loop intended to sequentially run everything. Instead, tests are fired explicitly depending on the target infrastructure being audited.

Here are the specific, standalone commands to run each test suite for each respective target.

---

## 🖥 1. Native Windows Desktop

The native Windows desktop app is tested using Flutter's core `integration_test` package. Because of native Windows build locks (`LNK1168` linker errors), tests must be passed sequentially on single files.

**Command:**

```bash
# Run the core app integration test against the native Windows SDK
cd app/flutter && flutter test integration_test/main_test.dart -d windows
```

_(To run specific sub-flows, substitute `main_test.dart` for internal flow files like `integration_test/flows/epg_flow_test.dart`)_

---

## 📱 2. Native Android Mobile & Android TV

Testing Android Mobile (e.g., Pixel phones) and Android TV (Leanback interface) relies perfectly on Flutter's `integration_test` ecosystem to validate true UI and OS integration safely.

**Steps:**

1. Boot up exactly ONE active emulator.
   - For Mobile: Start your standard Android Phone AVD.
   - For TV: Start your Android TV API AVD.
2. Quickly fetch the active Device ID via `flutter devices`. You should see an ID like `emulator-5554`.
3. Target that explicit emulator ID in your test run.

**Command:**

```bash
# Replace emulator-5554 with your active device ID
cd app/flutter && flutter test integration_test/main_test.dart -d emulator-5554
```

---

## 🌐 3. Web UI (Playwright)

Testing the compiled Flutter HTML CanvasKit web distribution is strictly handled via Playwright. Playwright tests all responsive layers (Mobile Viewport, Desktop Viewport) but only against the generic `web` build.

**🚨 Execution Sequence:**
Because Playwright tests browser capabilities natively, it relies on actual network connections. You MUST execute these three terminal commands completely separately in order to prevent `net::ERR_CONNECTION_REFUSED` pipeline failures.

1. **Start the Rust Backend API**

```bash
cd rust
cargo run -p crispy-server --release
```

2. **Wait, then Compile and Serve the Web Framework**

```bash
cd app/flutter && flutter build web --release
# Serve exclusively on IPv4
npx -y http-server app/flutter/build/web -p 3000 -a 127.0.0.1 -c-1 --cors
```

3. **Trigger Playwright Suite**

```bash
cd testing/playwright
npx playwright test --workers=4
```

_(You can see specific sub-layer testing guides and commands explicitly inside `testing/playwright/README.md`)_
