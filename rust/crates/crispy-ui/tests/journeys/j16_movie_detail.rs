//! J-16: Movie Detail Screen
//!
//! Dream: "Cinematic zoom-push transition, backdrop art, synopsis, cast,
//! similar titles, Play/Resume CTAs."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, VodData};
use slint::ComponentHandle;

pub struct J16;

impl Journey for J16 {
    const ID: &'static str = "j16";
    const NAME: &'static str = "Movie Detail Modal";
    const DEPENDS_ON: &'static [&'static str] = &["j15"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Open movie detail for an unwatched movie ───────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(3); // Movies
            ui.global::<AppState>().set_show_vod_detail(true);
            ui.global::<AppState>().set_vod_detail_item(VodData {
                id: "movie-interstellar".into(),
                name: "Interstellar".into(),
                stream_url: "http://iptv.example.com/movie/interstellar.ts".into(),
                item_type: "movie".into(),
                poster_url: "".into(),
                backdrop_url: "".into(),
                description: "A team of explorers travel through a wormhole in space in an attempt to ensure humanity's survival.".into(),
                genre: "Sci-Fi".into(),
                year: "2014".into(),
                rating: "8.6".into(),
                duration_minutes: 169,
                is_favorite: false,
                source_id: "src-1".into(),
                series_id: "".into(),
                season: 0,
                episode: 0,
                poster: slint::Image::default(),
            });
            ui.global::<AppState>()
                .set_vod_detail_has_multi_source(false);
            ui.global::<AppState>()
                .set_vod_detail_sources(slint::ModelRc::new(slint::VecModel::default()));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movie_detail_unwatched",
            "Open detail for unwatched movie",
            "Detail sheet with backdrop art, title, synopsis, Play CTA prominent",
        );

        // ── Step 1: Similar titles lane populated ──────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let similar = slint::VecModel::<VodData>::default();
            for i in 0..4u32 {
                similar.push(VodData {
                    id: format!("similar-{i}").into(),
                    name: format!("Related Film {}", i + 1).into(),
                    stream_url: "".into(),
                    item_type: "movie".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "Another great space film.".into(),
                    genre: "Sci-Fi".into(),
                    year: "2021".into(),
                    rating: "7.5".into(),
                    duration_minutes: 112,
                    is_favorite: false,
                    source_id: "src-1".into(),
                    series_id: "".into(),
                    season: 0,
                    episode: 0,
                    poster: slint::Image::default(),
                });
            }
            // Similar titles are shown as home-movies slice on the detail screen
            ui.global::<AppState>()
                .set_home_movies(slint::ModelRc::new(similar));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movie_detail_with_similar",
            "Similar titles lane visible",
            "More Like This lane shows related poster cards below synopsis",
        );

        // ── Step 2: Multi-source badge ─────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_vod_detail_has_multi_source(true);
            let badges = slint::VecModel::<crate::SourceBadge>::default();
            badges.push(crate::SourceBadge {
                source_name: "Primary IPTV".into(),
                quality_label: "1080p".into(),
                is_preferred: true,
            });
            badges.push(crate::SourceBadge {
                source_name: "Backup Stream".into(),
                quality_label: "720p".into(),
                is_preferred: false,
            });
            ui.global::<AppState>()
                .set_vod_detail_sources(slint::ModelRc::new(badges));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movie_detail_multi_source",
            "Multi-source quality badges visible",
            "1080p and 720p source badges shown; preferred source highlighted",
        );

        // ── Step 3: Detail for a movie already marked favourite ────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let mut item = ui.global::<AppState>().get_vod_detail_item();
            item.is_favorite = true;
            ui.global::<AppState>().set_vod_detail_item(item);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movie_detail_favourited",
            "Movie already in favourites",
            "Favourite (watchlist) icon shows filled/active state",
        );

        // ── Step 4: Close detail sheet ─────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_vod_detail(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movie_detail_closed",
            "Detail sheet dismissed",
            "Movies grid visible again behind closed detail sheet",
        );
    }
}
