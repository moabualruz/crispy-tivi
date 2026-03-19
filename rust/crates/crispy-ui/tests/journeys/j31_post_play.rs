//! J-31: Post-Play Screen
//!
//! Dream: "Replay, More Like This, Back to Browse. Auto-dismisses after 60s
//! countdown. Binge-watch: auto-plays next episode with countdown."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppWindow, PlayerState};
use slint::ComponentHandle;

pub struct J31;

impl Journey for J31 {
    const ID: &'static str = "j31";
    const NAME: &'static str = "Post-Play — Next Episode / Related";
    const DEPENDS_ON: &'static [&'static str] = &["j26"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Episode ends — post-play screen appears ────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(false);
            ps.set_is_paused(false);
            ps.set_is_live(false);
            ps.set_current_title("Breaking Bad S01E01".into());
            ps.set_show_osd(false);
            ps.set_show_post_play(true);
            ps.set_post_play_next_title("Breaking Bad S01E02 — Cat's in the Bag".into());
            // Auto-play next episode countdown starts at 10s
            ps.set_show_next_episode(true);
            ps.set_next_episode_title("Breaking Bad S01E02 — Cat's in the Bag".into());
            ps.set_next_countdown(10);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "post_play_initial",
            "Episode ends — post-play shown",
            "Post-play screen: Replay, More Like This, Back to Browse; next ep countdown",
        );

        // ── Countdown ticks — 7 seconds remaining ────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_next_countdown(7);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "post_play_countdown_7",
            "Countdown: 7s",
            "Next episode countdown shows 7s, progress arc filling",
        );

        // ── User cancels auto-play ────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_next_episode(false);
            ps.set_next_countdown(0);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "post_play_countdown_cancelled",
            "Auto-play cancelled",
            "Countdown dismissed, post-play buttons still present",
        );

        // ── Replay action ─────────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            // Replay: post-play hides, playback restarts
            ps.set_show_post_play(false);
            ps.set_is_playing(true);
            ps.set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "post_play_replay",
            "Replay selected",
            "Post-play dismissed, episode restarts from beginning",
        );

        // ── Back to post-play — Back to Browse action ─────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(false);
            ps.set_show_post_play(true);
            ps.set_post_play_next_title("Breaking Bad S01E02 — Cat's in the Bag".into());
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "post_play_back_to_browse",
            "Back to Browse selected",
            "Focus on Back to Browse button, glass highlighted",
        );

        // ── Back to Browse dismisses post-play ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_post_play(false);
            ps.set_is_playing(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "post_play_dismissed_to_browse",
            "Back to Browse executed",
            "Post-play gone, returns to series detail / browsing screen",
        );

        // ── Auto-dismiss after 60s (no interaction) ───────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            // Simulate: show post-play then auto-dismiss
            ps.set_show_post_play(true);
            ps.set_show_next_episode(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "post_play_auto_dismiss_pending",
            "Post-play shown — 60s timer running",
            "Post-play visible, 60s auto-dismiss timer active in background",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            // 60s elapsed — Rust auto-dismisses
            ps.set_show_post_play(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "post_play_auto_dismissed",
            "Auto-dismissed after 60s",
            "Post-play faded out after 60s, returns to browse with no user input",
        );
    }
}
