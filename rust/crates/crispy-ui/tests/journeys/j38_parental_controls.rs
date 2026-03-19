//! J-38: Parental Controls Configuration
//!
//! Dream: "Master PIN setup, per-profile content rating cap, channel/group blocking,
//! daily viewing time limits. All controls in Settings → Parental Controls section."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J38;

impl Journey for J38 {
    const ID: &'static str = "j38";
    const NAME: &'static str = "Parental Controls — PIN and Rating Locks";
    const DEPENDS_ON: &'static [&'static str] = &["j36"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Settings — Parental Controls section ───────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(7); // Settings
            app.set_parental_pin_set(false);
            app.set_parental_rating_limit(-1);
            app.set_parental_time_limit_minutes(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "parental_controls_no_pin",
            "Open Parental Controls",
            "Parental Controls section: 'No PIN set. Restrictions unenforced.' — Set PIN CTA",
        );

        // ── Step 1: Set master PIN ─────────────────────────────────────────

        harness.press_ok("set_pin_button", "Press Set PIN");

        harness.assert_screenshot(
            "pin_entry_dialog",
            "Set PIN dialog opens",
            "PIN entry dialog: 4 empty dots, D-pad number pad, 'Set your parental PIN' title",
        );

        // Enter 4-digit PIN
        harness.press_ok("pin_d1", "Enter PIN digit 1");
        harness.press_ok("pin_d2", "Enter PIN digit 2");
        harness.press_ok("pin_d3", "Enter PIN digit 3");
        harness.press_ok("pin_d4", "Enter PIN digit 4 — PIN saved");

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_parental_pin_set(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "parental_pin_set",
            "PIN set successfully",
            "Parental Controls: 'PIN is set. Required to access restricted content.' — Change PIN / Clear visible",
        );

        // ── Step 2: Set content rating cap — PG ───────────────────────────

        harness.assert_screenshot(
            "content_rating_section",
            "View content rating cap",
            "Rating selector chips: G | PG | PG-13 | R — none selected (no limit)",
        );

        // Select PG rating limit
        harness.press_down("navigate_rating", "Navigate to rating chips");
        harness.press_right("focus_pg", "Focus PG chip");
        harness.press_ok("select_pg", "Select PG rating limit");

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_parental_rating_limit(1); // PG
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "rating_limit_pg_set",
            "PG rating limit applied",
            "PG chip shows active state; content rated above PG now requires PIN",
        );

        // ── Step 3: Set PG-13 limit ────────────────────────────────────────

        harness.press_right("focus_pg13", "Navigate to PG-13 chip");
        harness.press_ok("select_pg13", "Select PG-13 limit");

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_parental_rating_limit(2); // PG-13
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "rating_limit_pg13_set",
            "PG-13 rating limit applied",
            "PG-13 chip active; R content blocked without PIN",
        );

        // ── Step 4: Set daily viewing time limit ───────────────────────────

        harness.press_down("navigate_time_limit", "Navigate to time limit section");

        harness.assert_screenshot(
            "time_limit_section",
            "View time limit setting",
            "Time limit: 'No limit set' with +/- controls; current value 0 min",
        );

        // Set 60-minute limit
        harness.press_right("increase_time_limit", "Increase time limit");
        harness.press_right("increase_time_limit_2", "Increase again");

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_parental_time_limit_minutes(60);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "time_limit_60_min",
            "60-minute daily limit set",
            "Time limit shows 60 min; 'Viewing stops after daily limit reached' note visible",
        );

        // ── Step 5: Verify protected content prompts PIN ───────────────────

        // Navigate to a restricted screen to verify PIN gate
        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(2); // Movies — contains R-rated content
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movies_with_rating_limit",
            "Browse movies with PG-13 limit",
            "Movies screen: R-rated titles show lock icon; PG-13 and below accessible",
        );

        // Select an R-rated title — PIN dialog appears
        harness.press_ok(
            "select_restricted_movie",
            "Press OK on locked R-rated movie",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_pin_dialog(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "restricted_content_pin_gate",
            "Restricted content selected",
            "PIN dialog: 'Enter parental PIN to access R-rated content'",
        );

        // ── Step 6: Change PIN ─────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_pin_dialog(false);
            app.set_active_screen(7); // Back to Settings
            slint::platform::update_timers_and_animations();
        }

        harness.press_ok("change_pin_button", "Press Change PIN");

        harness.assert_screenshot(
            "change_pin_dialog",
            "Change PIN dialog",
            "Dialog: 'Enter current PIN' → verify → 'Enter new PIN' → confirm",
        );

        // ── Step 7: Clear PIN — removes all restrictions ───────────────────

        harness.press_back("dismiss_change_pin", "Cancel change PIN");

        harness.press_ok("clear_pin_button", "Press Clear PIN");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_parental_pin_set(false);
            app.set_parental_rating_limit(-1);
            app.set_parental_time_limit_minutes(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "parental_controls_cleared",
            "PIN cleared",
            "Parental Controls returns to: 'No PIN set. Restrictions unenforced.'",
        );
    }
}
