//! J-23: Universal Search
//!
//! Dream: "Live-as-you-type results in <200ms, grouped by type (channels,
//! movies, series), artwork-heavy cards. Instant gratification."

use crate::harness::input::InputEmulation;
use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};
use crate::{AppState, AppWindow, ChannelData, VodData};
use slint::ComponentHandle;

pub struct J23;

impl Journey for J23 {
    const ID: &'static str = "j23";
    const NAME: &'static str = "Search — Live Results";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(harness: &ScreenshotHarness, _db: &TestDb) {
        // ── Navigate to Search screen (screen index 5) ────────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_active_screen(5);
            app.set_search_text("".into());
            app.set_is_searching(false);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "search_empty",
            "Navigate to Search",
            "Empty search screen with genre suggestion chips visible",
        );

        // ── Type first character — loading indicator appears ───────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_search_text("b".into());
            app.set_is_searching(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "search_typing_loading",
            "User types 'b'",
            "Loading indicator shown, live-as-you-type search in flight",
        );

        // ── Results arrive — grouped by channels and VOD ──────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_is_searching(false);

            if !harness.has_real_data() {
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
                    now_playing: "News at Six".into(),
                    logo: slint::Image::default(),
                });
                channels.push(ChannelData {
                    id: "ch-bbc2".into(),
                    name: "BBC Two".into(),
                    group: "Entertainment".into(),
                    logo_url: "".into(),
                    stream_url: "http://example.com/bbc2.ts".into(),
                    source_id: "src1".into(),
                    number: 2,
                    is_favorite: false,
                    has_catchup: false,
                    resolution: "720p".into(),
                    now_playing: "Panorama".into(),
                    logo: slint::Image::default(),
                });
                app.set_search_channels(slint::ModelRc::new(channels));

                let vod = slint::VecModel::<VodData>::default();
                vod.push(VodData {
                    id: "v-breaking-bad".into(),
                    name: "Breaking Bad".into(),
                    stream_url: "http://example.com/bb.mp4".into(),
                    item_type: "series".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "A chemistry teacher turned drug kingpin.".into(),
                    genre: "Drama".into(),
                    year: "2008".into(),
                    rating: "9.5".into(),
                    duration_minutes: 47,
                    is_favorite: false,
                    source_id: "src1".into(),
                    series_id: "".into(),
                    season: 0,
                    episode: 0,
                    poster: slint::Image::default(),
                });
                vod.push(VodData {
                    id: "v-blade".into(),
                    name: "Blade Runner 2049".into(),
                    stream_url: "http://example.com/br2049.mp4".into(),
                    item_type: "movie".into(),
                    poster_url: "".into(),
                    backdrop_url: "".into(),
                    description: "A blade runner uncovers a buried secret.".into(),
                    genre: "Sci-Fi".into(),
                    year: "2017".into(),
                    rating: "8.0".into(),
                    duration_minutes: 164,
                    is_favorite: false,
                    source_id: "src1".into(),
                    series_id: "".into(),
                    season: 0,
                    episode: 0,
                    poster: slint::Image::default(),
                });
                app.set_search_vod(slint::ModelRc::new(vod));
            }

            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "search_results_grouped",
            "Results appear",
            "Channels section and VOD section shown, artwork-heavy cards",
        );

        // ── Narrow query to 'bbc' — VOD section disappears ────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_search_text("bbc".into());
            app.set_is_searching(true);
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "search_typing_bbc",
            "User types 'bbc'",
            "Searching indicator shown for narrowed query",
        );

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_is_searching(false);
            app.set_search_vod(slint::ModelRc::new(slint::VecModel::<VodData>::default()));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "search_results_channels_only",
            "Narrowed to 'bbc'",
            "Only channel results shown, VOD section absent",
        );

        // ── Clear query — return to empty suggestion state ────────────────

        if let Some(ui) = harness.ui::<AppWindow>() {
            let app = ui.global::<AppState>();
            app.set_search_text("".into());
            app.set_is_searching(false);
            app.set_search_channels(slint::ModelRc::new(
                slint::VecModel::<ChannelData>::default(),
            ));
            slint::platform::update_timers_and_animations();
        }

        harness.assert_screenshot(
            "search_cleared",
            "Query cleared",
            "Empty state with genre suggestion chips restored",
        );
    }
}
