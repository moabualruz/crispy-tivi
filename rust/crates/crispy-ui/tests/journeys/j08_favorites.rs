//! J-08: Favorite Channels Quick-Access
//!
//! Dream: "Long-press OK to favorite. Favorites group pinned in sidebar.
//! Reorderable. Multiple named favorites groups."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ChannelData};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J08;

impl Journey for J08 {
    const ID: &'static str = "j08";
    const NAME: &'static str = "Favorites — Add / Remove / Browse";
    const DEPENDS_ON: &'static [&'static str] = &["j05"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Setup: Live TV screen — channels without favorites ─────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(1); // Live TV

            // Groups: Favorites pinned first (even when empty it should appear)
            let groups: Vec<slint::SharedString> = vec![
                "Favorites".into(),
                "News".into(),
                "Sports".into(),
                "Movies".into(),
            ];
            app.set_channel_groups(ModelRc::new(VecModel::from(groups)));
            app.set_active_channel_group("".into()); // All

            // Channels — none favorited yet
            let channels: Vec<ChannelData> = (1u32..=10)
                .map(|i| ChannelData {
                    id: format!("ch_{i}").into(),
                    name: format!("Channel {i:03}").into(),
                    group: if i <= 3 {
                        "News".into()
                    } else {
                        "Sports".into()
                    },
                    logo_url: "".into(),
                    stream_url: format!("http://iptv.example.com/live/ch{i}.ts").into(),
                    source_id: "test_src_0".into(),
                    number: i as i32,
                    is_favorite: false,
                    has_catchup: false,
                    resolution: "1080p".into(),
                    now_playing: format!("Show on Ch {i}").into(),
                    logo: Default::default(),
                })
                .collect();
            app.set_channels(ModelRc::new(VecModel::from(channels)));
            app.set_channel_window_start(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_tv_no_favorites",
            "Live TV — no favorites yet",
            "Favorites group in sidebar (empty); all channels listed; no favorite star icons",
        );

        // ── Step 1: Focus Channel 2 ────────────────────────────────────────

        harness.press_down("ch2_focused", "D-pad down to Channel 2");

        harness.assert_screenshot(
            "channel_2_focused",
            "Channel 2 focused",
            "Channel 2 row highlighted; EPG preview updates",
        );

        // ── Step 2: Long-press OK → add to favorites ───────────────────────
        // Long-press is simulated by the toggle-favorite callback.
        // In headless tests we inject state directly (long-press gesture not
        // available in key events — the Rust backend handles the gesture).

        harness.press_ok(
            "long_press_ok_ch2",
            "Long-press OK on Channel 2 to favorite",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // Channel 2 is now favorited
            let channels: Vec<ChannelData> = (1u32..=10)
                .map(|i| ChannelData {
                    id: format!("ch_{i}").into(),
                    name: format!("Channel {i:03}").into(),
                    group: if i <= 3 {
                        "News".into()
                    } else {
                        "Sports".into()
                    },
                    logo_url: "".into(),
                    stream_url: format!("http://iptv.example.com/live/ch{i}.ts").into(),
                    source_id: "test_src_0".into(),
                    number: i as i32,
                    is_favorite: i == 2, // Channel 2 favorited
                    has_catchup: false,
                    resolution: "1080p".into(),
                    now_playing: format!("Show on Ch {i}").into(),
                    logo: Default::default(),
                })
                .collect();
            app.set_channels(ModelRc::new(VecModel::from(channels)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "ch2_favorited",
            "Channel 2 added to favorites",
            "Channel 2 shows filled star/heart icon; toast or visual confirmation shown",
        );

        // ── Step 3: Add Channel 5 to favorites ────────────────────────────

        harness.press_down("ch3_focused", "D-pad down to Channel 3");
        harness.press_down("ch4_focused", "D-pad down to Channel 4");
        harness.press_down("ch5_focused", "D-pad down to Channel 5");
        harness.press_ok("favorite_ch5", "Long-press OK on Channel 5 to favorite");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            let channels: Vec<ChannelData> = (1u32..=10)
                .map(|i| ChannelData {
                    id: format!("ch_{i}").into(),
                    name: format!("Channel {i:03}").into(),
                    group: if i <= 3 {
                        "News".into()
                    } else {
                        "Sports".into()
                    },
                    logo_url: "".into(),
                    stream_url: format!("http://iptv.example.com/live/ch{i}.ts").into(),
                    source_id: "test_src_0".into(),
                    number: i as i32,
                    is_favorite: i == 2 || i == 5,
                    has_catchup: false,
                    resolution: "1080p".into(),
                    now_playing: format!("Show on Ch {i}").into(),
                    logo: Default::default(),
                })
                .collect();
            app.set_channels(ModelRc::new(VecModel::from(channels)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "two_channels_favorited",
            "Channel 2 and 5 favorited",
            "Both Channel 2 and 5 show favorite indicator; Favorites group in sidebar has count badge",
        );

        // ── Step 4: Switch to Favorites group — pinned sidebar entry ──────

        harness.press_left("sidebar_focused_for_fav", "D-pad left to group sidebar");
        harness.press_ok("all_group_focused", "Focus All group chip");

        harness.assert_screenshot(
            "sidebar_focused",
            "Group sidebar focused",
            "Sidebar focused; Favorites chip is first/pinned at top",
        );

        // Navigate up to Favorites (it's pinned at top)
        harness.press_up("favorites_chip_focused", "Navigate to Favorites chip");

        harness.assert_screenshot(
            "favorites_chip_focused",
            "Favorites group chip focused",
            "Favorites chip highlighted; pinned at top of sidebar group list",
        );

        harness.press_ok("favorites_group_selected", "Select Favorites group");

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_channel_group("Favorites".into());

            // Only favorited channels
            let fav_channels: Vec<ChannelData> = vec![
                ChannelData {
                    id: "ch_2".into(),
                    name: "Channel 002".into(),
                    group: "News".into(),
                    logo_url: "".into(),
                    stream_url: "http://iptv.example.com/live/ch2.ts".into(),
                    source_id: "test_src_0".into(),
                    number: 2,
                    is_favorite: true,
                    has_catchup: false,
                    resolution: "1080p".into(),
                    now_playing: "Show on Ch 2".into(),
                    logo: Default::default(),
                },
                ChannelData {
                    id: "ch_5".into(),
                    name: "Channel 005".into(),
                    group: "Sports".into(),
                    logo_url: "".into(),
                    stream_url: "http://iptv.example.com/live/ch5.ts".into(),
                    source_id: "test_src_0".into(),
                    number: 5,
                    is_favorite: true,
                    has_catchup: false,
                    resolution: "1080p".into(),
                    now_playing: "Show on Ch 5".into(),
                    logo: Default::default(),
                },
            ];
            app.set_channels(ModelRc::new(VecModel::from(fav_channels)));
            app.set_channel_window_start(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "favorites_group_view",
            "Favorites group selected",
            "Only 2 favorited channels shown; Favorites chip active in sidebar; reorder handles visible",
        );

        // ── Step 5: Remove a favorite ──────────────────────────────────────

        harness.press_right("ch2_focused_in_fav", "D-pad right to channel list");
        harness.press_ok(
            "unfavorite_ch2",
            "Long-press OK on Channel 2 — removes from favorites",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // Channel 2 removed from favorites — list now has only Channel 5
            let fav_channels: Vec<ChannelData> = vec![ChannelData {
                id: "ch_5".into(),
                name: "Channel 005".into(),
                group: "Sports".into(),
                logo_url: "".into(),
                stream_url: "http://iptv.example.com/live/ch5.ts".into(),
                source_id: "test_src_0".into(),
                number: 5,
                is_favorite: true,
                has_catchup: false,
                resolution: "1080p".into(),
                now_playing: "Show on Ch 5".into(),
                logo: Default::default(),
            }];
            app.set_channels(ModelRc::new(VecModel::from(fav_channels)));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "ch2_unfavorited",
            "Channel 2 removed from favorites",
            "Favorites list now shows only Channel 5; Channel 2 star icon cleared",
        );
    }
}
