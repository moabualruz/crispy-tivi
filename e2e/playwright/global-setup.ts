import type { FullConfig } from "@playwright/test";

/**
 * Playwright global setup — runs once before all tests.
 *
 * Verifies that both required services are reachable:
 *   1. Web server at http://127.0.0.1:3000 (Flutter web build)
 *   2. Backend server at http://127.0.0.1:8080 (crispy-server WebSocket)
 *
 * Fails fast with a clear error message if either service is down,
 * preventing flaky test runs caused by missing infrastructure.
 */
async function globalSetup(_config: FullConfig) {
  const webPort = process.env.CRISPY_WEB_PORT ?? "3000";
  const backendPort = process.env.CRISPY_PORT ?? "8081";
  const WEB_URL = `http://127.0.0.1:${webPort}`;
  const BACKEND_URL = `http://127.0.0.1:${backendPort}`;
  const MAX_RETRIES = 5;
  const RETRY_DELAY_MS = 2000;

  async function checkService(url: string, label: string): Promise<void> {
    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
        // Any HTTP response (even 404) means the server is up.
        console.log(
          `  [global-setup] ${label} is reachable (HTTP ${res.status})`,
        );
        return;
      } catch {
        if (attempt < MAX_RETRIES) {
          console.log(
            `  [global-setup] ${label} not ready (attempt ${attempt}/${MAX_RETRIES}), retrying in ${RETRY_DELAY_MS}ms...`,
          );
          await new Promise((r) => setTimeout(r, RETRY_DELAY_MS));
        }
      }
    }
    throw new Error(
      `${label} at ${url} is not reachable after ${MAX_RETRIES} attempts.\n` +
        `Start it before running E2E tests.\n` +
        `  Web server: npx -y http-server build/web -p ${webPort} -a 127.0.0.1 -c-1 --cors\n` +
        `  Backend:    cd rust && CRISPY_PORT=${backendPort} cargo run -p crispy-server --release`,
    );
  }

  console.log("[global-setup] Verifying required services...");
  await checkService(WEB_URL, "Web server (Flutter build)");
  await checkService(BACKEND_URL, "Backend server (crispy-server)");
  console.log("[global-setup] All services ready. Starting tests.\n");
}

export default globalSetup;
