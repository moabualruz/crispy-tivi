//! J-36: Create and Edit Profile
//!
//! Dream: "Netflix-style profile creation: name input, avatar picker, Kids toggle,
//! PIN toggle. Edit existing profile. Delete with confirmation dialog."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J36;

impl Journey for J36 {
    const ID: &'static str = "j36";
    const NAME: &'static str = "Create and Edit Profile";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Settings screen — manage profiles ──────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(7); // Settings
            // One existing profile (Alex) — "Add Profile" button visible
            let profiles = vec![crate::ProfileData {
                id: "profile_alex".into(),
                name: "Alex".into(),
                avatar_color: slint::Color::from_rgb_u8(0xFF, 0x4B, 0x2B).into(),
                is_kids: false,
                is_active: true,
                pin_protected: false,
            }];
            app.set_profiles(ModelRc::new(VecModel::from(profiles)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_profiles_list",
            "Open Settings — Profiles section",
            "Existing profile (Alex) shown with Edit button; Add Profile CTA visible",
        );

        // ── Step 1: Create profile form — blank ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Simulate entering the create-profile sub-screen
            // The editing-source pattern is reused: we set show-profile-menu to indicate
            // the profile creation flow is active.
            ui.global::<AppState>().set_show_profile_menu(false);
            slint::platform::update_timers_and_animations();
        }

        harness.press_ok("add_profile_button", "Press Add Profile");

        harness.assert_screenshot(
            "create_profile_form_empty",
            "Add Profile pressed",
            "Profile creation form shown: name field, avatar grid, Kids toggle, PIN toggle — all blank",
        );

        // ── Step 2: Enter profile name ─────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Populate the editing state with a typed name
            let mut src = ui.global::<AppState>().get_editing_source();
            src.name = "Jordan".into();
            ui.global::<AppState>().set_editing_source(src);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "create_profile_name_typed",
            "User types profile name",
            "Name field shows 'Jordan'; avatar grid and toggles still visible",
        );

        // ── Step 3: Select avatar color ─────────────────────────────────────

        harness.press_right("avatar_navigate", "Navigate avatar grid");
        harness.press_ok("avatar_select_blue", "Select blue avatar");

        harness.assert_screenshot(
            "create_profile_avatar_selected",
            "Avatar color chosen",
            "Selected avatar highlighted with focus ring; preview updates instantly",
        );

        // ── Step 4: Enable Kids toggle ─────────────────────────────────────

        harness.press_down("focus_kids_toggle", "Navigate to Kids toggle");
        harness.press_ok("kids_toggle_on", "Enable Kids toggle");

        harness.assert_screenshot(
            "create_profile_kids_enabled",
            "Kids toggle ON",
            "Kids badge shown on avatar preview; content rating warning visible",
        );

        // ── Step 5: Enable PIN protection ─────────────────────────────────

        harness.press_down("focus_pin_toggle", "Navigate to PIN toggle");
        harness.press_ok("pin_toggle_on", "Enable PIN toggle");

        harness.assert_screenshot(
            "create_profile_pin_enabled",
            "PIN protection ON",
            "PIN entry field appears below toggle for initial PIN setup",
        );

        // ── Step 6: Save — profile appears in list ─────────────────────────

        harness.press_down("focus_save_button", "Navigate to Save button");
        harness.press_ok("save_profile", "Confirm save");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // Simulate Rust completing the create-profile callback — two profiles now
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
                    id: "profile_jordan".into(),
                    name: "Jordan".into(),
                    avatar_color: slint::Color::from_rgb_u8(0x00, 0x90, 0xFF).into(),
                    is_kids: true,
                    is_active: false,
                    pin_protected: true,
                },
            ];
            app.set_profiles(ModelRc::new(VecModel::from(profiles)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "profile_created_in_list",
            "Profile saved",
            "Jordan profile appears in list with Kids badge and PIN lock icon",
        );

        // ── Step 7: Edit existing profile ─────────────────────────────────

        harness.press_down("navigate_to_jordan", "Navigate to Jordan profile row");
        harness.press_right("focus_edit_button", "Navigate to Edit button");
        harness.press_ok("open_edit_form", "Open edit form for Jordan");

        harness.assert_screenshot(
            "edit_profile_form",
            "Edit Profile form",
            "Form pre-populated: name 'Jordan', blue avatar selected, Kids ON, PIN ON",
        );

        // Rename the profile
        if let Some(ui) = harness.ui::<AppWindow>() {
            let mut src = ui.global::<AppState>().get_editing_source();
            src.name = "Jordan (edited)".into();
            ui.global::<AppState>().set_editing_source(src);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "edit_profile_renamed",
            "User edits profile name",
            "Name field shows updated value with cursor",
        );

        // ── Step 8: Delete profile — confirmation dialog ──────────────────

        harness.press_down("focus_delete_button", "Navigate to Delete button");
        harness.press_ok("press_delete", "Press Delete");

        harness.assert_screenshot(
            "delete_profile_confirmation",
            "Delete button pressed",
            "Confirmation dialog: 'Delete Jordan? This cannot be undone.' with Cancel / Delete",
        );

        harness.press_right("focus_delete_confirm", "Navigate to Delete in dialog");
        harness.press_ok("confirm_delete", "Confirm deletion");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // Rust removes the profile — back to one profile
            let profiles = vec![crate::ProfileData {
                id: "profile_alex".into(),
                name: "Alex".into(),
                avatar_color: slint::Color::from_rgb_u8(0xFF, 0x4B, 0x2B).into(),
                is_kids: false,
                is_active: true,
                pin_protected: false,
            }];
            app.set_profiles(ModelRc::new(VecModel::from(profiles)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "profile_deleted",
            "Profile deleted",
            "Jordan removed from list; only Alex remains; deletion confirmed",
        );
    }
}
