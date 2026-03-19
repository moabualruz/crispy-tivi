/// Headless Slint UI tests — uses i-slint-backend-testing for property/callback coverage.
///
/// All tests call `init_headless()` first, which initialises the testing backend
/// (no event-loop, no real GPU). The generated types (AppWindow, AppState, …) come
/// from the `slint::include_modules!()` at the crate root — these tests are an inline
/// `#[cfg(test)]` module so they share the same compilation unit and have direct access
/// to all generated types.
///
/// Screen index constants (mirrors app-state.slint comment):
///   0 = Home, 1 = LiveTV, 2 = EPG, 3 = Movies, 4 = Series,
///   5 = Search, 6 = Library, 7 = Settings, 8 = VodDetail, 9 = SeriesDetail
#[cfg(test)]
mod ui_tests {
    use slint::{ComponentHandle, Model};

    // ── Helpers ──────────────────────────────────────────────────────────

    /// Initialise the headless Slint testing backend.
    ///
    /// Safe to call multiple times; subsequent calls are no-ops.
    fn init_headless() {
        i_slint_backend_testing::init_no_event_loop();
    }

    /// Create a fresh AppWindow for each test (all state is default).
    fn make_window() -> crate::AppWindow {
        crate::AppWindow::new().expect("AppWindow::new() failed in headless mode")
    }

    // ════════════════════════════════════════════════════════════════════
    // Navigation
    // ════════════════════════════════════════════════════════════════════

    #[test]
    fn test_active_screen_is_home_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert_eq!(
            ui.global::<crate::AppState>().get_active_screen(),
            0,
            "active-screen should default to 0 (Home)"
        );
    }

    #[test]
    fn test_active_screen_changes_when_set_to_live_tv() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::AppState>().set_active_screen(1);
        assert_eq!(ui.global::<crate::AppState>().get_active_screen(), 1);
    }

    #[test]
    fn test_active_screen_changes_when_set_to_settings() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::AppState>().set_active_screen(7);
        assert_eq!(ui.global::<crate::AppState>().get_active_screen(), 7);
    }

    #[test]
    fn test_active_screen_returns_to_home_when_reset_to_zero() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::AppState>().set_active_screen(4);
        ui.global::<crate::AppState>().set_active_screen(0);
        assert_eq!(ui.global::<crate::AppState>().get_active_screen(), 0);
    }

    // ════════════════════════════════════════════════════════════════════
    // AppState — default property values
    // ════════════════════════════════════════════════════════════════════

    #[test]
    fn test_sources_list_is_empty_when_window_first_created() {
        init_headless();
        let ui = make_window();
        let sources = ui.global::<crate::AppState>().get_sources();
        assert_eq!(sources.row_count(), 0, "sources should be empty by default");
    }

    #[test]
    fn test_channels_list_is_empty_when_window_first_created() {
        init_headless();
        let ui = make_window();
        let channels = ui.global::<crate::AppState>().get_channels();
        assert_eq!(
            channels.row_count(),
            0,
            "channels should be empty by default"
        );
    }

    #[test]
    fn test_movies_list_is_empty_when_window_first_created() {
        init_headless();
        let ui = make_window();
        let movies = ui.global::<crate::AppState>().get_movies();
        assert_eq!(movies.row_count(), 0, "movies should be empty by default");
    }

    #[test]
    fn test_is_syncing_is_false_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::AppState>().get_is_syncing(),
            "is-syncing should be false by default"
        );
    }

    #[test]
    fn test_sync_progress_is_zero_when_window_first_created() {
        init_headless();
        let ui = make_window();
        let progress = ui.global::<crate::AppState>().get_sync_progress();
        assert!(
            (progress - 0.0_f32).abs() < f32::EPSILON,
            "sync-progress should be 0.0 by default, got {progress}"
        );
    }

    #[test]
    fn test_nav_visible_is_true_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            ui.global::<crate::AppState>().get_nav_visible(),
            "nav-visible should be true by default"
        );
    }

    #[test]
    fn test_active_language_is_en_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert_eq!(
            ui.global::<crate::AppState>()
                .get_active_language()
                .as_str(),
            "en",
            "active-language should default to \"en\""
        );
    }

    #[test]
    fn test_active_profile_name_is_default_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert_eq!(
            ui.global::<crate::AppState>()
                .get_active_profile_name()
                .as_str(),
            "Default",
            "active-profile-name should default to \"Default\""
        );
    }

    // ════════════════════════════════════════════════════════════════════
    // Onboarding
    // ════════════════════════════════════════════════════════════════════

    #[test]
    fn test_onboarding_is_active_false_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::OnboardingState>().get_is_active(),
            "OnboardingState.is-active should be false by default"
        );
    }

    #[test]
    fn test_onboarding_step_is_zero_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert_eq!(
            ui.global::<crate::OnboardingState>().get_step(),
            0,
            "OnboardingState.step should default to 0 (Welcome)"
        );
    }

    #[test]
    fn test_onboarding_step_advances_when_set_to_add_source() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::OnboardingState>().set_step(1);
        assert_eq!(ui.global::<crate::OnboardingState>().get_step(), 1);
    }

    #[test]
    fn test_onboarding_activates_when_is_active_set_to_true() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::OnboardingState>().set_is_active(true);
        assert!(ui.global::<crate::OnboardingState>().get_is_active());
    }

    // ════════════════════════════════════════════════════════════════════
    // Source dialog
    // ════════════════════════════════════════════════════════════════════

    #[test]
    fn test_source_dialog_hidden_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::AppState>().get_show_source_dialog(),
            "show-source-dialog should be false by default"
        );
    }

    #[test]
    fn test_source_dialog_visible_when_show_source_dialog_set_to_true() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::AppState>().set_show_source_dialog(true);
        assert!(ui.global::<crate::AppState>().get_show_source_dialog());
    }

    #[test]
    fn test_source_dialog_hidden_again_when_show_source_dialog_set_to_false() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::AppState>().set_show_source_dialog(true);
        ui.global::<crate::AppState>().set_show_source_dialog(false);
        assert!(!ui.global::<crate::AppState>().get_show_source_dialog());
    }

    #[test]
    fn test_editing_source_type_defaults_to_m3u_when_window_first_created() {
        init_headless();
        let ui = make_window();
        let src = ui.global::<crate::AppState>().get_editing_source();
        assert_eq!(
            src.source_type.as_str(),
            "m3u",
            "editing-source.source-type should default to \"m3u\""
        );
    }

    // ════════════════════════════════════════════════════════════════════
    // Profile state
    // ════════════════════════════════════════════════════════════════════

    #[test]
    fn test_profiles_list_is_empty_when_window_first_created() {
        init_headless();
        let ui = make_window();
        let profiles = ui.global::<crate::AppState>().get_profiles();
        assert_eq!(
            profiles.row_count(),
            0,
            "profiles should be empty by default"
        );
    }

    #[test]
    fn test_profile_menu_hidden_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::AppState>().get_show_profile_menu(),
            "show-profile-menu should be false by default"
        );
    }

    #[test]
    fn test_profile_picker_hidden_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::AppState>().get_show_profile_picker(),
            "show-profile-picker should be false by default"
        );
    }

    // ════════════════════════════════════════════════════════════════════
    // Player state
    // ════════════════════════════════════════════════════════════════════

    #[test]
    fn test_player_is_not_playing_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::PlayerState>().get_is_playing(),
            "PlayerState.is-playing should be false by default"
        );
    }

    #[test]
    fn test_player_is_not_fullscreen_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::PlayerState>().get_is_fullscreen(),
            "PlayerState.is-fullscreen should be false by default"
        );
    }

    #[test]
    fn test_player_is_fullscreen_when_is_fullscreen_set_to_true() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::PlayerState>().set_is_fullscreen(true);
        assert!(ui.global::<crate::PlayerState>().get_is_fullscreen());
    }

    // ════════════════════════════════════════════════════════════════════
    // Screen-layer visibility logic (derived properties)
    // ════════════════════════════════════════════════════════════════════

    #[test]
    fn test_is_syncing_becomes_true_when_set() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::AppState>().set_is_syncing(true);
        assert!(ui.global::<crate::AppState>().get_is_syncing());
    }

    #[test]
    fn test_sync_progress_updates_when_set_to_half() {
        init_headless();
        let ui = make_window();
        ui.global::<crate::AppState>().set_sync_progress(0.5);
        let p = ui.global::<crate::AppState>().get_sync_progress();
        assert!(
            (p - 0.5_f32).abs() < 1e-5,
            "sync-progress should be 0.5, got {p}"
        );
    }

    #[test]
    fn test_channel_overlay_hidden_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::AppState>().get_show_channel_overlay(),
            "show-channel-overlay should be false by default"
        );
    }

    #[test]
    fn test_vod_detail_hidden_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::AppState>().get_show_vod_detail(),
            "show-vod-detail should be false by default"
        );
    }

    #[test]
    fn test_series_detail_hidden_when_window_first_created() {
        init_headless();
        let ui = make_window();
        assert!(
            !ui.global::<crate::AppState>().get_show_series_detail(),
            "show-series-detail should be false by default"
        );
    }
}
