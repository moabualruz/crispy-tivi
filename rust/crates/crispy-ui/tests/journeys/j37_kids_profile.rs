//! J-37: Kids Profile Setup and Experience
//!
//! Dream: "Activate a Kids profile. UI switches to brighter skin, larger cards,
//! simplified nav. Age-rated content filtered out. PIN required to exit."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J37;

impl Journey for J37 {
    const ID: &'static str = "j37";
    const NAME: &'static str = "Kids Profile Setup";
    const DEPENDS_ON: &'static [&'static str] = &["j36"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Profile picker — Kids profile visible ──────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            let profiles = vec![
                crate::ProfileData {
                    id: "profile_alex".into(),
                    name: "Alex".into(),
                    avatar_color: slint::Color::from_rgb_u8(0xFF, 0x4B, 0x2B).into(),
                    is_kids: false,
                    is_active: true,
                    pin_protected: false,
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
            app.set_is_kids_mode(false);
            app.set_active_screen(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "profile_picker_with_kids",
            "Profile picker shown",
            "Kids profile tile visible with green avatar and Kids badge",
        );

        // ── Step 1: Select Kids profile ────────────────────────────────────

        harness.press_right("focus_kids_tile", "Navigate to Kids tile");
        harness.press_ok("select_kids_profile", "Select Kids profile");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_profile_picker(false);
            app.set_active_profile_name("Kids".into());
            app.set_is_kids_mode(true);
            app.set_active_screen(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "kids_home_screen",
            "Kids profile activated",
            "Home screen renders Kids skin: brighter colors, larger cards, simplified nav",
        );

        // ── Step 2: Kids nav — simplified (no EPG, no adult categories) ────

        harness.assert_screenshot(
            "kids_simplified_nav",
            "Kids navigation bar",
            "Nav shows only: For You, Movies, Shows — no EPG, no Library adult tabs",
        );

        // ── Step 3: Kids movies — age-rated content hidden ─────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(2); // Movies
            // Rating limit enforced — only G/PG content visible
            app.set_parental_rating_limit(1); // PG
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "kids_movies_filtered",
            "Navigate to Movies in Kids mode",
            "Movies screen shows only G/PG rated content; R/adult titles absent",
        );

        // ── Step 4: Kids series — same filter ──────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(3); // Series
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "kids_series_filtered",
            "Navigate to Series in Kids mode",
            "Series screen shows age-appropriate titles only",
        );

        // ── Step 5: Attempt to exit Kids mode — PIN required ──────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(0); // Home
            slint::platform::update_timers_and_animations();
        }

        // User opens profile menu to switch profile
        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_profile_menu(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "kids_profile_menu_open",
            "Open profile menu to switch",
            "Profile menu shown over Kids screen",
        );

        // Switching to a non-Kids profile triggers PIN dialog
        harness.press_ok("switch_to_adult_profile", "Select adult profile");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_profile_menu(false);
            app.set_show_pin_dialog(true);
            app.set_pin_target_profile_name("Alex".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "kids_exit_pin_required",
            "Exit Kids mode — PIN required",
            "PIN dialog: '4-digit PIN required to exit Kids mode' — D-pad number pad",
        );

        // ── Step 6: Enter correct PIN — Kids mode exits ────────────────────

        harness.press_ok("pin_1", "Enter PIN digit 1");
        harness.press_ok("pin_2", "Enter PIN digit 2");
        harness.press_ok("pin_3", "Enter PIN digit 3");
        harness.press_ok("pin_4", "Enter PIN digit 4 — correct");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_pin_dialog(false);
            app.set_is_kids_mode(false);
            app.set_parental_rating_limit(-1);
            app.set_active_profile_name("Alex".into());
            app.set_active_screen(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "kids_mode_exited",
            "Correct PIN — Kids mode exited",
            "Standard skin restored; Alex profile active; full content library visible",
        );
    }
}
