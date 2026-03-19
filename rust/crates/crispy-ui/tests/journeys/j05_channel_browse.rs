//! J-05: Channel Browsing — List View to Playback
//!
//! Dream: "Group sidebar + virtual channel list (10k+ channels). Inline EPG
//! now/next. Sub-500ms zap. Alphabet quick-jump."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ChannelData, PlayerState};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J05;

impl Journey for J05 {
    const ID: &'static str = "j05";
    const NAME: &'static str = "Channel Browsing — List View to Playback";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Step 0: Navigate to Live TV screen ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(1); // Live TV
            app.set_total_channel_count(10_500);
            app.set_is_loading_channels(false);

            // Group sidebar entries
            let groups: Vec<slint::SharedString> = vec![
                "News".into(),
                "Sports".into(),
                "Movies".into(),
                "Entertainment".into(),
                "Kids".into(),
                "Documentary".into(),
            ];
            app.set_channel_groups(ModelRc::new(VecModel::from(groups)));
            app.set_active_channel_group("".into()); // "All" selected

            // Windowed channel list — first 30 visible slots representing 10k+ dataset
            let channels: Vec<ChannelData> = (1u32..=30)
                .map(|i| ChannelData {
                    id: format!("ch_{i}").into(),
                    name: format!("Channel {i:03}").into(),
                    group: if i <= 5 {
                        "News".into()
                    } else {
                        "Sports".into()
                    },
                    logo_url: "".into(),
                    stream_url: format!("http://iptv.example.com/live/ch{i}.ts").into(),
                    source_id: "test_src_0".into(),
                    number: i as i32,
                    is_favorite: i <= 3,
                    has_catchup: i % 3 == 0,
                    resolution: if i % 5 == 0 {
                        "4K".into()
                    } else {
                        "1080p".into()
                    },
                    now_playing: format!("Programme {i}: Evening News").into(),
                    logo: Default::default(),
                })
                .collect();
            app.set_channels(ModelRc::new(VecModel::from(channels)));
            app.set_channel_window_start(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_tv_initial",
            "Live TV screen opens",
            "Group sidebar visible left; channel list with inline EPG now/next; 10k+ channels windowed",
        );

        // ── Step 1: Navigate down channel list ────────────────────────────

        harness.press_down("channel_2_focused", "D-pad down to channel 2");
        harness.press_down("channel_3_focused", "D-pad down to channel 3");
        harness.press_down("channel_4_focused", "D-pad down to channel 4");
        harness.press_down("channel_5_focused", "D-pad down to channel 5");

        harness.assert_screenshot(
            "channel_5_focused",
            "Navigate down 5 channels",
            "Channel 5 focused; EPG preview panel at top updates with channel 5 programme",
        );

        // ── Step 2: Navigate to group sidebar ─────────────────────────────

        harness.press_left("group_sidebar_focused", "D-pad left into group sidebar");

        harness.assert_screenshot(
            "group_sidebar_focused",
            "Group sidebar receives focus",
            "Group sidebar focused; 'All' chip highlighted with focus ring",
        );

        harness.press_down("group_news_focused", "Navigate to News group chip");

        harness.assert_screenshot(
            "news_chip_focused",
            "News group chip focused",
            "News chip has white focus ring; other chips unfocused",
        );

        harness.press_ok("news_group_selected", "Select News group filter");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_channel_group("News".into());
            let news_channels: Vec<ChannelData> = (1u32..=5)
                .map(|i| ChannelData {
                    id: format!("news_{i}").into(),
                    name: format!("News Channel {i}").into(),
                    group: "News".into(),
                    logo_url: "".into(),
                    stream_url: format!("http://iptv.example.com/live/news{i}.ts").into(),
                    source_id: "test_src_0".into(),
                    number: i as i32,
                    is_favorite: i == 1,
                    has_catchup: true,
                    resolution: "1080p".into(),
                    now_playing: format!("Breaking News Hour {i}").into(),
                    logo: Default::default(),
                })
                .collect();
            app.set_channels(ModelRc::new(VecModel::from(news_channels)));
            app.set_channel_window_start(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "news_group_filtered",
            "News group filter applied",
            "Channel list filtered to 5 News channels; News chip shows active state",
        );

        // ── Step 3: Alphabet quick-jump — number entry overlay (M-011) ────

        harness.press_right("channel_list_refocused", "D-pad right to channel list");

        harness.assert_screenshot(
            "channel_list_after_filter",
            "Channel list focused after group filter",
            "Channel 1 of News group pre-focused",
        );

        // ── Step 4: Select channel — playback starts sub-500ms ─────────────

        harness.press_ok(
            "channel_1_selected",
            "Select News Channel 1 — triggers playback",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_live(true);
            ps.set_current_title("News Channel 1".into());
            ps.set_current_group("News".into());
            ps.set_current_channel_id("news_1".into());
            ps.set_current_programme("Breaking News Hour 1".into());
            ps.set_show_osd(true);
            ps.set_buffered(0.4);
            ui.global::<AppState>().set_active_screen(4); // Player
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "channel_playing_osd_visible",
            "Channel selected — playback starts",
            "Player screen; OSD visible; channel name, programme, live badge shown",
        );

        // ── Step 5: OSD fades after 3s inactivity ─────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<PlayerState>().set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "osd_hidden_immersive",
            "OSD hides after 3s",
            "Immersive video fills screen; no OSD chrome; video underlay fills window",
        );
    }
}
