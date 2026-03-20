//! J-25: Recent Searches and Trending
//!
//! Dream: "Recent searches as chips (per-profile, persisted). Popular channels
//! surfaced. Clear history action. Genre chips as fallback when history empty."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ChannelData};
use slint::ComponentHandle;

pub struct J25;

impl Journey for J25 {
    const ID: &'static str = "j25";
    const NAME: &'static str = "Recent Searches and Trending";
    const DEPENDS_ON: &'static [&'static str] = &["j23"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Search screen with no history — genre chips as fallback ───────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(5);
            app.set_search_text("".into());
            app.set_is_searching(false);
            if !harness.has_real_data() {
                // Empty recent searches → genre chips shown as fallback
                app.set_recent_searches(slint::ModelRc::new(
                    slint::VecModel::<slint::SharedString>::default(),
                ));
            }
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "search_no_history",
            "First visit — no history",
            "Genre suggestion chips shown as fallback (Action, Drama, Sci-Fi, etc.)",
        );

        // ── After searches: recent chips appear (per-profile) ─────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            let history = slint::VecModel::<slint::SharedString>::default();
            history.push("breaking bad".into());
            history.push("bbc".into());
            history.push("interstellar".into());
            history.push("narcos".into());
            app.set_recent_searches(slint::ModelRc::new(history));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "search_with_history",
            "History populated",
            "Recent search chips shown: breaking bad, bbc, interstellar, narcos",
        );

        // ── Tap a recent chip — fills query and fires search immediately ──

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_search_text("bbc".into());
            app.set_is_searching(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "recent_chip_tapped",
            "Tap 'bbc' chip",
            "Query field fills with 'bbc', search fires immediately",
        );

        // ── Results arrive from chip tap ──────────────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_is_searching(false);
            let channels = slint::VecModel::<ChannelData>::default();
            channels.push(ChannelData {
                id: "ch-bbc1".into(),
                name: "BBC One".into(),
                group: "Entertainment".into(),
                logo_url: "".into(),
                stream_url: "http://example.com/bbc1.ts".into(),
                source_id: "src1".into(),
                number: 1,
                is_favorite: false,
                has_catchup: true,
                resolution: "1080p".into(),
                now_playing: "EastEnders".into(),
                logo: slint::Image::default(),
            });
            app.set_search_channels(slint::ModelRc::new(channels));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "recent_chip_results",
            "Results from chip tap",
            "BBC channels shown after chip tap search",
        );

        // ── Clear history — revert to genre chips ─────────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_search_text("".into());
            app.set_is_searching(false);
            app.set_recent_searches(slint::ModelRc::new(
                slint::VecModel::<slint::SharedString>::default(),
            ));
            app.set_search_channels(slint::ModelRc::new(
                slint::VecModel::<ChannelData>::default(),
            ));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "history_cleared",
            "Clear history tapped",
            "Recent chips removed, genre fallback chips restored",
        );
    }
}
