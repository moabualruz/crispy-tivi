//! J-33: App Settings — Language / Theme / Quality
//!
//! Dream: "Categorized settings. Immediate effect (no save button). Per-profile
//! where appropriate. Accessibility font size."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J33;

impl Journey for J33 {
    const ID: &'static str = "j33";
    const NAME: &'static str = "App Settings — Language / Theme / Quality";
    const DEPENDS_ON: &'static [&'static str] = &["j32"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Settings screen ────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(7); // Settings
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_overview",
            "Open Settings screen",
            "Categorized settings visible: Sources, Appearance, Playback, Privacy, About",
        );

        // ── Step 1: Language — English (default) ──────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_language("en".into());
            ui.global::<AppState>().set_is_rtl(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_language_en",
            "View language selection",
            "Language setting shows English selected",
        );

        // ── Step 2: Switch to Arabic (RTL) ────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_language("ar".into());
            ui.global::<AppState>().set_is_rtl(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_language_ar_rtl",
            "Switch language to Arabic",
            "UI mirrors to RTL layout immediately, Arabic text rendered",
        );

        // Reset to English for remainder
        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_language("en".into());
            ui.global::<AppState>().set_is_rtl(false);
            slint::platform::update_timers_and_animations();
        }

        // ── Step 3: Theme setting ──────────────────────────────────────────────

        harness.assert_screenshot(
            "settings_theme_dark",
            "View theme options",
            "Theme section shown — Dark selected (default)",
        );

        // ── Step 4: Video quality setting ─────────────────────────────────────

        harness.assert_screenshot(
            "settings_video_quality",
            "View video quality options",
            "Quality section: Auto, 1080p, 720p, 480p — Auto selected",
        );

        // ── Step 5: Playback settings ─────────────────────────────────────────

        harness.assert_screenshot(
            "settings_playback",
            "View playback settings",
            "Playback: audio language, subtitle language, hardware decode toggle, autoplay next",
        );

        // ── Step 6: Startup screen setting ────────────────────────────────────

        harness.assert_screenshot(
            "settings_startup_screen",
            "View startup screen options",
            "Startup screen setting: Home, Live TV, Last Watched",
        );

        // ── Step 7: Kids mode toggle ───────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_kids_mode(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_kids_mode_on",
            "Toggle kids mode on",
            "Kids mode enabled — UI shows bright simplified skin preview",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_kids_mode(false);
            slint::platform::update_timers_and_animations();
        }

        // ── Step 8: Analytics section ──────────────────────────────────────────

        harness.assert_screenshot(
            "settings_analytics_section",
            "Navigate to Privacy/Analytics section",
            "Analytics toggles shown — all default OFF",
        );

        // ── Step 9: About section ─────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_attribution(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_about",
            "Navigate to About section",
            "About section: app version, open source licenses link, diagnostics shortcut",
        );
    }
}
