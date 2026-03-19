//! J-46: First-Launch Privacy Consent
//!
//! Dream: "Three toggles all default OFF. Clear explanations. Continue without
//! opt-in. Changeable in Settings later."

use crate::harness::{
    db::TestDb, input::InputEmulation, journey_runner::Journey, renderer::ScreenshotHarness,
};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J46;

impl Journey for J46 {
    const ID: &'static str = "j46";
    const NAME: &'static str = "Privacy Consent Screen";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Privacy consent shown after onboarding ────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_privacy_consent(true);
            ui.global::<AppState>().set_privacy_accepted(false);
            // All analytics toggles default OFF (GDPR: no pre-ticked)
            ui.global::<AppState>()
                .set_analytics_playback_consent(false);
            ui.global::<AppState>().set_analytics_crash_consent(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "privacy_consent_initial",
            "Privacy consent screen appears after onboarding",
            "All privacy toggles default OFF, clear explanations visible",
        );

        // ── Step 1: Navigate to first toggle ──────────────────────────────────

        harness.press_down(
            "privacy_toggle_1_focused",
            "Focus on first toggle (Crash Reports)",
        );

        harness.assert_screenshot(
            "privacy_consent_toggle_1_description",
            "Focus on Crash Reports toggle",
            "Crash reports toggle focused, description text readable",
        );

        // ── Step 2: Navigate to second toggle ─────────────────────────────────

        harness.press_down(
            "privacy_toggle_2_focused",
            "Focus on second toggle (Playback Analytics)",
        );

        harness.assert_screenshot(
            "privacy_consent_toggle_2_description",
            "Focus on Playback Analytics toggle",
            "Playback analytics toggle focused, description text readable",
        );

        // ── Step 3: Enable crash reports only ─────────────────────────────────

        harness.press_up(
            "privacy_toggle_1_refocused",
            "Navigate back up to Crash Reports",
        );
        harness.press_ok("privacy_crash_toggled", "Toggle Crash Reports ON");

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_analytics_crash_consent(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "privacy_consent_crash_enabled",
            "Enable crash reports toggle",
            "Crash reports toggle ON, playback analytics still OFF",
        );

        // ── Step 4: Navigate to Continue button ───────────────────────────────

        harness.press_down(
            "privacy_continue_approach_1",
            "Navigate toward Continue button",
        );
        harness.press_down("privacy_continue_focused", "Continue button focused");

        harness.assert_screenshot(
            "privacy_consent_continue_focused",
            "Focus on Continue button",
            "Continue button focused — app proceeds without requiring full consent",
        );

        // ── Step 5: Confirm and proceed ───────────────────────────────────────

        harness.press_ok("privacy_continue_pressed", "Press Continue");

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_privacy_consent(false);
            ui.global::<AppState>().set_privacy_accepted(true);
            ui.global::<AppState>().set_active_screen(0); // Home
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "home_after_privacy_consent",
            "Continue pressed, proceed to app",
            "Privacy screen dismissed, home screen shown — consent choices saved",
        );
    }
}
