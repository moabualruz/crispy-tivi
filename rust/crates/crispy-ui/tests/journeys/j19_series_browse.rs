//! J-19: Series Browse to Detail to Episode Play
//!
//! Dream: "Season chips, episode rows with thumbnails. Watched dimmed with
//! checkmark. Next unwatched highlighted. Default to relevant season."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, CategoryData, VodData};
use slint::ComponentHandle;

pub struct J19;

impl Journey for J19 {
    const ID: &'static str = "j19";
    const NAME: &'static str = "Series — Browse and Season Navigation";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Navigate to Series screen (index 4) ───────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(4); // Series
            ui.global::<AppState>().set_is_loading_vod(false);
            ui.global::<AppState>()
                .set_series(slint::ModelRc::new(slint::VecModel::default()));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "series_empty",
            "Series screen with no content",
            "Empty state with Add Source CTA visible",
        );

        // ── Step 1: Series grid populated ────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let cats = slint::VecModel::<CategoryData>::default();
            for name in &["Drama", "Action", "Comedy", "Thriller"] {
                cats.push(CategoryData {
                    name: (*name).into(),
                    category_type: "genre".into(),
                });
            }
            ui.global::<AppState>()
                .set_vod_categories(slint::ModelRc::new(cats));
            ui.global::<AppState>()
                .set_active_vod_category("Drama".into());

            let series_list = slint::VecModel::<VodData>::default();
            for i in 0..10u32 {
                series_list.push(VodData {
                    id: format!("series-{i}").into(),
                    name: format!("Drama Series {}", i + 1).into(),
                    stream_url: "".into(),
                    item_type: "series".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "A gripping drama.".into(),
                    genre: "Drama".into(),
                    year: "2023".into(),
                    rating: "8.2".into(),
                    duration_minutes: 0,
                    is_favorite: false,
                    source_id: "src-1".into(),
                    series_id: slint::SharedString::from(format!("series-{i}")).into(),
                    season: 0,
                    episode: 0,
                    poster: slint::Image::default(),
                });
            }
            ui.global::<AppState>()
                .set_series(slint::ModelRc::new(series_list));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "series_grid_drama",
            "Series grid populated with Drama genre",
            "Poster card grid shows drama series; genre chips visible",
        );

        // ── Step 2: Open series detail ────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_series_detail(true);
            ui.global::<AppState>().set_series_detail_item(VodData {
                id: "series-0".into(),
                name: "Drama Series 1".into(),
                stream_url: "".into(),
                item_type: "series".into(),
                poster_url: "".into(),
                backdrop_url: "".into(),
                description: "A gripping multi-season drama about power and survival.".into(),
                genre: "Drama".into(),
                year: "2021".into(),
                rating: "9.0".into(),
                duration_minutes: 0,
                is_favorite: false,
                source_id: "src-1".into(),
                series_id: "series-0".into(),
                season: 1,
                episode: 0,
                poster: slint::Image::default(),
            });
            ui.global::<AppState>().set_series_active_season(1);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "series_detail_no_episodes",
            "Series detail open, episodes not yet loaded",
            "Backdrop, title, synopsis visible; episode list empty",
        );

        // ── Step 3: Season 1 episodes loaded ─────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let eps = slint::VecModel::<VodData>::default();
            // E1 and E2 watched, E3 is next unwatched, E4-E6 unwatched
            for i in 0..6u32 {
                eps.push(VodData {
                    id: format!("series-0-s1e{}", i + 1).into(),
                    name: format!("Episode {}", i + 1).into(),
                    stream_url: format!("http://iptv.example.com/ep/{}", i + 1).into(),
                    item_type: "episode".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: format!("Season 1, Episode {} synopsis.", i + 1).into(),
                    genre: "Drama".into(),
                    year: "2021".into(),
                    rating: "".into(),
                    duration_minutes: 48,
                    is_favorite: false,
                    source_id: "src-1".into(),
                    series_id: "series-0".into(),
                    season: 1,
                    episode: (i + 1) as i32,
                    poster: slint::Image::default(),
                });
            }
            ui.global::<AppState>()
                .set_series_episodes(slint::ModelRc::new(eps));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "series_detail_s1_episodes",
            "Season 1 episodes loaded",
            "Episode rows visible; E1/E2 dimmed (watched); E3 highlighted as next unwatched",
        );

        // ── Step 4: Switch to Season 2 via chip ───────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_series_active_season(2);

            let eps_s2 = slint::VecModel::<VodData>::default();
            for i in 0..4u32 {
                eps_s2.push(VodData {
                    id: format!("series-0-s2e{}", i + 1).into(),
                    name: format!("Episode {}", i + 1).into(),
                    stream_url: format!("http://iptv.example.com/s2ep/{}", i + 1).into(),
                    item_type: "episode".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: format!("Season 2, Episode {} synopsis.", i + 1).into(),
                    genre: "Drama".into(),
                    year: "2022".into(),
                    rating: "".into(),
                    duration_minutes: 52,
                    is_favorite: false,
                    source_id: "src-1".into(),
                    series_id: "series-0".into(),
                    season: 2,
                    episode: (i + 1) as i32,
                    poster: slint::Image::default(),
                });
            }
            ui.global::<AppState>()
                .set_series_episodes(slint::ModelRc::new(eps_s2));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "series_detail_s2_chip",
            "Season 2 chip selected",
            "S2 chip highlighted; episode list refreshes with Season 2 episodes",
        );

        // ── Step 5: Close detail and return to grid ───────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_series_detail(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "series_grid_returned",
            "Series detail closed",
            "Series grid visible again; focus returns to selected card",
        );
    }
}
