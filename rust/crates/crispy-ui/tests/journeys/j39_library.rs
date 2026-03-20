//! J-39: Library and Favorites Screen
//!
//! Dream: "Unified library hub: Continue Watching, Watchlist, Favorites, History,
//! custom collections. All per-profile. Instant access without network."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J39;

impl Journey for J39 {
    const ID: &'static str = "j39";
    const NAME: &'static str = "Library and Favorites Screen";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Navigate to Library (tab index 6) ─────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(6); // Library

            if !harness.has_real_data() {
                // Seed some VOD items for favorites display
                let movies = vec![
                    crate::VodData {
                        id: "m001".into(),
                        name: "Interstellar".into(),
                        poster_url: "".into(),
                        backdrop_url: "".into(),
                        stream_url: "".into(),
                        item_type: "movie".into(),
                        description: "".into(),
                        duration_minutes: 169,
                        is_favorite: true,
                        rating: "PG".into(),
                        year: "2014".into(),
                        genre: "Sci-Fi".into(),
                        source_id: "src1".into(),
                        series_id: "".into(),
                        season: 0,
                        episode: 0,
                        poster: Default::default(),
                    },
                    crate::VodData {
                        id: "m002".into(),
                        name: "Dune".into(),
                        poster_url: "".into(),
                        backdrop_url: "".into(),
                        stream_url: "".into(),
                        item_type: "movie".into(),
                        description: "".into(),
                        duration_minutes: 155,
                        is_favorite: true,
                        rating: "PG-13".into(),
                        year: "2021".into(),
                        genre: "Sci-Fi".into(),
                        source_id: "src1".into(),
                        series_id: "".into(),
                        season: 0,
                        episode: 0,
                        poster: Default::default(),
                    },
                ];
                app.set_movies(ModelRc::new(VecModel::from(movies)));

                // Seed watch history
                let history = vec![
                    crate::WatchHistoryData {
                        id: "m002".into(),
                        name: "Dune".into(),
                        media_type: "movie".into(),
                        stream_url: "".into(),
                        position_ms: 4914000, // ~82 min of 155 = 45%
                        duration_ms: 9300000,
                        watched_at: "Today, 20:15".into(),
                        progress: 0.45,
                    },
                    crate::WatchHistoryData {
                        id: "ch_bbc1".into(),
                        name: "BBC One".into(),
                        media_type: "channel".into(),
                        stream_url: "".into(),
                        position_ms: 0,
                        duration_ms: 0,
                        watched_at: "Today, 18:30".into(),
                        progress: 0.0,
                    },
                ];
                app.set_watch_history(ModelRc::new(VecModel::from(history)));

                // Seed custom collections
                app.set_collection_names(ModelRc::new(VecModel::from(vec![
                    "Sci-Fi Night".into(),
                    "Weekend Movies".into(),
                ])));
            }

            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "library_favorites_tab",
            "Open Library screen",
            "Library screen — Favorites tab active; favorited channels and movies listed",
        );

        // ── Step 1: Favorites tab — movies ────────────────────────────────

        harness.assert_screenshot(
            "library_favorites_movies",
            "Favorites tab content",
            "Interstellar and Dune shown as favorites; Dune has 45% progress bar",
        );

        // ── Step 2: Watchlist tab ──────────────────────────────────────────

        harness.press_right("navigate_watchlist_tab", "Navigate to Watchlist tab");
        harness.press_ok("select_watchlist_tab", "Select Watchlist tab");

        harness.assert_screenshot(
            "library_watchlist_tab",
            "Switch to Watchlist tab",
            "Watchlist tab active; series added to watchlist shown",
        );

        // ── Step 3: History tab ────────────────────────────────────────────

        harness.press_right("navigate_history_tab", "Navigate to History tab");
        harness.press_right("navigate_history_tab_2", "Navigate right again");
        harness.press_ok("select_history_tab", "Select History tab");

        harness.assert_screenshot(
            "library_history_tab",
            "Switch to History tab",
            "History tab: Dune (Today 20:15, 45%) and BBC One (Today 18:30) in reverse-chrono order",
        );

        // ── Step 4: Collections — create new ──────────────────────────────

        harness.press_down(
            "navigate_create_collection",
            "Navigate to Create Collection button",
        );
        harness.press_ok("open_create_collection", "Press Create Collection");

        harness.assert_screenshot(
            "create_collection_dialog",
            "Create Collection pressed",
            "Text input dialog: 'Collection name' field focused, keyboard visible",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // Simulate Rust completing create-collection callback
            app.set_collection_names(ModelRc::new(VecModel::from(vec![
                "Sci-Fi Night".into(),
                "Weekend Movies".into(),
                "Action Picks".into(),
            ])));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "collection_created",
            "Collection 'Action Picks' created",
            "Three collections visible: Sci-Fi Night, Weekend Movies, Action Picks",
        );

        // ── Step 5: Continue Watching section ─────────────────────────────

        harness.press_up(
            "navigate_continue_watching",
            "Navigate to Continue Watching section",
        );

        harness.assert_screenshot(
            "library_continue_watching",
            "Continue Watching section",
            "Dune card with 45% progress bar shown; resume button focused",
        );

        // Resume Dune playback
        harness.press_ok("resume_dune", "Press OK to resume Dune");

        harness.assert_screenshot(
            "library_resume_playback",
            "Resume Dune from 45%",
            "Playback starts; OSD shows resume position",
        );

        // ── Step 6: Delete a collection ────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(6); // Back to Library
            slint::platform::update_timers_and_animations();
        }

        harness.press_ok("focus_scifi_collection", "Focus Sci-Fi Night collection");
        harness.press_right("focus_delete_collection", "Navigate to delete icon");
        harness.press_ok("delete_scifi_collection", "Delete Sci-Fi Night");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_collection_names(ModelRc::new(VecModel::from(vec![
                "Weekend Movies".into(),
                "Action Picks".into(),
            ])));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "collection_deleted",
            "Sci-Fi Night collection deleted",
            "Two collections remain; Sci-Fi Night removed",
        );
    }
}
