//! J-13: Multi-Day EPG Navigation
//!
//! Dream: "Day selector chips + date picker, 7 days back + 7 forward, continuous
//! scroll across midnight."
//!
//! This journey exercises the day-offset selector: today, yesterday, two days
//! back, tomorrow, and seven days forward. Each offset triggers a label change
//! and fresh row data representing that day's schedule.
//! Screenshots document what IS rendered — the review pipeline catches deviations.

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, EpgChannelRow, EpgData};
use slint::ComponentHandle;

pub struct J13;

impl Journey for J13 {
    const ID: &'static str = "j13";
    const NAME: &'static str = "Multi-Day EPG Navigation";
    const DEPENDS_ON: &'static [&'static str] = &["j11"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // Helper: build a single representative row for a given day offset.
        // In the real app, Rust rebuilds epg-rows when select-epg-date fires.
        // Here we simulate that by setting rows + label together.
        fn make_row_for_day(offset: i32) -> EpgChannelRow {
            let (title, start_h, end_h, is_now): (&str, i32, i32, bool) = match offset {
                i32::MIN..=-1 => ("Archived Broadcast", 20, 22, false),
                0 => ("Evening Report", 20, 21, true),
                _ => ("Upcoming Special", 21, 23, false),
            };

            let prog = EpgData {
                channel_id: "ch-news".into(),
                channel_name: "CrispyNews HD".into(),
                channel_logo: Default::default(),
                title: title.into(),
                start_hour: start_h,
                start_minute: 0,
                end_hour: end_h,
                end_minute: 0,
                duration_minutes: (end_h - start_h) * 60,
                progress_percent: if is_now { 0.4 } else { 0.0 },
                description: slint::SharedString::from(format!(
                    "Programme for day offset {offset}."
                ))
                .into(),
                category: "News".into(),
                has_catchup: offset < 0,
                is_now,
            };

            EpgChannelRow {
                channel_id: "ch-news".into(),
                channel_name: "CrispyNews HD".into(),
                channel_logo: Default::default(),
                programmes: vec![prog].as_slice().into(),
            }
        }

        fn day_label(offset: i32) -> &'static str {
            match offset {
                -7 => "7 Days Ago",
                -2 => "2 Days Ago",
                -1 => "Yesterday",
                0 => "Today",
                1 => "Tomorrow",
                7 => "7 Days Ahead",
                _ => "Selected Day",
            }
        }

        // ── Setup: EPG screen, today ───────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(2);
            ui.global::<AppState>().set_epg_now_hour(20);
            ui.global::<AppState>().set_epg_now_minute(30);
            ui.global::<AppState>().set_epg_selected_date_offset(0);
            ui.global::<AppState>()
                .set_epg_date_label(day_label(0).into());
            let row = make_row_for_day(0);
            ui.global::<AppState>()
                .set_epg_rows(vec![row].as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_multiday_today",
            "Day 0 — Today",
            "Day chip 'Today' active; grid shows current day schedule with live programme",
        );

        // ── Step 1: Navigate to Yesterday (offset -1) ─────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_selected_date_offset(-1);
            ui.global::<AppState>()
                .set_epg_date_label(day_label(-1).into());
            let row = make_row_for_day(-1);
            ui.global::<AppState>()
                .set_epg_rows(vec![row].as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_multiday_yesterday",
            "Day -1 — Yesterday",
            "'Yesterday' chip active; all programmes past; catch-up icons shown",
        );

        // ── Step 2: Navigate 2 days back (offset -2) ──────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_selected_date_offset(-2);
            ui.global::<AppState>()
                .set_epg_date_label(day_label(-2).into());
            let row = make_row_for_day(-2);
            ui.global::<AppState>()
                .set_epg_rows(vec![row].as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_multiday_minus2",
            "Day -2 — 2 Days Ago",
            "Day chip shows '2 Days Ago'; historic schedule; catch-up available badge",
        );

        // ── Step 3: Navigate to maximum past (offset -7) ──────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_selected_date_offset(-7);
            ui.global::<AppState>()
                .set_epg_date_label(day_label(-7).into());
            let row = make_row_for_day(-7);
            ui.global::<AppState>()
                .set_epg_rows(vec![row].as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_multiday_minus7",
            "Day -7 — Maximum past",
            "Leftmost chip '7 Days Ago' active; no navigation further back",
        );

        // ── Step 4: Navigate back to Today ────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_selected_date_offset(0);
            ui.global::<AppState>()
                .set_epg_date_label(day_label(0).into());
            let row = make_row_for_day(0);
            ui.global::<AppState>()
                .set_epg_rows(vec![row].as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_multiday_back_today",
            "Return to Today",
            "'Today' chip re-selected; live now-line and current programme visible",
        );

        // ── Step 5: Navigate to Tomorrow (offset +1) ──────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_selected_date_offset(1);
            ui.global::<AppState>()
                .set_epg_date_label(day_label(1).into());
            let row = make_row_for_day(1);
            ui.global::<AppState>()
                .set_epg_rows(vec![row].as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_multiday_tomorrow",
            "Day +1 — Tomorrow",
            "'Tomorrow' chip active; all programmes future; Remind Me actions available",
        );

        // ── Step 6: Navigate to maximum future (offset +7) ────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_epg_selected_date_offset(7);
            ui.global::<AppState>()
                .set_epg_date_label(day_label(7).into());
            let row = make_row_for_day(7);
            ui.global::<AppState>()
                .set_epg_rows(vec![row].as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_multiday_plus7",
            "Day +7 — Maximum future",
            "Rightmost chip '7 Days Ahead' active; no navigation further forward",
        );

        // ── Step 7: Midnight-crossing programme (spans two calendar days) ──

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Simulate a programme that started at 23:00 yesterday and ends 01:00 today.
            // The now-line at 00:30 falls within this cross-midnight programme.
            ui.global::<AppState>().set_epg_selected_date_offset(0);
            ui.global::<AppState>().set_epg_date_label("Today".into());
            ui.global::<AppState>().set_epg_now_hour(0);
            ui.global::<AppState>().set_epg_now_minute(30);

            let midnight_prog = EpgData {
                channel_id: "ch-news".into(),
                channel_name: "CrispyNews HD".into(),
                channel_logo: Default::default(),
                title: "Late Night Special".into(),
                // Represented as starting before midnight on this day's window
                start_hour: 23,
                start_minute: 0,
                end_hour: 1,
                end_minute: 0,
                duration_minutes: 120,
                progress_percent: 0.25,
                description: "Cross-midnight broadcast — starts yesterday, ends today.".into(),
                category: "News".into(),
                has_catchup: false,
                is_now: true,
            };

            let row = EpgChannelRow {
                channel_id: "ch-news".into(),
                channel_name: "CrispyNews HD".into(),
                channel_logo: Default::default(),
                programmes: vec![midnight_prog].as_slice().into(),
            };

            ui.global::<AppState>()
                .set_epg_rows(vec![row].as_slice().into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "epg_multiday_midnight_cross",
            "Cross-midnight programme at 00:30",
            "Now-line at left edge; programme cell spans full visible width; LIVE badge shown",
        );
    }
}
