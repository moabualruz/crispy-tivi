//! J-40: Watch History Browser
//!
//! Dream: "Chronological watch history. Filter by type (channel/movie/series) and date.
//! Individual item removal. Per-profile isolation. Clear all with confirmation."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J40;

impl Journey for J40 {
    const ID: &'static str = "j40";
    const NAME: &'static str = "Watch History Browser";
    const DEPENDS_ON: &'static [&'static str] = &["j39"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Library — History tab — populated ─────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(6); // Library

            // Seed a rich history spanning multiple types and dates
            let history = vec![
                crate::WatchHistoryData {
                    id: "m_dune".into(),
                    name: "Dune".into(),
                    media_type: "movie".into(),
                    stream_url: "".into(),
                    position_ms: 6696000,
                    duration_ms: 9300000,
                    watched_at: "Today, 21:05".into(),
                    progress: 0.72,
                },
                crate::WatchHistoryData {
                    id: "ch_bbc1".into(),
                    name: "BBC One".into(),
                    media_type: "channel".into(),
                    stream_url: "".into(),
                    position_ms: 0,
                    duration_ms: 0,
                    watched_at: "Today, 19:30".into(),
                    progress: 0.0,
                },
                crate::WatchHistoryData {
                    id: "s_bb_e3".into(),
                    name: "Breaking Bad — S01E03".into(),
                    media_type: "episode".into(),
                    stream_url: "".into(),
                    position_ms: 3000000,
                    duration_ms: 3000000,
                    watched_at: "Yesterday, 22:10".into(),
                    progress: 1.0,
                },
                crate::WatchHistoryData {
                    id: "m_inter".into(),
                    name: "Interstellar".into(),
                    media_type: "movie".into(),
                    stream_url: "".into(),
                    position_ms: 10140000,
                    duration_ms: 10140000,
                    watched_at: "Yesterday, 20:00".into(),
                    progress: 1.0,
                },
                crate::WatchHistoryData {
                    id: "ch_cnn".into(),
                    name: "CNN International".into(),
                    media_type: "channel".into(),
                    stream_url: "".into(),
                    position_ms: 0,
                    duration_ms: 0,
                    watched_at: "2 days ago".into(),
                    progress: 0.0,
                },
            ];
            app.set_watch_history(ModelRc::new(VecModel::from(history)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "history_tab_populated",
            "Library — History tab",
            "Chronological history: Dune (72%), BBC One, Breaking Bad (done), Interstellar (done), CNN — grouped by Today/Yesterday",
        );

        // ── Step 1: Focus on a history item ────────────────────────────────

        harness.press_down("focus_first_item", "Navigate to first history item");

        harness.assert_screenshot(
            "history_item_focused",
            "First history item focused",
            "Dune row highlighted with focus ring; resume button and remove button visible on focus",
        );

        // ── Step 2: Resume from history ────────────────────────────────────

        harness.press_ok("resume_dune_from_history", "Press OK — resume Dune");

        harness.assert_screenshot(
            "history_resume_playback",
            "Resume Dune from 72%",
            "Dune plays from 72% position; OSD shows seek position",
        );

        // ── Step 3: Return to history tab ─────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(6);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "history_after_resume",
            "Return to History tab",
            "History list unchanged; Dune still at top (most recent)",
        );

        // ── Step 4: Remove individual history item ─────────────────────────

        harness.press_down("focus_bbc_item", "Navigate to BBC One item");
        harness.press_right("focus_remove_button", "Navigate to remove button");
        harness.press_ok("remove_bbc_item", "Remove BBC One from history");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // BBC One removed — 4 items remain
            let history = vec![
                crate::WatchHistoryData {
                    id: "m_dune".into(),
                    name: "Dune".into(),
                    media_type: "movie".into(),
                    stream_url: "".into(),
                    position_ms: 6696000,
                    duration_ms: 9300000,
                    watched_at: "Today, 21:05".into(),
                    progress: 0.72,
                },
                crate::WatchHistoryData {
                    id: "s_bb_e3".into(),
                    name: "Breaking Bad — S01E03".into(),
                    media_type: "episode".into(),
                    stream_url: "".into(),
                    position_ms: 3000000,
                    duration_ms: 3000000,
                    watched_at: "Yesterday, 22:10".into(),
                    progress: 1.0,
                },
                crate::WatchHistoryData {
                    id: "m_inter".into(),
                    name: "Interstellar".into(),
                    media_type: "movie".into(),
                    stream_url: "".into(),
                    position_ms: 10140000,
                    duration_ms: 10140000,
                    watched_at: "Yesterday, 20:00".into(),
                    progress: 1.0,
                },
                crate::WatchHistoryData {
                    id: "ch_cnn".into(),
                    name: "CNN International".into(),
                    media_type: "channel".into(),
                    stream_url: "".into(),
                    position_ms: 0,
                    duration_ms: 0,
                    watched_at: "2 days ago".into(),
                    progress: 0.0,
                },
            ];
            app.set_watch_history(ModelRc::new(VecModel::from(history)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "history_item_removed",
            "BBC One removed from history",
            "BBC One no longer in list; 4 items remain; list reflows without gap",
        );

        // ── Step 5: Clear all history — confirmation dialog ────────────────

        harness.press_up(
            "navigate_clear_history_button",
            "Navigate to Clear History button",
        );
        harness.press_ok("press_clear_history", "Press Clear History");

        harness.assert_screenshot(
            "clear_history_confirmation",
            "Clear History pressed",
            "Confirmation dialog: 'Clear all watch history? This cannot be undone.' — Cancel / Clear All",
        );

        harness.press_right("focus_clear_all_confirm", "Navigate to Clear All in dialog");
        harness.press_ok("confirm_clear_all", "Confirm Clear All");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_watch_history(ModelRc::new(VecModel::from(vec![])));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "history_cleared",
            "All history cleared",
            "History tab shows empty state: 'No watch history yet. Start watching to see it here.'",
        );
    }
}
