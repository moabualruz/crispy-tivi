//! J-44: Network Failure Recovery
//!
//! Dream: "Seamless degradation: buffer grace period during brief outage,
//! auto-retry with exponential backoff, cached channel/EPG data browsable offline.
//! Clear status indicators — not generic error pages."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J44;

impl Journey for J44 {
    const ID: &'static str = "j44";
    const NAME: &'static str = "Network Failure Recovery";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Normal state — online, live TV playing ─────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(1); // Live TV
            app.set_network_status(0); // online
            app.set_is_offline(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_tv_online",
            "Live TV — online, channel playing",
            "Live TV playing normally; no error indicators; signal strength normal",
        );

        // ── Step 1: Network drops — buffer grace period ────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // network-status: 1 = device offline
            app.set_network_status(1);
            app.set_is_offline(false); // grace period — not yet showing offline UI
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "network_drop_grace_period",
            "Network drops — buffer grace period",
            "Video continues from buffer; subtle buffering indicator appears; no error yet (5s grace)",
        );

        // ── Step 2: Grace period expires — offline mode activated ──────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_is_offline(true);
            app.set_sync_message("Connection lost. Retrying…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "offline_mode_activated",
            "Offline mode — grace period expired",
            "Offline banner: 'No connection. Retrying…' with spinner; video paused; cached data visible",
        );

        // ── Step 3: Browse cached content offline ──────────────────────────

        // User can still browse cached channels and EPG
        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(0); // Home
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "home_browsable_offline",
            "Home screen — browsable offline",
            "Home shows cached content; offline badge in corner; 'Offline — cached data' subtitle",
        );

        // Navigate to Live TV — channel list visible from cache
        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(1);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_tv_offline_cached",
            "Live TV — cached channel list offline",
            "Channel list visible from local cache; channels show cached EPG; play attempts show retry spinner",
        );

        // ── Step 4: Auto-retry with backoff — retry attempts visible ───────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_sync_message("Retrying in 5s… (attempt 2/4)".into());
            app.set_is_syncing(true);
            app.set_sync_progress(0.0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "auto_retry_attempt_2",
            "Auto-retry — attempt 2/4",
            "Retry indicator: 'Retrying in 5s… (attempt 2/4)'; exponential backoff visible",
        );

        // ── Step 5: network-status 2 — internet unreachable (DNS/WAN) ──────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_network_status(2); // internet unreachable
            app.set_sync_message("Internet unreachable. Check your connection.".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "internet_unreachable",
            "Internet unreachable",
            "More specific error: 'Internet unreachable' (not just device offline); manual retry button",
        );

        // ── Step 6: network-status 3 — source server down ─────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_network_status(3); // source server down
            app.set_sync_message("Source server unavailable. Content may be outdated.".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_server_down",
            "Source server down",
            "Source-specific error: server down message; cached content still browsable; 'Check source' link",
        );

        // ── Step 7: Connection restored — auto-recovery ────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_network_status(0);
            app.set_is_offline(false);
            app.set_is_syncing(true);
            app.set_sync_progress(0.3);
            app.set_sync_message("Reconnected. Refreshing sources…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "connection_restored_syncing",
            "Connection restored — auto-sync",
            "Positive banner: 'Reconnected'; sync progress bar; EPG refreshing automatically",
        );

        // ── Step 8: Full recovery — back to normal ─────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_is_syncing(false);
            app.set_sync_progress(1.0);
            app.set_sync_message("".into());
            app.set_is_offline(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "fully_recovered",
            "Full recovery — normal operation resumed",
            "All error banners gone; live TV resumes; EPG refreshed; no offline indicators",
        );
    }
}
