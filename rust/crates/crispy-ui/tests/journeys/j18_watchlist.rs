//! J-18: Add Movie to Watchlist
//!
//! Dream: "One-press add from detail or long-press from card, instant
//! optimistic UI update."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, VodData};
use slint::ComponentHandle;

pub struct J18;

impl Journey for J18 {
    const ID: &'static str = "j18";
    const NAME: &'static str = "Watchlist — Add / Remove / Browse";
    const DEPENDS_ON: &'static [&'static str] = &["j15"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Movie detail with empty watchlist state ────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(3); // Movies
            ui.global::<AppState>().set_show_vod_detail(true);
            ui.global::<AppState>().set_vod_detail_item(VodData {
                id: "movie-oppenheimer".into(),
                name: "Oppenheimer".into(),
                stream_url: "http://iptv.example.com/movie/oppenheimer.ts".into(),
                item_type: "movie".into(),
                poster_url: "".into(),
                backdrop_url: "".into(),
                description:
                    "The story of J. Robert Oppenheimer and the development of the atomic bomb."
                        .into(),
                genre: "Drama".into(),
                year: "2023".into(),
                rating: "8.9".into(),
                duration_minutes: 180,
                is_favorite: false,
                source_id: "src-1".into(),
                series_id: "".into(),
                season: 0,
                episode: 0,
                poster: slint::Image::default(),
            });
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "watchlist_detail_not_added",
            "Movie detail before adding to watchlist",
            "Watchlist (favourite) button shows unfilled/outline icon",
        );

        // ── Step 1: One-press add — optimistic UI update ───────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Optimistic update: flip is_favorite immediately, Rust persists async
            let mut item = ui.global::<AppState>().get_vod_detail_item();
            item.is_favorite = true;
            ui.global::<AppState>().set_vod_detail_item(item);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "watchlist_added_optimistic",
            "Watchlist button pressed — optimistic fill",
            "Watchlist icon immediately fills to active state; no loading delay",
        );

        // ── Step 2: Movies grid reflects watchlist state on card ──────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_vod_detail(false);

            let movies = slint::VecModel::<VodData>::default();
            // First card: now in watchlist
            movies.push(VodData {
                id: "movie-oppenheimer".into(),
                name: "Oppenheimer".into(),
                stream_url: "".into(),
                item_type: "movie".into(),
                poster_url: "".into(),
                backdrop_url: "".into(),
                description: "".into(),
                genre: "Drama".into(),
                year: "2023".into(),
                rating: "8.9".into(),
                duration_minutes: 180,
                is_favorite: true, // persisted
                source_id: "src-1".into(),
                series_id: "".into(),
                season: 0,
                episode: 0,
                poster: slint::Image::default(),
            });
            for i in 1..8u32 {
                movies.push(VodData {
                    id: format!("movie-{i}").into(),
                    name: format!("Movie {i}").into(),
                    stream_url: "".into(),
                    item_type: "movie".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "".into(),
                    genre: "Drama".into(),
                    year: "2022".into(),
                    rating: "7.0".into(),
                    duration_minutes: 100,
                    is_favorite: false,
                    source_id: "src-1".into(),
                    series_id: "".into(),
                    season: 0,
                    episode: 0,
                    poster: slint::Image::default(),
                });
            }
            ui.global::<AppState>()
                .set_movies(slint::ModelRc::new(movies));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "watchlist_card_badge",
            "Grid: watchlist badge on card",
            "Oppenheimer card shows watchlist indicator; others do not",
        );

        // ── Step 3: Remove from watchlist (toggle off) ─────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_vod_detail(true);
            let mut item = ui.global::<AppState>().get_vod_detail_item();
            item.id = "movie-oppenheimer".into();
            item.name = "Oppenheimer".into();
            item.is_favorite = true;
            ui.global::<AppState>().set_vod_detail_item(item);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "watchlist_detail_added_state",
            "Detail reopened — showing filled watchlist button",
            "Watchlist icon in active/filled state; press again to remove",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            let mut item = ui.global::<AppState>().get_vod_detail_item();
            item.is_favorite = false;
            ui.global::<AppState>().set_vod_detail_item(item);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "watchlist_removed",
            "Watchlist toggled off",
            "Watchlist icon returns to outline; removal is instant",
        );
    }
}
