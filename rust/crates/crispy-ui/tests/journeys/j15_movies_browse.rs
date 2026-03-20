//! J-15: Browse Movies by Genre Lanes
//!
//! Dream: "Hero with key art, genre lanes with poster cards, progressive image
//! loading, Continue Watching first lane."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, CategoryData, ContinueWatchingData, VodData};
use slint::ComponentHandle;

pub struct J15;

impl Journey for J15 {
    const ID: &'static str = "j15";
    const NAME: &'static str = "Movies — Browse Grid";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Navigate to Movies screen (index 3) ────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(3); // Movies
            ui.global::<AppState>().set_is_loading_vod(false);
            if !harness.has_real_data() {
                ui.global::<AppState>()
                    .set_movies(slint::ModelRc::new(slint::VecModel::default()));
            }
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movies_empty",
            "Movies screen with no content",
            "Empty state with Add Source CTA visible",
        );

        // ── Step 1: Loading state ──────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_loading_vod(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movies_loading",
            "Movies loading spinner",
            "Loading indicator visible while fetching movies",
        );

        // ── Step 2: Continue Watching lane populated ───────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_is_loading_vod(false);

            if !harness.has_real_data() {
                let cw = slint::VecModel::<ContinueWatchingData>::default();
                cw.push(ContinueWatchingData {
                    id: "movie-cw-1".into(),
                    title: "Interstellar".into(),
                    image_url: "".into(),
                    progress: 0.45,
                    content_type: "movie".into(),
                    poster: slint::Image::default(),
                });
                cw.push(ContinueWatchingData {
                    id: "movie-cw-2".into(),
                    title: "Dune: Part Two".into(),
                    image_url: "".into(),
                    progress: 0.12,
                    content_type: "movie".into(),
                    poster: slint::Image::default(),
                });
                ui.global::<AppState>()
                    .set_continue_watching_items(slint::ModelRc::new(cw));
            }
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movies_continue_watching_lane",
            "Continue Watching lane populated",
            "Resume row shows last-watched movies sorted by recency with progress bars",
        );

        // ── Step 3: Genre categories + movies grid ─────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            if !harness.has_real_data() {
                let cats = slint::VecModel::<CategoryData>::default();
                for name in &["Action", "Drama", "Sci-Fi", "Comedy", "Thriller"] {
                    cats.push(CategoryData {
                        name: (*name).into(),
                        category_type: "genre".into(),
                    });
                }
                ui.global::<AppState>()
                    .set_vod_categories(slint::ModelRc::new(cats));
                ui.global::<AppState>()
                    .set_active_vod_category("Action".into());

                let movies = slint::VecModel::<VodData>::default();
                for i in 0..12u32 {
                    movies.push(VodData {
                        id: format!("movie-{i}").into(),
                        name: format!("Action Movie {}", i + 1).into(),
                        stream_url: "".into(),
                        item_type: "movie".into(),
                        poster_url: "".into(),
                        backdrop_url: "".into(),
                        description: "An action-packed thriller.".into(),
                        genre: "Action".into(),
                        year: "2024".into(),
                        rating: "8.1".into(),
                        duration_minutes: 120,
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
            }
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movies_genre_grid_action",
            "Action genre chip selected, grid populated",
            "Poster card grid shown; genre chip row visible; Action chip active",
        );

        // ── Step 4: Switch genre to Sci-Fi ────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_active_vod_category("Sci-Fi".into());

            let scifi = slint::VecModel::<VodData>::default();
            for i in 0..8u32 {
                scifi.push(VodData {
                    id: format!("scifi-{i}").into(),
                    name: format!("Sci-Fi Film {}", i + 1).into(),
                    stream_url: "".into(),
                    item_type: "movie".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "A journey to the stars.".into(),
                    genre: "Sci-Fi".into(),
                    year: "2023".into(),
                    rating: "7.8".into(),
                    duration_minutes: 138,
                    is_favorite: false,
                    source_id: "src-1".into(),
                    series_id: "".into(),
                    season: 0,
                    episode: 0,
                    poster: slint::Image::default(),
                });
            }
            ui.global::<AppState>()
                .set_movies(slint::ModelRc::new(scifi));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movies_scifi_filtered",
            "Sci-Fi genre chip selected",
            "Grid refreshes with Sci-Fi titles; Sci-Fi chip highlighted; count updated",
        );
    }
}
