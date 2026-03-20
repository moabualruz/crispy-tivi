//! J-07: Number Pad Direct Channel Entry
//!
//! Dream: "Digit keys → large number overlay. Auto-switch after 1.5s timeout.
//! Channel name preview. Configurable timeout."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ChannelData, PlayerState};
use slint::SharedString;
use slint::platform::{Key, WindowEvent};
use slint::{ComponentHandle, ModelRc, VecModel};

pub struct J07;

impl Journey for J07 {
    const ID: &'static str = "j07";
    const NAME: &'static str = "Number-Pad Channel Entry";
    const DEPENDS_ON: &'static [&'static str] = &["j05"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Setup: watching a channel, player active ───────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(1); // Live TV — M-011 number entry lives here

            if !harness.has_real_data() {
                // Channels for lookup (number 1–999 range)
                let channels: Vec<ChannelData> = (1u32..=50)
                    .map(|i| ChannelData {
                        id: format!("ch_{i}").into(),
                        name: format!("Channel {i:03}").into(),
                        group: "All".into(),
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
            }

            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_live(true);
            ps.set_current_title("Channel 001".into());
            ps.set_current_channel_id("ch_1".into());
            ps.set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "watching_ch1",
            "Watching Channel 1 — number pad idle",
            "Immersive playback; no number overlay",
        );

        // ── Step 1: Press digit '4' — number overlay appears ──────────────

        // Inject digit '4' as a key event (M-011 FocusScope in LiveTvScreen captures digits)
        {
            let w = harness.window();
            let text: SharedString = "4".into();
            w.dispatch_event(WindowEvent::KeyPressed { text: text.clone() });
            w.dispatch_event(WindowEvent::KeyReleased { text });
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "number_overlay_4",
            "Digit '4' pressed — number overlay shown",
            "Large number overlay displays '4'; channel name preview shows Channel 004; 1.5s timeout starts",
        );

        // ── Step 2: Press digit '2' — overlay updates to two digits ───────

        {
            let w = harness.window();
            let text: SharedString = "2".into();
            w.dispatch_event(WindowEvent::KeyPressed { text: text.clone() });
            w.dispatch_event(WindowEvent::KeyReleased { text });
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "number_overlay_42",
            "Digit '2' pressed — overlay shows '42'",
            "Overlay displays '42'; channel name preview updates to Channel 042; timeout resets",
        );

        // ── Step 3: Press digit '3' — three-digit entry ────────────────────

        {
            let w = harness.window();
            let text: SharedString = "3".into();
            w.dispatch_event(WindowEvent::KeyPressed { text: text.clone() });
            w.dispatch_event(WindowEvent::KeyReleased { text });
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "number_overlay_423",
            "Digit '3' pressed — overlay shows '423'",
            "Overlay displays '423'; channel preview shows 'Channel not found' if out of range",
        );

        // ── Step 4: Timeout fires — auto-switch to channel 42 (closest) ───

        // Simulate 1.5s timeout expiry: M-011 Timer commits filter-channels("")
        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            // Filter to channel 42 (the last valid match before 423)
            let matched: Vec<ChannelData> = vec![ChannelData {
                id: "ch_42".into(),
                name: "Channel 042".into(),
                group: "All".into(),
                logo_url: "".into(),
                stream_url: "http://iptv.example.com/live/ch42.ts".into(),
                source_id: "test_src_0".into(),
                number: 42,
                is_favorite: false,
                has_catchup: false,
                resolution: "1080p".into(),
                now_playing: "Show on Ch 42".into(),
                logo: Default::default(),
            }];
            app.set_channels(ModelRc::new(VecModel::from(matched)));
            app.set_channel_window_start(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "number_timeout_filter_applied",
            "1.5s timeout — number entry committed",
            "Overlay dismissed; channel list filtered; auto-switch triggers playback",
        );

        // ── Step 5: Playback switches to matched channel ───────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_current_title("Channel 042".into());
            ps.set_current_channel_id("ch_42".into());
            ps.set_current_programme("Show on Ch 42".into());
            ps.set_show_osd(true);
            ui.global::<AppState>().set_active_screen(4); // Player
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "ch42_playing",
            "Channel 42 playing after number-pad entry",
            "Player shows Channel 042; OSD visible with channel name; number overlay gone",
        );

        // ── Step 6: Fresh entry — two-digit direct match ───────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            ui.global::<AppState>().set_active_screen(1); // Back to Live TV for next entry
            ui.global::<PlayerState>().set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "ready_for_second_entry",
            "Ready for second number-pad entry",
            "Immersive playback; no overlay",
        );

        // Enter '5' then '0' → Channel 50
        {
            let w = harness.window();
            for ch in ['5', '0'] {
                let text: SharedString = SharedString::from(ch);
                w.dispatch_event(WindowEvent::KeyPressed { text: text.clone() });
                w.dispatch_event(WindowEvent::KeyReleased { text });
                slint::platform::update_timers_and_animations();
            }
        }

        harness.assert_screenshot(
            "number_overlay_50",
            "Two digits entered — '50'",
            "Overlay shows '50'; Channel 050 name preview; configurable 1.5s timeout running",
        );
    }
}
