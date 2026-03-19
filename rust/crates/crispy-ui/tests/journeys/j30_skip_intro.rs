//! J-30: Skip Intro / Credits / Recap
//!
//! Dream: "Contextual skip button appears at the right moment. Not
//! default-focused (no accidental skip). Fade animation. Chapter markers
//! on seek bar indicate intro / recap / credits boundaries."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppWindow, PlayerState};
use slint::ComponentHandle;

pub struct J30;

impl Journey for J30 {
    const ID: &'static str = "j30";
    const NAME: &'static str = "Skip Intro / Skip Recap";
    const DEPENDS_ON: &'static [&'static str] = &["j26"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Episode starts — no skip button yet (pre-intro) ───────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_paused(false);
            ps.set_is_live(false);
            ps.set_current_title("Breaking Bad S01E01".into());
            ps.set_current_group("Series".into());
            ps.set_duration(2820.0); // 47 minutes
            ps.set_position(0.0);
            ps.set_show_osd(false);
            ps.set_show_skip_intro(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "episode_start_no_skip",
            "Episode begins",
            "No skip button — pre-intro section, clean viewing",
        );

        // ── Intro chapter begins — Skip Intro button fades in ─────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_position(12.0); // intro starts ~12s in
            ps.set_show_skip_intro(true); // button fades in
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "skip_intro_visible",
            "Intro chapter detected",
            "Skip Intro button faded in, not default-focused, bottom-right position",
        );

        // ── OSD revealed alongside skip button ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_osd(true);
            ps.set_show_skip_intro(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "skip_intro_with_osd",
            "OSD open during intro",
            "Skip button and OSD coexist, chapter markers visible on seek bar",
        );

        // ── User focuses Skip Intro (explicit D-pad navigation) ───────────

        harness.assert_screenshot(
            "skip_intro_focused",
            "D-pad focus on Skip Intro",
            "Skip button gains white focus ring, still not auto-focused",
        );

        // ── Skip tapped — position jumps past intro ────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_position(96.0); // post-intro at ~1m36s
            ps.set_show_skip_intro(false); // button fades out
            ps.set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "intro_skipped",
            "Skip Intro tapped",
            "Playback jumped past intro, skip button faded out, clean view",
        );

        // ── Credits chapter — Skip Credits button appears ─────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_position(2700.0); // near end, credits chapter
            ps.set_show_skip_intro(true); // reused for skip-credits
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "skip_credits_visible",
            "Credits chapter detected",
            "Skip Credits button shown, same styling as Skip Intro",
        );

        // ── Credits skipped — episode ends cleanly ────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_position(2820.0); // end of episode
            ps.set_show_skip_intro(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "credits_skipped",
            "Credits skipped",
            "Skip button gone, episode at end position",
        );
    }
}
