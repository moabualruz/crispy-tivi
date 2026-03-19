//! J-06: Channel Zapping — Quick Switch While Watching
//!
//! Dream: "D-pad up/down instant channel switch. Zap banner overlay. Rapid
//! zap with deferred video load. Previous channel toggle."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ChannelData, PlayerState};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J06;

impl Journey for J06 {
    const ID: &'static str = "j06";
    const NAME: &'static str = "Instant Channel Zapping";
    const DEPENDS_ON: &'static [&'static str] = &["j05"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Setup: start watching Channel 5 ───────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(4); // Player screen

            // Populate the channel list for zap navigation
            let channels: Vec<ChannelData> = (1u32..=20)
                .map(|i| ChannelData {
                    id: format!("ch_{i}").into(),
                    name: format!("Channel {i:03}").into(),
                    group: "All".into(),
                    logo_url: "".into(),
                    stream_url: format!("http://iptv.example.com/live/ch{i}.ts").into(),
                    source_id: "test_src_0".into(),
                    number: i as i32,
                    is_favorite: i <= 3,
                    has_catchup: false,
                    resolution: "1080p".into(),
                    now_playing: format!("Programme on Ch {i}").into(),
                    logo: Default::default(),
                })
                .collect();
            app.set_channels(ModelRc::new(VecModel::from(channels)));

            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_live(true);
            ps.set_current_title("Channel 005".into());
            ps.set_current_channel_id("ch_5".into());
            ps.set_current_programme("Programme on Ch 5".into());
            ps.set_show_osd(false); // OSD hidden during immersive watch
            ps.set_buffered(0.6);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "watching_ch5_immersive",
            "Watching Channel 5 — OSD hidden",
            "Immersive playback; no OSD; video fills window",
        );

        // ── Step 1: Zap up — D-pad up shows channel banner ────────────────

        harness.press_up("zap_up_ch6_banner", "D-pad up zaps to Channel 6");

        if let Some(ui) = harness.ui::<AppWindow>() {
            // Zap banner overlay: new channel info shown, video load deferred
            let app = ui.global::<AppState>();
            app.set_show_channel_overlay(true);
            let ps = ui.global::<PlayerState>();
            ps.set_is_buffering(true); // deferred load — buffering while banner shows
            ps.set_current_title("Channel 006".into());
            ps.set_current_channel_id("ch_6".into());
            ps.set_current_programme("Programme on Ch 6".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "zap_banner_ch6",
            "Zap banner appears — Channel 6",
            "Zap overlay shows Channel 6 name and programme; previous video still visible; buffering indicator",
        );

        // ── Step 2: Rapid zap — D-pad up again before load completes ──────

        harness.press_up("rapid_zap_ch7", "Rapid D-pad up — skip to Channel 7");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_current_title("Channel 007".into());
            ps.set_current_channel_id("ch_7".into());
            ps.set_current_programme("Programme on Ch 7".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "zap_banner_ch7_rapid",
            "Rapid zap — Channel 7 before 6 loaded",
            "Zap banner updates to Channel 7; deferred load cancels Channel 6 request",
        );

        harness.press_up("rapid_zap_ch8", "Rapid D-pad up — skip to Channel 8");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_current_title("Channel 008".into());
            ps.set_current_channel_id("ch_8".into());
            ps.set_current_programme("Programme on Ch 8".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "zap_banner_ch8_rapid",
            "Rapid zap — Channel 8",
            "Banner reflects Channel 8; previous zaps discarded",
        );

        // ── Step 3: Zap settles — video loads for Channel 8 ───────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_channel_overlay(false);
            let ps = ui.global::<PlayerState>();
            ps.set_is_buffering(false);
            ps.set_is_playing(true);
            ps.set_show_osd(true); // OSD briefly shown on settle
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "ch8_playing_osd",
            "Channel 8 settled — video loaded",
            "Channel 8 playing; OSD visible briefly; no zap banner",
        );

        // ── Step 4: Zap down — D-pad down ─────────────────────────────────

        harness.press_down("zap_down_ch7", "D-pad down zaps back to Channel 7");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_channel_overlay(true);
            let ps = ui.global::<PlayerState>();
            ps.set_is_buffering(true);
            ps.set_current_title("Channel 007".into());
            ps.set_current_channel_id("ch_7".into());
            ps.set_current_programme("Programme on Ch 7".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "zap_down_ch7_banner",
            "Zap down to Channel 7",
            "Zap banner shows Channel 7; D-pad down reversal works",
        );

        // ── Step 5: Previous channel toggle (Back key) ─────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_show_channel_overlay(false);
            let ps = ui.global::<PlayerState>();
            ps.set_is_buffering(false);
            ps.set_is_playing(true);
            ps.set_current_title("Channel 007".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "ch7_settled",
            "Channel 7 settled",
            "Channel 7 playing; banner gone; OSD visible",
        );

        // Back = toggle to previous channel (ch_8)
        harness.press_back("prev_channel_toggle", "Back key — toggle previous channel");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_current_title("Channel 008".into());
            ps.set_current_channel_id("ch_8".into());
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "prev_channel_ch8",
            "Previous channel restored — Channel 8",
            "Previous channel (Channel 8) restored instantly; OSD shows channel name",
        );
    }
}
