//! J-24: Browse by Category / Genre Filters
//!
//! Dream: "Filter chips (genre, year, rating, resolution) that are
//! combinable. Instant re-filter — no loading screen between chip taps."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, CategoryData, VodData};
use slint::ComponentHandle;

fn make_movie(id: &str, name: &str, genre: &str, year: &str, rating: &str, mins: i32) -> VodData {
    VodData {
        id: id.into(),
        name: name.into(),
        stream_url: "".into(),
        item_type: "movie".into(),
        poster_url: "".into(),
        backdrop_url: "".into(),
        description: "".into(),
        genre: genre.into(),
        year: year.into(),
        rating: rating.into(),
        duration_minutes: mins,
        is_favorite: false,
        source_id: "src-1".into(),
        series_id: "".into(),
        season: 0,
        episode: 0,
        poster: slint::Image::default(),
    }
}

pub struct J24;

impl Journey for J24 {
    const ID: &'static str = "j24";
    const NAME: &'static str = "Browse Filters and Sorting";
    const DEPENDS_ON: &'static [&'static str] = &["j23"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Movies screen — unfiltered full catalogue ─────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(3); // Movies
            app.set_active_vod_category("".into());

            if !harness.has_real_data() {
                let cats = slint::VecModel::<CategoryData>::default();
                for (name, ct) in &[("Sci-Fi", "genre"), ("Action", "genre"), ("Drama", "genre")] {
                    cats.push(CategoryData {
                        name: (*name).into(),
                        category_type: (*ct).into(),
                    });
                }
                app.set_vod_categories(slint::ModelRc::new(cats));

                let movies = slint::VecModel::<VodData>::default();
                movies.push(make_movie(
                    "m1",
                    "Interstellar",
                    "Sci-Fi",
                    "2014",
                    "8.6",
                    169,
                ));
                movies.push(make_movie(
                    "m2",
                    "The Dark Knight",
                    "Action",
                    "2008",
                    "9.0",
                    152,
                ));
                movies.push(make_movie("m3", "Arrival", "Sci-Fi", "2016", "7.9", 116));
                app.set_movies(slint::ModelRc::new(movies));
            }
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "movies_unfiltered",
            "Movies screen open",
            "Full catalogue shown, all category chips in default state",
        );

        // ── Apply category filter: Sci-Fi ─────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_vod_category("Sci-Fi".into());

            let sci_fi = slint::VecModel::<VodData>::default();
            sci_fi.push(make_movie(
                "m1",
                "Interstellar",
                "Sci-Fi",
                "2014",
                "8.6",
                169,
            ));
            sci_fi.push(make_movie("m3", "Arrival", "Sci-Fi", "2016", "7.9", 116));
            app.set_movies(slint::ModelRc::new(sci_fi));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "filter_category_scifi",
            "Category chip: Sci-Fi",
            "Only Sci-Fi movies shown, chip highlighted, instant re-filter",
        );

        // ── Switch to Action category ─────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_vod_category("Action".into());

            let action = slint::VecModel::<VodData>::default();
            action.push(make_movie(
                "m2",
                "The Dark Knight",
                "Action",
                "2008",
                "9.0",
                152,
            ));
            app.set_movies(slint::ModelRc::new(action));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "filter_category_action",
            "Category chip: Action",
            "Only Action movies shown, chip switches instantly with no loading screen",
        );

        // ── Clear filter — all movies restored ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_vod_category("".into());

            let all_movies = slint::VecModel::<VodData>::default();
            all_movies.push(make_movie(
                "m1",
                "Interstellar",
                "Sci-Fi",
                "2014",
                "8.6",
                169,
            ));
            all_movies.push(make_movie(
                "m2",
                "The Dark Knight",
                "Action",
                "2008",
                "9.0",
                152,
            ));
            all_movies.push(make_movie("m3", "Arrival", "Sci-Fi", "2016", "7.9", 116));
            app.set_movies(slint::ModelRc::new(all_movies));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "filters_cleared",
            "Filter cleared",
            "Full catalogue restored, all chips back to default state",
        );
    }
}
