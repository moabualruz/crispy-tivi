//! J-21: Up Next Queue
//!
//! Dream: "One card per series in Continue Watching (Plex pattern). Sorted by
//! recency. Direct resume on OK."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ContinueWatchingData, VodData};
use slint::ComponentHandle;

pub struct J21;

impl Journey for J21 {
    const ID: &'static str = "j21";
    const NAME: &'static str = "Up Next Queue on Home Screen";
    const DEPENDS_ON: &'static [&'static str] = &["j19"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Home screen with empty Continue Watching lane ──────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(0); // Home
            if !harness.has_real_data() {
                ui.global::<AppState>()
                    .set_continue_watching_items(slint::ModelRc::new(slint::VecModel::default()));
            }
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "up_next_lane_empty",
            "Home screen — Continue Watching lane empty",
            "Lane absent or shows empty state before any series are started",
        );

        // ── Step 1: One card per series (Plex On Deck pattern) ────────────
        // Each series contributes exactly one card — the next unwatched episode.

        if let Some(ui) = harness.ui::<AppWindow>() {
            if !harness.has_real_data() {
                let cw = slint::VecModel::<ContinueWatchingData>::default();
                // Most recent: Breaking Bad S1E3
                cw.push(ContinueWatchingData {
                    id: "bb-s1e3".into(),
                    title: "Breaking Bad · S1E3".into(),
                    image_url: "".into(),
                    progress: 0.0, // next unwatched — no progress yet
                    content_type: "episode".into(),
                    poster: slint::Image::default(),
                });
                // Second: Succession S2E5 (in progress)
                cw.push(ContinueWatchingData {
                    id: "succ-s2e5".into(),
                    title: "Succession · S2E5".into(),
                    image_url: "".into(),
                    progress: 0.62,
                    content_type: "episode".into(),
                    poster: slint::Image::default(),
                });
                // Third: The Wire S1E1 (just started)
                cw.push(ContinueWatchingData {
                    id: "wire-s1e1".into(),
                    title: "The Wire · S1E1".into(),
                    image_url: "".into(),
                    progress: 0.08,
                    content_type: "episode".into(),
                    poster: slint::Image::default(),
                });
                ui.global::<AppState>()
                    .set_continue_watching_items(slint::ModelRc::new(cw));
            }
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "up_next_three_series",
            "Up Next: 3 series, one card each",
            "Three episode cards in Continue Watching lane sorted by recency; progress bars shown",
        );

        // ── Step 2: Focus first card (Breaking Bad) — direct resume on OK ─

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Simulate focusing the first Up Next card; detail pre-loaded for direct play
            ui.global::<AppState>().set_show_series_detail(false);
            ui.global::<AppState>().set_series_detail_item(VodData {
                id: "series-breaking".into(),
                name: "Breaking Bad".into(),
                stream_url: "".into(),
                item_type: "series".into(),
                poster_url: "".into(),
                backdrop_url: "".into(),
                description: "A chemistry teacher turned drug lord.".into(),
                genre: "Drama".into(),
                year: "2008".into(),
                rating: "9.5".into(),
                duration_minutes: 0,
                is_favorite: false,
                source_id: "src-1".into(),
                series_id: "series-breaking".into(),
                season: 1,
                episode: 3,
                poster: slint::Image::default(),
            });
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "up_next_focused_card",
            "First Up Next card focused",
            "Breaking Bad card focused; press OK resumes S1E3 directly without detail screen",
        );

        // ── Step 3: After watching an episode, card advances to next ep ───

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Update the CW lane: BB card now shows S1E4 (next unwatched)
            let cw_updated = slint::VecModel::<ContinueWatchingData>::default();
            cw_updated.push(ContinueWatchingData {
                id: "bb-s1e4".into(),
                title: "Breaking Bad · S1E4".into(),
                image_url: "".into(),
                progress: 0.0,
                content_type: "episode".into(),
                poster: slint::Image::default(),
            });
            cw_updated.push(ContinueWatchingData {
                id: "succ-s2e5".into(),
                title: "Succession · S2E5".into(),
                image_url: "".into(),
                progress: 0.62,
                content_type: "episode".into(),
                poster: slint::Image::default(),
            });
            cw_updated.push(ContinueWatchingData {
                id: "wire-s1e1".into(),
                title: "The Wire · S1E1".into(),
                image_url: "".into(),
                progress: 0.08,
                content_type: "episode".into(),
                poster: slint::Image::default(),
            });
            ui.global::<AppState>()
                .set_continue_watching_items(slint::ModelRc::new(cw_updated));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "up_next_advanced_to_e4",
            "Breaking Bad card advanced to S1E4 after watching S1E3",
            "One card per series; card title updates to next unwatched episode automatically",
        );
    }
}
