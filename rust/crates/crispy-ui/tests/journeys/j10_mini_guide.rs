//! J-10: Live TV Mini-Guide Overlay (Now/Next Strip)
//!
//! Dream: "Bottom strip overlay with now/next EPG. Cycle nearby channels.
//! Watch from Start for catch-up. Auto-hide 5s."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ChannelData, EpgData, PlayerState};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J10;

impl Journey for J10 {
    const ID: &'static str = "j10";
    const NAME: &'static str = "Mini-Guide / Now-Next Overlay";
    const DEPENDS_ON: &'static [&'static str] = &["j05"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Setup: watching Channel 3, OSD hidden ─────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(4); // Player

            // Nearby channels for mini-guide cycling
            let channels: Vec<ChannelData> = (1u32..=8)
                .map(|i| ChannelData {
                    id: format!("ch_{i}").into(),
                    name: format!("Channel {i:03}").into(),
                    group: "All".into(),
                    logo_url: "".into(),
                    stream_url: format!("http://iptv.example.com/live/ch{i}.ts").into(),
                    source_id: "test_src_0".into(),
                    number: i as i32,
                    is_favorite: i <= 2,
                    has_catchup: i % 2 == 0, // even channels have catch-up
                    resolution: "1080p".into(),
                    now_playing: format!("Programme on Ch {i}").into(),
                    logo: Default::default(),
                })
                .collect();
            app.set_channels(ModelRc::new(VecModel::from(channels)));

            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_live(true);
            ps.set_current_title("Channel 003".into());
            ps.set_current_channel_id("ch_3".into());
            ps.set_current_programme("Evening Drama".into());
            ps.set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "watching_ch3_immersive",
            "Watching Channel 3 — immersive, no overlay",
            "Full-screen video; no OSD; no mini-guide",
        );

        // ── Step 1: Open mini-guide (OK / info key) ───────────────────────

        harness.press_ok("mini_guide_open", "OK key opens mini-guide overlay");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_channel_overlay(true);

            // EPG rows for nearby channels (ch_2, ch_3 current, ch_4)
            let epg_rows: Vec<EpgData> = vec![
                // ch_2 row
                EpgData {
                    channel_id: "ch_2".into(),
                    channel_name: "Channel 002".into(),
                    channel_logo: Default::default(),
                    title: "Morning Show".into(),
                    start_hour: 18,
                    start_minute: 0,
                    end_hour: 19,
                    end_minute: 0,
                    duration_minutes: 60,
                    progress_percent: 0.45,
                    description: "Daily morning programme".into(),
                    category: "Entertainment".into(),
                    has_catchup: true,
                    is_now: true,
                },
                // ch_3 current row
                EpgData {
                    channel_id: "ch_3".into(),
                    channel_name: "Channel 003".into(),
                    channel_logo: Default::default(),
                    title: "Evening Drama".into(),
                    start_hour: 19,
                    start_minute: 0,
                    end_hour: 20,
                    end_minute: 30,
                    duration_minutes: 90,
                    progress_percent: 0.3,
                    description: "Prime time drama series".into(),
                    category: "Drama".into(),
                    has_catchup: false,
                    is_now: true,
                },
                // ch_4 row
                EpgData {
                    channel_id: "ch_4".into(),
                    channel_name: "Channel 004".into(),
                    channel_logo: Default::default(),
                    title: "Sports Night".into(),
                    start_hour: 19,
                    start_minute: 30,
                    end_hour: 22,
                    end_minute: 0,
                    duration_minutes: 150,
                    progress_percent: 0.15,
                    description: "Live sports coverage".into(),
                    category: "Sports".into(),
                    has_catchup: true,
                    is_now: true,
                },
            ];
            app.set_epg_rows(ModelRc::new(VecModel::from(
                epg_rows
                    .into_iter()
                    .map(|e| crate::EpgChannelRow {
                        channel_id: e.channel_id.clone(),
                        channel_name: e.channel_name.clone(),
                        channel_logo: Default::default(),
                        programmes: ModelRc::new(VecModel::from(vec![e])),
                    })
                    .collect::<Vec<_>>(),
            )));
            app.set_epg_now_hour(19);
            app.set_epg_now_minute(30);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "mini_guide_visible",
            "Mini-guide overlay opens",
            "Bottom strip shows now/next EPG for nearby channels; current channel highlighted; progress bars visible",
        );

        // ── Step 2: Cycle up — preview Channel 2 ──────────────────────────

        harness.press_up("mini_guide_ch2_preview", "D-pad up cycles to Channel 2");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            // Preview ch_2 — video deferred, banner updates
            ps.set_current_title("Channel 002".into());
            ps.set_current_programme("Morning Show".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "mini_guide_ch2_highlighted",
            "Channel 2 previewed in mini-guide",
            "Channel 2 row highlighted in mini-guide; programme name and progress bar shown",
        );

        // ── Step 3: Cycle down — return to Channel 3, then Channel 4 ──────

        harness.press_down("mini_guide_ch3_preview", "D-pad down back to Channel 3");

        harness.assert_screenshot(
            "mini_guide_ch3_current",
            "Channel 3 re-highlighted (current)",
            "Channel 3 row highlighted; 'Now' badge; progress at 30%",
        );

        harness.press_down("mini_guide_ch4_preview", "D-pad down to Channel 4");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_current_title("Channel 004".into());
            ps.set_current_programme("Sports Night".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "mini_guide_ch4_highlighted",
            "Channel 4 previewed — catch-up available",
            "Channel 4 row highlighted; 'Watch from Start' option visible (has_catchup=true)",
        );

        // ── Step 4: Select Channel 4 — switches playback ──────────────────

        harness.press_ok("switch_to_ch4", "OK on Channel 4 — switch channel");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_channel_overlay(false);
            let ps = ui.global::<PlayerState>();
            ps.set_current_title("Channel 004".into());
            ps.set_current_channel_id("ch_4".into());
            ps.set_current_programme("Sports Night".into());
            ps.set_is_playing(true);
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "ch4_playing_osd",
            "Switched to Channel 4",
            "Mini-guide dismissed; Channel 4 playing; OSD shows channel name and programme",
        );

        // ── Step 5: Mini-guide auto-hides after 5s ────────────────────────

        // Simulate re-opening mini-guide then auto-hide
        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_channel_overlay(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "mini_guide_auto_hide_start",
            "Mini-guide re-opened — 5s auto-hide timer starts",
            "Mini-guide visible; 5-second auto-hide timer active",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_show_channel_overlay(false);
            ui.global::<PlayerState>().set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "mini_guide_auto_hidden",
            "Mini-guide auto-hides after 5s",
            "Mini-guide dismissed automatically; immersive playback resumes; no chrome visible",
        );
    }
}
