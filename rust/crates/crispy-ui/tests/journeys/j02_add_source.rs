//! J-02: Add Additional Source (Post-Onboarding)
//!
//! Dream: "Add source from Settings without interrupting playback. Same dynamic
//! per-type form. Channels merge automatically with duplicate detection."

use crate::harness::{
    db::TestDb, input::InputEmulation, journey_runner::Journey, renderer::ScreenshotHarness,
};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J02;

impl Journey for J02 {
    const ID: &'static str = "j02";
    const NAME: &'static str = "Add Additional Source (Post-Onboarding)";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Navigate to Settings ──────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(7); // Settings
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_screen",
            "Navigate to Settings",
            "Settings screen visible with source management section",
        );

        // ── Step 1: Open Add Source dialog ────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_source_dialog(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_dialog_open",
            "Open Add Source dialog",
            "Source dialog appears with type selector and empty form",
        );

        // ── Step 2: M3U form ──────────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let mut src = ui.global::<AppState>().get_editing_source();
            src.source_type = "m3u".into();
            src.name = "".into();
            src.url = "".into();
            ui.global::<AppState>().set_editing_source(src);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_form_m3u_empty",
            "Select M3U type",
            "M3U form shown with URL field only",
        );

        // ── Step 3: Type M3U source details ───────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let mut src = ui.global::<AppState>().get_editing_source();
            src.name = "My Extra M3U".into();
            src.url = "http://iptv.example.com/extra.m3u".into();
            ui.global::<AppState>().set_editing_source(src);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_form_m3u_filled",
            "Enter M3U name and URL",
            "M3U form fields populated, ready to validate",
        );

        // ── Step 4: Switch to Xtream type ─────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let mut src = ui.global::<AppState>().get_editing_source();
            src.source_type = "xtream".into();
            src.name = "My Xtream".into();
            src.url = "http://xtream.example.com".into();
            src.username = "user123".into();
            src.password = "pass456".into();
            ui.global::<AppState>().set_editing_source(src);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_form_xtream_filled",
            "Switch to Xtream type and fill credentials",
            "Xtream form with server, username, and password fields filled",
        );

        // ── Step 5: Switch to Stalker type ────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let mut src = ui.global::<AppState>().get_editing_source();
            src.source_type = "stalker".into();
            src.name = "My Stalker Portal".into();
            src.url = "http://stalker.example.com".into();
            src.username = "AA:BB:CC:DD:EE:FF".into();
            src.password = "".into();
            ui.global::<AppState>().set_editing_source(src);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_form_stalker_filled",
            "Switch to Stalker type and fill portal/MAC",
            "Stalker form with portal URL and MAC address fields filled",
        );

        // ── Step 6: Validation in progress ────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            // source-validate-state: 0=idle, 1=validating, 2=ok, 3=error
            ui.global::<AppState>().set_source_validate_state(1);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_validating",
            "Validate source",
            "Validation spinner shown while checking connectivity",
        );

        // ── Step 7: Validation success ────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_source_validate_state(2);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "source_validation_ok",
            "Validation succeeds",
            "Green success indicator shown, Save button enabled",
        );

        // ── Step 8: Sync progress after save ──────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_source_dialog(false);
            ui.global::<AppState>().set_is_syncing(true);
            ui.global::<AppState>().set_sync_progress(0.35);
            ui.global::<AppState>()
                .set_sync_message("Syncing channels…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "sync_in_progress",
            "Source saved, sync starts automatically",
            "Sync progress indicator visible in settings",
        );

        // ── Step 9: Sync complete, sources list updated ───────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_syncing(false);
            ui.global::<AppState>().set_sync_progress(1.0);
            ui.global::<AppState>()
                .set_sync_message("Sync complete".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "sync_complete",
            "Sync completes",
            "Source card visible in list with green health dot and channel count",
        );
    }
}
