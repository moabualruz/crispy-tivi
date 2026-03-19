//! J-45: Stream Source Failover
//!
//! Dream: "4-step automatic recovery when a stream fails:
//! 1. Detect stall → 2. Try alternate stream URL → 3. Quality downgrade → 4. Source failover.
//! User sees non-intrusive quality notification. Only shows error if ALL steps fail."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J45;

impl Journey for J45 {
    const ID: &'static str = "j45";
    const NAME: &'static str = "Stream Source Failover";
    const DEPENDS_ON: &'static [&'static str] = &["j44"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Live TV — channel playing normally ─────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(1); // Live TV
            app.set_network_status(0);
            app.set_is_offline(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "stream_playing_normal",
            "Channel playing — normal quality",
            "BBC One playing at 1080p; OSD shows stream quality; no errors",
        );

        // ── Step 1: Stream stalls — detecting failure ──────────────────────

        // Rust detects mpv stall (timeout on frames) — shows buffering
        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // Use sync_message as a proxy for OSD notification text
            app.set_sync_message("Buffering…".into());
            app.set_is_syncing(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "stream_stalled_buffering",
            "Stream stalls — buffering indicator",
            "Buffering spinner on OSD; 'Buffering…' text; player continues attempting recovery",
        );

        // ── Step 2: Step 1 recovery — alternate stream URL tried ──────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_sync_message("Trying alternate stream…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "failover_step1_alternate_url",
            "Failover step 1 — alternate URL",
            "Non-intrusive toast: 'Switching to alternate stream'; brief spinner; no full error screen",
        );

        // ── Step 3: Step 2 recovery — quality downgrade ────────────────────

        // Alternate URL also fails — downgrade from 1080p to 720p
        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_sync_message("Reduced to 720p for stability".into());
            app.set_is_syncing(false); // stream resumed at lower quality
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "failover_step2_quality_downgrade",
            "Failover step 2 — quality downgrade to 720p",
            "Stream resumed at 720p; OSD quality badge updates to '720p'; notification: 'Reduced quality for stability'",
        );

        // ── Step 4: Stream resumes after quality downgrade ─────────────────

        harness.assert_screenshot(
            "stream_resumed_720p",
            "Stream playing at 720p",
            "Video playing at 720p; OSD shows reduced quality badge; user can manually select higher quality",
        );

        // ── Step 5: Full stream failure — step 3: source failover ──────────

        // Simulate even 720p fails — try next source/provider
        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_sync_message("Trying backup source…".into());
            app.set_is_syncing(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "failover_step3_backup_source",
            "Failover step 3 — backup source",
            "OSD: 'Switching to backup source'; brief loading; no black screen if possible",
        );

        // ── Step 6: All steps succeed — normal playback from backup ────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_is_syncing(false);
            app.set_sync_message("Now using backup source".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "failover_success_backup",
            "Failover succeeded — backup source playing",
            "Stream playing from backup source; notification: 'Now using backup source'; quality restored",
        );

        // ── Step 7: Terminal failure — all 4 steps exhausted ──────────────

        // Simulate all 4 steps fail → show error state
        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_is_syncing(false);
            app.set_sync_message("Stream unavailable".into());
            app.set_network_status(3); // source down
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "failover_all_steps_failed",
            "All failover steps exhausted — stream unavailable",
            "Error overlay on player: 'Stream Unavailable. All sources tried.' with Retry / Browse options",
        );

        // ── Step 8: User presses Retry — restart from step 1 ──────────────

        harness.press_ok("retry_stream_failover", "Press Retry");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_network_status(0);
            app.set_is_syncing(true);
            app.set_sync_message("Retrying stream…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "failover_retry_initiated",
            "Retry pressed — failover sequence restarts",
            "Loading state; 'Retrying…' shown; 4-step sequence restarts from step 1",
        );

        // ── Step 9: Browse channels — graceful fallback ────────────────────

        // User presses Browse instead of Retry
        harness.press_back("dismiss_error", "Press Back — dismiss error");
        harness.press_down("navigate_browse_button", "Navigate to Browse button");
        harness.press_ok("go_browse_channels", "Press Browse — go to channel list");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_is_syncing(false);
            app.set_sync_message("".into());
            app.set_active_screen(1); // Live TV channel list
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "graceful_fallback_channel_list",
            "Graceful fallback — channel list shown",
            "Channel list visible; failed channel indicated; user can select a different channel",
        );
    }
}
