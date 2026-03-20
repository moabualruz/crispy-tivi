//! J-32: Settings — Source Health Dashboard
//!
//! Dream: "Status cards per source. Health dots (green/yellow/red). Sync progress
//! inline. Human-readable errors. Auto-sync config."

use crate::harness::{
    db::TestDb, input::InputEmulation, journey_runner::Journey, renderer::ScreenshotHarness,
};
use crate::{AppState, AppWindow, SourceData};
use slint::ComponentHandle;

pub struct J32;

impl Journey for J32 {
    const ID: &'static str = "j32";
    const NAME: &'static str = "Settings — Source Health Dashboard";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Settings screen with multiple sources ──────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(7); // Settings
            // Populate three sources with different health states
            let sources = slint::ModelRc::new(slint::VecModel::from(vec![
                SourceData {
                    id: "src-1".into(),
                    name: "Main M3U".into(),
                    source_type: "m3u".into(),
                    url: "http://iptv.example.com/main.m3u".into(),
                    username: "".into(),
                    password: "".into(),
                    channel_count: 4820,
                    vod_count: 0,
                    sync_status: "ok".into(),
                    last_sync_error: "".into(),
                    enabled: true,
                },
                SourceData {
                    id: "src-2".into(),
                    name: "Xtream Premium".into(),
                    source_type: "xtream".into(),
                    url: "http://xtream.example.com".into(),
                    username: "user".into(),
                    password: "****".into(),
                    channel_count: 1200,
                    vod_count: 8500,
                    sync_status: "warning".into(),
                    last_sync_error: "EPG data stale (>24h)".into(),
                    enabled: true,
                },
                SourceData {
                    id: "src-3".into(),
                    name: "Stalker Portal".into(),
                    source_type: "stalker".into(),
                    url: "http://stalker.example.com".into(),
                    username: "AA:BB:CC:DD:EE:FF".into(),
                    password: "".into(),
                    channel_count: 0,
                    vod_count: 0,
                    sync_status: "error".into(),
                    last_sync_error: "Connection refused".into(),
                    enabled: false,
                },
            ]));
            ui.global::<AppState>().set_sources(sources);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_health_dashboard",
            "Navigate to Settings",
            "Source health dashboard with green/yellow/red health dots per source",
        );

        // ── Step 1: Focus on error source card ────────────────────────────────

        harness.press_down(
            "source_card_2_focused",
            "Navigate focus down to second source",
        );
        harness.press_down(
            "source_card_error_focused",
            "Navigate focus to error source",
        );

        harness.assert_screenshot(
            "source_card_error_detail",
            "Error source card focused",
            "Error source card focused with red indicator and human-readable error message",
        );

        // ── Step 2: Trigger manual sync on error source ───────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_syncing(true);
            ui.global::<AppState>().set_sync_progress(0.0);
            ui.global::<AppState>()
                .set_sync_message("Reconnecting to Stalker Portal…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_sync_started",
            "Trigger sync on error source",
            "Inline sync progress shown on the source card being synced",
        );

        // ── Step 3: Sync progress mid-way ─────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_sync_progress(0.6);
            ui.global::<AppState>()
                .set_sync_message("Loading channels (720/1200)…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_sync_progress",
            "Sync in progress",
            "Progress bar at 60% with channel count shown inline",
        );

        // ── Step 4: All sources healthy after sync ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_sync_progress(1.0);
            ui.global::<AppState>().set_is_syncing(false);
            ui.global::<AppState>()
                .set_sync_message("All sources synced".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "all_sources_healthy",
            "All syncs complete",
            "All source cards show green health dots with updated channel counts",
        );
    }
}
