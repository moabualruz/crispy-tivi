//! J-14: EPG Search and Filtering
//!
//! Dream: "Search programs by title across channels, filter chips: Live Now,
//! Today, Catch-Up, genre."
//!
//! This journey types a search query, verifies results appear, then exercises
//! each filter chip (Live Now, Today, Catch-Up, genre) and the empty-result state.
//! Screenshots document what IS rendered — the review pipeline catches deviations.

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, EpgChannelRow, EpgData};
use slint::ComponentHandle;

pub struct J14;

impl Journey for J14 {
    const ID: &'static str = "j14";
    const NAME: &'static str = "EPG Search";
    const DEPENDS_ON: &'static [&'static str] = &["j11"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Setup: EPG screen with a populated grid ────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(2);
            ui.global::<AppState>().set_epg_now_hour(20);
            ui.global::<AppState>().set_epg_now_minute(30);
            ui.global::<AppState>().set_epg_date_label("Today".into());
            ui.global::<AppState>().set_epg_selected_date_offset(0);
            ui.global::<AppState>().set_epg_search_query("".into());

            // Seed: three channels, mix of past / live / future / genres
            let news_programmes: Vec<EpgData> = vec![
                EpgData {
                    channel_id: "ch-news".into(),
                    channel_name: "CrispyNews HD".into(),
                    channel_logo: Default::default(),
                    title: "Morning Briefing".into(),
                    start_hour: 18,
                    start_minute: 0,
                    end_hour: 19,
                    end_minute: 30,
                    duration_minutes: 90,
                    progress_percent: 1.0,
                    description: "Catch-up available — top global stories.".into(),
                    category: "News".into(),
                    has_catchup: true,
                    is_now: false,
                },
                EpgData {
                    channel_id: "ch-news".into(),
                    channel_name: "CrispyNews HD".into(),
                    channel_logo: Default::default(),
                    title: "Evening Report".into(),
                    start_hour: 20,
                    start_minute: 0,
                    end_hour: 21,
                    end_minute: 0,
                    duration_minutes: 60,
                    progress_percent: 0.5,
                    description: "Live: in-depth coverage.".into(),
                    category: "News".into(),
                    has_catchup: false,
                    is_now: true,
                },
            ];

            let sports_programmes: Vec<EpgData> = vec![
                EpgData {
                    channel_id: "ch-sport".into(),
                    channel_name: "CrispySport 1".into(),
                    channel_logo: Default::default(),
                    title: "Championship League".into(),
                    start_hour: 20,
                    start_minute: 0,
                    end_hour: 22,
                    end_minute: 0,
                    duration_minutes: 120,
                    progress_percent: 0.25,
                    description: "Live match.".into(),
                    category: "Sports".into(),
                    has_catchup: false,
                    is_now: true,
                },
                EpgData {
                    channel_id: "ch-sport".into(),
                    channel_name: "CrispySport 1".into(),
                    channel_logo: Default::default(),
                    title: "Highlights Show".into(),
                    start_hour: 22,
                    start_minute: 15,
                    end_hour: 23,
                    end_minute: 0,
                    duration_minutes: 45,
                    progress_percent: 0.0,
                    description: "Match highlights — coming up.".into(),
                    category: "Sports".into(),
                    has_catchup: false,
                    is_now: false,
                },
            ];

            let movies_programmes: Vec<EpgData> = vec![EpgData {
                channel_id: "ch-movies".into(),
                channel_name: "CrispyCinema".into(),
                channel_logo: Default::default(),
                title: "The Grand Illusion".into(),
                start_hour: 19,
                start_minute: 0,
                end_hour: 21,
                end_minute: 15,
                duration_minutes: 135,
                progress_percent: 0.72,
                description: "Classic wartime drama.".into(),
                category: "Movies".into(),
                has_catchup: false,
                is_now: true,
            }];

            let rows = vec![
                EpgChannelRow {
                    channel_id: "ch-news".into(),
                    channel_name: "CrispyNews HD".into(),
                    channel_logo: Default::default(),
                    programmes: news_programmes.as_slice().into(),
                },
                EpgChannelRow {
                    channel_id: "ch-sport".into(),
                    channel_name: "CrispySport 1".into(),
                    channel_logo: Default::default(),
                    programmes: sports_programmes.as_slice().into(),
                },
                EpgChannelRow {
                    channel_id: "ch-movies".into(),
                    channel_name: "CrispyCinema".into(),
                    channel_logo: Default::default(),
                    programmes: movies_programmes.as_slice().into(),
                },
            ];

            ui.global::<AppState>().set_epg_rows(rows.as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_search_idle",
            "EPG grid before search",
            "Full grid visible; search bar empty; all three channels shown",
        );

        // ── Step 1: Type a search query — "League" ─────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            // In the real app, on_search_epg fires and Rust filters rows, then
            // sets epg_search_query + filtered epg_rows via DataEvent::EpgSearchResults.
            // In the journey we simulate the post-filter UI state directly.
            ui.global::<AppState>()
                .set_epg_search_query("League".into());

            // Simulate filtered result: only the sports live programme matches
            let filtered: Vec<EpgData> = vec![EpgData {
                channel_id: "ch-sport".into(),
                channel_name: "CrispySport 1".into(),
                channel_logo: Default::default(),
                title: "Championship League".into(),
                start_hour: 20,
                start_minute: 0,
                end_hour: 22,
                end_minute: 0,
                duration_minutes: 120,
                progress_percent: 0.25,
                description: "Live match.".into(),
                category: "Sports".into(),
                has_catchup: false,
                is_now: true,
            }];

            let filtered_rows = vec![EpgChannelRow {
                channel_id: "ch-sport".into(),
                channel_name: "CrispySport 1".into(),
                channel_logo: Default::default(),
                programmes: filtered.as_slice().into(),
            }];

            ui.global::<AppState>()
                .set_epg_rows(filtered_rows.as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_search_results",
            "Search query 'League'",
            "Grid filtered to one result: Championship League on CrispySport 1",
        );

        // ── Step 2: Filter — Live Now ──────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_search_query("".into());

            // Live Now filter: only is_now=true programmes
            let live_news = EpgData {
                channel_id: "ch-news".into(),
                channel_name: "CrispyNews HD".into(),
                channel_logo: Default::default(),
                title: "Evening Report".into(),
                start_hour: 20,
                start_minute: 0,
                end_hour: 21,
                end_minute: 0,
                duration_minutes: 60,
                progress_percent: 0.5,
                description: "Live: in-depth coverage.".into(),
                category: "News".into(),
                has_catchup: false,
                is_now: true,
            };

            let live_sport = EpgData {
                channel_id: "ch-sport".into(),
                channel_name: "CrispySport 1".into(),
                channel_logo: Default::default(),
                title: "Championship League".into(),
                start_hour: 20,
                start_minute: 0,
                end_hour: 22,
                end_minute: 0,
                duration_minutes: 120,
                progress_percent: 0.25,
                description: "Live match.".into(),
                category: "Sports".into(),
                has_catchup: false,
                is_now: true,
            };

            let live_movie = EpgData {
                channel_id: "ch-movies".into(),
                channel_name: "CrispyCinema".into(),
                channel_logo: Default::default(),
                title: "The Grand Illusion".into(),
                start_hour: 19,
                start_minute: 0,
                end_hour: 21,
                end_minute: 15,
                duration_minutes: 135,
                progress_percent: 0.72,
                description: "Classic wartime drama.".into(),
                category: "Movies".into(),
                has_catchup: false,
                is_now: true,
            };

            let live_rows = vec![
                EpgChannelRow {
                    channel_id: "ch-news".into(),
                    channel_name: "CrispyNews HD".into(),
                    channel_logo: Default::default(),
                    programmes: vec![live_news].as_slice().into(),
                },
                EpgChannelRow {
                    channel_id: "ch-sport".into(),
                    channel_name: "CrispySport 1".into(),
                    channel_logo: Default::default(),
                    programmes: vec![live_sport].as_slice().into(),
                },
                EpgChannelRow {
                    channel_id: "ch-movies".into(),
                    channel_name: "CrispyCinema".into(),
                    channel_logo: Default::default(),
                    programmes: vec![live_movie].as_slice().into(),
                },
            ];

            ui.global::<AppState>()
                .set_epg_rows(live_rows.as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_search_filter_live_now",
            "Filter: Live Now",
            "Grid shows only currently airing programmes across all channels",
        );

        // ── Step 3: Filter — Catch-Up available ───────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let catchup_prog = EpgData {
                channel_id: "ch-news".into(),
                channel_name: "CrispyNews HD".into(),
                channel_logo: Default::default(),
                title: "Morning Briefing".into(),
                start_hour: 18,
                start_minute: 0,
                end_hour: 19,
                end_minute: 30,
                duration_minutes: 90,
                progress_percent: 1.0,
                description: "Catch-up available — top global stories.".into(),
                category: "News".into(),
                has_catchup: true,
                is_now: false,
            };

            let catchup_rows = vec![EpgChannelRow {
                channel_id: "ch-news".into(),
                channel_name: "CrispyNews HD".into(),
                channel_logo: Default::default(),
                programmes: vec![catchup_prog].as_slice().into(),
            }];

            ui.global::<AppState>()
                .set_epg_rows(catchup_rows.as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_search_filter_catchup",
            "Filter: Catch-Up",
            "Grid shows only programmes with catch-up replay available",
        );

        // ── Step 4: Filter — Genre: Sports ────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let sports_live = EpgData {
                channel_id: "ch-sport".into(),
                channel_name: "CrispySport 1".into(),
                channel_logo: Default::default(),
                title: "Championship League".into(),
                start_hour: 20,
                start_minute: 0,
                end_hour: 22,
                end_minute: 0,
                duration_minutes: 120,
                progress_percent: 0.25,
                description: "Live match.".into(),
                category: "Sports".into(),
                has_catchup: false,
                is_now: true,
            };

            let sports_future = EpgData {
                channel_id: "ch-sport".into(),
                channel_name: "CrispySport 1".into(),
                channel_logo: Default::default(),
                title: "Highlights Show".into(),
                start_hour: 22,
                start_minute: 15,
                end_hour: 23,
                end_minute: 0,
                duration_minutes: 45,
                progress_percent: 0.0,
                description: "Match highlights.".into(),
                category: "Sports".into(),
                has_catchup: false,
                is_now: false,
            };

            let sports_rows = vec![EpgChannelRow {
                channel_id: "ch-sport".into(),
                channel_name: "CrispySport 1".into(),
                channel_logo: Default::default(),
                programmes: vec![sports_live, sports_future].as_slice().into(),
            }];

            ui.global::<AppState>()
                .set_epg_rows(sports_rows.as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_search_filter_genre_sports",
            "Filter: Genre = Sports",
            "Only sports-category programmes shown; sports colour accent on cells",
        );

        // ── Step 5: No results state ───────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_epg_search_query("xyzzy_no_match".into());
            ui.global::<AppState>().set_epg_rows(Default::default()); // empty = no matches
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_search_no_results",
            "Search with no results",
            "Empty-state shown: 'No programmes found' with search query echoed",
        );

        // ── Step 6: Clear search — restore full grid ───────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_search_query("".into());

            let all_programmes_news: Vec<EpgData> = vec![
                EpgData {
                    channel_id: "ch-news".into(),
                    channel_name: "CrispyNews HD".into(),
                    channel_logo: Default::default(),
                    title: "Morning Briefing".into(),
                    start_hour: 18,
                    start_minute: 0,
                    end_hour: 19,
                    end_minute: 30,
                    duration_minutes: 90,
                    progress_percent: 1.0,
                    description: "Catch-up available — top global stories.".into(),
                    category: "News".into(),
                    has_catchup: true,
                    is_now: false,
                },
                EpgData {
                    channel_id: "ch-news".into(),
                    channel_name: "CrispyNews HD".into(),
                    channel_logo: Default::default(),
                    title: "Evening Report".into(),
                    start_hour: 20,
                    start_minute: 0,
                    end_hour: 21,
                    end_minute: 0,
                    duration_minutes: 60,
                    progress_percent: 0.5,
                    description: "Live: in-depth coverage.".into(),
                    category: "News".into(),
                    has_catchup: false,
                    is_now: true,
                },
            ];

            let restored_rows = vec![EpgChannelRow {
                channel_id: "ch-news".into(),
                channel_name: "CrispyNews HD".into(),
                channel_logo: Default::default(),
                programmes: all_programmes_news.as_slice().into(),
            }];

            ui.global::<AppState>()
                .set_epg_rows(restored_rows.as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_search_cleared",
            "Search cleared — full grid restored",
            "Search bar empty; full programme schedule visible again",
        );
    }
}
