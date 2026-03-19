//! J-27: Live TV OSD
//!
//! Dream: "Channel info + LIVE badge at top. EPG now/next strip. Timeshift
//! seek bar when rewinding. 'Jump to Live' pill restores live edge."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppWindow, PlayerState};
use slint::ComponentHandle;

pub struct J27;

impl Journey for J27 {
    const ID: &'static str = "j27";
    const NAME: &'static str = "Player OSD — Live TV Controls";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Live channel playing — OSD hidden ────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_is_playing(true);
            ps.set_is_paused(false);
            ps.set_is_live(true);
            ps.set_current_title("BBC One".into());
            ps.set_current_group("Entertainment".into());
            ps.set_current_programme("The One Show".into());
            ps.set_channel_logo_url("".into());
            ps.set_duration(0.0); // 0 = live (no fixed duration)
            ps.set_position(0.0);
            ps.set_buffered(0.0);
            ps.set_volume(1.0);
            ps.set_is_muted(false);
            ps.set_current_resolution("1080p".into());
            ps.set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_playing_osd_hidden",
            "Live TV playing",
            "Clean live view, no chrome, full-screen channel",
        );

        // ── OSD revealed — LIVE badge + channel info strip ────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_osd_visible",
            "OSD revealed",
            "LIVE badge, channel name, current programme shown at top; EPG now/next strip",
        );

        // ── Enter timeshift — seek back in time ──────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            // Timeshift: duration = buffer window (e.g. 3600s = 1hr), position = 2700s back
            ps.set_duration(3600.0);
            ps.set_position(2700.0); // 15 minutes behind live edge
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_timeshift_active",
            "Seek back in timeshift",
            "Timeshift seek bar visible, LIVE badge dimmed, position behind live edge",
        );

        // ── Seek further back ─────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_position(1200.0); // 40 minutes behind live
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_timeshift_deep",
            "Deep timeshift scrub",
            "Seek bar deep in buffer, time offset label shows -40m",
        );

        // ── Jump to Live pill active ───────────────────────────────────────

        harness.assert_screenshot(
            "live_jump_to_live_pill",
            "Jump to Live pill visible",
            "Go Live pill shown prominently when behind live edge",
        );

        // ── Jump to Live tapped — live edge restored ──────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_duration(0.0); // back to pure live
            ps.set_position(0.0);
            ps.set_show_osd(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_edge_restored",
            "Jump to Live tapped",
            "Live edge restored, LIVE badge bright, timeshift bar gone",
        );

        // ── OSD auto-hides ────────────────────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let ps = ui.global::<PlayerState>();
            ps.set_show_osd(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "live_osd_autohidden",
            "OSD auto-hides",
            "Clean live view restored after 3s inactivity",
        );
    }
}
