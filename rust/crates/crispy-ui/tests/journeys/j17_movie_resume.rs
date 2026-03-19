//! J-17: Movie Resume Watching
//!
//! Dream: "Continue Watching lane sorted by recency, direct resume on OK,
//! position saved every 30s."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ContinueWatchingData, VodData};
use slint::ComponentHandle;

pub struct J17;

impl Journey for J17 {
    const ID: &'static str = "j17";
    const NAME: &'static str = "Movie Resume Playback";
    const DEPENDS_ON: &'static [&'static str] = &["j16"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Home screen with Continue Watching lane ────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(0); // Home

            // Three movies in progress, sorted most-recent first
            let cw = slint::VecModel::<ContinueWatchingData>::default();
            cw.push(ContinueWatchingData {
                id: "movie-dune2".into(),
                title: "Dune: Part Two".into(),
                image_url: "".into(),
                progress: 0.68,
                content_type: "movie".into(),
                poster: slint::Image::default(),
            });
            cw.push(ContinueWatchingData {
                id: "movie-interstellar".into(),
                title: "Interstellar".into(),
                image_url: "".into(),
                progress: 0.45,
                content_type: "movie".into(),
                poster: slint::Image::default(),
            });
            cw.push(ContinueWatchingData {
                id: "movie-arrival".into(),
                title: "Arrival".into(),
                image_url: "".into(),
                progress: 0.22,
                content_type: "movie".into(),
                poster: slint::Image::default(),
            });
            ui.global::<AppState>()
                .set_continue_watching_items(slint::ModelRc::new(cw));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "resume_home_continue_watching",
            "Home Continue Watching lane with 3 in-progress movies",
            "Lane shows cards sorted by recency; progress bars reflect position",
        );

        // ── Step 1: Focus on first item (Dune Part Two, most recent) ───────

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Navigate to Movies screen to show the in-progress item detail
            ui.global::<AppState>().set_active_screen(3); // Movies
            ui.global::<AppState>().set_show_vod_detail(true);
            ui.global::<AppState>().set_vod_detail_item(VodData {
                id: "movie-dune2".into(),
                name: "Dune: Part Two".into(),
                stream_url: "http://iptv.example.com/movie/dune2.ts".into(),
                item_type: "movie".into(),
                poster_url: "".into(),
                backdrop_url: "".into(),
                description: "Paul Atreides unites with Chani and the Fremen.".into(),
                genre: "Sci-Fi".into(),
                year: "2024".into(),
                rating: "8.8".into(),
                duration_minutes: 166,
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
            "resume_detail_with_resume_cta",
            "Detail sheet for in-progress movie",
            "Resume CTA shown (not just Play); progress bar reflects 68% position",
        );

        // ── Step 2: Cross-device resume prompt ────────────────────────────
        // Simulates resume prompt when the same movie was left mid-way on another device.

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_resume_prompt(true);
            ui.global::<AppState>()
                .set_resume_source_device("Living Room TV".into());
            ui.global::<AppState>()
                .set_resume_position_label("1h 23m".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "resume_cross_device_prompt",
            "Cross-device resume prompt shown",
            "Dialog asks user to resume from 1h 23m (from Living Room TV) or start over",
        );

        // ── Step 3: Dismiss prompt and begin playback ──────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_resume_prompt(false);
            ui.global::<AppState>().set_show_vod_detail(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "resume_playback_started",
            "Playback starts from saved position",
            "Player layer active; UI chrome visible; position restored",
        );
    }
}
