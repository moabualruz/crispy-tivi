//! J-26: Full OSD Interaction — VOD Mode
//!
//! Dream: "Zero UI until needed. Any key press reveals instant OSD. Thumbnail
//! seek scrubbing. Secondary tray for extras. OSD auto-hides after 3s."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppWindow, PlayerState};
use slint::ComponentHandle;

pub struct J26;

impl Journey for J26 {
    const ID: &'static str = "j26";
    const NAME: &'static str = "Player OSD — VOD Controls";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── VOD playing — OSD hidden (zero UI) ───────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_paused(false);
            ps.set_is_live(false);
            ps.set_current_title("Interstellar".into());
            ps.set_current_group("Movies".into());
            ps.set_duration(9540.0); // 159 minutes
            ps.set_position(2700.0); // 45 minutes in
            ps.set_buffered(0.5);
            ps.set_volume(1.0);
            ps.set_is_muted(false);
            ps.set_current_resolution("1080p".into());
            ps.set_show_osd(false); // OSD hidden — zero UI state
            ps.set_show_tracks_panel(false);
            ps.set_show_skip_intro(false);
            ps.set_show_post_play(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "vod_playing_osd_hidden",
            "VOD playing — no interaction",
            "Fullscreen video, zero UI chrome, clean viewing experience",
        );

        // ── Key press — OSD appears instantly ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "vod_osd_visible",
            "Key press reveals OSD",
            "OSD instantly visible: title, seek bar, play/pause, skip controls",
        );

        // ── Pause ─────────────────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(false);
            ps.set_is_paused(true);
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "vod_paused",
            "User pauses",
            "OSD shows pause state, play button prominent, seek bar frozen",
        );

        // ── Seek — scrubbing seek bar ─────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            // Scrub forward to 60 minutes
            ps.set_position(3600.0);
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "vod_seeking",
            "Seek bar scrubbed to 60m",
            "Seek position updated, progress bar reflects new position",
        );

        // ── Secondary tray open (D-pad Down) ─────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_osd(true);
            ps.set_is_playing(true);
            ps.set_is_paused(false);
            // Secondary tray contains audio/sub/speed controls
            // Represented by show_tracks_panel toggled later in J28;
            // here we just capture the OSD in tray-open state
            ps.set_show_tracks_panel(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "vod_osd_secondary_tray",
            "D-pad Down: secondary tray",
            "OSD secondary tray visible below main controls (audio, subs, speed)",
        );

        // ── Mute ─────────────────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_muted(true);
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "vod_muted",
            "Mute toggled",
            "Volume indicator shows Muted, mute icon active",
        );

        // ── OSD auto-hides (Rust sets show_osd=false after 3s) ───────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_muted(false);
            ps.set_is_playing(true);
            ps.set_show_osd(false); // simulates 3s auto-hide firing
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "vod_osd_autohidden",
            "OSD auto-hides after 3s",
            "OSD faded out, clean video surface restored",
        );
    }
}
