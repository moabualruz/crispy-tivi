//! Application setup — initializes CrispyService and wires Slint callbacks.

use crispy_server::CrispyService;
use crispy_server::models::Source;
use slint::ComponentHandle;

/// Resolve the database path from env or default.
pub(crate) fn resolve_db_path() -> String {
    if let Ok(p) = std::env::var("CRISPY_DB_PATH") {
        return p;
    }
    let home = std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .unwrap_or_else(|_| ".".to_string());
    let dir = format!("{home}/.crispytivi/data");
    let _ = std::fs::create_dir_all(&dir);
    format!("{dir}/crispy.db")
}

/// Initialize the app: create CrispyService, load settings, wire callbacks.
pub(crate) fn init(ui: &super::AppWindow) -> anyhow::Result<CrispyService> {
    let db_path = resolve_db_path();
    tracing::info!(db_path = %db_path, "Opening database");

    let service = CrispyService::open(&db_path)?;

    // Load persisted theme preference (0=system, 1=dark, 2=light)
    let theme_mode: i32 = service
        .get_setting("theme")?
        .and_then(|v| v.parse().ok())
        .unwrap_or(1); // Default to dark

    let theme = ui.global::<super::Theme>();
    theme.set_theme_mode(theme_mode);

    // Load persisted language preference
    let lang = service
        .get_setting("language")?
        .unwrap_or_else(|| "en".to_string());

    let app_state = ui.global::<super::AppState>();
    app_state.set_active_language(lang.clone().into());
    app_state.set_is_rtl(super::i18n::is_rtl(&lang));
    super::i18n::set_locale(&lang);

    // Wire navigation callback
    app_state.on_navigate(|screen_index| {
        tracing::debug!(screen = screen_index, "Navigate to screen");
    });

    // Wire theme callback
    let svc = service.clone();
    app_state.on_set_theme(move |mode| {
        let label = match mode {
            0 => "system",
            1 => "dark",
            _ => "light",
        };
        tracing::info!(theme = label, "Theme changed");
        if let Err(e) = svc.set_setting("theme", &mode.to_string()) {
            tracing::error!(error = %e, "Failed to persist theme");
        }
    });

    // Wire language callback
    let svc = service.clone();
    app_state.on_set_language(move |lang| {
        let lang_str = lang.to_string();
        super::i18n::set_locale(&lang_str);
        tracing::info!(language = %lang_str, "Language changed");
        if let Err(e) = svc.set_setting("language", &lang_str) {
            tracing::error!(error = %e, "Failed to persist language");
        }
    });

    // Wire source save callback
    let svc = service.clone();
    let ui_weak = ui.as_weak();
    app_state.on_save_source(move |name, stype, url, user, pass| {
        let source = Source {
            id: format!("src_{}", chrono::Utc::now().timestamp_millis()),
            name: name.to_string(),
            source_type: stype.to_string(),
            url: url.to_string(),
            username: if user.is_empty() {
                None
            } else {
                Some(user.to_string())
            },
            password: if pass.is_empty() {
                None
            } else {
                Some(pass.to_string())
            },
            access_token: None,
            device_id: None,
            user_id: None,
            mac_address: None,
            epg_url: None,
            user_agent: None,
            refresh_interval_minutes: 60,
            accept_self_signed: false,
            enabled: true,
            sort_order: 0,
            last_sync_time: None,
            last_sync_status: None,
            last_sync_error: None,
            created_at: Some(chrono::Utc::now().naive_utc()),
            updated_at: Some(chrono::Utc::now().naive_utc()),
        };
        tracing::info!(name = %source.name, source_type = %source.source_type, "Saving source");
        if let Err(e) = svc.save_source(&source) {
            tracing::error!(error = %e, "Failed to save source");
            return;
        }
        if let Some(ui) = ui_weak.upgrade() {
            super::data::load_sources(&ui, &svc);
        }
    });

    // Wire source delete callback
    let svc = service.clone();
    let ui_weak = ui.as_weak();
    app_state.on_delete_source(move |source_id| {
        tracing::info!(source_id = %source_id, "Deleting source");
        if let Err(e) = svc.delete_source(&source_id) {
            tracing::error!(error = %e, "Failed to delete source");
            return;
        }
        if let Some(ui) = ui_weak.upgrade() {
            super::data::reload_all(&ui, &svc);
        }
    });

    // Wire search callback
    let svc = service.clone();
    let ui_weak = ui.as_weak();
    app_state.on_perform_search(move |query| {
        let query_str = query.to_string();
        if query_str.is_empty() {
            return;
        }
        if let Some(ui) = ui_weak.upgrade() {
            super::data::perform_search(&ui, &svc, &query_str);
        }
    });

    // Wire channel favorite toggle (uses default profile for now)
    let svc = service.clone();
    let ui_weak = ui.as_weak();
    app_state.on_toggle_favorite(move |channel_id| {
        let cid = channel_id.to_string();
        let profile = "default";
        tracing::debug!(channel_id = %cid, "Toggle favorite");
        let favorites = svc.get_favorites(profile).unwrap_or_default();
        let result = if favorites.contains(&cid) {
            svc.remove_favorite(profile, &cid)
        } else {
            svc.add_favorite(profile, &cid)
        };
        if let Err(e) = result {
            tracing::error!(error = %e, "Failed to toggle favorite");
            return;
        }
        if let Some(ui) = ui_weak.upgrade() {
            super::data::load_channels(&ui, &svc);
        }
    });

    // Wire play-channel callback
    let svc = service.clone();
    let ui_weak = ui.as_weak();
    app_state.on_play_channel(move |channel_id| {
        let cid = channel_id.to_string();
        tracing::info!(channel_id = %cid, "Play channel");

        // Look up channel to get stream URL and metadata
        let channels = svc
            .get_channels_by_ids(std::slice::from_ref(&cid))
            .unwrap_or_default();
        if let Some(ch) = channels.first()
            && let Some(ui) = ui_weak.upgrade()
        {
            let player = ui.global::<super::PlayerState>();
            player.set_current_title(ch.name.clone().into());
            player.set_current_group(ch.channel_group.clone().unwrap_or_default().into());
            player.set_current_channel_id(ch.id.clone().into());
            player.set_is_live(true);
            player.set_is_playing(true);
            player.set_show_osd(true);
            // Actual playback via PlayerBackend deferred to Phase 3.1
            tracing::info!(
                url = %ch.stream_url,
                name = %ch.name,
                "Stream ready (playback backend not yet connected)"
            );
        }
    });

    // Wire player control callbacks
    let ui_weak = ui.as_weak();
    let player_state = ui.global::<super::PlayerState>();

    player_state.on_play_pause({
        let ui_weak = ui_weak.clone();
        move || {
            if let Some(ui) = ui_weak.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                ps.set_is_paused(!ps.get_is_paused());
                tracing::debug!(paused = ps.get_is_paused(), "Play/pause toggled");
            }
        }
    });

    player_state.on_stop({
        let ui_weak = ui_weak.clone();
        move || {
            if let Some(ui) = ui_weak.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                ps.set_is_playing(false);
                ps.set_is_paused(false);
                ps.set_is_buffering(false);
                ps.set_current_title(Default::default());
                tracing::info!("Playback stopped");
            }
        }
    });

    player_state.on_seek(|position| {
        tracing::debug!(position, "Seek requested (backend not connected)");
    });

    player_state.on_set_volume({
        let ui_weak = ui_weak.clone();
        move |vol| {
            if let Some(ui) = ui_weak.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                ps.set_volume(vol.clamp(0.0, 1.0));
                ps.set_is_muted(false);
            }
        }
    });

    player_state.on_toggle_mute({
        let ui_weak = ui_weak.clone();
        move || {
            if let Some(ui) = ui_weak.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                ps.set_is_muted(!ps.get_is_muted());
            }
        }
    });

    player_state.on_show_controls({
        let ui_weak = ui_weak.clone();
        move || {
            if let Some(ui) = ui_weak.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                ps.set_show_osd(!ps.get_show_osd());
            }
        }
    });

    // Wire onboarding callbacks
    let onboarding = ui.global::<super::OnboardingState>();

    let svc = service.clone();
    let ui_weak = ui.as_weak();
    onboarding.on_complete(move || {
        tracing::info!("Onboarding complete");
        if let Err(e) = svc.set_setting("onboarding_done", "true") {
            tracing::error!(error = %e, "Failed to persist onboarding state");
        }
        if let Some(ui) = ui_weak.upgrade() {
            ui.global::<super::OnboardingState>().set_is_active(false);
            super::data::reload_all(&ui, &svc);
        }
    });

    onboarding.on_skip(move || {
        tracing::info!("Onboarding skipped");
    });

    // Load initial data
    super::data::reload_all(ui, &service);

    // Show onboarding if first run
    let is_first_run = service
        .get_setting("onboarding_done")
        .ok()
        .flatten()
        .is_none();
    if is_first_run {
        tracing::info!("First run detected — showing onboarding");
        ui.global::<super::OnboardingState>().set_is_active(true);
    }

    Ok(service)
}
