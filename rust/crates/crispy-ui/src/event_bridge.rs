//! EventBridge — the ONLY file that imports both Slint-generated types and event channels.
//!
//! Responsibilities:
//! 1. `wire()` — connect Slint callbacks to the three event queues
//! 2. `spawn_player_handler()` — owns MpvBackend, processes PlayerEvents
//! 3. `spawn_data_listener()` — maps DataEvents to Slint properties
//! 4. `apply_data_event()` — pure DataEvent → Slint property mapping

use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
};

use crispy_player::PlayerBackend;
use slint::{ComponentHandle, Model, ModelRc, SharedString, VecModel};
use tokio::sync::mpsc;

use crate::events::{
    ChannelInfo, DataEvent, HighPriorityEvent, LoadingKind, NormalEvent, PlayerEvent, Screen,
    SourceInfo, SourceInput, VodInfo,
};

// ── wire ─────────────────────────────────────────────────────────────────────

/// Wire all Slint callbacks to the three event queues.
///
/// Called on the UI thread during `app::init`. Uses `try_send` throughout —
/// if a queue is full the event is logged and dropped (non-fatal).
pub(crate) fn wire(
    ui: &super::AppWindow,
    player_tx: mpsc::Sender<PlayerEvent>,
    high_tx: mpsc::Sender<HighPriorityEvent>,
    normal_tx: mpsc::Sender<NormalEvent>,
) {
    // ── PlayerState callbacks ─────────────────────────────────────────────

    let ps = ui.global::<super::PlayerState>();

    ps.on_play_pause({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::TogglePause) {
                tracing::warn!(error = %e, "player_tx full: TogglePause dropped");
            }
        }
    });

    ps.on_stop({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::Stop) {
                tracing::warn!(error = %e, "player_tx full: Stop dropped");
            }
        }
    });

    ps.on_seek({
        let tx = player_tx.clone();
        move |position| {
            if let Err(e) = tx.try_send(PlayerEvent::Seek {
                position_secs: position as f64,
            }) {
                tracing::warn!(error = %e, "player_tx full: Seek dropped");
            }
        }
    });

    ps.on_set_volume({
        let tx = player_tx.clone();
        move |vol| {
            if let Err(e) = tx.try_send(PlayerEvent::SetVolume { volume: vol }) {
                tracing::warn!(error = %e, "player_tx full: SetVolume dropped");
            }
        }
    });

    ps.on_toggle_mute({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::ToggleMute) {
                tracing::warn!(error = %e, "player_tx full: ToggleMute dropped");
            }
        }
    });

    ps.on_show_controls({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::ShowControls { visible: true }) {
                tracing::warn!(error = %e, "player_tx full: ShowControls dropped");
            }
        }
    });

    // ── AppState callbacks ────────────────────────────────────────────────

    let app = ui.global::<super::AppState>();

    app.on_navigate({
        let tx = high_tx.clone();
        move |screen_index| {
            let screen = Screen::from_i32(screen_index).unwrap_or(Screen::Home);
            if let Err(e) = tx.try_send(HighPriorityEvent::Navigate { screen }) {
                tracing::warn!(error = %e, "high_tx full: Navigate dropped");
            }
        }
    });

    app.on_play_channel({
        let tx = high_tx.clone();
        move |channel_id| {
            if let Err(e) = tx.try_send(HighPriorityEvent::PlayChannel {
                channel_id: channel_id.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: PlayChannel dropped");
            }
        }
    });

    app.on_filter_channels({
        let tx = high_tx.clone();
        move |group, _search| {
            if let Err(e) = tx.try_send(HighPriorityEvent::FilterContent {
                query: group.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: FilterChannels dropped");
            }
        }
    });

    app.on_perform_search({
        let tx = high_tx.clone();
        move |query| {
            if let Err(e) = tx.try_send(HighPriorityEvent::Search {
                query: query.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: Search dropped");
            }
        }
    });

    app.on_toggle_favorite({
        let tx = high_tx.clone();
        move |channel_id| {
            if let Err(e) = tx.try_send(HighPriorityEvent::ToggleChannelFavorite {
                channel_id: channel_id.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: ToggleFavorite dropped");
            }
        }
    });

    app.on_set_theme({
        let tx = high_tx.clone();
        move |mode| {
            if let Err(e) = tx.try_send(HighPriorityEvent::ChangeTheme {
                theme_name: mode.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: SetTheme dropped");
            }
        }
    });

    app.on_set_language({
        let tx = high_tx.clone();
        move |lang| {
            if let Err(e) = tx.try_send(HighPriorityEvent::ChangeLanguage {
                language_tag: lang.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: SetLanguage dropped");
            }
        }
    });

    app.on_load_more_channels({
        let tx = high_tx.clone();
        move || {
            if let Err(e) = tx.try_send(HighPriorityEvent::LoadMore {
                kind: LoadingKind::Channels,
            }) {
                tracing::warn!(error = %e, "high_tx full: LoadMoreChannels dropped");
            }
        }
    });

    app.on_load_more_movies({
        let tx = high_tx.clone();
        move || {
            if let Err(e) = tx.try_send(HighPriorityEvent::LoadMore {
                kind: LoadingKind::Movies,
            }) {
                tracing::warn!(error = %e, "high_tx full: LoadMoreMovies dropped");
            }
        }
    });

    app.on_load_more_series({
        let tx = high_tx.clone();
        move || {
            if let Err(e) = tx.try_send(HighPriorityEvent::LoadMore {
                kind: LoadingKind::Series,
            }) {
                tracing::warn!(error = %e, "high_tx full: LoadMoreSeries dropped");
            }
        }
    });

    // ── AppState normal-priority callbacks ────────────────────────────────

    app.on_save_source({
        let tx = normal_tx.clone();
        move |name, stype, url, user, pass| {
            if let Err(e) = tx.try_send(NormalEvent::SaveSource {
                input: SourceInput {
                    name: name.to_string(),
                    source_type: stype.to_string(),
                    url: url.to_string(),
                    username: user.to_string(),
                    password: pass.to_string(),
                    mac_address: String::new(),
                    epg_url: String::new(),
                },
            }) {
                tracing::warn!(error = %e, "normal_tx full: SaveSource dropped");
            }
        }
    });

    app.on_delete_source({
        let tx = normal_tx.clone();
        move |source_id| {
            if let Err(e) = tx.try_send(NormalEvent::DeleteSource {
                source_id: source_id.to_string(),
            }) {
                tracing::warn!(error = %e, "normal_tx full: DeleteSource dropped");
            }
        }
    });

    app.on_sync_source({
        let tx = normal_tx.clone();
        move |source_id| {
            if let Err(e) = tx.try_send(NormalEvent::SyncSource {
                source_id: source_id.to_string(),
            }) {
                tracing::warn!(error = %e, "normal_tx full: SyncSource dropped");
            }
        }
    });

    app.on_sync_all({
        let tx = normal_tx.clone();
        move || {
            if let Err(e) = tx.try_send(NormalEvent::SyncAll) {
                tracing::warn!(error = %e, "normal_tx full: SyncAll dropped");
            }
        }
    });

    app.on_filter_vod({
        let tx = high_tx.clone();
        move |category, item_type| {
            if let Err(e) = tx.try_send(HighPriorityEvent::FilterVod {
                category: category.to_string(),
                item_type: item_type.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: FilterVod dropped");
            }
        }
    });

    app.on_play_vod({
        let tx = high_tx.clone();
        move |vod_id| {
            if let Err(e) = tx.try_send(HighPriorityEvent::PlayVod {
                vod_id: vod_id.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: PlayVod dropped");
            }
        }
    });

    // ── OnboardingState ───────────────────────────────────────────────────

    let onboarding = ui.global::<super::OnboardingState>();
    onboarding.on_complete({
        let tx = normal_tx.clone();
        move || {
            if let Err(e) = tx.try_send(NormalEvent::CompleteOnboarding) {
                tracing::warn!(error = %e, "normal_tx full: OnboardingComplete dropped");
            }
        }
    });

    // ── DiagnosticsState ──────────────────────────────────────────────────

    let diag = ui.global::<super::DiagnosticsState>();
    diag.on_toggle({
        let tx = normal_tx.clone();
        move || {
            if let Err(e) = tx.try_send(NormalEvent::RunDiagnostics) {
                tracing::warn!(error = %e, "normal_tx full: DiagnosticsToggle dropped");
            }
        }
    });

    diag.on_export_logs(|| {
        tracing::info!("Log export requested (not yet implemented)");
    });
}

// ── spawn_player_handler ──────────────────────────────────────────────────────

/// Spawn a tokio task that owns the MpvBackend and processes PlayerEvents.
///
/// The backend is held in a shared `Arc<Mutex<Option<MpvBackend>>>` so that
/// `spawn_data_listener` can also call `play()` on `PlaybackReady`.
pub(crate) fn spawn_player_handler(
    ui_weak: slint::Weak<super::AppWindow>,
    mut player_rx: mpsc::Receiver<PlayerEvent>,
    backend: Arc<Mutex<Option<crispy_player::mpv_backend::MpvBackend>>>,
) {
    tokio::spawn(async move {
        while let Some(event) = player_rx.recv().await {
            match &event {
                PlayerEvent::TogglePause => {
                    let result = {
                        let guard = backend.lock().unwrap();
                        guard.as_ref().map(|b| b.pause())
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, "Pause failed");
                    }
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            ps.set_is_paused(!ps.get_is_paused());
                        }
                    });
                }

                PlayerEvent::Stop => {
                    let result = {
                        let guard = backend.lock().unwrap();
                        guard.as_ref().map(|b| b.stop())
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, "Stop failed");
                    }
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            ps.set_is_playing(false);
                            ps.set_is_paused(false);
                            ps.set_is_buffering(false);
                            ps.set_current_title(Default::default());
                        }
                    });
                }

                PlayerEvent::Seek { position_secs } => {
                    let pos = *position_secs;
                    let result = {
                        let guard = backend.lock().unwrap();
                        guard.as_ref().map(|b| b.seek(pos))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, "Seek failed");
                    }
                }

                PlayerEvent::SeekRelative { delta_secs } => {
                    let delta = *delta_secs;
                    tracing::debug!(
                        delta,
                        "SeekRelative (no-op until mpv exposes relative seek)"
                    );
                }

                PlayerEvent::SetVolume { volume } => {
                    let vol = *volume;
                    let result = {
                        let guard = backend.lock().unwrap();
                        guard.as_ref().map(|b| b.set_volume(vol))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, "SetVolume failed");
                    }
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            ps.set_volume(vol.clamp(0.0, 1.0));
                            ps.set_is_muted(false);
                        }
                    });
                }

                PlayerEvent::ToggleMute => {
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            ps.set_is_muted(!ps.get_is_muted());
                        }
                    });
                }

                PlayerEvent::ShowControls { visible } => {
                    let v = *visible;
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            ps.set_show_osd(if v { !ps.get_show_osd() } else { false });
                        }
                    });
                }

                PlayerEvent::SetFullscreen { fullscreen } => {
                    let fs = *fullscreen;
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            ui.global::<super::PlayerState>().set_is_fullscreen(fs);
                        }
                    });
                }

                PlayerEvent::NextAudioTrack => {
                    tracing::debug!("NextAudioTrack (mpv cycle audio)");
                    // mpv: "cycle audio" — TODO when track API is exposed
                }

                PlayerEvent::NextSubtitleTrack => {
                    tracing::debug!("NextSubtitleTrack (mpv cycle sub)");
                    // mpv: "cycle sub" — TODO when track API is exposed
                }

                PlayerEvent::SetSpeed { speed } => {
                    tracing::debug!(speed, "SetSpeed (no-op until speed property exposed)");
                }
            }
        }
        tracing::info!("player_handler task exited");
    });
}

// ── spawn_data_listener ───────────────────────────────────────────────────────

/// Spawn a tokio task that receives DataEvents and applies them to Slint state.
///
/// `PlaybackReady` is handled here — it locks the shared backend and calls `play()`.
pub(crate) fn spawn_data_listener(
    ui_weak: slint::Weak<super::AppWindow>,
    mut data_rx: mpsc::Receiver<DataEvent>,
    backend: Arc<Mutex<Option<crispy_player::mpv_backend::MpvBackend>>>,
    render_context_ready: Arc<AtomicBool>,
    image_cache: Arc<crate::image_cache::ImageCache>,
) {
    tokio::spawn(async move {
        while let Some(event) = data_rx.recv().await {
            // After applying data events, trigger image prefetch
            let should_load_images = matches!(
                &event,
                DataEvent::ChannelsReady { .. }
                    | DataEvent::MoviesReady { .. }
                    | DataEvent::SeriesReady { .. }
            );

            match event {
                DataEvent::PlaybackReady { url, title } => {
                    // Wait for the render context to be ready before playing
                    // (prevents video-only-audio race condition on first play)
                    let mut waited = 0u32;
                    while !render_context_ready.load(Ordering::Acquire) && waited < 50 {
                        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
                        waited += 1;
                    }
                    if waited >= 50 {
                        tracing::warn!("Render context not ready after 5s — playing anyway");
                    }

                    // Play on the backend (thread-safe mpv call)
                    let result = {
                        let guard = backend.lock().unwrap();
                        guard.as_ref().map(|b| b.play(&url))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, url = %url, "PlaybackReady: play failed");
                    }
                    let title_clone = title.clone();
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            ps.set_current_title(SharedString::from(title_clone.as_str()));
                            ps.set_is_playing(true);
                            ps.set_is_buffering(false);
                            ps.set_show_osd(true);
                        }
                    });
                }

                other => {
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            apply_data_event(&ui, other);
                        }
                    });
                }
            }

            // Prefetch images for newly loaded content
            if should_load_images {
                let cache = Arc::clone(&image_cache);
                let ui_w = ui_weak.clone();
                tokio::spawn(async move {
                    load_images_for_ui(&ui_w, &cache).await;
                });
            }
        }
        tracing::info!("data_listener task exited");
    });
}

// ── apply_data_event ─────────────────────────────────────────────────────────

/// Pure mapping: DataEvent → Slint property mutations.
///
/// MUST be called on the UI thread (inside `invoke_from_event_loop` or directly).
pub(crate) fn apply_data_event(ui: &super::AppWindow, event: DataEvent) {
    let app = ui.global::<super::AppState>();
    let _ps = ui.global::<super::PlayerState>();

    match event {
        DataEvent::SourcesReady { sources } => {
            let items: Vec<super::SourceData> = sources.iter().map(source_info_to_slint).collect();
            app.set_sources(ModelRc::new(VecModel::from(items)));
        }

        DataEvent::ChannelsReady {
            channels,
            groups: in_groups,
            total,
            has_more,
        } => {
            let items: Vec<super::ChannelData> =
                channels.iter().map(channel_info_to_slint).collect();
            app.set_channels(ModelRc::new(VecModel::from(items)));
            app.set_total_channel_count(total);
            app.set_has_more_channels(has_more);

            // Populate groups from the complete state-provided list
            let sc_groups: Vec<SharedString> = in_groups
                .into_iter()
                .map(|s| SharedString::from(s.as_str()))
                .collect();
            app.set_channel_groups(ModelRc::new(VecModel::from(sc_groups)));
        }

        DataEvent::MoviesReady {
            movies,
            categories: in_categories,
            total,
            has_more,
        } => {
            let items: Vec<super::VodData> = movies.iter().map(vod_info_to_slint).collect();
            app.set_movies(ModelRc::new(VecModel::from(items)));
            app.set_total_movie_count(total);
            app.set_has_more_movies(has_more);

            let sc_cats: Vec<super::CategoryData> = in_categories
                .into_iter()
                .map(|c| super::CategoryData {
                    name: SharedString::from(c.as_str()),
                    category_type: SharedString::from("movie"),
                })
                .collect();
            app.set_vod_categories(ModelRc::new(VecModel::from(sc_cats)));
        }

        DataEvent::SeriesReady {
            series,
            categories: in_categories,
            total,
            has_more,
        } => {
            let items: Vec<super::VodData> = series.iter().map(vod_info_to_slint).collect();
            app.set_series(ModelRc::new(VecModel::from(items)));
            app.set_total_series_count(total);
            app.set_has_more_series(has_more);

            let sc_cats: Vec<super::CategoryData> = in_categories
                .into_iter()
                .map(|c| super::CategoryData {
                    name: SharedString::from(c.as_str()),
                    category_type: SharedString::from("series"),
                })
                .collect();
            app.set_vod_categories(ModelRc::new(VecModel::from(sc_cats)));
        }

        DataEvent::ChannelsAppend { channels, has_more } => {
            let existing = app.get_channels();
            let mut items: Vec<super::ChannelData> = existing.iter().collect();
            items.extend(channels.iter().map(channel_info_to_slint));
            app.set_channels(ModelRc::new(VecModel::from(items)));
            app.set_has_more_channels(has_more);
        }

        DataEvent::MoviesAppend { movies, has_more } => {
            let existing = app.get_movies();
            let mut items: Vec<super::VodData> = existing.iter().collect();
            items.extend(movies.iter().map(vod_info_to_slint));
            app.set_movies(ModelRc::new(VecModel::from(items)));
            app.set_has_more_movies(has_more);
        }

        DataEvent::SeriesAppend { series, has_more } => {
            let existing = app.get_series();
            let mut items: Vec<super::VodData> = existing.iter().collect();
            items.extend(series.iter().map(vod_info_to_slint));
            app.set_series(ModelRc::new(VecModel::from(items)));
            app.set_has_more_series(has_more);
        }

        DataEvent::SearchResults {
            channels,
            movies,
            series,
            ..
        } => {
            let ch: Vec<super::ChannelData> = channels.iter().map(channel_info_to_slint).collect();
            let mv: Vec<super::VodData> = movies.iter().map(vod_info_to_slint).collect();
            // Merge movies + series into search_vod
            let mut vod: Vec<super::VodData> = mv;
            vod.extend(series.iter().map(vod_info_to_slint));
            app.set_search_channels(ModelRc::new(VecModel::from(ch)));
            app.set_search_vod(ModelRc::new(VecModel::from(vod)));
            app.set_is_searching(false);
        }

        DataEvent::LoadingStarted { kind } => match kind {
            LoadingKind::Channels => app.set_is_loading_channels(true),
            LoadingKind::Movies | LoadingKind::Series => app.set_is_loading_vod(true),
            LoadingKind::Search => app.set_is_searching(true),
            LoadingKind::Sync => app.set_is_syncing(true),
        },

        DataEvent::LoadingFinished { kind } => match kind {
            LoadingKind::Channels => app.set_is_loading_channels(false),
            LoadingKind::Movies | LoadingKind::Series => app.set_is_loading_vod(false),
            LoadingKind::Search => app.set_is_searching(false),
            LoadingKind::Sync => app.set_is_syncing(false),
        },

        DataEvent::SyncStarted { source_id } => {
            app.set_is_syncing(true);
            app.set_sync_message(SharedString::from(format!("Syncing {source_id}…").as_str()));
        }

        DataEvent::SyncProgress { source_id, percent } => {
            app.set_sync_message(SharedString::from(
                format!("Syncing {source_id}: {percent}%").as_str(),
            ));
        }

        DataEvent::SyncCompleted { result } => {
            app.set_is_syncing(false);
            use crate::events::SyncResult;
            let msg = match result {
                SyncResult::Success {
                    channel_count,
                    vod_count,
                    ..
                } => format!("Sync complete: {channel_count} channels, {vod_count} VOD"),
                SyncResult::Failed { error, .. } => format!("Sync failed: {error}"),
            };
            app.set_sync_message(SharedString::from(msg.as_str()));
        }

        DataEvent::SyncFailed { source_id, error } => {
            app.set_is_syncing(false);
            app.set_sync_message(SharedString::from(
                format!("Sync failed ({source_id}): {error}").as_str(),
            ));
        }

        DataEvent::ThemeApplied { theme_name } => {
            // theme_name is an int stringified — parse back; default 1 (auto)
            let mode: i32 = theme_name.parse().unwrap_or(1);
            ui.global::<super::Theme>().set_theme_mode(mode);
        }

        DataEvent::LanguageApplied { language_tag } => {
            let is_rtl = matches!(language_tag.as_str(), "ar" | "he" | "fa" | "ur");
            app.set_active_language(SharedString::from(language_tag.as_str()));
            app.set_is_rtl(is_rtl);
        }

        DataEvent::OnboardingDismissed => {
            ui.global::<super::OnboardingState>().set_is_active(false);
        }

        DataEvent::ScreenChanged { screen } => {
            app.set_active_screen(screen as i32);
        }

        DataEvent::DiagnosticsInfo { report } => {
            tracing::info!(report = %report, "Diagnostics");
            // DiagnosticsState has no text property in current .slint — log only
        }

        DataEvent::Error { message } => {
            tracing::error!(message = %message, "DataEngine error surfaced to UI");
            app.set_sync_message(SharedString::from(message.as_str()));
        }

        // PlaybackReady is handled in spawn_data_listener before reaching here
        DataEvent::PlaybackReady { .. } => {}
    }
}

// ── Conversion helpers ────────────────────────────────────────────────────────

fn channel_info_to_slint(c: &ChannelInfo) -> super::ChannelData {
    super::ChannelData {
        id: SharedString::from(c.id.as_str()),
        name: SharedString::from(c.name.as_str()),
        group: SharedString::from(c.channel_group.as_deref().unwrap_or("")),
        logo_url: SharedString::from(c.logo_url.as_deref().unwrap_or("")),
        stream_url: SharedString::from(c.stream_url.as_str()),
        source_id: SharedString::from(c.source_id.as_deref().unwrap_or("")),
        number: c.number.unwrap_or(0),
        is_favorite: c.is_favorite,
        now_playing: SharedString::default(),
        logo: Default::default(),
    }
}

fn vod_info_to_slint(v: &VodInfo) -> super::VodData {
    super::VodData {
        id: SharedString::from(v.id.as_str()),
        name: SharedString::from(v.name.as_str()),
        stream_url: SharedString::from(v.stream_url.as_str()),
        item_type: SharedString::from(v.item_type.as_str()),
        poster_url: SharedString::from(v.poster_url.as_deref().unwrap_or("")),
        genre: SharedString::default(),
        year: SharedString::from(v.year.map(|y| y.to_string()).unwrap_or_default().as_str()),
        rating: SharedString::from(v.rating.as_deref().unwrap_or("")),
        source_id: SharedString::from(v.source_id.as_deref().unwrap_or("")),
        series_id: SharedString::default(),
        season: 0,
        episode: 0,
        poster: Default::default(),
    }
}

fn source_info_to_slint(s: &SourceInfo) -> super::SourceData {
    super::SourceData {
        id: SharedString::from(s.id.as_str()),
        name: SharedString::from(s.name.as_str()),
        source_type: SharedString::from(s.source_type.as_str()),
        url: SharedString::from(s.url.as_str()),
        username: SharedString::default(),
        password: SharedString::default(),
        channel_count: 0,
        vod_count: 0,
        sync_status: SharedString::from(s.last_sync_status.as_deref().unwrap_or("")),
    }
}

// ── Image loading ─────────────────────────────────────────────────────────────

/// Fetch images for currently visible channels and VOD items, updating the
/// Slint model in-place as each image is decoded.
async fn load_images_for_ui(
    ui_weak: &slint::Weak<super::AppWindow>,
    image_cache: &Arc<crate::image_cache::ImageCache>,
) {
    // Collect URLs from the current Slint models
    let (tx, rx) = std::sync::mpsc::channel();
    let ui_w = ui_weak.clone();
    let _ = slint::invoke_from_event_loop(move || {
        let Some(ui) = ui_w.upgrade() else {
            let _ = tx.send((Vec::new(), Vec::new(), Vec::new()));
            return;
        };
        let app = ui.global::<super::AppState>();

        let ch_urls: Vec<(usize, String)> = app
            .get_channels()
            .iter()
            .enumerate()
            .filter(|(_, c)| !c.logo_url.is_empty())
            .map(|(i, c)| (i, c.logo_url.to_string()))
            .collect();

        let mv_urls: Vec<(usize, String)> = app
            .get_movies()
            .iter()
            .enumerate()
            .filter(|(_, v)| !v.poster_url.is_empty())
            .map(|(i, v)| (i, v.poster_url.to_string()))
            .collect();

        let sr_urls: Vec<(usize, String)> = app
            .get_series()
            .iter()
            .enumerate()
            .filter(|(_, v)| !v.poster_url.is_empty())
            .map(|(i, v)| (i, v.poster_url.to_string()))
            .collect();

        let _ = tx.send((ch_urls, mv_urls, sr_urls));
    });
    
    let Ok((channel_urls, movie_urls, series_urls)) = rx.recv() else { return; };

    // Download images with bounded concurrency (8 concurrent downloads)
    let semaphore = Arc::new(tokio::sync::Semaphore::new(8));

    // Channel logos
    for (idx, url) in channel_urls {
        let cache = Arc::clone(image_cache);
        let sem = Arc::clone(&semaphore);
        let ui_w = ui_weak.clone();
        tokio::spawn(async move {
            let _permit = sem.acquire().await;
            if let Some(buf) = cache.get_image_buffer(&url).await {
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w.upgrade() {
                        let app = ui.global::<super::AppState>();
                        let model = app.get_channels();
                        if let Some(mut item) = model.row_data(idx) {
                            item.logo = slint::Image::from_rgba8(buf);
                            model.set_row_data(idx, item);
                        }
                    }
                });
            }
        });
    }

    // Movie posters
    for (idx, url) in movie_urls {
        let cache = Arc::clone(image_cache);
        let sem = Arc::clone(&semaphore);
        let ui_w = ui_weak.clone();
        tokio::spawn(async move {
            let _permit = sem.acquire().await;
            if let Some(buf) = cache.get_image_buffer(&url).await {
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w.upgrade() {
                        let app = ui.global::<super::AppState>();
                        let model = app.get_movies();
                        if let Some(mut item) = model.row_data(idx) {
                            item.poster = slint::Image::from_rgba8(buf);
                            model.set_row_data(idx, item);
                        }
                    }
                });
            }
        });
    }

    // Series posters
    for (idx, url) in series_urls {
        let cache = Arc::clone(image_cache);
        let sem = Arc::clone(&semaphore);
        let ui_w = ui_weak.clone();
        tokio::spawn(async move {
            let _permit = sem.acquire().await;
            if let Some(buf) = cache.get_image_buffer(&url).await {
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w.upgrade() {
                        let app = ui.global::<super::AppState>();
                        let model = app.get_series();
                        if let Some(mut item) = model.row_data(idx) {
                            item.poster = slint::Image::from_rgba8(buf);
                            model.set_row_data(idx, item);
                        }
                    }
                });
            }
        });
    }
}
