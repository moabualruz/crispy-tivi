//! J-04: First-Time Content Discovery (Guided Tour)
//!
//! Dream: "Getting Started checklist card on first home visit. 3-step guided
//! exploration. Dismissible, never returns once dismissed."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J04;

impl Journey for J04 {
    const ID: &'static str = "j04";
    const NAME: &'static str = "First-Time Content Discovery (Guided Tour)";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Home screen with Getting Started checklist ─────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(0); // Home
            ui.global::<AppState>().set_getting_started_dismissed(false);
            ui.global::<AppState>().set_gs_source_added(true);
            ui.global::<AppState>().set_gs_browsed_channels(false);
            ui.global::<AppState>().set_gs_played_channel(false);
            ui.global::<AppState>().set_gs_profile_set(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "home_getting_started_card",
            "First home visit after onboarding",
            "Getting Started checklist card visible on home screen with partial completion",
        );

        // ── Step 1: Launch guided tour ─────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_guided_tour(true);
            ui.global::<AppState>().set_guided_tour_step(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "guided_tour_step_0",
            "Guided tour starts",
            "Tour overlay shown at step 0 — highlights navigation bar",
        );

        // ── Step 2: Tour step 1 — Live TV ─────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_guided_tour_step(1);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "guided_tour_step_1",
            "Advance tour to step 1",
            "Tour highlights Live TV section with explanation",
        );

        // ── Step 3: Tour step 2 — EPG ─────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_guided_tour_step(2);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "guided_tour_step_2",
            "Advance tour to step 2",
            "Tour highlights EPG section with explanation",
        );

        // ── Step 4: Tour step 3 — Search ──────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_guided_tour_step(3);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "guided_tour_step_3",
            "Advance tour to step 3",
            "Tour highlights Search pill with explanation",
        );

        // ── Step 5: Tour dismissed ─────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_guided_tour(false);
            ui.global::<AppState>().set_getting_started_dismissed(false);
            // Mark some checklist items done to show partial progress
            ui.global::<AppState>().set_gs_browsed_channels(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "home_after_tour_checklist_partial",
            "Tour ends, return to home",
            "Getting Started card still visible with browse-channels item checked",
        );

        // ── Step 6: All checklist items complete ──────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_gs_played_channel(true);
            ui.global::<AppState>().set_gs_profile_set(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "home_checklist_all_done",
            "All getting-started steps completed",
            "All checklist items checked, dismiss button prominent",
        );

        // ── Step 7: Checklist dismissed permanently ───────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_getting_started_dismissed(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "home_checklist_dismissed",
            "User dismisses checklist",
            "Checklist card gone, home screen shows full content layout",
        );
    }
}
