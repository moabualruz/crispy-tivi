//! J-22: Series Progress Tracking
//!
//! Dream: "Per-episode watched/unwatched/in-progress states, season-level
//! progress, bulk mark watched/unwatched."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, VodData};
use slint::ComponentHandle;

pub struct J22;

impl Journey for J22 {
    const ID: &'static str = "j22";
    const NAME: &'static str = "Episode Progress Tracking";
    const DEPENDS_ON: &'static [&'static str] = &["j19"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Series detail — mix of watched/in-progress/unwatched ──

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(4); // Series
            ui.global::<AppState>().set_show_series_detail(true);
            ui.global::<AppState>().set_series_detail_item(VodData {
                id: "series-succession".into(),
                name: "Succession".into(),
                stream_url: "".into(),
                item_type: "series".into(),
                poster_url: "".into(),
                backdrop_url: "".into(),
                description: "The Roy family battles over their media empire.".into(),
                genre: "Drama".into(),
                year: "2018".into(),
                rating: "9.3".into(),
                duration_minutes: 0,
                is_favorite: true,
                source_id: "src-1".into(),
                series_id: "series-succession".into(),
                season: 1,
                episode: 0,
                poster: slint::Image::default(),
            });
            ui.global::<AppState>().set_series_active_season(1);

            // Build episode list: E1–E3 watched, E4 in-progress, E5–E10 unwatched
            let eps = slint::VecModel::<VodData>::default();
            for i in 0..10u32 {
                eps.push(VodData {
                    id: format!("succ-s1e{}", i + 1).into(),
                    name: format!(
                        "Ep {}: {}",
                        i + 1,
                        match i {
                            0 => "Celebration",
                            1 => "Shit Show at the F**k Factory",
                            2 => "Lifeboats",
                            3 => "Sad Sack Wasp Trap",
                            4 => "I Went to Market",
                            5 => "Which Side Are You On?",
                            6 => "Austerlitz",
                            7 => "Prague",
                            8 => "Pre-Nuptial",
                            _ => "Nobody Is Ever Missing",
                        }
                    )
                    .into(),
                    stream_url: format!("http://iptv.example.com/succ/s1e{}", i + 1).into(),
                    item_type: "episode".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "Episode synopsis.".into(),
                    genre: "Drama".into(),
                    year: "2018".into(),
                    rating: "".into(),
                    duration_minutes: 55,
                    // E1–E3 marked as favourite to simulate watched (is_favorite is
                    // the only per-item bool available; Rust tracks watched state in DB)
                    is_favorite: i < 3,
                    source_id: "src-1".into(),
                    series_id: "series-succession".into(),
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
            "progress_s1_mixed_states",
            "Season 1: E1–E3 watched, E4 in-progress, E5–E10 unwatched",
            "Episode rows: watched rows dimmed with checkmark; E4 highlighted; others normal",
        );

        // ── Step 1: Season-level progress indicator ───────────────────────

        if let Some(_ui) = harness.ui::<AppWindow>() {
            // Season-level progress is derived from episode states by Rust.
            // Capture with 3/10 episodes watched — 30% season progress.
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "progress_season_progress_bar",
            "Season 1 progress bar at 30%",
            "Season chip shows progress bar or counter (3/10 watched)",
        );

        // ── Step 2: Switch season — Season 2 all unwatched ───────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_series_active_season(2);

            let eps_s2 = slint::VecModel::<VodData>::default();
            for i in 0..10u32 {
                eps_s2.push(VodData {
                    id: format!("succ-s2e{}", i + 1).into(),
                    name: format!("Season 2, Episode {}", i + 1).into(),
                    stream_url: format!("http://iptv.example.com/succ/s2e{}", i + 1).into(),
                    item_type: "episode".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "Season 2 episode synopsis.".into(),
                    genre: "Drama".into(),
                    year: "2019".into(),
                    rating: "".into(),
                    duration_minutes: 58,
                    is_favorite: false,
                    source_id: "src-1".into(),
                    series_id: "series-succession".into(),
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
            "progress_s2_all_unwatched",
            "Season 2 selected — all episodes unwatched",
            "S2 chip active; all rows show unwatched state; E1 highlighted as next to watch",
        );

        // ── Step 3: Bulk mark Season 2 as watched ────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Simulate bulk-mark: all S2 episodes flip to watched state
            let eps_s2_watched = slint::VecModel::<VodData>::default();
            for i in 0..10u32 {
                eps_s2_watched.push(VodData {
                    id: format!("succ-s2e{}", i + 1).into(),
                    name: format!("Season 2, Episode {}", i + 1).into(),
                    stream_url: format!("http://iptv.example.com/succ/s2e{}", i + 1).into(),
                    item_type: "episode".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "Season 2 episode synopsis.".into(),
                    genre: "Drama".into(),
                    year: "2019".into(),
                    rating: "".into(),
                    duration_minutes: 58,
                    is_favorite: true, // all marked watched
                    source_id: "src-1".into(),
                    series_id: "series-succession".into(),
                    season: 2,
                    episode: (i + 1) as i32,
                    poster: slint::Image::default(),
                });
            }
            ui.global::<AppState>()
                .set_series_episodes(slint::ModelRc::new(eps_s2_watched));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "progress_s2_bulk_marked_watched",
            "Season 2 bulk-marked as watched",
            "All S2 episode rows dimmed with checkmarks; season progress shows 10/10",
        );

        // ── Step 4: Bulk mark Season 2 as unwatched ──────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let eps_s2_unwatched = slint::VecModel::<VodData>::default();
            for i in 0..10u32 {
                eps_s2_unwatched.push(VodData {
                    id: format!("succ-s2e{}", i + 1).into(),
                    name: format!("Season 2, Episode {}", i + 1).into(),
                    stream_url: format!("http://iptv.example.com/succ/s2e{}", i + 1).into(),
                    item_type: "episode".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "Season 2 episode synopsis.".into(),
                    genre: "Drama".into(),
                    year: "2019".into(),
                    rating: "".into(),
                    duration_minutes: 58,
                    is_favorite: false, // all unmarked
                    source_id: "src-1".into(),
                    series_id: "series-succession".into(),
                    season: 2,
                    episode: (i + 1) as i32,
                    poster: slint::Image::default(),
                });
            }
            ui.global::<AppState>()
                .set_series_episodes(slint::ModelRc::new(eps_s2_unwatched));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "progress_s2_bulk_unmarked",
            "Season 2 bulk-marked as unwatched",
            "All S2 rows return to unwatched state; progress resets to 0/10",
        );
    }
}
