//! J-34: Backup and Restore Settings
//!
//! Dream: "Export to JSON. Import with merge (non-destructive). Encrypted
//! credentials stay encrypted. Cross-platform compatible."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::ComponentHandle;

pub struct J34;

impl Journey for J34 {
    const ID: &'static str = "j34";
    const NAME: &'static str = "Backup and Restore Settings";
    const DEPENDS_ON: &'static [&'static str] = &["j32"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Settings — Backup section ─────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(7); // Settings
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "settings_backup_section",
            "Navigate to Backup section in Settings",
            "Backup section visible: Export button and Import button",
        );

        // ── Step 1: Export in progress ────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_syncing(true);
            ui.global::<AppState>()
                .set_sync_message("Preparing backup…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "backup_export_progress",
            "Trigger Export Backup",
            "Export spinner shown while serialising settings to JSON",
        );

        // ── Step 2: Export complete ────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_syncing(false);
            ui.global::<AppState>()
                .set_sync_message("Backup saved to crispy-tivi-backup.json".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "backup_export_done",
            "Export completes",
            "Success toast: file path shown, credentials encrypted in export",
        );

        // ── Step 3: Import ready ───────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_sync_message("".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "backup_import_ready",
            "Select Import Backup",
            "File picker or path entry shown for selecting backup JSON",
        );

        // ── Step 4: Import merge in progress ──────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_syncing(true);
            ui.global::<AppState>().set_sync_progress(0.5);
            ui.global::<AppState>()
                .set_sync_message("Merging settings (non-destructive)…".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "backup_import_progress",
            "Import in progress",
            "Progress indicator shown — merge does not delete existing data",
        );

        // ── Step 5: Import complete ────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_syncing(false);
            ui.global::<AppState>().set_sync_progress(1.0);
            ui.global::<AppState>()
                .set_sync_message("Restore complete — 3 sources imported".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "backup_import_done",
            "Import completes",
            "Success message: N sources imported, encrypted credentials preserved",
        );
    }
}
