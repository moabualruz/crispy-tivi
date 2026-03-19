//! J-29: PiP Mode
//!
//! Dream: "PiP window in corner of screen, persists across navigation,
//! repositionable, audio continues uninterrupted."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, PlayerState};
use slint::ComponentHandle;

pub struct J29;

impl Journey for J29 {
    const ID: &'static str = "j29";
    const NAME: &'static str = "Picture-in-Picture Mode";
    const DEPENDS_ON: &'static [&'static str] = &["j26"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── VOD playing fullscreen before PiP ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_paused(false);
            ps.set_is_live(false);
            ps.set_current_title("Interstellar".into());
            ps.set_duration(9540.0);
            ps.set_position(2700.0);
            ps.set_show_osd(false);

            let app = ui.global::<AppState>();
            app.set_pip_active(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "fullscreen_before_pip",
            "VOD playing fullscreen",
            "Interstellar playing, no PiP window, full-screen video",
        );

        // ── Activate PiP — video shrinks to corner window ─────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_pip_active(true);
            // Active screen returns to browsing (Movies)
            app.set_active_screen(3);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "pip_active_on_movies",
            "PiP activated — browse Movies",
            "PiP window in bottom-right corner, Movies screen behind it, audio continues",
        );

        // ── Navigate to Search — PiP persists ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(5); // Search
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "pip_persists_on_search",
            "Navigate to Search",
            "PiP window still visible in corner, persists across navigation",
        );

        // ── Navigate to Home — PiP persists ──────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(0); // Home
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "pip_persists_on_home",
            "Navigate to Home",
            "PiP window persists at home screen, playback and audio uninterrupted",
        );

        // ── Dismiss PiP — stop playback ───────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_pip_active(false);
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "pip_dismissed",
            "PiP dismissed",
            "PiP window gone, home screen clean, playback stopped",
        );
    }
}
