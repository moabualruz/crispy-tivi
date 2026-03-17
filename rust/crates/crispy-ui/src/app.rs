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

    // Load initial data
    super::data::reload_all(ui, &service);

    Ok(service)
}
