//! J-35: Diagnostics and Troubleshooting
//!
//! Dream: "System info, GPU pipeline level, network latency, player stats.
//! Run Health Check. Export log."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J35;

impl Journey for J35 {
    const ID: &'static str = "j35";
    const NAME: &'static str = "Diagnostics and Troubleshooting";
    const DEPENDS_ON: &'static [&'static str] = &["j32"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Settings entry point ───────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(7); // Settings
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_diagnostics_entry",
            "Navigate to Settings",
            "Diagnostics entry point visible in Settings (About/Debug section)",
        );

        // ── Step 1: Diagnostics panel ─────────────────────────────────────────

        harness.assert_screenshot(
            "diagnostics_panel",
            "Open Diagnostics panel",
            "Diagnostics panel visible with system info, GPU pipeline level, network latency",
        );

        // ── Step 2: GPU pipeline section ──────────────────────────────────────

        harness.assert_screenshot(
            "diagnostics_gpu_pipeline",
            "View GPU pipeline section",
            "GPU pipeline section shows: vo=gpu-next, hwdec=auto-safe, pipeline level",
        );

        // ── Step 3: Network latency section ───────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_network_status(0); // online
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "diagnostics_network",
            "View network diagnostics",
            "Network section: connectivity status, source ping latencies listed",
        );

        // ── Step 4: Player stats section ──────────────────────────────────────

        harness.assert_screenshot(
            "diagnostics_player_stats",
            "View player stats section",
            "Player section: codec info, frame drop count, buffer health, video resolution",
        );

        // ── Step 5: Health check running ──────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_syncing(true);
            ui.global::<AppState>()
                .set_sync_message("Running health check…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "diagnostics_health_check_running",
            "Run Health Check",
            "Health check spinner shown, checking GPU, network, sources",
        );

        // ── Step 6: Health check result ───────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_syncing(false);
            ui.global::<AppState>()
                .set_sync_message("Health check complete: 2 warnings".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "diagnostics_health_check_result",
            "Health check completes",
            "Health check results shown with pass/warn/fail per subsystem",
        );

        // ── Step 7: Export log ────────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_sync_message("Log exported to crispy-tivi.log".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "diagnostics_log_exported",
            "Export diagnostic log",
            "Success toast: log file path shown for sharing with support",
        );
    }
}
