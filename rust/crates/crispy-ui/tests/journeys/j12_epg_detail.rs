//! J-12: EPG Program Detail Sheet
//!
//! Dream: "Bottom sheet with artwork, synopsis, cast, context-dependent actions:
//! Watch Now (live), Catch-Up (past with catchup flag), Remind Me (future)."
//!
//! This journey opens the detail sheet for three programme types and verifies
//! the correct action buttons appear in each context.
//! Screenshots document what IS rendered — the review pipeline catches deviations.

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, EpgChannelRow, EpgData};
use slint::ComponentHandle;

pub struct J12;

impl Journey for J12 {
    const ID: &'static str = "j12";
    const NAME: &'static str = "EPG Program Detail Sheet";
    const DEPENDS_ON: &'static [&'static str] = &["j11"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Setup: EPG screen with data (inherit from J-11 seed) ───────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(2);
            ui.global::<AppState>().set_epg_now_hour(20);
            ui.global::<AppState>().set_epg_now_minute(30);
            ui.global::<AppState>().set_epg_date_label("Today".into());
            ui.global::<AppState>().set_epg_selected_date_offset(0);

            // Minimal row set so the grid is not empty behind the sheet
            let programmes: Vec<EpgData> = vec![EpgData {
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
                description: "Live match coverage. Full-time whistle at 22:00.".into(),
                category: "Sports".into(),
                has_catchup: false,
                is_now: true,
            }];

            let rows = vec![EpgChannelRow {
                channel_id: "ch-sport".into(),
                channel_name: "CrispySport 1".into(),
                channel_logo: Default::default(),
                programmes: programmes.as_slice().into(),
            }];

            ui.global::<AppState>().set_epg_rows(rows.as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        // ── Step 1: Sheet closed (baseline) ───────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_epg_detail(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_detail_closed",
            "Detail sheet closed",
            "EPG grid visible without any overlay sheet",
        );

        // ── Step 2: Watch Now — live programme ─────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_epg_detail_program_id("prog-sport-live".into());
            ui.global::<AppState>()
                .set_epg_detail_channel_id("ch-sport".into());
            ui.global::<AppState>()
                .set_epg_detail_channel_name("CrispySport 1".into());
            ui.global::<AppState>()
                .set_epg_detail_title("Championship League".into());
            ui.global::<AppState>().set_epg_detail_description(
                "Live match coverage. Full-time whistle at 22:00. \
                     Two teams battle for the title in this season finale."
                    .into(),
            );
            ui.global::<AppState>().set_epg_detail_start("20:00".into());
            ui.global::<AppState>().set_epg_detail_end("22:00".into());
            ui.global::<AppState>()
                .set_epg_detail_category("Sports".into());
            ui.global::<AppState>().set_epg_detail_has_catchup(false);
            ui.global::<AppState>().set_epg_detail_is_now(true);
            ui.global::<AppState>().set_show_epg_detail(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_detail_live",
            "Detail sheet — live programme",
            "Sheet shows Watch Now button; LIVE badge visible; no Catch-Up or Remind",
        );

        // ── Step 3: Catch-Up — past programme with catch-up available ──────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_epg_detail_program_id("prog-news-morning".into());
            ui.global::<AppState>()
                .set_epg_detail_channel_id("ch-news".into());
            ui.global::<AppState>()
                .set_epg_detail_channel_name("CrispyNews HD".into());
            ui.global::<AppState>()
                .set_epg_detail_title("Morning Briefing".into());
            ui.global::<AppState>().set_epg_detail_description(
                "Top stories from around the world. \
                     Business, politics, and sport in 90 minutes."
                    .into(),
            );
            ui.global::<AppState>().set_epg_detail_start("18:00".into());
            ui.global::<AppState>().set_epg_detail_end("19:30".into());
            ui.global::<AppState>()
                .set_epg_detail_category("News".into());
            ui.global::<AppState>().set_epg_detail_has_catchup(true);
            ui.global::<AppState>().set_epg_detail_is_now(false);
            // sheet stays open — update props in place
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_detail_catchup",
            "Detail sheet — past programme with catch-up",
            "Sheet shows Watch (catch-up) button; no LIVE badge; no Remind",
        );

        // ── Step 4: Past programme without catch-up ────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_epg_detail_program_id("prog-sport-prematch".into());
            ui.global::<AppState>()
                .set_epg_detail_channel_id("ch-sport".into());
            ui.global::<AppState>()
                .set_epg_detail_channel_name("CrispySport 1".into());
            ui.global::<AppState>()
                .set_epg_detail_title("Pre-Match".into());
            ui.global::<AppState>()
                .set_epg_detail_description("Build-up to tonight's fixture.".into());
            ui.global::<AppState>().set_epg_detail_start("19:30".into());
            ui.global::<AppState>().set_epg_detail_end("20:00".into());
            ui.global::<AppState>()
                .set_epg_detail_category("Sports".into());
            ui.global::<AppState>().set_epg_detail_has_catchup(false);
            ui.global::<AppState>().set_epg_detail_is_now(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_detail_past_no_catchup",
            "Detail sheet — past without catch-up",
            "Sheet shows neither Watch nor Catch-Up; only Close; no Remind",
        );

        // ── Step 5: Remind Me — future programme ───────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>()
                .set_epg_detail_program_id("prog-movies-night".into());
            ui.global::<AppState>()
                .set_epg_detail_channel_id("ch-movies".into());
            ui.global::<AppState>()
                .set_epg_detail_channel_name("CrispyCinema".into());
            ui.global::<AppState>()
                .set_epg_detail_title("Night at the Museum".into());
            ui.global::<AppState>().set_epg_detail_description(
                "Comedy adventure. A museum night guard discovers the \
                     exhibits come to life after dark."
                    .into(),
            );
            ui.global::<AppState>().set_epg_detail_start("21:30".into());
            ui.global::<AppState>().set_epg_detail_end("23:15".into());
            ui.global::<AppState>()
                .set_epg_detail_category("Movies".into());
            ui.global::<AppState>().set_epg_detail_has_catchup(false);
            ui.global::<AppState>().set_epg_detail_is_now(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_detail_future_remind",
            "Detail sheet — future programme",
            "Sheet shows Remind Me button; no Watch or Catch-Up; no LIVE badge",
        );

        // ── Step 6: Dismiss the sheet ──────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_epg_detail(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_detail_dismissed",
            "Sheet dismissed",
            "EPG grid returns to full-screen; no sheet overlay",
        );
    }
}
