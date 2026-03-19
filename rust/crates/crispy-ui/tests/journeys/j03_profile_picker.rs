//! J-03: Returning User — Profile Picker to Resume
//!
//! Dream: "Netflix-style profile tiles on launch. PIN protection with lockout.
//! Last-used profile pre-focused. Per-profile state isolation."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::{ComponentHandle, Model, ModelRc, VecModel};

pub struct J03;

impl Journey for J03 {
    const ID: &'static str = "j03";
    const NAME: &'static str = "Returning User — Profile Picker to Resume";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Launch — profile picker shown on returning visit ──────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();

            // Populate 3 profiles (Netflix-style tiles)
            let profiles = vec![
                crate::ProfileData {
                    id: "profile_alex".into(),
                    name: "Alex".into(),
                    avatar_color: slint::Color::from_rgb_u8(0xFF, 0x4B, 0x2B).into(),
                    is_kids: false,
                    is_active: true, // last-used profile — pre-focused
                    pin_protected: false,
                },
                crate::ProfileData {
                    id: "profile_sam".into(),
                    name: "Sam".into(),
                    avatar_color: slint::Color::from_rgb_u8(0x00, 0x90, 0xFF).into(),
                    is_kids: false,
                    is_active: false,
                    pin_protected: true, // PIN-protected profile
                },
                crate::ProfileData {
                    id: "profile_kids".into(),
                    name: "Kids".into(),
                    avatar_color: slint::Color::from_rgb_u8(0x00, 0xC8, 0x53).into(),
                    is_kids: true,
                    is_active: false,
                    pin_protected: false,
                },
            ];
            app.set_profiles(ModelRc::new(VecModel::from(profiles)));
            app.set_show_profile_picker(true);
            app.set_active_screen(0); // Home
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "profile_picker_shown",
            "App launches with returning user",
            "Netflix-style profile tiles visible; last-used profile pre-focused",
        );

        // ── Step 1: Navigate between profile tiles ─────────────────────────

        harness.press_right("profile_focus_sam", "Navigate to Sam profile");

        harness.assert_screenshot(
            "profile_sam_focused",
            "D-pad right to Sam",
            "Sam tile focused with white focus ring",
        );

        harness.press_right("profile_focus_kids", "Navigate to Kids profile");

        harness.assert_screenshot(
            "profile_kids_focused",
            "D-pad right to Kids",
            "Kids tile focused; Kids badge visible",
        );

        harness.press_left("profile_sam_refocused", "Navigate back to Sam");

        // ── Step 2: Select PIN-protected profile — PIN dialog appears ──────

        harness.press_ok("select_sam_profile", "Select PIN-protected Sam profile");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_pin_dialog(true);
            app.set_pin_target_profile_id("profile_sam".into());
            app.set_pin_target_profile_name("Sam".into());
            app.set_pin_wrong(false);
            app.set_show_profile_picker(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "pin_dialog_shown",
            "PIN dialog appears for Sam",
            "PIN entry dialog visible; profile name shown; 4 empty PIN dots",
        );

        // ── Step 3: Enter wrong PIN — lockout feedback ─────────────────────

        harness.press_ok("pin_digit_1", "Enter first PIN digit");
        harness.press_ok("pin_digit_2", "Enter second PIN digit");
        harness.press_ok("pin_digit_3", "Enter third PIN digit");
        harness.press_ok("pin_digit_4", "Enter fourth PIN digit — wrong PIN");

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_pin_wrong(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "pin_wrong_feedback",
            "Wrong PIN entered",
            "PIN dots shake; 'Wrong PIN' error shown; field clears for retry",
        );

        // ── Step 4: Dismiss PIN dialog — return to picker ─────────────────

        harness.press_back("pin_dismissed", "Back dismisses PIN dialog");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_pin_dialog(false);
            app.set_pin_wrong(false);
            app.set_show_profile_picker(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "returned_to_picker",
            "PIN dismissed — back to profile picker",
            "Profile picker visible again; Sam tile still focused",
        );

        // ── Step 5: Select non-PIN profile (Alex) — enters app ────────────

        harness.press_left("profile_alex_focused", "Navigate to Alex (no PIN)");
        harness.press_ok("select_alex", "Select Alex profile");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_profile_picker(false);
            app.set_active_profile_name("Alex".into());
            app.set_active_screen(0); // Home
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "home_as_alex",
            "Alex profile selected — home screen",
            "Home screen shown; Alex profile active; per-profile content state loaded",
        );
    }
}
