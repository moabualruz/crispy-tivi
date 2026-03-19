//! J-47: Analytics Opt-In / Opt-Out Management
//!
//! Dream: "Same toggles as initial consent. Detailed data explanations. Delete
//! My Data option."

use crate::harness::{
    db::TestDb, input::InputEmulation, journey_runner::Journey, renderer::ScreenshotHarness,
};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J47;

impl Journey for J47 {
    const ID: &'static str = "j47";
    const NAME: &'static str = "Analytics Opt-In / Opt-Out";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Privacy section in Settings ───────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(7); // Settings
            // Both consents OFF (user previously declined)
            ui.global::<AppState>()
                .set_analytics_playback_consent(false);
            ui.global::<AppState>().set_analytics_crash_consent(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_privacy_section",
            "Navigate to Privacy section in Settings",
            "Privacy section visible with same toggles as initial consent, both OFF",
        );

        // ── Step 1: Enable playback analytics ─────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_analytics_playback_consent(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "analytics_playback_enabled",
            "Enable playback analytics toggle",
            "Playback analytics ON — detailed data explanation visible below toggle",
        );

        // ── Step 2: Enable crash reports ──────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_analytics_crash_consent(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "analytics_all_enabled",
            "Enable crash reports toggle",
            "Both analytics toggles ON, detailed explanations visible for each",
        );

        // ── Step 3: Focus on Delete My Data option ────────────────────────────

        harness.press_down(
            "analytics_delete_data_focused",
            "Navigate focus to Delete My Data option",
        );

        harness.assert_screenshot(
            "analytics_delete_data_option",
            "Delete My Data focused",
            "Delete My Data button visible with destructive styling and focus ring",
        );

        // ── Step 4: Opt back out of playback analytics ────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_analytics_playback_consent(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "analytics_playback_disabled",
            "Disable playback analytics",
            "Playback analytics OFF, crash reports still ON — granular per-category control",
        );

        // ── Step 5: Delete all data — confirmation dialog ─────────────────────

        harness.press_ok("delete_data_dialog_triggered", "Trigger Delete My Data");

        harness.assert_screenshot(
            "delete_data_confirmation_dialog",
            "Delete My Data confirmation dialog",
            "Confirmation dialog shown before destructive action — requires explicit confirmation",
        );

        // ── Step 6: Cancel deletion ───────────────────────────────────────────

        harness.press_back("delete_data_dialog_cancelled", "Cancel data deletion");

        harness.assert_screenshot(
            "analytics_after_cancel_delete",
            "Dialog dismissed after cancel",
            "Dialog dismissed, analytics settings unchanged",
        );
    }
}
