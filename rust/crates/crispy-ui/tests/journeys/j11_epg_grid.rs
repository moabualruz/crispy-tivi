//! J-11: Full EPG Grid Navigation
//!
//! Dream: "Full-screen grid with PiP, now-line, past dimmed/current highlighted/
//! future normal, 60fps scroll across channels and time."
//!
//! This journey sets up representative EPG data and captures the grid at each
//! meaningful state: empty, populated, now-line visible, cell focused, PiP active.
//! Screenshots document what IS rendered — the review pipeline catches deviations.

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, EpgChannelRow, EpgData};
use slint::ComponentHandle;

pub struct J11;

impl Journey for J11 {
    const ID: &'static str = "j11";
    const NAME: &'static str = "EPG Grid — Full-Screen TV Guide";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Navigate to EPG screen (empty state) ───────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(2); // EPG screen
            ui.global::<AppState>().set_epg_rows(Default::default());
            ui.global::<AppState>().set_epg_date_label("Today".into());
            ui.global::<AppState>().set_epg_now_hour(20);
            ui.global::<AppState>().set_epg_now_minute(30);
            ui.global::<AppState>().set_epg_selected_date_offset(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_empty",
            "EPG screen — no data",
            "Empty-state placeholder shown when epg-rows is empty",
        );

        // ── Step 1: Populate with multi-channel EPG rows ───────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
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
                    description: "Top stories from around the world.".into(),
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
                    description: "In-depth analysis of the day's events.".into(),
                    category: "News".into(),
                    has_catchup: false,
                    is_now: true,
                },
                EpgData {
                    channel_id: "ch-news".into(),
                    channel_name: "CrispyNews HD".into(),
                    channel_logo: Default::default(),
                    title: "Late Edition".into(),
                    start_hour: 21,
                    start_minute: 0,
                    end_hour: 22,
                    end_minute: 0,
                    duration_minutes: 60,
                    progress_percent: 0.0,
                    description: "Night round-up.".into(),
                    category: "News".into(),
                    has_catchup: false,
                    is_now: false,
                },
            ];

            let sports_programmes: Vec<EpgData> = vec![
                EpgData {
                    channel_id: "ch-sport".into(),
                    channel_name: "CrispySport 1".into(),
                    channel_logo: Default::default(),
                    title: "Pre-Match".into(),
                    start_hour: 19,
                    start_minute: 30,
                    end_hour: 20,
                    end_minute: 0,
                    duration_minutes: 30,
                    progress_percent: 1.0,
                    description: "Build-up to tonight's fixture.".into(),
                    category: "Sports".into(),
                    has_catchup: true,
                    is_now: false,
                },
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
                    description: "Live match coverage.".into(),
                    category: "Sports".into(),
                    has_catchup: false,
                    is_now: true,
                },
            ];

            let movies_programmes: Vec<EpgData> = vec![
                EpgData {
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
                    description: "Classic wartime drama. Directed by Jean Renoir.".into(),
                    category: "Movies".into(),
                    has_catchup: false,
                    is_now: true,
                },
                EpgData {
                    channel_id: "ch-movies".into(),
                    channel_name: "CrispyCinema".into(),
                    channel_logo: Default::default(),
                    title: "Night at the Museum".into(),
                    start_hour: 21,
                    start_minute: 30,
                    end_hour: 23,
                    end_minute: 15,
                    duration_minutes: 105,
                    progress_percent: 0.0,
                    description: "Comedy adventure — coming up next.".into(),
                    category: "Movies".into(),
                    has_catchup: false,
                    is_now: false,
                },
            ];

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
            "epg_grid_populated",
            "EPG grid with 3 channels",
            "Grid shows news, sports, movies rows with now-line at 20:30",
        );

        // ── Step 2: Now-line at midnight boundary ──────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_now_hour(0);
            ui.global::<AppState>().set_epg_now_minute(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_grid_midnight",
            "Now-line at midnight",
            "Now-line sits at leftmost edge of the timeline grid",
        );

        // ── Step 3: Focus a live cell (D-pad nav simulated via detail props) ─

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_now_hour(20);
            ui.global::<AppState>().set_epg_now_minute(30);
            // Populate detail props — EPG screen reads these into the info bar
            ui.global::<AppState>()
                .set_epg_detail_channel_id("ch-sport".into());
            ui.global::<AppState>()
                .set_epg_detail_title("Championship League".into());
            ui.global::<AppState>()
                .set_epg_detail_description("Live match coverage.".into());
            ui.global::<AppState>().set_epg_detail_start("20:00".into());
            ui.global::<AppState>().set_epg_detail_end("22:00".into());
            ui.global::<AppState>().set_epg_detail_has_catchup(false);
            ui.global::<AppState>().set_epg_detail_is_now(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_grid_live_focused",
            "D-pad focus on live sports cell",
            "Info bar at bottom shows title, 20:00–22:00 range, LIVE badge",
        );

        // ── Step 4: Focus a past catch-up cell ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_epg_detail_channel_id("ch-news".into());
            ui.global::<AppState>()
                .set_epg_detail_title("Morning Briefing".into());
            ui.global::<AppState>()
                .set_epg_detail_description("Top stories from around the world.".into());
            ui.global::<AppState>().set_epg_detail_start("18:00".into());
            ui.global::<AppState>().set_epg_detail_end("19:30".into());
            ui.global::<AppState>().set_epg_detail_has_catchup(true);
            ui.global::<AppState>().set_epg_detail_is_now(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_grid_catchup_focused",
            "D-pad focus on past catch-up cell",
            "Info bar shows catch-up icon; past cell rendered dimmed",
        );

        // ── Step 5: Focus a future cell ────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_epg_detail_channel_id("ch-movies".into());
            ui.global::<AppState>()
                .set_epg_detail_title("Night at the Museum".into());
            ui.global::<AppState>()
                .set_epg_detail_description("Comedy adventure — coming up next.".into());
            ui.global::<AppState>().set_epg_detail_start("21:30".into());
            ui.global::<AppState>().set_epg_detail_end("23:15".into());
            ui.global::<AppState>().set_epg_detail_has_catchup(false);
            ui.global::<AppState>().set_epg_detail_is_now(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_grid_future_focused",
            "D-pad focus on future cell",
            "Info bar shows Remind action; future cell at normal opacity",
        );
    }
}
