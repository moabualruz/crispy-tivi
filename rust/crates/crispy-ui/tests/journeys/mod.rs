//! Journey registry — all 46 journeys registered in one place.
//!
//! `register_all_journeys` is called by the screenshot test entry point.
//! Journey modules contain placeholder `run()` bodies; Phase 3 fills them in.

use crate::harness::journey_runner::JourneyRunner;

pub mod j01_onboarding;
pub mod j02_add_source;
pub mod j03_profile_picker;
pub mod j04_guided_tour;
pub mod j05_channel_browse;
pub mod j06_zapping;
pub mod j07_number_pad;
pub mod j08_favorites;
pub mod j10_mini_guide;
pub mod j11_epg_grid;
pub mod j12_epg_detail;
pub mod j13_epg_multiday;
pub mod j14_epg_search;
pub mod j15_movies_browse;
pub mod j16_movie_detail;
pub mod j17_movie_resume;
pub mod j18_watchlist;
pub mod j19_series_browse;
pub mod j20_binge_watch;
pub mod j21_up_next;
pub mod j22_episode_progress;
pub mod j23_search;
pub mod j24_browse_filters;
pub mod j25_recent_trending;
pub mod j26_osd_vod;
pub mod j27_osd_live;
pub mod j28_audio_subs;
pub mod j29_pip;
pub mod j30_skip_intro;
pub mod j31_post_play;
pub mod j32_source_health;
pub mod j33_app_settings;
pub mod j34_backup_restore;
pub mod j35_diagnostics;
pub mod j36_create_profile;
pub mod j37_kids_profile;
pub mod j38_parental_controls;
pub mod j39_library;
pub mod j40_watch_history;
pub mod j41_server_mode;
pub mod j42_cross_device_resume;
pub mod j43_dpad_nav;
pub mod j44_network_failure;
pub mod j45_stream_failover;
pub mod j46_privacy_consent;
pub mod j47_analytics;

/// Register all journeys with the runner.
///
/// The runner performs a topological sort internally — registration order
/// does not matter for execution order.
pub fn register_all_journeys(runner: &mut JourneyRunner) {
    runner.register::<j01_onboarding::J01>();
    runner.register::<j02_add_source::J02>();
    runner.register::<j03_profile_picker::J03>();
    runner.register::<j04_guided_tour::J04>();
    runner.register::<j05_channel_browse::J05>();
    runner.register::<j06_zapping::J06>();
    runner.register::<j07_number_pad::J07>();
    runner.register::<j08_favorites::J08>();
    runner.register::<j10_mini_guide::J10>();
    runner.register::<j11_epg_grid::J11>();
    runner.register::<j12_epg_detail::J12>();
    runner.register::<j13_epg_multiday::J13>();
    runner.register::<j14_epg_search::J14>();
    runner.register::<j15_movies_browse::J15>();
    runner.register::<j16_movie_detail::J16>();
    runner.register::<j17_movie_resume::J17>();
    runner.register::<j18_watchlist::J18>();
    runner.register::<j19_series_browse::J19>();
    runner.register::<j20_binge_watch::J20>();
    runner.register::<j21_up_next::J21>();
    runner.register::<j22_episode_progress::J22>();
    runner.register::<j23_search::J23>();
    runner.register::<j24_browse_filters::J24>();
    runner.register::<j25_recent_trending::J25>();
    runner.register::<j26_osd_vod::J26>();
    runner.register::<j27_osd_live::J27>();
    runner.register::<j28_audio_subs::J28>();
    runner.register::<j29_pip::J29>();
    runner.register::<j30_skip_intro::J30>();
    runner.register::<j31_post_play::J31>();
    runner.register::<j32_source_health::J32>();
    runner.register::<j33_app_settings::J33>();
    runner.register::<j34_backup_restore::J34>();
    runner.register::<j35_diagnostics::J35>();
    runner.register::<j36_create_profile::J36>();
    runner.register::<j37_kids_profile::J37>();
    runner.register::<j38_parental_controls::J38>();
    runner.register::<j39_library::J39>();
    runner.register::<j40_watch_history::J40>();
    runner.register::<j41_server_mode::J41>();
    runner.register::<j42_cross_device_resume::J42>();
    runner.register::<j43_dpad_nav::J43>();
    runner.register::<j44_network_failure::J44>();
    runner.register::<j45_stream_failover::J45>();
    runner.register::<j46_privacy_consent::J46>();
    runner.register::<j47_analytics::J47>();
}
