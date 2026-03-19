//! J-28: Audio / Subtitle Track Switching
//!
//! Dream: "Right-slide panel. Codec + channels info. Subtitle delay control.
//! Forced subs flag. Per-profile language defaults applied automatically."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppWindow, PlayerState};
use slint::ComponentHandle;

pub struct J28;

impl Journey for J28 {
    const ID: &'static str = "j28";
    const NAME: &'static str = "Audio and Subtitle Track Picker";
    const DEPENDS_ON: &'static [&'static str] = &["j26"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── VOD playing — tracks panel closed ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_paused(false);
            ps.set_is_live(false);
            ps.set_current_title("Interstellar".into());
            ps.set_duration(9540.0);
            ps.set_position(2700.0);
            ps.set_show_osd(true);
            ps.set_show_tracks_panel(false);

            let audio_tracks: Vec<slint::SharedString> = vec![
                "English (AC3 5.1)".into(),
                "Arabic (AAC 2.0)".into(),
                "French (AAC 2.0)".into(),
            ];
            ps.set_audio_track_labels(std::rc::Rc::new(slint::VecModel::from(audio_tracks)).into());
            ps.set_active_audio_track(0);

            let sub_tracks: Vec<slint::SharedString> = vec![
                "Off".into(),
                "English (SRT)".into(),
                "Arabic (SRT)".into(),
                "French (SRT)".into(),
            ];
            ps.set_subtitle_track_labels(
                std::rc::Rc::new(slint::VecModel::from(sub_tracks)).into(),
            );
            ps.set_active_subtitle_track(0); // Off

            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "tracks_panel_closed",
            "VOD playing — OSD visible",
            "OSD visible, tracks panel button in secondary tray, panel closed",
        );

        // ── Open audio/subtitle panel (right-slide) ───────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_tracks_panel(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "tracks_panel_open",
            "Tracks panel opens",
            "Right-slide panel visible: Audio section + Subtitle section with track rows",
        );

        // ── Switch audio to Arabic ────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_active_audio_track(1); // Arabic
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "audio_switched_arabic",
            "Select Arabic audio",
            "Arabic track highlighted active, English deselected",
        );

        // ── Enable English subtitles ──────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_active_subtitle_track(1); // English SRT
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "subtitles_english_enabled",
            "Enable English subtitles",
            "English SRT track active, subtitle strip visible over video",
        );

        // ── Switch subtitles to Arabic ────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_active_subtitle_track(2); // Arabic SRT
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "subtitles_arabic",
            "Switch to Arabic subtitles",
            "Arabic SRT active, panel shows checkmark on Arabic row",
        );

        // ── Turn off subtitles ────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_active_subtitle_track(0); // Off
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "subtitles_off",
            "Subtitles turned off",
            "Off row active in subtitle section",
        );

        // ── Close panel ───────────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_tracks_panel(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "tracks_panel_closed_after",
            "Panel dismissed",
            "Panel slides out, OSD returns to normal state",
        );
    }
}
