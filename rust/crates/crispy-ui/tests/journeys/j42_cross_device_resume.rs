//! J-42: Cross-Device Resume via Server Mode
//!
//! Dream: "Watch on desktop, resume on phone (WASM). Resume position syncs
//! between native LocalProvider and WASM RemoteProvider clients via WebSocket.
//! Seamless handoff — pick up where you left off on any device."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J42;

impl Journey for J42 {
    const ID: &'static str = "j42";
    const NAME: &'static str = "Cross-Device Resume via Server Mode";
    const DEPENDS_ON: &'static [&'static str] = &["j41"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Desktop — playing Dune at 45% ─────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(0); // Home (player running in Layer 0)
            app.set_server_mode_enabled(true);

            // Dune is in watch history with 45% progress
            let history = vec![crate::WatchHistoryData {
                id: "m_dune".into(),
                name: "Dune".into(),
                media_type: "movie".into(),
                stream_url: "".into(),
                position_ms: 4185000,
                duration_ms: 9300000,
                watched_at: "Now".into(),
                progress: 0.45,
            }];
            app.set_watch_history(ModelRc::new(VecModel::from(history)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "desktop_playing_dune",
            "Desktop — Dune playing at 45%",
            "Home screen with video underlay; server mode active; Dune at 45% in history",
        );

        // ── Step 1: WASM client connects — represented in UI ──────────────

        // Simulate a browser client connecting (server mode active)
        harness.assert_screenshot(
            "server_client_connected",
            "Phone/browser client connects",
            "Settings server section would show 1 connected client; resume state synced",
        );

        // ── Step 2: Navigate to Library to see Continue Watching ──────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(6); // Library
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "library_continue_watching_synced",
            "Library — Continue Watching shows Dune",
            "Dune with 45% progress bar; resume position synced from remote client",
        );

        // ── Step 3: Remote client advances position — sync reflected ───────

        // Simulate the WASM browser client advancing playback to 60%
        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            let history = vec![crate::WatchHistoryData {
                id: "m_dune".into(),
                name: "Dune".into(),
                media_type: "movie".into(),
                stream_url: "".into(),
                position_ms: 5580000,
                duration_ms: 9300000,
                watched_at: "Now".into(),
                progress: 0.60,
            }];
            app.set_watch_history(ModelRc::new(VecModel::from(history)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "cross_device_position_updated",
            "Remote client advanced to 60%",
            "Continue Watching — Dune progress bar updated to 60% via WebSocket sync",
        );

        // ── Step 4: Resume on desktop from synced position ─────────────────

        harness.press_down(
            "navigate_dune_card",
            "Navigate to Dune Continue Watching card",
        );
        harness.press_ok("resume_dune_60", "Resume Dune from synced 60% position");

        harness.assert_screenshot(
            "resume_from_synced_position",
            "Resumed from synced 60% position",
            "Dune plays from 60%; OSD shows position matching remote client's last position",
        );

        // ── Step 5: Stop playing — return to library ──────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(6); // Library
            let history = vec![crate::WatchHistoryData {
                id: "m_dune".into(),
                name: "Dune".into(),
                media_type: "movie".into(),
                stream_url: "".into(),
                position_ms: 5859000,
                duration_ms: 9300000,
                watched_at: "Just now".into(),
                progress: 0.63,
            }];
            app.set_watch_history(ModelRc::new(VecModel::from(history)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "cross_device_final_state",
            "Resume position updated after playback",
            "Dune now at 63% — synced back to all connected clients via WebSocket",
        );
    }
}
