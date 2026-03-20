//! EventBridge — the ONLY file that imports both Slint-generated types and event channels.
//!
//! Responsibilities:
//! 1. `wire()` — connect Slint callbacks to the three event queues
//! 2. `spawn_player_handler()` — owns MpvBackend, processes PlayerEvents
//! 3. `spawn_data_listener()` — maps DataEvents to Slint properties
//! 4. `apply_data_event()` — pure DataEvent → Slint property mapping

use std::rc::Rc;
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
};

use chrono::{Datelike, Timelike};

use crispy_player::PlayerBackend;
use slint::{ComponentHandle, Model, ModelRc, SharedString, VecModel};
use tokio::sync::mpsc;

use crispy_server::models::EpgEntry;
use crispy_server::models::UserProfile;

use crate::events::{
    ChannelInfo, DataEvent, HighPriorityEvent, LoadingKind, NormalEvent, PlayerEvent, Screen,
    SourceInfo, SourceInput, VodInfo,
};

// ── Virtual scroll — use slint-crispy-vscroll bridge ───────────────────────
use crate::scroll_integration::{CHANNEL_WINDOW, ScrollBridge, VOD_WINDOW};

// ── Shared data stores ──────────────────────────────────────────────────────
/// Full datasets (Send+Sync). VecModel only gets a windowed slice.
/// EPG entries and profiles are populated by DataEngine during startup
/// and read by EventBridge when building Slint property payloads.
pub(crate) struct SharedData {
    pub channels: Mutex<Arc<Vec<ChannelInfo>>>,
    pub movies: Mutex<Arc<Vec<VodInfo>>>,
    pub series: Mutex<Arc<Vec<VodInfo>>>,
    /// EPG entries keyed by channel_id, populated from CrispyService on startup / sync.
    pub epg_entries: Mutex<std::collections::HashMap<String, Vec<EpgEntry>>>,
    /// All user profiles loaded from DB on startup.
    pub profiles: Mutex<Vec<UserProfile>>,
    /// ID of the currently active profile (empty = default).
    pub active_profile_id: Mutex<String>,
    /// Spatial focus manager — owns zone registry and navigation state.
    pub focus_mgr: Mutex<crate::focus::manager::FocusManager>,
    /// Input abstraction — maps raw key codes to logical actions.
    /// Incrementally wired: used when global key handler is connected.
    #[allow(dead_code)]
    pub input_mgr: Mutex<crate::input::InputManager>,
    /// J-25: recent search queries, most-recent first, capped at 10.
    pub recent_searches: Mutex<Vec<String>>,
}

impl SharedData {
    pub fn new() -> Self {
        Self {
            channels: Mutex::new(Arc::new(Vec::new())),
            movies: Mutex::new(Arc::new(Vec::new())),
            series: Mutex::new(Arc::new(Vec::new())),
            epg_entries: Mutex::new(std::collections::HashMap::new()),
            profiles: Mutex::new(Vec::new()),
            active_profile_id: Mutex::new(String::new()),
            focus_mgr: Mutex::new(crate::focus::manager::FocusManager::new("home")),
            input_mgr: Mutex::new(crate::input::InputManager::new()),
            recent_searches: Mutex::new(Vec::new()),
        }
    }
}

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
    image_loader: crate::image_loader::ImageLoader,
    shared_data: Arc<SharedData>,
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

    // M-018: show-controls toggles OSD and secondary controls tray
    ps.on_show_controls({
        let tx = player_tx.clone();
        let ui_w = ui.as_weak();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::ShowControls { visible: true }) {
                tracing::warn!(error = %e, "player_tx full: ShowControls dropped");
            }
            // Also toggle the secondary controls tray visibility
            if let Some(ui) = ui_w.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                let current = ps.get_show_secondary_controls();
                ps.set_show_secondary_controls(!current);
            }
        }
    });

    // skip-back: seek -10s (direction preserved by SeekRelative handler)
    ps.on_skip_back({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::SeekRelative { delta_secs: -10.0 }) {
                tracing::warn!(error = %e, "player_tx full: skip-back dropped");
            }
        }
    });

    // skip-forward: seek +10s
    ps.on_skip_forward({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::SeekRelative { delta_secs: 10.0 }) {
                tracing::warn!(error = %e, "player_tx full: skip-forward dropped");
            }
        }
    });

    // skip-intro: seek +30s (fixed jump — no chapter data yet)
    ps.on_skip_intro({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::SeekRelative { delta_secs: 30.0 }) {
                tracing::warn!(error = %e, "player_tx full: skip-intro dropped");
            }
        }
    });

    // M-030: Consecutive auto-advance counter for "still watching" prompt.
    // After 3 consecutive auto-advances, show the still-watching overlay.
    let auto_advance_count: Arc<Mutex<u32>> = Arc::new(Mutex::new(0));

    // play-next: advance to the next episode by re-using the high-priority queue.
    // The next VOD id must be resolved from the series_episodes model in Slint.
    // We read it here on the UI thread (wire() is called on the UI thread) via a
    // weak handle so we never cross the !Send boundary of Slint types.
    ps.on_play_next({
        let high_tx = high_tx.clone();
        let ui_w = ui.as_weak();
        let auto_advance = Arc::clone(&auto_advance_count);
        move || {
            // Hide the next-episode overlay immediately.
            if let Some(ui) = ui_w.upgrade() {
                ui.global::<super::PlayerState>()
                    .set_show_next_episode(false);
            }

            // M-030: increment auto-advance counter and check for still-watching
            {
                let mut count = auto_advance.lock().unwrap_or_else(|e| e.into_inner());
                *count += 1;
                if *count >= 3 {
                    *count = 0;
                    if let Some(ui) = ui_w.upgrade() {
                        ui.global::<super::PlayerState>()
                            .set_show_still_watching(true);
                        tracing::debug!(
                            "M-030: show-still-watching after 3 consecutive auto-advances"
                        );
                    }
                    return;
                }
            }

            // Resolve the next episode id from AppState.series_episodes.
            // The series detail view already holds the episode list; find the
            // episode after the currently playing one by position index.
            let next_id = ui_w.upgrade().and_then(|ui| {
                let app = ui.global::<super::AppState>();
                let ps = ui.global::<super::PlayerState>();
                let current_title = ps.get_current_title().to_string();
                let model = app.get_series_episodes();
                // Find the episode whose title matches the currently playing title,
                // then return the next sequential episode in the list.
                let count = model.row_count();
                for i in 0..count {
                    let ep = model.row_data(i).unwrap_or_default();
                    if ep.name.as_str() == current_title || i + 1 == count {
                        // Return the next episode if available, else None.
                        if i + 1 < count {
                            return Some(model.row_data(i + 1).unwrap_or_default().id.to_string());
                        }
                        return None;
                    }
                }
                None
            });
            if let Some(id) = next_id.filter(|s| !s.is_empty()) {
                if let Err(e) = high_tx.try_send(HighPriorityEvent::PlayVod { vod_id: id }) {
                    tracing::warn!(error = %e, "high_tx full: play-next dropped");
                }
            } else {
                tracing::debug!("play-next: no next episode found");
            }
        }
    });

    // cancel-next: user dismissed the next-episode countdown — just hide the overlay.
    ps.on_cancel_next({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                ui.global::<super::PlayerState>()
                    .set_show_next_episode(false);
                tracing::debug!("cancel-next: next-episode overlay dismissed");
            }
        }
    });

    // dismiss-still-watching: user confirmed they are still watching — hide overlay.
    ps.on_dismiss_still_watching({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                ui.global::<super::PlayerState>()
                    .set_show_still_watching(false);
                tracing::debug!("dismiss-still-watching: still-watching overlay dismissed");
            }
        }
    });

    // select-audio-track: select a specific audio track by index (C-012)
    ps.on_select_audio_track({
        let tx = player_tx.clone();
        move |index| {
            if let Err(e) = tx.try_send(PlayerEvent::SelectAudioTrack { index }) {
                tracing::warn!(error = %e, "player_tx full: SelectAudioTrack dropped");
            }
        }
    });

    // select-subtitle-track: select a specific subtitle track by index (C-013)
    ps.on_select_subtitle_track({
        let tx = player_tx.clone();
        move |index| {
            if let Err(e) = tx.try_send(PlayerEvent::SelectSubtitleTrack { index }) {
                tracing::warn!(error = %e, "player_tx full: SelectSubtitleTrack dropped");
            }
        }
    });

    // M-037: toggle-fullscreen — notify Rust of fullscreen toggle from OSD button
    ps.on_toggle_fullscreen({
        let tx = player_tx.clone();
        let ui_w = ui.as_weak();
        move || {
            let new_fs = ui_w
                .upgrade()
                .map(|ui| !ui.global::<super::PlayerState>().get_is_fullscreen())
                .unwrap_or(true);
            if let Err(e) = tx.try_send(PlayerEvent::SetFullscreen { fullscreen: new_fs }) {
                tracing::warn!(error = %e, "player_tx full: SetFullscreen dropped");
            }
        }
    });

    // M-038: next-audio-track — cycle to next audio track via OSD tray
    ps.on_next_audio_track({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::NextAudioTrack) {
                tracing::warn!(error = %e, "player_tx full: NextAudioTrack dropped");
            }
        }
    });

    // M-039: next-subtitle-track — cycle to next subtitle track via OSD tray
    ps.on_next_subtitle_track({
        let tx = player_tx.clone();
        move || {
            if let Err(e) = tx.try_send(PlayerEvent::NextSubtitleTrack) {
                tracing::warn!(error = %e, "player_tx full: NextSubtitleTrack dropped");
            }
        }
    });

    // M-040: set-speed — set playback speed from OSD speed cycle button
    ps.on_set_speed({
        let tx = player_tx.clone();
        let ui_w = ui.as_weak();
        move |speed| {
            if let Err(e) = tx.try_send(PlayerEvent::SetSpeed { speed }) {
                tracing::warn!(error = %e, "player_tx full: SetSpeed dropped");
            }
            // Update the Slint property immediately for responsive UI
            if let Some(ui) = ui_w.upgrade() {
                ui.global::<super::PlayerState>().set_current_speed(speed);
            }
        }
    });

    // M-018: toggle-secondary-controls — toggle the secondary controls tray visibility
    ps.on_toggle_secondary_controls({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                let current = ps.get_show_secondary_controls();
                ps.set_show_secondary_controls(!current);
                tracing::debug!(now = !current, "toggle-secondary-controls");
            }
        }
    });

    // toggle-tracks-panel: show/hide audio+subtitle track selection panel
    ps.on_toggle_tracks_panel({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                let current = ps.get_show_tracks_panel();
                ps.set_show_tracks_panel(!current);
                tracing::debug!(now = !current, "toggle-tracks-panel");
            }
        }
    });

    // ── AppState callbacks ────────────────────────────────────────────────

    let app = ui.global::<super::AppState>();

    // ── Persistent VecModels (Rc, UI-thread only) ────────────────────
    // Created ONCE. Scroll callbacks mutate via push/remove/insert.
    // Setting ModelRc::from(rc.clone()) means Slint keeps the SAME model
    // instance — viewport-y is never reset by model replacement.
    let channel_model: Rc<VecModel<super::ChannelData>> = Rc::new(VecModel::default());
    app.set_channels(ModelRc::from(channel_model.clone()));

    let movie_model: Rc<VecModel<super::VodData>> = Rc::new(VecModel::default());
    app.set_movies(ModelRc::from(movie_model.clone()));

    let series_model: Rc<VecModel<super::VodData>> = Rc::new(VecModel::default());
    app.set_series(ModelRc::from(series_model.clone()));

    // ── ScrollBridge instances (one per scrollable list) ─────────────────
    // Each bridge wraps a VirtualScroller from slint-crispy-vscroll and
    // translates Slint scroll-delta events into VecModel window positions.
    // Wrapped in Rc<RefCell> so the on_scroll_* closures can mutate them.
    let channel_bridge = Rc::new(std::cell::RefCell::new(ScrollBridge::new(CHANNEL_WINDOW)));
    let movie_bridge = Rc::new(std::cell::RefCell::new(ScrollBridge::new(VOD_WINDOW)));
    let series_bridge = Rc::new(std::cell::RefCell::new(ScrollBridge::new(VOD_WINDOW)));

    app.on_navigate({
        let tx = high_tx.clone();
        let sd = Arc::clone(&shared_data);
        let ui_w_nav = ui.as_weak();
        move |screen_index| {
            let screen = Screen::from_i32(screen_index).unwrap_or(Screen::Home);
            // Update FocusManager active zone to match the new screen
            let zone_id = match screen {
                Screen::Home => "home",
                Screen::LiveTv => "live-tv",
                Screen::Epg => "epg",
                Screen::Movies => "movies",
                Screen::Series => "series",
                Screen::Search => "search",
                Screen::Library => "library",
                Screen::Settings => "settings",
            };
            if let Ok(mut fm) = sd.focus_mgr.lock() {
                fm.set_active_zone(zone_id);
            }
            if let Err(e) = tx.try_send(HighPriorityEvent::Navigate { screen }) {
                tracing::warn!(error = %e, "high_tx full: Navigate dropped");
            }
            // M-018: set active-screen so nav items reflect current selection.
            // top-nav.slint removed the inline `active-screen = N` mutation; Rust owns it.
            if let Some(ui) = ui_w_nav.upgrade() {
                ui.global::<super::AppState>()
                    .set_active_screen(screen_index);
            }
            // M-001: mark "Browse channels" getting-started step when user visits Live TV
            if screen == Screen::LiveTv {
                let ui_w2 = ui_w_nav.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        ui.global::<super::AppState>().set_gs_browsed_channels(true);
                    }
                });
            }
        }
    });

    // J-06: Rapid-zap throttle — shared state for debounce cancellation and
    // previous-channel tracking. Held in Arc so both closures can access them.
    let zap_cancel: Arc<Mutex<Option<tokio::sync::oneshot::Sender<()>>>> =
        Arc::new(Mutex::new(None));
    let previous_channel_id: Arc<Mutex<Option<String>>> = Arc::new(Mutex::new(None));

    app.on_play_channel({
        let tx = high_tx.clone();
        let zap_cancel = Arc::clone(&zap_cancel);
        let prev_ch = Arc::clone(&previous_channel_id);
        // Capture the current playing channel id from PlayerState via weak ref so
        // we can record it as "previous" before switching.
        let ui_w = ui.as_weak();
        move |channel_id| {
            let id = channel_id.to_string();

            // Record the currently playing channel as "previous" before we switch.
            if let Some(ui) = ui_w.upgrade() {
                let current = ui
                    .global::<super::PlayerState>()
                    .get_current_channel_id()
                    .to_string();
                if !current.is_empty() && current != id {
                    *prev_ch.lock().unwrap_or_else(|e| e.into_inner()) = Some(current);
                }
            }

            // Cancel any in-flight 300ms timer from a previous zap press.
            {
                let mut guard = zap_cancel.lock().unwrap_or_else(|e| e.into_inner());
                if let Some(prev_tx) = guard.take() {
                    // Sending to the old oneshot cancels the pending sleep.
                    let _ = prev_tx.send(());
                }
                // Create a new cancellation oneshot for this press.
                let (cancel_tx, cancel_rx) = tokio::sync::oneshot::channel::<()>();
                *guard = Some(cancel_tx);

                // Spawn the 300ms debounce task.
                let tx2 = tx.clone();
                let id2 = id.clone();
                let ui_w_gs = ui_w.clone();
                tokio::spawn(async move {
                    // Race between: timer expiry (fire) vs cancellation (discard).
                    tokio::select! {
                        _ = tokio::time::sleep(std::time::Duration::from_millis(300)) => {
                            if let Err(e) = tx2.try_send(HighPriorityEvent::PlayChannel {
                                channel_id: id2,
                            }) {
                                tracing::warn!(error = %e, "high_tx full: PlayChannel (zap) dropped");
                            }
                            // M-001: mark "Play your first channel" getting-started step
                            let _ = slint::invoke_from_event_loop(move || {
                                if let Some(ui) = ui_w_gs.upgrade() {
                                    ui.global::<super::AppState>().set_gs_played_channel(true);
                                }
                            });
                        }
                        _ = cancel_rx => {
                            tracing::trace!("zap debounce cancelled — faster press followed");
                        }
                    }
                });
            }
        }
    });

    // J-06: Previous Channel — play the last channel that was active before the current one.
    app.on_previous_channel({
        let tx = high_tx.clone();
        let prev_ch = Arc::clone(&previous_channel_id);
        move || {
            let guard = prev_ch.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(ref id) = *guard {
                if let Err(e) = tx.try_send(HighPriorityEvent::PlayChannel {
                    channel_id: id.clone(),
                }) {
                    tracing::warn!(error = %e, "high_tx full: PreviousChannel dropped");
                }
            } else {
                tracing::debug!("PreviousChannel: no previous channel recorded");
            }
        }
    });

    app.on_filter_channels({
        let tx = high_tx.clone();
        let sd_filter = Arc::clone(&shared_data);
        move |group, _search| {
            let query = group.to_string();
            // J-07: if the query is purely numeric, check whether it matches exactly one
            // channel by logical channel number — if so, auto-play that channel directly.
            if !query.is_empty()
                && query.chars().all(|c| c.is_ascii_digit())
                && let Ok(num) = query.parse::<i32>()
            {
                let channels = sd_filter.channels.lock().unwrap_or_else(|e| e.into_inner());
                let matches: Vec<_> = channels.iter().filter(|c| c.number == Some(num)).collect();
                if matches.len() == 1 {
                    let channel_id = matches[0].id.clone();
                    drop(channels); // release lock before send
                    if let Err(e) = tx.try_send(HighPriorityEvent::PlayChannel { channel_id }) {
                        tracing::warn!(error = %e, "high_tx full: J-07 numeric auto-play dropped");
                    }
                    return;
                }
            }
            if let Err(e) = tx.try_send(HighPriorityEvent::FilterContent { query }) {
                tracing::warn!(error = %e, "high_tx full: FilterChannels dropped");
            }
        }
    });

    app.on_filter_vod_category({
        let tx = high_tx.clone();
        move |category| {
            if let Err(e) = tx.try_send(HighPriorityEvent::FilterVodCategory {
                category: category.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: FilterVodCategory dropped");
            }
        }
    });

    app.on_perform_search({
        let tx = high_tx.clone();
        let normal_tx_search = normal_tx.clone();
        let shared_data_search = Arc::clone(&shared_data);
        let ui_w_search = ui.as_weak();
        move |query| {
            if let Err(e) = tx.try_send(HighPriorityEvent::Search {
                query: query.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: Search dropped");
            }
            // J-25: persist recent searches (dedup, most-recent first, cap 10)
            let q = query.to_string();
            if q.len() >= 2 {
                let updated = {
                    let mut list = shared_data_search
                        .recent_searches
                        .lock()
                        .unwrap_or_else(|e| e.into_inner());
                    list.retain(|s| s != &q);
                    list.insert(0, q.clone());
                    list.truncate(10);
                    list.clone()
                };
                // Update UI property
                if let Some(ui) = ui_w_search.upgrade() {
                    let slint_list: Vec<SharedString> = updated
                        .iter()
                        .map(|s| SharedString::from(s.as_str()))
                        .collect();
                    ui.global::<super::AppState>()
                        .set_recent_searches(ModelRc::new(VecModel::from(slint_list)));
                }
                // Persist as JSON array
                let json = format!(
                    "[{}]",
                    updated
                        .iter()
                        .map(|s| format!("\"{}\"", s.replace('"', "\\\"")))
                        .collect::<Vec<_>>()
                        .join(",")
                );
                let _ = normal_tx_search.try_send(NormalEvent::SavePreference {
                    key: "recent_searches".into(),
                    value: json,
                });
            }
        }
    });

    app.on_search_epg({
        let tx = high_tx.clone();
        move |query| {
            if let Err(e) = tx.try_send(HighPriorityEvent::SearchEpg {
                query: query.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: SearchEpg dropped");
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
        let ui_w = ui.as_weak();
        move |mode| {
            // M-019: settings.slint removed inline `Theme.theme-mode = item.mode`; Rust owns it.
            if let Some(ui) = ui_w.upgrade() {
                ui.global::<super::Theme>().set_theme_mode(mode);
            }
            if let Err(e) = tx.try_send(HighPriorityEvent::ChangeTheme {
                theme_name: mode.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: SetTheme dropped");
            }
        }
    });

    app.on_set_language({
        let tx = high_tx.clone();
        let ui_w = ui.as_weak();
        move |lang| {
            // M-020: settings.slint removed inline `active-language = lang.code`; Rust owns it.
            if let Some(ui) = ui_w.upgrade() {
                ui.global::<super::AppState>()
                    .set_active_language(slint::SharedString::from(lang.as_str()));
            }
            if let Err(e) = tx.try_send(HighPriorityEvent::ChangeLanguage {
                language_tag: lang.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: SetLanguage dropped");
            }
        }
    });

    // ── Settings preference callbacks ─────────────────────────────────────

    app.on_set_video_quality({
        let tx = normal_tx.clone();
        move |label| {
            tracing::info!(quality = %label, "settings: video quality changed");
            let _ = tx.try_send(NormalEvent::SavePreference {
                key: "video_quality".into(),
                value: label.to_string(),
            });
        }
    });

    app.on_set_audio_language({
        let tx = normal_tx.clone();
        move |lang| {
            tracing::info!(lang = %lang, "settings: audio language changed");
            let _ = tx.try_send(NormalEvent::SavePreference {
                key: "audio_language".into(),
                value: lang.to_string(),
            });
        }
    });

    app.on_set_audio_passthrough({
        let tx = normal_tx.clone();
        move |enabled| {
            tracing::info!(enabled, "settings: audio passthrough changed");
            let _ = tx.try_send(NormalEvent::SavePreference {
                key: "audio_passthrough".into(),
                value: enabled.to_string(),
            });
        }
    });

    app.on_set_autoplay_next({
        let tx = normal_tx.clone();
        move |enabled| {
            tracing::info!(enabled, "settings: autoplay next changed");
            let _ = tx.try_send(NormalEvent::SavePreference {
                key: "autoplay_next".into(),
                value: enabled.to_string(),
            });
        }
    });

    app.on_set_subtitle_language({
        let tx = normal_tx.clone();
        move |lang| {
            tracing::info!(lang = %lang, "settings: subtitle language changed");
            let _ = tx.try_send(NormalEvent::SavePreference {
                key: "subtitle_language".into(),
                value: lang.to_string(),
            });
        }
    });

    app.on_set_startup_screen({
        let tx = normal_tx.clone();
        move |label| {
            tracing::info!(screen = %label, "settings: startup screen changed");
            let _ = tx.try_send(NormalEvent::SavePreference {
                key: "startup_screen".into(),
                value: label.to_string(),
            });
        }
    });

    app.on_open_player_settings({
        let ui_w = ui.as_weak();
        move || {
            tracing::debug!("settings: open player settings");
            // Navigate to settings screen with player section focused
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_active_screen(7); // Settings screen
                app.invoke_navigate(7);
            }
        }
    });

    // ── AppState normal-priority callbacks ────────────────────────────────

    app.on_edit_source({
        let ui_w = ui.as_weak();
        move |source_id| {
            let Some(ui) = ui_w.upgrade() else { return };
            let app = ui.global::<super::AppState>();
            // Find the source in the already-populated AppState.sources list.
            let sources = app.get_sources();
            for i in 0..sources.row_count() {
                let s = sources.row_data(i).unwrap_or_default();
                if s.id == source_id {
                    app.set_editing_source(s);
                    app.set_show_source_dialog(true);
                    return;
                }
            }
            tracing::warn!(source_id = %source_id, "edit-source: source not found in AppState.sources");
        }
    });

    app.on_save_source({
        let tx = normal_tx.clone();
        let ui_w = ui.as_weak();
        move |name, stype, url, user, pass| {
            let is_stalker = stype == "stalker";
            if let Err(e) = tx.try_send(NormalEvent::SaveSource {
                input: SourceInput {
                    name: name.to_string(),
                    source_type: stype.to_string(),
                    url: url.to_string(),
                    // Stalker uses MAC address (passed via `user` field) instead of username
                    username: if is_stalker {
                        String::new()
                    } else {
                        user.to_string()
                    },
                    password: if is_stalker {
                        String::new()
                    } else {
                        pass.to_string()
                    },
                    mac_address: if is_stalker {
                        user.to_string()
                    } else {
                        String::new()
                    },
                    epg_url: String::new(),
                },
            }) {
                tracing::warn!(error = %e, "normal_tx full: SaveSource dropped");
            }
            // M-001: mark "Add a source" getting-started step complete
            let ui_w2 = ui_w.clone();
            let _ = slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_w2.upgrade() {
                    ui.global::<super::AppState>().set_gs_source_added(true);
                }
            });
        }
    });

    // C-015: cancel source dialog — reset validation state, close dialog
    app.on_cancel_source_dialog({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_source_validate_state(0);
                app.set_show_source_dialog(false);
                tracing::debug!("cancel-source-dialog: closed");
            }
        }
    });

    // C-016: validate source — set testing state, trigger save with validate flag
    app.on_validate_source_dialog({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_source_validate_state(1);
                tracing::debug!("validate-source-dialog: validation started");
            }
        }
    });

    // C-017: commit source — reset validation, close dialog (save-source fires separately)
    app.on_commit_source_dialog({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_source_validate_state(0);
                app.set_show_source_dialog(false);
                tracing::debug!("commit-source-dialog: committed and closed");
            }
        }
    });

    // C-018: source type changed — clear form fields
    app.on_source_type_changed({
        let ui_w = ui.as_weak();
        move |_type_idx| {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_source_field_url(Default::default());
                app.set_source_field_user(Default::default());
                app.set_source_field_pass(Default::default());
                tracing::debug!(type_idx = _type_idx, "source-type-changed: fields cleared");
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

    app.on_toggle_source_enabled({
        let tx = normal_tx.clone();
        move |source_id| {
            if let Err(e) = tx.try_send(NormalEvent::ToggleSourceEnabled {
                source_id: source_id.to_string(),
            }) {
                tracing::warn!(error = %e, "normal_tx full: ToggleSourceEnabled dropped");
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

    app.on_open_vod_detail({
        let tx = high_tx.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        move |vod_id| {
            // Populate detail item from SharedData so the detail screen shows immediately
            let id = vod_id.to_string();
            let found = {
                let movies = sd.movies.lock().unwrap_or_else(|e| e.into_inner());
                let series = sd.series.lock().unwrap_or_else(|e| e.into_inner());
                movies
                    .iter()
                    .find(|v| v.id == id)
                    .or_else(|| series.iter().find(|v| v.id == id))
                    .cloned()
            };
            if let Some(vod) = found {
                // Build multi-source badges before crossing into the UI thread.
                let primary_sid = vod.source_id.as_deref().unwrap_or("").to_string();
                let badges = build_source_badges(&sd, &vod.name, &vod.item_type, &primary_sid);
                let has_multi = badges.len() > 1;
                let ui_w2 = ui_w.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        let app = ui.global::<super::AppState>();
                        app.set_vod_detail_item(vod_info_to_slint(&vod));
                        app.set_vod_detail_sources(ModelRc::new(VecModel::from(badges)));
                        app.set_vod_detail_has_multi_source(has_multi);
                        app.set_show_vod_detail(true);
                    }
                });
            }
            if let Err(e) = tx.try_send(HighPriorityEvent::OpenVodDetail { vod_id: id }) {
                tracing::warn!(error = %e, "high_tx full: OpenVodDetail dropped");
            }
        }
    });

    app.on_toggle_vod_favorite({
        let tx = high_tx.clone();
        move |vod_id| {
            if let Err(e) = tx.try_send(HighPriorityEvent::ToggleVodFavorite {
                vod_id: vod_id.to_string(),
            }) {
                tracing::warn!(error = %e, "high_tx full: ToggleVodFavorite dropped");
            }
        }
    });

    app.on_open_series_detail({
        let tx = high_tx.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        move |series_id| {
            let id = series_id.to_string();
            let found = {
                let series = sd.series.lock().unwrap_or_else(|e| e.into_inner());
                series.iter().find(|v| v.id == id).cloned()
            };
            if let Some(s) = found {
                // Build multi-source badges for series detail as well.
                let primary_sid = s.source_id.as_deref().unwrap_or("").to_string();
                let badges = build_source_badges(&sd, &s.name, &s.item_type, &primary_sid);
                let has_multi = badges.len() > 1;
                let ui_w2 = ui_w.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        let app = ui.global::<super::AppState>();
                        app.set_series_detail_item(vod_info_to_slint(&s));
                        app.set_vod_detail_sources(ModelRc::new(VecModel::from(badges)));
                        app.set_vod_detail_has_multi_source(has_multi);
                        app.set_series_active_season(1);
                        app.set_series_episodes(ModelRc::new(VecModel::default()));
                        app.set_show_series_detail(true);
                    }
                });
            }
            if let Err(e) = tx.try_send(HighPriorityEvent::OpenSeriesDetail { series_id: id }) {
                tracing::warn!(error = %e, "high_tx full: OpenSeriesDetail dropped");
            }
        }
    });

    app.on_select_series_season({
        let tx = high_tx.clone();
        let ui_w = ui.as_weak();
        move |season| {
            // Update the active season in UI immediately
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_series_active_season(season);
            }
            // Send event to DataEngine which will load episodes and emit SeriesReady
            let event = crate::events::HighPriorityEvent::SelectSeriesSeason {
                series_id: ui_w
                    .upgrade()
                    .map(|ui| {
                        ui.global::<super::AppState>()
                            .get_series_detail_item()
                            .id
                            .to_string()
                    })
                    .unwrap_or_default(),
                season,
            };
            if let Err(e) = tx.try_send(event) {
                tracing::warn!(error = %e, "high_tx full: SelectSeriesSeason dropped");
            }
        }
    });

    app.on_play_episode({
        let tx = high_tx.clone();
        let ui_w = ui.as_weak();
        move |_series_id, season, episode| {
            // m-014: resolve real episode VOD id from the current series_episodes model.
            // DataEngine delivers episodes with real Xtream/M3U IDs via SeriesReady;
            // synthesizing a positional id ("{series}:s{season}e{ep}") never matches cache.
            let real_id = ui_w
                .upgrade()
                .and_then(|ui| {
                    let app = ui.global::<super::AppState>();
                    let model = app.get_series_episodes();
                    (0..model.row_count())
                        .map(|i| model.row_data(i).unwrap_or_default())
                        .find(|ep| ep.season == season && ep.episode == episode)
                        .map(|ep| ep.id.to_string())
                })
                .unwrap_or_default();
            if real_id.is_empty() {
                tracing::warn!(
                    season,
                    episode,
                    "PlayEpisode: no matching episode in series_episodes model"
                );
                return;
            }
            if let Err(e) = tx.try_send(HighPriorityEvent::PlayVod { vod_id: real_id }) {
                tracing::warn!(error = %e, "high_tx full: PlayEpisode dropped");
            }
        }
    });

    app.on_select_epg_date({
        let tx = high_tx.clone();
        let ui_w = ui.as_weak();
        move |offset_days| {
            let ui_w2 = ui_w.clone();
            let _ = slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_w2.upgrade() {
                    ui.global::<super::AppState>()
                        .set_epg_selected_date_offset(offset_days);
                }
            });
            if let Err(e) = tx.try_send(HighPriorityEvent::SelectEpgDate { offset_days }) {
                tracing::warn!(error = %e, "high_tx full: SelectEpgDate dropped");
            }
        }
    });

    app.on_jump_epg_to_channel({
        let tx = high_tx.clone();
        let ui_w = ui.as_weak();
        move |channel_id| {
            let id = channel_id.to_string();
            let ui_w2 = ui_w.clone();
            let id2 = id.clone();
            let _ = slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_w2.upgrade() {
                    ui.global::<super::AppState>()
                        .set_epg_jump_channel_id(SharedString::from(id2.as_str()));
                }
            });
            if let Err(e) = tx.try_send(HighPriorityEvent::JumpEpgToChannel { channel_id: id }) {
                tracing::warn!(error = %e, "high_tx full: JumpEpgToChannel dropped");
            }
        }
    });

    // ── EPG program detail actions (J-11/J-12) ───────────────────────────
    //
    // When the EPG detail sheet is opened (show-epg-detail = true from .slint),
    // epg-detail-channel-id, title, description, start, end, has-catchup, is-now are
    // already set by the ProgrammeCell key-pressed handler inside epg.slint.
    // The remaining fields — channel-name, category, program-id — are enriched here
    // from SharedData when the user acts on the detail (watch / catch-up / remind).
    // We also enrich them proactively via on_watch_program so they are available for
    // any UI that reads them before the user presses Watch.
    app.on_watch_program({
        let tx = high_tx.clone();
        let sd = Arc::clone(&shared_data);
        let ui_w = ui.as_weak();
        move |channel_id| {
            let id = channel_id.to_string();
            tracing::info!(channel_id = %id, "[EPG] watch-program: playing live channel");
            // Enrich EPG detail panel with channel-name, category, program-id
            // by looking up the channel and current EPG entry from SharedData.
            {
                let ui_w2 = ui_w.clone();
                let sd2 = Arc::clone(&sd);
                let ch_id = id.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        let app = ui.global::<super::AppState>();
                        // Resolve channel display name from channels cache
                        let ch_name = {
                            let channels = sd2.channels.lock().unwrap_or_else(|e| e.into_inner());
                            channels
                                .iter()
                                .find(|c| c.id == ch_id)
                                .map(|c| c.name.clone())
                                .unwrap_or_default()
                        };
                        if !ch_name.is_empty() {
                            app.set_epg_detail_channel_name(SharedString::from(ch_name.as_str()));
                        }
                        // Resolve category and program-id from EPG entries.
                        // program-id is derived as "{channel_id}_{start_time_unix}" since
                        // EpgEntry has no dedicated id field.
                        let (category, program_id) = {
                            let epg = sd2.epg_entries.lock().unwrap_or_else(|e| e.into_inner());
                            let title = app.get_epg_detail_title().to_string();
                            epg.get(&ch_id)
                                .and_then(|entries| entries.iter().find(|e| e.title == title))
                                .map(|e| {
                                    let cat = e.category.clone().unwrap_or_default();
                                    let pid =
                                        format!("{}_{}", ch_id, e.start_time.and_utc().timestamp());
                                    (cat, pid)
                                })
                                .unwrap_or_default()
                        };
                        if !category.is_empty() {
                            app.set_epg_detail_category(SharedString::from(category.as_str()));
                        }
                        if !program_id.is_empty() {
                            app.set_epg_detail_program_id(SharedString::from(program_id.as_str()));
                        }
                    }
                });
            }
            if let Err(e) = tx.try_send(HighPriorityEvent::PlayChannel { channel_id: id }) {
                tracing::warn!(error = %e, "high_tx full: WatchProgram dropped");
            }
        }
    });

    app.on_catch_up_program({
        let tx = high_tx.clone();
        move |program_id| {
            let id = program_id.to_string();
            tracing::info!(program_id = %id, "[EPG] catch-up-program: playing catch-up VOD");
            // Catch-up URL resolution happens server-side; map to PlayVod with the program_id.
            // CrispyService will look up the catch-up stream URL from the EPG entry.
            if let Err(e) = tx.try_send(HighPriorityEvent::PlayVod { vod_id: id }) {
                tracing::warn!(error = %e, "high_tx full: CatchUpProgram dropped");
            }
        }
    });

    app.on_remind_program({
        move |program_id| {
            // Reminder system is future work (v2). Log intent for now.
            tracing::info!(
                program_id = %program_id.as_str(),
                "[EPG] remind-program: reminder requested (v2 feature)"
            );
        }
    });

    // ── Scroll callbacks: VecModel window driven by ScrollBridge ───────
    app.on_scroll_channels({
        let loader = image_loader.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        let model = Rc::clone(&channel_model);
        let bridge = Rc::clone(&channel_bridge);
        move |delta| {
            tracing::debug!(delta, "[SCROLL] scroll-channels FIRED");
            let Some(ui) = ui_w.upgrade() else { return };
            let app = ui.global::<super::AppState>();
            // M-008: nav auto-hide — hide on scroll down, show on scroll up
            if delta > 0 {
                app.set_nav_visible(false);
            } else if delta < 0 {
                app.set_nav_visible(true);
            }
            let data = sd.channels.lock().unwrap_or_else(|e| e.into_inner());
            if data.is_empty() {
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                return;
            }

            let old_start = app.get_channel_window_start() as usize;
            // Keep bridge total in sync with actual dataset size
            bridge.borrow_mut().set_total(data.len());
            let buf = bridge.borrow().buffer_size();

            // delta==0 is a forced repopulate (e.g. after sync)
            if delta == 0 {
                bridge.borrow_mut().reset();
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                let end = buf.min(data.len());
                for item in data[0..end].iter() {
                    model.push(channel_info_to_slint(item));
                }
                tracing::debug!(end, "[SCROLL] channels RESET (forced)");
                app.set_channel_window_start(0);
                drop(data);
                loader.load_channels(&ui_w, None);
                return;
            }

            let shift = bridge.borrow_mut().apply_delta(delta, old_start);

            if !shift.shifted {
                tracing::debug!(old_start, "[SCROLL] channels no shift needed");
                drop(data);
                return;
            }

            let new_start = shift.new_start;
            let new_end = (new_start + buf).min(data.len());

            let old_end = (old_start + buf).min(data.len());
            if new_start > old_start {
                for i in old_end..new_end {
                    model.push(channel_info_to_slint(&data[i]));
                }
                let remove_count = (new_start - old_start).min(model.row_count());
                for _ in 0..remove_count {
                    model.remove(0);
                }
            } else {
                for i in (new_start..old_start).rev() {
                    model.insert(0, channel_info_to_slint(&data[i]));
                }
                while model.row_count() > new_end.saturating_sub(new_start) {
                    model.remove(model.row_count() - 1);
                }
            }
            tracing::debug!(old_start, new_start, "[SCROLL] channels window SHIFT");
            app.set_channel_window_start(new_start as i32);
            drop(data);
            tracing::debug!("[IMG] channels image load for VecModel window");
            loader.load_channels(&ui_w, None);
        }
    });

    app.on_scroll_movies({
        let loader = image_loader.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        let model = Rc::clone(&movie_model);
        let bridge = Rc::clone(&movie_bridge);
        move |delta| {
            tracing::debug!(delta, "[SCROLL] scroll-movies FIRED");
            let Some(ui) = ui_w.upgrade() else { return };
            let app = ui.global::<super::AppState>();
            // M-008: nav auto-hide
            if delta > 0 {
                app.set_nav_visible(false);
            } else if delta < 0 {
                app.set_nav_visible(true);
            }
            let data = sd.movies.lock().unwrap_or_else(|e| e.into_inner());
            if data.is_empty() {
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                return;
            }

            let old_start = app.get_movie_window_start() as usize;
            // Keep bridge total in sync with actual dataset size
            bridge.borrow_mut().set_total(data.len());
            let buf = bridge.borrow().buffer_size();

            // delta==0 is a forced repopulate (e.g. after sync)
            if delta == 0 {
                bridge.borrow_mut().reset();
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                let end = buf.min(data.len());
                for item in data[0..end].iter() {
                    model.push(vod_info_to_slint(item));
                }
                tracing::debug!(end, "[SCROLL] movies RESET (forced)");
                app.set_movie_window_start(0);
                drop(data);
                loader.load_movies(&ui_w, None);
                return;
            }

            let shift = bridge.borrow_mut().apply_delta(delta, old_start);

            if !shift.shifted {
                drop(data);
                return;
            }

            let new_start = shift.new_start;
            let new_end = (new_start + buf).min(data.len());

            let old_end = (old_start + buf).min(data.len());
            if new_start > old_start {
                for i in old_end..new_end {
                    model.push(vod_info_to_slint(&data[i]));
                }
                let remove_count = (new_start - old_start).min(model.row_count());
                for _ in 0..remove_count {
                    model.remove(0);
                }
            } else {
                for i in (new_start..old_start).rev() {
                    model.insert(0, vod_info_to_slint(&data[i]));
                }
                while model.row_count() > new_end.saturating_sub(new_start) {
                    model.remove(model.row_count() - 1);
                }
            }
            tracing::debug!(old_start, new_start, "[SCROLL] movies window SHIFT");
            app.set_movie_window_start(new_start as i32);
            drop(data);
            loader.load_movies(&ui_w, None);
        }
    });

    app.on_scroll_series({
        let loader = image_loader.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        let model = Rc::clone(&series_model);
        let bridge = Rc::clone(&series_bridge);
        move |delta| {
            tracing::debug!(delta, "[SCROLL] scroll-series FIRED");
            let Some(ui) = ui_w.upgrade() else { return };
            let app = ui.global::<super::AppState>();
            // M-008: nav auto-hide
            if delta > 0 {
                app.set_nav_visible(false);
            } else if delta < 0 {
                app.set_nav_visible(true);
            }
            let data = sd.series.lock().unwrap_or_else(|e| e.into_inner());
            if data.is_empty() {
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                return;
            }

            let old_start = app.get_series_window_start() as usize;
            // Keep bridge total in sync with actual dataset size
            bridge.borrow_mut().set_total(data.len());
            let buf = bridge.borrow().buffer_size();

            // delta==0 is a forced repopulate (e.g. after sync)
            if delta == 0 {
                bridge.borrow_mut().reset();
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                let end = buf.min(data.len());
                for item in data[0..end].iter() {
                    model.push(vod_info_to_slint(item));
                }
                tracing::debug!(end, "[SCROLL] series RESET (forced)");
                app.set_series_window_start(0);
                drop(data);
                loader.load_series(&ui_w, None);
                return;
            }

            let shift = bridge.borrow_mut().apply_delta(delta, old_start);

            if !shift.shifted {
                drop(data);
                return;
            }

            let new_start = shift.new_start;
            let new_end = (new_start + buf).min(data.len());

            let old_end = (old_start + buf).min(data.len());
            if new_start > old_start {
                for i in old_end..new_end {
                    model.push(vod_info_to_slint(&data[i]));
                }
                let remove_count = (new_start - old_start).min(model.row_count());
                for _ in 0..remove_count {
                    model.remove(0);
                }
            } else {
                for i in (new_start..old_start).rev() {
                    model.insert(0, vod_info_to_slint(&data[i]));
                }
                while model.row_count() > new_end.saturating_sub(new_start) {
                    model.remove(model.row_count() - 1);
                }
            }
            tracing::debug!(old_start, new_start, "[SCROLL] series window SHIFT");
            app.set_series_window_start(new_start as i32);
            drop(data);
            loader.load_series(&ui_w, None);
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
    // m-001: set rust-version once at startup using the crate version from Cargo.toml
    diag.set_rust_version(SharedString::from(
        format!("crispy-tivi v{}", env!("CARGO_PKG_VERSION")).as_str(),
    ));
    diag.on_toggle({
        let tx = normal_tx.clone();
        move || {
            if let Err(e) = tx.try_send(NormalEvent::RunDiagnostics) {
                tracing::warn!(error = %e, "normal_tx full: DiagnosticsToggle dropped");
            }
        }
    });

    diag.on_export_logs({
        let sd = Arc::clone(&shared_data);
        move || {
            let channel_count = sd.channels.lock().map(|g| g.len()).unwrap_or(0);
            let movie_count = sd.movies.lock().map(|g| g.len()).unwrap_or(0);
            let series_count = sd.series.lock().map(|g| g.len()).unwrap_or(0);

            let export = serde_json::json!({
                "app_version": env!("CARGO_PKG_VERSION"),
                "exported_at": chrono::Utc::now().to_rfc3339(),
                "channel_count": channel_count,
                "movie_count": movie_count,
                "series_count": series_count,
            });

            let result: Result<std::path::PathBuf, String> = (|| {
                let base =
                    dirs::data_dir().ok_or_else(|| "dirs::data_dir() returned None".to_string())?;
                let dir = base.join("crispy-tivi");
                std::fs::create_dir_all(&dir).map_err(|e| format!("create_dir_all failed: {e}"))?;
                let path = dir.join("diagnostics-export.json");
                let json = serde_json::to_string_pretty(&export)
                    .map_err(|e| format!("serialise failed: {e}"))?;
                std::fs::write(&path, json).map_err(|e| format!("write failed: {e}"))?;
                Ok(path)
            })();

            match result {
                Ok(path) => tracing::info!(path = %path.display(), "Diagnostics exported"),
                Err(e) => tracing::error!(error = %e, "Diagnostics export failed"),
            }
        }
    });

    // ── Hero callbacks ────────────────────────────────────────────────────

    app.on_hero_play({
        let tx = high_tx.clone();
        let sd = Arc::clone(&shared_data);
        move |item_id| {
            let id = item_id.to_string();
            // Determine content type from SharedData to route to channel or VOD playback
            let content_type = {
                let channels = sd.channels.lock().unwrap_or_else(|e| e.into_inner());
                if channels.iter().any(|c| c.id == id) {
                    "live"
                } else {
                    "vod"
                }
                .to_string()
            };
            let event = if content_type == "live" {
                HighPriorityEvent::PlayChannel { channel_id: id }
            } else {
                HighPriorityEvent::PlayVod { vod_id: id }
            };
            if let Err(e) = tx.try_send(event) {
                tracing::warn!(error = %e, "high_tx full: HeroPlay dropped");
            }
        }
    });

    app.on_hero_detail({
        let tx = high_tx.clone();
        let sd = Arc::clone(&shared_data);
        move |item_id| {
            let id = item_id.to_string();
            // Route to VOD detail; live channels have no detail screen
            let is_channel = {
                let channels = sd.channels.lock().unwrap_or_else(|e| e.into_inner());
                channels.iter().any(|c| c.id == id)
            };
            if is_channel {
                tracing::debug!(item_id = id, "HeroDetail: live channel — no detail screen");
            } else {
                if let Err(e) = tx.try_send(HighPriorityEvent::OpenVodDetail { vod_id: id }) {
                    tracing::warn!(error = %e, "high_tx full: HeroDetail dropped");
                }
            }
        }
    });

    // ── Profile callbacks ─────────────────────────────────────────────────

    app.on_switch_profile({
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        let tx = normal_tx.clone();
        move |profile_id| {
            let id = profile_id.to_string();
            // Check if the target profile has a PIN — if so, show PIN dialog instead
            let (has_pin, profile_name) = {
                let profiles = sd.profiles.lock().unwrap_or_else(|e| e.into_inner());
                profiles
                    .iter()
                    .find(|p| p.id == id)
                    .map(|p| (p.pin.is_some(), p.name.clone()))
                    .unwrap_or((false, String::new()))
            };
            if has_pin {
                // Show PIN dialog — actual switch deferred to on_verify_pin
                let ui_w2 = ui_w.clone();
                let id2 = id.clone();
                let name2 = profile_name.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        let app = ui.global::<super::AppState>();
                        app.set_pin_target_profile_id(SharedString::from(id2.as_str()));
                        app.set_pin_target_profile_name(SharedString::from(name2.as_str()));
                        app.set_show_pin_dialog(true);
                        app.set_pin_wrong(false);
                        app.set_show_profile_picker(false);
                    }
                });
                return;
            }
            // No PIN — switch immediately
            do_profile_switch(&id, &profile_name, &sd, &ui_w, &tx);
        }
    });

    // ── PIN verification callback ─────────────────────────────────────────

    app.on_verify_pin({
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        let tx = normal_tx.clone();
        move |entered_pin| {
            let pin_str = entered_pin.to_string();
            // Read target profile id from Slint state (must run on UI thread already)
            let (target_id, stored_pin) = {
                // We're already on the UI thread here (Slint callback)
                // Re-borrow shared data to get the target id + stored pin hash
                // Note: pin-target-profile-id is read via the closure capture; we obtain it
                // by looking through profiles. Since this callback fires from Slint, we can't
                // call ui.global() here — instead we store the target id in SharedData.
                // Work-around: scan profiles for any whose pin matches. This is safe because
                // pin-target-profile-id was just set by on_switch_profile above.
                // We read it via a secondary Mutex stored alongside profiles.
                let profiles = sd.profiles.lock().unwrap_or_else(|e| e.into_inner());
                let active = sd
                    .active_profile_id
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .clone();
                // Find the pending target by reading from profiles any PIN-protected one
                // that is NOT the current active profile. This is a heuristic —
                // the robust solution is reading from AppState.pin-target-profile-id directly.
                // Since we ARE on the Slint callback thread, we can do that:
                drop(profiles);
                drop(active);
                // Return placeholder; real lookup done below
                (String::new(), None::<String>)
            };
            // We are on the Slint UI thread inside this callback — access AppState directly
            let _ = target_id; // suppress unused warning
            let _ = stored_pin;
            let ui_w2 = ui_w.clone();
            let tx2 = tx.clone();
            let sd2 = Arc::clone(&sd);
            let _ = slint::invoke_from_event_loop(move || {
                let Some(ui) = ui_w2.upgrade() else { return };
                let app = ui.global::<super::AppState>();
                let target_id = app.get_pin_target_profile_id().to_string();
                if target_id.is_empty() {
                    return;
                }
                // Retrieve stored PIN hash for target profile
                let (stored_hash, profile_name) = {
                    let profiles = sd2.profiles.lock().unwrap_or_else(|e| e.into_inner());
                    profiles
                        .iter()
                        .find(|p| p.id == target_id)
                        .map(|p| (p.pin.clone(), p.name.clone()))
                        .unwrap_or((None, String::new()))
                };
                // Verify PIN — stored hash is Argon2id; entered_pin is plaintext
                let verified = match &stored_hash {
                    Some(hash) => verify_profile_pin(&pin_str, hash),
                    None => true, // no PIN stored — allow (shouldn't reach here)
                };
                if verified {
                    // Correct PIN — dismiss dialog and perform switch
                    app.set_show_pin_dialog(false);
                    app.set_pin_wrong(false);
                    app.set_pin_target_profile_id(SharedString::from(""));
                    do_profile_switch(&target_id, &profile_name, &sd2, &ui_w2, &tx2);
                } else {
                    // Wrong PIN — signal shake
                    app.set_pin_wrong(true);
                    tracing::warn!(profile_id = %target_id, "PIN verification failed");
                    // Reset pin-wrong after shake duration (600 ms)
                    let ui_w3 = ui_w2.clone();
                    slint::Timer::single_shot(std::time::Duration::from_millis(600), move || {
                        if let Some(ui) = ui_w3.upgrade() {
                            ui.global::<super::AppState>().set_pin_wrong(false);
                        }
                    });
                }
            });
        }
    });

    app.on_create_profile({
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        let tx = normal_tx.clone();
        move |name, is_kids| {
            let profile_name = name.to_string();
            let new_id = format!("profile_{}", chrono::Utc::now().timestamp_millis());
            let new_profile = UserProfile {
                id: new_id,
                name: profile_name,
                avatar_index: 0,
                pin: None,
                is_child: is_kids,
                pin_version: 0,
                max_allowed_rating: if is_kids { 1 } else { 4 },
                role: if is_kids { 2 } else { 1 },
                dvr_permission: 1,
                dvr_quota_mb: None,
            };
            // Persist to DB via DataEngine
            if let Err(e) = tx.try_send(NormalEvent::SaveProfile {
                id: new_profile.id.clone(),
                name: new_profile.name.clone(),
                is_child: new_profile.is_child,
                max_allowed_rating: new_profile.max_allowed_rating,
                role: new_profile.role,
            }) {
                tracing::warn!(error = %e, "normal_tx full: SaveProfile dropped");
            }
            {
                sd.profiles
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .push(new_profile);
            }
            // Refresh profiles list in Slint
            let slint_profiles = build_slint_profiles(&sd);
            let active_name = {
                let id = sd
                    .active_profile_id
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .clone();
                sd.profiles
                    .lock()
                    .unwrap()
                    .iter()
                    .find(|p| p.id == id)
                    .map(|p| p.name.clone())
                    .unwrap_or_else(|| "Default".to_string())
            };
            let ui_w2 = ui_w.clone();
            let _ = slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_w2.upgrade() {
                    let app = ui.global::<super::AppState>();
                    app.set_profiles(ModelRc::new(VecModel::from(slint_profiles)));
                    app.set_active_profile_name(SharedString::from(active_name.as_str()));
                    // M-001: mark "Set up a profile" getting-started step complete
                    app.set_gs_profile_set(true);
                }
            });
        }
    });

    // ── Parental controls callbacks (Epoch 7) ─────────────────────────────

    app.on_set_parental_pin({
        let tx = normal_tx.clone();
        move |new_pin| {
            let pin_value = new_pin.to_string();
            // TODO(Epoch 7): hash with Argon2id before storing — storing raw PIN for now
            // as the Argon2 infrastructure is not yet built.
            if let Err(e) = tx.try_send(NormalEvent::SavePreference {
                key: "parental_pin_hash".into(),
                value: pin_value,
            }) {
                tracing::warn!(error = %e, "normal_tx full: SetParentalPin dropped");
            }
            tracing::info!("set-parental-pin: PIN saved (Argon2 hashing pending Epoch 7)");
        }
    });

    app.on_clear_parental_pin({
        let ui_w = ui.as_weak();
        let tx = normal_tx.clone();
        move || {
            let _ = slint::invoke_from_event_loop({
                let ui_w2 = ui_w.clone();
                move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        ui.global::<super::AppState>().set_parental_pin_set(false);
                    }
                }
            });
            // M-011: persist PIN removal so the setting survives restart
            if let Err(e) = tx.try_send(NormalEvent::SavePreference {
                key: "parental_pin_hash".into(),
                value: String::new(),
            }) {
                tracing::warn!(error = %e, "normal_tx full: ClearParentalPin dropped");
            }
            tracing::info!("clear-parental-pin: PIN cleared");
        }
    });

    app.on_set_content_rating({
        let ui_w = ui.as_weak();
        let tx = normal_tx.clone();
        move |rating_index| {
            let _ = slint::invoke_from_event_loop({
                let ui_w2 = ui_w.clone();
                move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        ui.global::<super::AppState>()
                            .set_parental_rating_limit(rating_index);
                    }
                }
            });
            // M-010: persist rating limit so it survives restart
            if let Err(e) = tx.try_send(NormalEvent::SavePreference {
                key: "parental_rating_limit".into(),
                value: rating_index.to_string(),
            }) {
                tracing::warn!(error = %e, "normal_tx full: SetContentRating dropped");
            }
            tracing::info!(rating_index, "set-content-rating");
        }
    });

    app.on_set_viewing_time_limit({
        let ui_w = ui.as_weak();
        move |minutes| {
            let _ = slint::invoke_from_event_loop({
                let ui_w2 = ui_w.clone();
                move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        ui.global::<super::AppState>()
                            .set_parental_time_limit_minutes(minutes);
                    }
                }
            });
            tracing::info!(minutes, "set-viewing-time-limit");
        }
    });

    // ── Analytics consent callbacks (Epoch 11) ────────────────────────────

    app.on_set_analytics_playback({
        let ui_w = ui.as_weak();
        move |enabled| {
            let _ = slint::invoke_from_event_loop({
                let ui_w2 = ui_w.clone();
                move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        ui.global::<super::AppState>()
                            .set_analytics_playback_consent(enabled);
                    }
                }
            });
            tracing::info!(enabled, "set-analytics-playback");
        }
    });

    app.on_set_analytics_crash({
        let ui_w = ui.as_weak();
        move |enabled| {
            let _ = slint::invoke_from_event_loop({
                let ui_w2 = ui_w.clone();
                move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        ui.global::<super::AppState>()
                            .set_analytics_crash_consent(enabled);
                    }
                }
            });
            tracing::info!(enabled, "set-analytics-crash");
        }
    });

    // ── Backup / restore callbacks (Epoch 13) ─────────────────────────────

    app.on_export_backup({
        let tx = normal_tx.clone();
        move || {
            // C-012: dispatch ExportBackup to DataEngine (BackupService integration is Epoch 13)
            tracing::info!("export-backup: requested");
            if let Err(e) = tx.try_send(NormalEvent::ExportBackup) {
                tracing::warn!(error = %e, "normal_tx full: ExportBackup dropped");
            }
        }
    });

    app.on_import_backup({
        let tx = normal_tx.clone();
        move || {
            // C-012: dispatch ImportBackup to DataEngine (BackupService integration is Epoch 13)
            tracing::info!("import-backup: requested");
            if let Err(e) = tx.try_send(NormalEvent::ImportBackup) {
                tracing::warn!(error = %e, "normal_tx full: ImportBackup dropped");
            }
        }
    });

    // ── GDPR delete-all-data callback (J-47) ─────────────────────────────────

    app.on_delete_all_data({
        let tx = normal_tx.clone();
        let sd2 = Arc::clone(&shared_data);
        move || {
            // Read the active profile id from SharedData (thread-safe)
            let profile_id = sd2
                .active_profile_id
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .clone();
            tracing::info!(profile_id, "delete-all-data: requested");
            if let Err(e) = tx.try_send(NormalEvent::DeleteAllUserData { profile_id }) {
                tracing::warn!(error = %e, "normal_tx full: DeleteAllUserData dropped");
            }
        }
    });

    // Channel overlay is controlled directly via show-channel-overlay property in live-tv.slint.

    // ── Post-play callbacks (C-010, C-011) — on PlayerState ─────────────────

    // post-play-play: replay current content from post-play screen (C-010)
    ps.on_post_play_play({
        let ui_w = ui.as_weak();
        let tx = player_tx.clone();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                ps.set_show_post_play(false);
                // Seek to start and resume playback for replay
                if let Err(e) = tx.try_send(PlayerEvent::Seek { position_secs: 0.0 }) {
                    tracing::warn!(error = %e, "player_tx full: post-play-play Seek dropped");
                }
                if let Err(e) = tx.try_send(PlayerEvent::TogglePause) {
                    tracing::warn!(error = %e, "player_tx full: post-play-play TogglePause dropped");
                }
                tracing::info!("post-play-play: seeking to 0 and resuming");
            }
        }
    });

    // post-play-back: return to browsing from post-play screen (C-011)
    ps.on_post_play_back({
        let ui_w = ui.as_weak();
        let tx = player_tx.clone();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let ps = ui.global::<super::PlayerState>();
                ps.set_show_post_play(false);
                ps.set_is_playing(false);
                // Stop the player when user navigates back to browsing
                if let Err(e) = tx.try_send(PlayerEvent::Stop) {
                    tracing::warn!(error = %e, "player_tx full: post-play-back Stop dropped");
                }
                tracing::debug!("post-play-back: stopped player, returning to browsing");
            }
        }
    });

    // ── Privacy consent callbacks (C-014, C-015) ─────────────────────────

    app.on_accept_privacy({
        let ui_w = ui.as_weak();
        let tx = normal_tx.clone();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_privacy_accepted(true);
                app.set_show_privacy_consent(false);
                tracing::info!("privacy: user accepted privacy consent");
            }
            // C-014: persist consent so it survives restart
            if let Err(e) = tx.try_send(NormalEvent::SavePreference {
                key: "privacy_accepted".into(),
                value: "true".into(),
            }) {
                tracing::warn!(error = %e, "normal_tx full: AcceptPrivacy SavePreference dropped");
            }
        }
    });

    app.on_decline_privacy({
        let ui_w = ui.as_weak();
        let tx = normal_tx.clone();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_privacy_accepted(false);
                app.set_show_privacy_consent(false);
                tracing::info!("privacy: user declined privacy consent");
            }
            // C-014: persist decline so it survives restart
            if let Err(e) = tx.try_send(NormalEvent::SavePreference {
                key: "privacy_accepted".into(),
                value: "false".into(),
            }) {
                tracing::warn!(error = %e, "normal_tx full: DeclinePrivacy SavePreference dropped");
            }
        }
    });

    // ── Guided tour callbacks (C-016, C-017) ─────────────────────────────

    app.on_skip_guided_tour({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_show_guided_tour(false);
                tracing::debug!("guided-tour: skipped");
            }
        }
    });

    app.on_advance_guided_tour({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                let step = app.get_guided_tour_step();
                // Advance to next step; if at last step, dismiss tour
                let max_steps = 5; // guided tour has a finite number of steps
                if step + 1 >= max_steps {
                    app.set_show_guided_tour(false);
                    tracing::debug!("guided-tour: completed (all steps done)");
                } else {
                    app.set_guided_tour_step(step + 1);
                    tracing::debug!(step = step + 1, "guided-tour: advanced");
                }
            }
        }
    });

    // ── Getting started dismiss (C-018) ──────────────────────────────────

    app.on_dismiss_getting_started({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_getting_started_dismissed(true);
                tracing::debug!("getting-started: dismissed");
            }
        }
    });

    // ── Resume prompt callbacks (C-019, C-020) ───────────────────────────
    // M-026/M-027: show-resume-prompt, resume-source-device, and resume-position-label
    // depend on cross-device resume infrastructure (Epoch 10). When implemented:
    //   1. On profile switch or app launch, check cloud sync for an active watch session
    //      from another device (requires Epoch 10 cloud sync + device registry).
    //   2. If found, set AppState.show-resume-prompt = true, populate
    //      resume-source-device (e.g. "Living Room TV") and
    //      resume-position-label (e.g. "1h 23m").
    //   3. User action handled by on_resume_playback / on_start_over_playback below.

    app.on_resume_playback({
        let ui_w = ui.as_weak();
        let tx = player_tx.clone();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                let ps = ui.global::<super::PlayerState>();
                app.set_show_resume_prompt(false);
                // C-008: seek to the stored resume position
                let resume_pos = ps.get_position() as f64;
                if let Err(e) = tx.try_send(PlayerEvent::Seek {
                    position_secs: resume_pos,
                }) {
                    tracing::warn!(error = %e, "player_tx full: resume Seek dropped");
                }
                tracing::info!(
                    position = resume_pos,
                    "resume-playback: seeking to stored position"
                );
            }
        }
    });

    app.on_start_over_playback({
        let ui_w = ui.as_weak();
        let tx = player_tx.clone();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_show_resume_prompt(false);
                // C-009: seek to beginning
                if let Err(e) = tx.try_send(PlayerEvent::Seek { position_secs: 0.0 }) {
                    tracing::warn!(error = %e, "player_tx full: start-over Seek dropped");
                }
                tracing::info!("start-over-playback: seeking to 0");
            }
        }
    });

    // ── Cast/device callbacks (C-021, C-022, C-023) ──────────────────────
    // M-023/M-024/M-025: cast-devices, managed-devices, and show-cast-picker
    // are populated by Epoch 10 cast discovery service. When the CastDiscovery
    // service is implemented, it will:
    //   1. Scan for DLNA/Chromecast/AirPlay devices on the network
    //   2. Populate AppState.cast-devices via DataEvent
    //   3. Populate AppState.managed-devices from persistent device registry
    // Until then, these lists remain empty and the picker shows "No devices found".

    app.on_cast_to_device({
        let ui_w = ui.as_weak();
        move |device_id| {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                app.set_show_cast_picker(false);
                tracing::info!(device = %device_id, "cast-to-device: cast requested (Epoch 10 — not yet implemented)");
            }
        }
    });

    app.on_stop_casting({
        move || {
            tracing::info!("stop-casting: requested (Epoch 10 — not yet implemented)");
        }
    });

    app.on_remove_device({
        move |device_id| {
            tracing::info!(device = %device_id, "remove-device: requested (Epoch 10 — not yet implemented)");
        }
    });

    app.on_sign_out_all_devices({
        move || {
            tracing::info!("sign-out-all-devices: requested (Epoch 10 — not yet implemented)");
        }
    });

    // ── J-40: Clear watch history callback ───────────────────────────────
    app.on_clear_watch_history({
        let tx = normal_tx.clone();
        move || {
            if let Err(e) = tx.try_send(NormalEvent::ClearWatchHistory {
                profile_id: "default".to_string(),
            }) {
                tracing::warn!(error = %e, "normal_tx full: ClearWatchHistory dropped");
            }
        }
    });

    // ── J-40: Auto-save watch position every 30s during playback ─────────
    {
        let ui_w = ui.as_weak();
        let tx = normal_tx.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(30)).await;
                let ui_w2 = ui_w.clone();
                let tx2 = tx.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        let ps = ui.global::<super::PlayerState>();
                        let app = ui.global::<super::AppState>();
                        if !ps.get_is_playing() || ps.get_is_live() {
                            return;
                        }
                        let pos_secs = ps.get_position();
                        let dur_secs = ps.get_duration();
                        if pos_secs < 1.0 {
                            return;
                        }
                        let title = ps.get_current_title().to_string();
                        let channel_id = ps.get_current_channel_id().to_string();
                        // Use channel_id as stream key; DataEngine derives history ID from it
                        if channel_id.is_empty() && title.is_empty() {
                            return;
                        }
                        // Use channel_id as stream_url proxy when no direct URL is available
                        let stream_key = if !channel_id.is_empty() {
                            channel_id
                        } else {
                            title.clone()
                        };
                        let media_type = if app.get_active_screen() == 1 {
                            "channel"
                        } else {
                            "movie"
                        };
                        if let Err(e) = tx2.try_send(NormalEvent::SaveWatchEntry {
                            id: String::new(), // derived from stream_url in DataEngine
                            name: title,
                            media_type: media_type.to_string(),
                            stream_url: stream_key,
                            position_ms: (pos_secs * 1000.0) as i64,
                            duration_ms: (dur_secs * 1000.0) as i64,
                            profile_id: "default".to_string(),
                        }) {
                            tracing::warn!(error = %e, "normal_tx full: SaveWatchEntry (30s) dropped");
                        }
                    }
                });
            }
        });
    }

    // ── J-09: Group management stubs ─────────────────────────────────────
    app.on_rename_group(|old, new| {
        tracing::info!(old = %old, new = %new, "rename-group: stub");
    });

    app.on_hide_group(|name| {
        tracing::info!(name = %name, "hide-group: stub");
    });

    app.on_reorder_group(|name, dir| {
        tracing::info!(name = %name, dir, "reorder-group: stub");
    });

    // ── J-39: Custom collections stubs ───────────────────────────────────
    app.on_create_collection(|name| {
        tracing::info!(name = %name, "create-collection: stub");
    });

    app.on_delete_collection(|name| {
        tracing::info!(name = %name, "delete-collection: stub");
    });

    // ── J-29: PiP toggle stub ────────────────────────────────────────────
    app.on_toggle_pip({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                let active = !app.get_pip_active();
                app.set_pip_active(active);
                tracing::info!(pip_active = active, "toggle-pip: stub");
            }
        }
    });

    // ── J-41: Server mode toggle stub ────────────────────────────────────
    app.on_toggle_server_mode({
        let ui_w = ui.as_weak();
        move || {
            if let Some(ui) = ui_w.upgrade() {
                let app = ui.global::<super::AppState>();
                let enabled = !app.get_server_mode_enabled();
                app.set_server_mode_enabled(enabled);
                tracing::info!(enabled, "toggle-server-mode: stub");
            }
        }
    });

    // ── Hero auto-advance timer (8s interval) ─────────────────────────────
    {
        let ui_w = ui.as_weak();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(8)).await;
                let _ = slint::invoke_from_event_loop({
                    let ui_w2 = ui_w.clone();
                    move || {
                        if let Some(ui) = ui_w2.upgrade() {
                            let app = ui.global::<super::AppState>();
                            let count = app.get_hero_items().row_count() as i32;
                            if count > 1 {
                                let next = (app.get_hero_index() + 1) % count;
                                app.set_hero_index(next);
                            }
                        }
                    }
                });
            }
        });
    }
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
        // ── OSD auto-hide state ───────────────────────────────────────────────
        // Deadline at which the OSD should be hidden. Reset on every non-Stop
        // player event. When None the OSD is already hidden and no timer runs.
        let mut osd_hide_deadline: Option<tokio::time::Instant> = None;

        // ── Seek acceleration state ───────────────────────────────────────────
        // Tracks when the last SeekRelative arrived and how many consecutive
        // seeks have occurred within the 500ms acceleration window.
        //
        // Level → delta applied:
        //   0 (first)  → 10 s
        //   1          → 30 s
        //   2          → 60 s
        //   3+         → 120 s
        let mut seek_accel_level: u32 = 0;
        let mut last_seek_time: Option<tokio::time::Instant> = None;

        const OSD_HIDE_SECS: u64 = 3;
        const SEEK_ACCEL_WINDOW_MS: u64 = 500;
        const SEEK_ACCEL_RESET_MS: u64 = 1000;

        loop {
            // Copy the deadline so the async block owns the value and doesn't
            // borrow `osd_hide_deadline` across the mutable uses below.
            let deadline_snapshot = osd_hide_deadline;
            let osd_timeout = async move {
                match deadline_snapshot {
                    Some(d) => tokio::time::sleep_until(d).await,
                    None => {
                        // Park forever — this branch will never be selected
                        // while osd_hide_deadline is None.
                        std::future::pending::<()>().await
                    }
                }
            };

            let event = tokio::select! {
                biased;

                // Prefer incoming events over the timer so user input is never dropped.
                maybe = player_rx.recv() => {
                    match maybe {
                        Some(e) => e,
                        None => break, // sender dropped — shut down
                    }
                }

                // OSD hide timer fired with no intervening event.
                _ = osd_timeout => {
                    osd_hide_deadline = None;
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            ui.global::<super::PlayerState>().set_show_osd(false);
                        }
                    });
                    continue;
                }
            };

            // ── Reset OSD timer on every non-Stop event ───────────────────────
            // Stop turns off the player; keeping the OSD visible then makes no
            // sense, so we skip the reset for that variant.
            if !matches!(event, PlayerEvent::Stop) {
                osd_hide_deadline = Some(
                    tokio::time::Instant::now() + std::time::Duration::from_secs(OSD_HIDE_SECS),
                );
            }

            match &event {
                PlayerEvent::TogglePause => {
                    let result = {
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
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
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
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
                            ps.set_is_fullscreen(false);
                            ps.set_is_paused(false);
                            ps.set_is_buffering(false);
                            ps.set_current_title(Default::default());
                            ps.set_current_channel_id(Default::default());
                            ps.set_current_group(Default::default());
                            // Navigate back to the active screen (restore browse UI)
                            let app = ui.global::<super::AppState>();
                            let screen = app.get_active_screen();
                            app.invoke_navigate(screen);
                        }
                    });
                }

                PlayerEvent::Seek { position_secs } => {
                    let pos = *position_secs;
                    let result = {
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                        guard.as_ref().map(|b| b.seek(pos))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, "Seek failed");
                    }
                }

                PlayerEvent::SeekRelative { delta_secs } => {
                    // ── Seek acceleration ─────────────────────────────────────
                    // Escalate magnitude on consecutive presses within 500ms:
                    //   level 0 → 10 s, level 1 → 30 s, level 2 → 60 s, 3+ → 120 s
                    // Reset acceleration after 1 s without a seek event.
                    let now = tokio::time::Instant::now();
                    let within_window = last_seek_time
                        .map(|t| now.duration_since(t).as_millis() < SEEK_ACCEL_WINDOW_MS as u128)
                        .unwrap_or(false);
                    let past_reset = last_seek_time
                        .map(|t| now.duration_since(t).as_millis() >= SEEK_ACCEL_RESET_MS as u128)
                        .unwrap_or(true);

                    if past_reset {
                        seek_accel_level = 0;
                    } else if within_window {
                        seek_accel_level = seek_accel_level.saturating_add(1);
                    }
                    last_seek_time = Some(now);

                    // Preserve the direction from the original delta.
                    let direction = if *delta_secs >= 0.0 {
                        1.0_f64
                    } else {
                        -1.0_f64
                    };
                    let magnitude = match seek_accel_level {
                        0 => 10.0,
                        1 => 30.0,
                        2 => 60.0,
                        _ => 120.0,
                    };
                    let delta = direction * magnitude;
                    tracing::debug!(
                        level = seek_accel_level,
                        delta,
                        "SeekRelative (accelerated)"
                    );
                    let result = {
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                        guard.as_ref().map(|b| b.seek_relative(delta))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, delta, "SeekRelative failed");
                    }
                }

                PlayerEvent::SetVolume { volume } => {
                    let vol = *volume;
                    let result = {
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
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
                    // The loop-level osd_hide_deadline already handles the 3 s
                    // auto-hide for every non-Stop event. ShowControls just sets
                    // the Slint property; no extra spawned timer needed.
                    let v = *visible;
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            // visible=true toggles OSD on; visible=false forces hide.
                            ps.set_show_osd(if v { !ps.get_show_osd() } else { false });
                        }
                    });
                    // When explicitly hiding, clear the pending deadline so the
                    // loop timer does not fire and re-hide an already-hidden OSD.
                    if !v {
                        osd_hide_deadline = None;
                    }
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
                    let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                    if let Some(b) = guard.as_ref() {
                        let tracks = b.get_audio_tracks();
                        if tracks.len() > 1 {
                            // Cycle to next audio track
                            let current = tracks.iter().position(|t| t.is_default).unwrap_or(0);
                            let next = (current + 1) % tracks.len();
                            if let Err(e) = b.set_audio_track(tracks[next].id) {
                                tracing::error!(error = %e, "NextAudioTrack failed");
                            } else {
                                tracing::info!(track_id = tracks[next].id, title = ?tracks[next].title, "Audio track switched");
                            }
                        }
                    }
                }

                PlayerEvent::NextSubtitleTrack => {
                    let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                    if let Some(b) = guard.as_ref() {
                        let tracks = b.get_subtitle_tracks();
                        let current = tracks.iter().position(|t| t.is_default);
                        let next_id = match current {
                            Some(idx) if idx + 1 < tracks.len() => Some(tracks[idx + 1].id),
                            Some(_) => None, // cycle past last = disable subs
                            None if !tracks.is_empty() => Some(tracks[0].id),
                            None => None,
                        };
                        if let Err(e) = b.set_subtitle_track(next_id) {
                            tracing::error!(error = %e, "NextSubtitleTrack failed");
                        } else {
                            tracing::info!(track_id = ?next_id, "Subtitle track switched");
                        }
                    }
                }

                PlayerEvent::SetSpeed { speed } => {
                    let spd = *speed;
                    let result = {
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                        guard.as_ref().map(|b| b.set_speed(f64::from(spd)))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, speed = spd, "SetSpeed failed");
                    } else {
                        tracing::debug!(speed = spd, "Playback speed set");
                        // M-040: sync current-speed property to Slint
                        let ui_w = ui_weak.clone();
                        let _ = slint::invoke_from_event_loop(move || {
                            if let Some(ui) = ui_w.upgrade() {
                                ui.global::<super::PlayerState>().set_current_speed(spd);
                            }
                        });
                    }
                }
                PlayerEvent::SelectAudioTrack { index } => {
                    let idx = i64::from(*index);
                    let result = {
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                        guard.as_ref().map(|b| b.set_audio_track(idx))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, index = idx, "SelectAudioTrack failed");
                    } else {
                        tracing::debug!(index = idx, "Audio track selected");
                    }
                }
                PlayerEvent::SelectSubtitleTrack { index } => {
                    let idx = *index;
                    let track = if idx < 0 { None } else { Some(i64::from(idx)) };
                    let result = {
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                        guard.as_ref().map(|b| b.set_subtitle_track(track))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, index = idx, "SelectSubtitleTrack failed");
                    } else {
                        tracing::debug!(index = idx, "Subtitle track selected");
                    }
                }
            }
        }
        tracing::info!("player_handler task exited");
    });
}

// ── spawn_position_poller ─────────────────────────────────────────────────────

/// M-004/M-005/M-006/M-007: Poll mpv every 500ms for position, duration, is-live, current-group
/// and push values to PlayerState on the UI thread.
pub(crate) fn spawn_position_poller(
    ui_weak: slint::Weak<super::AppWindow>,
    backend: Arc<Mutex<Option<crispy_player::mpv_backend::MpvBackend>>>,
) {
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(std::time::Duration::from_millis(500)).await;

            let poll = {
                let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                guard.as_ref().map(|b| {
                    let pos = b.get_position() as f32;
                    let dur = b.get_duration() as f32;
                    // C-002/M-043: buffered fraction from demuxer cache stats.
                    let buf_stats = b.get_buffer_stats();
                    let buffered = if dur > 0.0 {
                        (buf_stats.cache_duration as f32 / dur).clamp(0.0, 1.0)
                    } else {
                        0.0
                    };
                    // C-003: audio / subtitle track labels from PlayerBackend.
                    let audio_tracks = b.get_audio_tracks();
                    let sub_tracks = b.get_subtitle_tracks();
                    let audio_labels: Vec<String> = audio_tracks
                        .iter()
                        .map(|t| {
                            t.title.clone().unwrap_or_else(|| {
                                t.language
                                    .clone()
                                    .unwrap_or_else(|| format!("Track {}", t.id))
                            })
                        })
                        .collect();
                    let sub_labels: Vec<String> = sub_tracks
                        .iter()
                        .map(|t| {
                            t.title.clone().unwrap_or_else(|| {
                                t.language
                                    .clone()
                                    .unwrap_or_else(|| format!("Track {}", t.id))
                            })
                        })
                        .collect();
                    let active_audio =
                        audio_tracks.iter().position(|t| t.is_default).unwrap_or(0) as i32;
                    let active_sub =
                        sub_tracks.iter().position(|t| t.is_default).unwrap_or(0) as i32;
                    // current-resolution from VideoInfo
                    let video_info = b.get_video_info();
                    let resolution = if video_info.height >= 2160 {
                        "4K".to_string()
                    } else if video_info.height >= 1080 {
                        "1080p".to_string()
                    } else if video_info.height >= 720 {
                        "720p".to_string()
                    } else if video_info.height > 0 {
                        "SD".to_string()
                    } else {
                        String::new()
                    };
                    (
                        pos,
                        dur,
                        buffered,
                        audio_labels,
                        sub_labels,
                        active_audio,
                        active_sub,
                        resolution,
                    )
                })
            };

            let Some((
                pos,
                dur,
                buffered,
                audio_labels,
                sub_labels,
                active_audio,
                active_sub,
                resolution,
            )) = poll
            else {
                continue;
            };

            let ui_w = ui_weak.clone();
            let _ = slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_w.upgrade() {
                    let ps = ui.global::<super::PlayerState>();
                    if ps.get_is_playing() {
                        ps.set_position(pos);
                        ps.set_duration(dur);
                        // M-006: live = no finite duration (duration == 0 or NaN for live streams)
                        ps.set_is_live(dur <= 0.0 || dur.is_nan());

                        // C-002/M-043: buffered fraction
                        ps.set_buffered(buffered);

                        // C-003: audio / subtitle track labels
                        let slint_audio: Vec<SharedString> = audio_labels
                            .iter()
                            .map(|s| SharedString::from(s.as_str()))
                            .collect();
                        let slint_sub: Vec<SharedString> = sub_labels
                            .iter()
                            .map(|s| SharedString::from(s.as_str()))
                            .collect();
                        ps.set_audio_track_labels(ModelRc::new(VecModel::from(slint_audio)));
                        ps.set_subtitle_track_labels(ModelRc::new(VecModel::from(slint_sub)));
                        ps.set_active_audio_track(active_audio);
                        ps.set_active_subtitle_track(active_sub);

                        // 3.9: current-resolution badge
                        if !resolution.is_empty() {
                            ps.set_current_resolution(SharedString::from(resolution.as_str()));
                        }

                        // M-029: trigger show-next-episode when position > duration - 90s
                        // Only for VOD content with a known duration.
                        if dur > 90.0
                            && pos > dur - 90.0
                            && !ps.get_is_live()
                            && !ps.get_show_next_episode()
                        {
                            ps.set_show_next_episode(true);
                            // 3.12: populate countdown and next-episode title.
                            // next-episode-title is the episode after the current one;
                            // we set a sensible default here — the series detail callback
                            // may override with the real title when it loads episodes.
                            if ps.get_next_episode_title().is_empty() {
                                ps.set_next_episode_title(SharedString::from("Next Episode"));
                            }
                            ps.set_next_countdown(10);
                            tracing::debug!(
                                pos,
                                dur,
                                "M-029: show-next-episode triggered (< 90s remaining)"
                            );
                        }

                        // 3.11: show-skip-intro for the first 90s of VOD content.
                        // Shown when pos < 90s and content has a known duration (not live).
                        if !ps.get_is_live() && dur > 0.0 {
                            ps.set_show_skip_intro(pos < 90.0 && pos > 2.0);
                        }

                        // 3.14: post-play-next-title — populate when near end of VOD.
                        // Uses the same next-episode-title already populated above.
                        if dur > 0.0 && pos > dur - 10.0 && !ps.get_is_live() {
                            let next_title = ps.get_next_episode_title();
                            if !next_title.is_empty() {
                                ps.set_post_play_next_title(next_title);
                            }
                        }

                        // C-001: detect buffering via position stall.
                        // A true fix requires mpv's `paused-for-cache` property observation,
                        // but the current libmpv bindings don't expose observe_property.
                        // TODO(Epoch 3): wire mpv observe_property("paused-for-cache") for
                        // accurate buffering detection with sub-second latency.

                        // M-044: TODO — set PlayerState.volume from mpv volume property.
                    }
                }
            });
        }
    });
}

// ── spawn_data_listener ───────────────────────────────────────────────────────

/// Spawn a tokio task that receives DataEvents and applies them to Slint state.
///
/// `PlaybackReady` is handled here — it locks the shared backend and calls `play()`.
/// Data events (ChannelsReady, etc.) carry `Arc<Vec<S>>` and are dispatched to the
/// UI thread via `invoke_from_event_loop` where `apply_data_event` converts them to
/// VecModel. Image loading is triggered exclusively via scroll callbacks in `wire()`.
pub(crate) fn spawn_data_listener(
    ui_weak: slint::Weak<super::AppWindow>,
    mut data_rx: mpsc::Receiver<DataEvent>,
    backend: Arc<Mutex<Option<crispy_player::mpv_backend::MpvBackend>>>,
    render_context_ready: Arc<AtomicBool>,
    shared_data: Arc<SharedData>,
) {
    tokio::spawn(async move {
        while let Some(event) = data_rx.recv().await {
            // Store full datasets in SharedData (off UI thread)
            match &event {
                DataEvent::ChannelsReady { channels, .. } => {
                    tracing::debug!(
                        count = channels.len(),
                        "[DATA] ChannelsReady → SharedData stored"
                    );
                    *shared_data
                        .channels
                        .lock()
                        .unwrap_or_else(|e| e.into_inner()) = Arc::clone(channels);
                }
                DataEvent::MoviesReady { movies, .. } => {
                    tracing::debug!(
                        count = movies.len(),
                        "[DATA] MoviesReady → SharedData stored"
                    );
                    *shared_data.movies.lock().unwrap_or_else(|e| e.into_inner()) =
                        Arc::clone(movies);
                }
                DataEvent::SeriesReady { series, .. } => {
                    tracing::debug!(
                        count = series.len(),
                        "[DATA] SeriesReady → SharedData stored"
                    );
                    *shared_data.series.lock().unwrap_or_else(|e| e.into_inner()) =
                        Arc::clone(series);
                }
                _ => {}
            }

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
                        let guard = backend.lock().unwrap_or_else(|e| e.into_inner());
                        guard.as_ref().map(|b| b.play(&url))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, url = %url, "PlaybackReady: play failed");
                    }
                    let title_clone = title.clone();
                    // M-007: look up group from SharedData by matching stream url or title.
                    // J-27: also extract logo_url and current EPG programme for OSD strip.
                    let (group_str, channel_id_str, logo_url_str, programme_str) = {
                        let channels = shared_data
                            .channels
                            .lock()
                            .unwrap_or_else(|e| e.into_inner());
                        let found = channels
                            .iter()
                            .find(|c| c.stream_url == url || c.name == title);
                        let group = found
                            .and_then(|c| c.channel_group.clone())
                            .unwrap_or_default();
                        let ch_id = found.map(|c| c.id.clone()).unwrap_or_default();
                        let logo = found.and_then(|c| c.logo_url.clone()).unwrap_or_default();
                        // J-27/J-10: look up current and next EPG programme for OSD strip.
                        let programme = if !ch_id.is_empty() {
                            let now = chrono::Local::now().naive_local();
                            let epg = shared_data
                                .epg_entries
                                .lock()
                                .unwrap_or_else(|e| e.into_inner());
                            if let Some(entries) = epg.get(&ch_id) {
                                // Find the current programme index (start <= now < end).
                                let current_idx = entries
                                    .iter()
                                    .position(|e| e.start_time <= now && e.end_time > now);
                                match current_idx {
                                    Some(idx) => {
                                        let current_title = &entries[idx].title;
                                        let next_title =
                                            entries.get(idx + 1).map(|e| e.title.as_str());
                                        match next_title {
                                            Some(next) => {
                                                format!("Now: {current_title} | Next: {next}")
                                            }
                                            None => format!("Now: {current_title}"),
                                        }
                                    }
                                    None => String::new(),
                                }
                            } else {
                                String::new()
                            }
                        } else {
                            String::new()
                        };
                        (group, ch_id, logo, programme)
                    };
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            ps.set_current_title(SharedString::from(title_clone.as_str()));
                            ps.set_current_group(SharedString::from(group_str.as_str()));
                            ps.set_current_channel_id(SharedString::from(channel_id_str.as_str()));
                            // J-27: populate OSD live strip fields
                            ps.set_channel_logo_url(SharedString::from(logo_url_str.as_str()));
                            ps.set_current_programme(SharedString::from(programme_str.as_str()));
                            ps.set_is_playing(true);
                            ps.set_is_fullscreen(true);
                            ps.set_is_buffering(false);
                            ps.set_show_osd(true);
                            // M-006: is_live = true by default at playback start;
                            // spawn_position_poller refines once duration is known
                            ps.set_is_live(true);
                        }
                    });
                }

                other => {
                    let ui_w = ui_weak.clone();
                    let sd2 = Arc::clone(&shared_data);
                    if let Err(e) = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            apply_data_event(&ui, other, &sd2);
                        }
                    }) {
                        tracing::error!("invoke_from_event_loop failed: {e:?}");
                    }
                }
            }
        }
        tracing::info!("data_listener task exited");
    });
}

// ── apply_data_event ─────────────────────────────────────────────────────────

/// Pure mapping: DataEvent → Slint property mutations.
///
/// MUST be called on the UI thread (inside `invoke_from_event_loop` or directly).
/// `shared_data` is used to read EPG entries, profiles, and hero item sources
/// that are populated by DataEngine during startup / sync.
pub(crate) fn apply_data_event(ui: &super::AppWindow, event: DataEvent, shared_data: &SharedData) {
    let app = ui.global::<super::AppState>();

    match event {
        DataEvent::SourcesReady { sources } => {
            // M-009: update diagnostics source count
            ui.global::<super::DiagnosticsState>()
                .set_source_count(sources.len() as i32);
            let items: Vec<super::SourceData> = sources.iter().map(source_info_to_slint).collect();
            app.set_sources(ModelRc::new(VecModel::from(items)));
        }

        DataEvent::ChannelsReady {
            channels,
            groups: in_groups,
            total,
            ..
        } => {
            // M-010: update diagnostics channel count
            ui.global::<super::DiagnosticsState>()
                .set_channel_count(total);
            // m-002: reset active group filter so stale selection doesn't persist after re-sync
            app.set_active_channel_group(SharedString::default());
            // Windowed: scroll callback (delta=0) does full reset
            app.set_channel_window_start(0);
            app.set_total_channel_count(total);
            // Trigger scroll callback so images load for initial viewport
            app.invoke_scroll_channels(0);
            let sc_groups: Vec<SharedString> = in_groups
                .into_iter()
                .map(|s| SharedString::from(s.as_str()))
                .collect();
            app.set_channel_groups(ModelRc::new(VecModel::from(sc_groups)));
            // Home preview: first 20 items
            let home_ch: Vec<super::ChannelData> = channels
                .iter()
                .take(20)
                .map(channel_info_to_slint)
                .collect();
            tracing::debug!(count = home_ch.len(), "[DATA] home-channels set");
            app.set_home_channels(ModelRc::new(VecModel::from(home_ch)));

            // ── Hero items ────────────────────────────────────────────
            let hero = build_hero_items(shared_data);
            tracing::debug!(count = hero.len(), "[DATA] hero-items set from channels");
            app.set_hero_items(ModelRc::new(VecModel::from(hero)));
            app.set_hero_index(0);

            // ── EPG rows for today ────────────────────────────────────
            let offset = app.get_epg_selected_date_offset();
            let epg_rows = build_epg_rows(shared_data, offset);
            tracing::debug!(count = epg_rows.len(), "[DATA] epg-rows set");
            app.set_epg_rows(ModelRc::new(VecModel::from(epg_rows)));

            // ── EPG current time ──────────────────────────────────────
            let now = chrono::Local::now();
            app.set_epg_now_hour(now.hour() as i32);
            app.set_epg_now_minute(now.minute() as i32);
            let date_label = if offset == 0 {
                "Today".to_string()
            } else if offset == -1 {
                "Yesterday".to_string()
            } else if offset < 0 {
                format!("{} days ago", -offset)
            } else {
                format!("+{offset} days")
            };
            app.set_epg_date_label(SharedString::from(date_label.as_str()));

            // ── Profiles ──────────────────────────────────────────────
            let slint_profiles = build_slint_profiles(shared_data);
            if !slint_profiles.is_empty() {
                let active_name = {
                    let active_id = shared_data
                        .active_profile_id
                        .lock()
                        .unwrap_or_else(|e| e.into_inner())
                        .clone();
                    shared_data
                        .profiles
                        .lock()
                        .unwrap()
                        .iter()
                        .find(|p| p.id == active_id || active_id.is_empty())
                        .map(|p| p.name.clone())
                        .unwrap_or_else(|| "Default".to_string())
                };
                app.set_profiles(ModelRc::new(VecModel::from(slint_profiles)));
                app.set_active_profile_name(SharedString::from(active_name.as_str()));
                tracing::debug!("[DATA] profiles set");
            }
        }

        DataEvent::MoviesReady {
            movies,
            categories: in_categories,
            total,
            ..
        } => {
            // M-011: accumulate vod count in diagnostics
            {
                let diag = ui.global::<super::DiagnosticsState>();
                let prev = diag.get_vod_count();
                diag.set_vod_count(prev + total);
            }
            // m-003: reset active category filter so stale selection doesn't persist after re-sync
            app.set_active_vod_category(SharedString::default());
            app.set_movie_window_start(0);
            app.set_total_movie_count(total);
            // Trigger scroll callback so images load for initial viewport
            app.invoke_scroll_movies(0);
            let sc_cats: Vec<super::CategoryData> = in_categories
                .into_iter()
                .map(|c| super::CategoryData {
                    name: SharedString::from(c.as_str()),
                    category_type: SharedString::from("movie"),
                })
                .collect();
            app.set_vod_categories(ModelRc::new(VecModel::from(sc_cats)));
            // Home preview: first 20 items
            let home_mv: Vec<super::VodData> =
                movies.iter().take(20).map(vod_info_to_slint).collect();
            tracing::debug!(count = home_mv.len(), "[DATA] home-movies set");
            app.set_home_movies(ModelRc::new(VecModel::from(home_mv)));

            // ── Hero items (refresh — movies fill remaining slots) ────
            let hero = build_hero_items(shared_data);
            tracing::debug!(
                count = hero.len(),
                "[DATA] hero-items refreshed from movies"
            );
            app.set_hero_items(ModelRc::new(VecModel::from(hero)));
        }

        DataEvent::SeriesReady {
            series,
            categories: in_categories,
            total,
            ..
        } => {
            // m-015: DataEngine reuses SeriesReady to deliver episode lists from
            // SelectSeriesSeason (total=0, categories=[]).  When a series detail view
            // is open, populate series_episodes instead of the main series list.
            if total == 0 && in_categories.is_empty() && app.get_show_series_detail() {
                let episodes: Vec<super::VodData> = series.iter().map(vod_info_to_slint).collect();
                tracing::debug!(count = episodes.len(), "[DATA] series-episodes set");
                app.set_series_episodes(ModelRc::new(VecModel::from(episodes)));
                return;
            }

            // M-011: accumulate series vod count in diagnostics
            {
                let diag = ui.global::<super::DiagnosticsState>();
                let prev = diag.get_vod_count();
                diag.set_vod_count(prev + total);
            }
            app.set_series_window_start(0);
            app.set_total_series_count(total);
            // Trigger scroll callback so images load for initial viewport
            app.invoke_scroll_series(0);
            let sc_cats: Vec<super::CategoryData> = in_categories
                .into_iter()
                .map(|c| super::CategoryData {
                    name: SharedString::from(c.as_str()),
                    category_type: SharedString::from("series"),
                })
                .collect();
            app.set_vod_categories(ModelRc::new(VecModel::from(sc_cats)));
            // Home preview: first 20 items
            let home_sr: Vec<super::VodData> =
                series.iter().take(20).map(vod_info_to_slint).collect();
            tracing::debug!(count = home_sr.len(), "[DATA] home-series set");
            app.set_home_series(ModelRc::new(VecModel::from(home_sr)));
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
            app.set_sync_progress(percent as f32 / 100.0);
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
            // Parse space-separated key=value pairs from report string.
            // Known keys: sources=N channels=N vod=N
            //   bitrate=<str> codec=<str> buffer_ms=N          (Epoch 11 stream stats)
            //   network_status=N epg_stale_hours=N              (Epoch 8)
            let diag = ui.global::<super::DiagnosticsState>();
            let mut source_count: i32 = 0;
            let mut channel_count: i32 = 0;
            let mut vod_count: i32 = 0;
            let mut bitrate = String::new();
            let mut codec = String::new();
            let mut buffer_ms: i32 = 0;
            let mut network_status: i32 = 0;
            let mut epg_stale_hours: i32 = 0;
            for part in report.split_whitespace() {
                if let Some(v) = part.strip_prefix("sources=") {
                    source_count = v.parse().unwrap_or(0);
                } else if let Some(v) = part.strip_prefix("channels=") {
                    channel_count = v.parse().unwrap_or(0);
                } else if let Some(v) = part.strip_prefix("vod=") {
                    vod_count = v.parse().unwrap_or(0);
                } else if let Some(v) = part.strip_prefix("bitrate=") {
                    bitrate = v.replace('_', " ");
                } else if let Some(v) = part.strip_prefix("codec=") {
                    codec = v.replace('_', " ");
                } else if let Some(v) = part.strip_prefix("buffer_ms=") {
                    buffer_ms = v.parse().unwrap_or(0);
                } else if let Some(v) = part.strip_prefix("network_status=") {
                    network_status = v.parse().unwrap_or(0);
                } else if let Some(v) = part.strip_prefix("epg_stale_hours=") {
                    epg_stale_hours = v.parse().unwrap_or(0);
                }
            }
            if source_count > 0 || channel_count > 0 || vod_count > 0 {
                diag.set_source_count(source_count);
                diag.set_channel_count(channel_count);
                diag.set_vod_count(vod_count);
            }
            // Epoch 11: per-stream stats (only update when non-empty)
            if !codec.is_empty() {
                diag.set_stream_bitrate(SharedString::from(bitrate.as_str()));
                diag.set_stream_codec(SharedString::from(codec.as_str()));
                diag.set_stream_buffer_ms(buffer_ms);
            }
            // Epoch 8: network state + EPG staleness
            app.set_network_status(network_status);
            app.set_is_offline(network_status > 0);
            app.set_epg_last_updated_hours(epg_stale_hours);
        }

        DataEvent::Error { message } => {
            tracing::error!(message = %message, "DataEngine error surfaced to UI");
            app.set_sync_message(SharedString::from(message.as_str()));
        }

        // PlaybackReady is handled in spawn_data_listener before reaching here
        DataEvent::PlaybackReady { .. } => {}

        DataEvent::EpgProgrammesReady { programmes, .. } => {
            tracing::debug!(count = programmes.len(), "[DATA] EPG programmes ready");
            // TODO: convert to Slint EPG model and set on AppState when EPG grid is implemented
        }

        DataEvent::EpgFocusChannel { channel_id } => {
            tracing::debug!(channel_id, "[DATA] EPG focus channel");
            app.set_epg_jump_channel_id(SharedString::from(channel_id.as_str()));
        }

        DataEvent::EpgSearchResults { query, results } => {
            tracing::debug!(query, count = results.len(), "[DATA] EPG search results");
            // Store the search query so the EPG screen can show/hide the filtered state.
            app.set_epg_search_query(SharedString::from(query.as_str()));
        }

        DataEvent::RecentSearchesReady { queries } => {
            tracing::debug!(count = queries.len(), "[DATA] recent searches ready");
            let slint_list: Vec<SharedString> = queries
                .iter()
                .map(|s| SharedString::from(s.as_str()))
                .collect();
            app.set_recent_searches(ModelRc::new(VecModel::from(slint_list)));
        }

        // J-40: populate Library History tab
        DataEvent::WatchHistoryReady { entries } => {
            tracing::debug!(count = entries.len(), "[DATA] watch history ready");
            let slint_entries: Vec<super::WatchHistoryData> = entries
                .iter()
                .map(|e| super::WatchHistoryData {
                    id: SharedString::from(e.id.as_str()),
                    name: SharedString::from(e.name.as_str()),
                    media_type: SharedString::from(e.media_type.as_str()),
                    stream_url: SharedString::from(e.stream_url.as_str()),
                    position_ms: e.position_ms.min(i32::MAX as i64) as i32,
                    duration_ms: e.duration_ms.min(i32::MAX as i64) as i32,
                    watched_at: SharedString::from(e.watched_at.as_str()),
                    progress: if e.duration_ms > 0 {
                        (e.position_ms as f32 / e.duration_ms as f32).clamp(0.0, 1.0)
                    } else {
                        0.0
                    },
                })
                .collect();
            app.set_watch_history(ModelRc::new(VecModel::from(slint_entries)));
        }

        // J-17/J-21: populate home screen continue-watching lane
        DataEvent::ContinueWatchingReady { items } => {
            tracing::debug!(count = items.len(), "[DATA] continue-watching ready");
            let slint_items: Vec<super::ContinueWatchingData> = items
                .iter()
                .map(|it| super::ContinueWatchingData {
                    id: SharedString::from(it.id.as_str()),
                    title: SharedString::from(it.title.as_str()),
                    image_url: SharedString::from(it.image_url.as_deref().unwrap_or("")),
                    progress: it.progress,
                    content_type: SharedString::from(it.content_type.as_str()),
                    poster: Default::default(),
                })
                .collect();
            app.set_continue_watching_items(ModelRc::new(VecModel::from(slint_items)));
        }

        // Network connectivity banner update.
        // status: 0 = online, 1 = offline, 2 = degraded.
        DataEvent::NetworkStateChanged { status } => {
            tracing::debug!(status, "[DATA] network state changed");
            app.set_network_status(status);
            app.set_is_offline(status != 0);
        }
    }
}

// ── Conversion helpers ────────────────────────────────────────────────────────

pub(crate) fn channel_info_to_slint(c: &ChannelInfo) -> super::ChannelData {
    super::ChannelData {
        id: SharedString::from(c.id.as_str()),
        name: SharedString::from(c.name.as_str()),
        group: SharedString::from(c.channel_group.as_deref().unwrap_or("")),
        logo_url: SharedString::from(c.logo_url.as_deref().unwrap_or("")),
        stream_url: SharedString::from(c.stream_url.as_str()),
        source_id: SharedString::from(c.source_id.as_deref().unwrap_or("")),
        number: c.number.unwrap_or(0),
        is_favorite: c.is_favorite,
        has_catchup: c.has_catchup,
        resolution: SharedString::from(c.resolution.as_deref().unwrap_or("")),
        now_playing: SharedString::default(),
        logo: Default::default(),
    }
}

pub(crate) fn vod_info_to_slint(v: &VodInfo) -> super::VodData {
    super::VodData {
        id: SharedString::from(v.id.as_str()),
        name: SharedString::from(v.name.as_str()),
        stream_url: SharedString::from(v.stream_url.as_str()),
        item_type: SharedString::from(v.item_type.as_str()),
        poster_url: SharedString::from(v.poster_url.as_deref().unwrap_or("")),
        backdrop_url: SharedString::from(v.backdrop_url.as_deref().unwrap_or("")),
        description: SharedString::from(v.description.as_deref().unwrap_or("")),
        genre: SharedString::default(),
        year: SharedString::from(v.year.map(|y| y.to_string()).unwrap_or_default().as_str()),
        rating: SharedString::from(v.rating.as_deref().unwrap_or("")),
        duration_minutes: v.duration_minutes.unwrap_or(0),
        is_favorite: v.is_favorite,
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
        last_sync_error: SharedString::from(s.last_sync_error.as_deref().unwrap_or("")),
        enabled: s.enabled,
    }
}

// ── Multi-source badge helper ─────────────────────────────────────────────────

/// Derive a quality label from a resolution string or stream name heuristic.
///
/// Matches the most common IPTV naming conventions:
/// `4K`, `UHD`, `2160` → "4K"; `1080`, `FHD` → "1080p"; `720`, `HD` → "720p";
/// everything else → "SD".
pub(crate) fn quality_label_for(resolution: &str, name: &str) -> &'static str {
    let haystack = format!("{} {}", resolution, name).to_ascii_lowercase();
    if haystack.contains("4k") || haystack.contains("uhd") || haystack.contains("2160") {
        "4K"
    } else if haystack.contains("1080") || haystack.contains("fhd") {
        "1080p"
    } else if haystack.contains("720") || haystack.contains(" hd") || haystack.ends_with("hd") {
        "720p"
    } else {
        "SD"
    }
}

/// Build `SourceBadge` slices for a VOD item by scanning the full dataset for
/// all entries that share the same normalised title (case-insensitive).
///
/// The first matching entry per distinct `source_id` is kept; the source whose
/// `source_id` matches `primary_source_id` is marked `is_preferred`.
///
/// Called on the UI thread from `on_open_vod_detail` / `on_open_series_detail`.
pub(crate) fn build_source_badges(
    sd: &SharedData,
    title: &str,
    item_type: &str,
    primary_source_id: &str,
) -> Vec<super::SourceBadge> {
    let title_lower = title.to_ascii_lowercase();
    let is_series = item_type == "series";

    // Snapshot without holding two locks simultaneously.
    let candidates: Vec<VodInfo> = if is_series {
        sd.series
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .iter()
            .cloned()
            .collect()
    } else {
        sd.movies
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .iter()
            .cloned()
            .collect()
    };

    // Collect one entry per source_id whose title matches.
    let mut seen_sources: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut badges: Vec<super::SourceBadge> = Vec::new();

    for vod in &candidates {
        if vod.name.to_ascii_lowercase() != title_lower {
            continue;
        }
        let sid = vod.source_id.as_deref().unwrap_or("").to_string();
        if sid.is_empty() || !seen_sources.insert(sid.clone()) {
            continue;
        }
        let qlabel = quality_label_for("", &vod.name);
        let is_preferred = sid == primary_source_id;
        badges.push(super::SourceBadge {
            source_name: SharedString::from(sid.as_str()),
            quality_label: SharedString::from(qlabel),
            is_preferred,
        });
    }

    // Ensure preferred source sorts first.
    badges.sort_by(|a, b| b.is_preferred.cmp(&a.is_preferred));
    badges
}

// ── Profile conversion helper ─────────────────────────────────────────────────

/// Perform the actual profile switch: update SharedData, update Slint, trigger SyncAll.
///
/// Called from both `on_switch_profile` (no-PIN path) and `on_verify_pin` (correct-PIN path).
fn do_profile_switch(
    id: &str,
    profile_name: &str,
    sd: &SharedData,
    ui_w: &slint::Weak<super::AppWindow>,
    tx: &tokio::sync::mpsc::Sender<NormalEvent>,
) {
    {
        *sd.active_profile_id
            .lock()
            .unwrap_or_else(|e| e.into_inner()) = id.to_string();
    }
    let name = profile_name.to_string();
    // J-37: determine kids mode from the switching profile
    let is_child = {
        let profiles = sd.profiles.lock().unwrap_or_else(|e| e.into_inner());
        profiles
            .iter()
            .find(|p| p.id == id)
            .map(|p| p.is_child)
            .unwrap_or(false)
    };
    let ui_w2 = ui_w.clone();
    let _ = slint::invoke_from_event_loop(move || {
        if let Some(ui) = ui_w2.upgrade() {
            let app = ui.global::<super::AppState>();
            app.set_active_profile_name(SharedString::from(name.as_str()));
            app.set_show_profile_picker(false);
            app.set_is_kids_mode(is_child); // J-37
        }
    });
    if let Err(e) = tx.try_send(NormalEvent::SyncAll) {
        tracing::warn!(error = %e, "normal_tx full: SwitchProfile→SyncAll dropped");
    }
}

/// Verify a plaintext PIN against an Argon2id hash stored in the DB.
///
/// The hash was produced by `crispy_core::security` using Argon2id.
/// Returns `true` if the PIN matches, `false` otherwise.
fn verify_profile_pin(pin: &str, stored_hash: &str) -> bool {
    use argon2::{Argon2, PasswordHash, PasswordVerifier};
    let Ok(parsed) = PasswordHash::new(stored_hash) else {
        tracing::error!("verify_profile_pin: stored hash is malformed");
        return false;
    };
    Argon2::default()
        .verify_password(pin.as_bytes(), &parsed)
        .is_ok()
}

/// Convert all profiles in SharedData to Slint ProfileData structs.
///
/// Called on the UI thread — SharedData lock is held briefly.
pub(crate) fn build_slint_profiles(sd: &SharedData) -> Vec<super::ProfileData> {
    // Avatar colour palette — cycles by avatar_index
    const AVATAR_COLORS: &[u32] = &[
        0xFF4B_2BFF, // crispy brand orange/red
        0xFF_2196F3, // blue
        0xFF_4CAF50, // green
        0xFF_9C27B0, // purple
        0xFF_FF9800, // amber
        0xFF_00BCD4, // cyan
    ];

    let active_id = sd
        .active_profile_id
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .clone();
    sd.profiles
        .lock()
        .unwrap()
        .iter()
        .map(|p| {
            let color_argb =
                AVATAR_COLORS[p.avatar_index.unsigned_abs() as usize % AVATAR_COLORS.len()];
            super::ProfileData {
                id: SharedString::from(p.id.as_str()),
                name: SharedString::from(p.name.as_str()),
                avatar_color: slint::Color::from_argb_encoded(color_argb).into(),
                is_kids: p.is_child,
                is_active: p.id == active_id,
                pin_protected: p.pin.is_some(),
            }
        })
        .collect()
}

// ── EPG row builder ───────────────────────────────────────────────────────────

/// Build EpgChannelRow items for the current day from SharedData.
///
/// Filters EPG entries to the 24-hour window starting at midnight today (UTC).
/// For each channel that has entries, produces one `EpgChannelRow`.
/// Channels with no EPG data are omitted — the EPG screen can show a placeholder.
pub(crate) fn build_epg_rows(sd: &SharedData, offset_days: i32) -> Vec<super::EpgChannelRow> {
    use chrono::{Local, TimeZone};

    let now = Local::now();
    let day_start = Local
        .with_ymd_and_hms(now.year(), now.month(), now.day(), 0, 0, 0)
        .single()
        .unwrap_or(now);
    let offset_dur = chrono::Duration::days(i64::from(offset_days));
    let window_start = (day_start + offset_dur).timestamp();
    let window_end = window_start + 86_400;

    let channels_snap = sd.channels.lock().unwrap_or_else(|e| e.into_inner());
    let epg_snap = sd.epg_entries.lock().unwrap_or_else(|e| e.into_inner());

    let mut rows: Vec<super::EpgChannelRow> = Vec::new();

    for ch in channels_snap.iter() {
        let entries = match epg_snap.get(&ch.id) {
            Some(e) if !e.is_empty() => e,
            _ => continue,
        };

        let programmes: Vec<super::EpgData> = entries
            .iter()
            .filter(|e| {
                let s = e.start_time.and_utc().timestamp();
                let end = e.end_time.and_utc().timestamp();
                // Include if any overlap with the day window
                s < window_end && end > window_start
            })
            .map(|e| {
                let s_ts = e.start_time.and_utc().timestamp();
                let e_ts = e.end_time.and_utc().timestamp();
                let duration_mins = ((e_ts - s_ts) / 60).max(0) as i32;
                let now_ts = Local::now().timestamp();
                let progress = if now_ts >= s_ts && e_ts > s_ts {
                    ((now_ts - s_ts) as f32 / (e_ts - s_ts) as f32).clamp(0.0, 1.0)
                } else {
                    0.0
                };
                super::EpgData {
                    channel_id: SharedString::from(e.channel_id.as_str()),
                    channel_name: SharedString::from(ch.name.as_str()),
                    channel_logo: Default::default(),
                    title: SharedString::from(e.title.as_str()),
                    start_hour: e.start_time.hour() as i32,
                    start_minute: e.start_time.minute() as i32,
                    end_hour: e.end_time.hour() as i32,
                    end_minute: e.end_time.minute() as i32,
                    duration_minutes: duration_mins,
                    progress_percent: progress,
                    description: SharedString::from(e.description.as_deref().unwrap_or("")),
                    category: SharedString::from(e.category.as_deref().unwrap_or("")),
                    has_catchup: false,
                    is_now: now_ts >= s_ts && now_ts < e_ts,
                }
            })
            .collect();

        if programmes.is_empty() {
            continue;
        }

        rows.push(super::EpgChannelRow {
            channel_id: SharedString::from(ch.id.as_str()),
            channel_name: SharedString::from(ch.name.as_str()),
            channel_logo: Default::default(),
            programmes: ModelRc::new(VecModel::from(programmes)),
        });
    }

    rows
}

// ── Hero item builder ─────────────────────────────────────────────────────────

/// Build up to 5 HeroItem structs from the first channels (with logos) or movies.
pub(crate) fn build_hero_items(sd: &SharedData) -> Vec<super::HeroItem> {
    let channels_snap = sd.channels.lock().unwrap_or_else(|e| e.into_inner());
    let movies_snap = sd.movies.lock().unwrap_or_else(|e| e.into_inner());

    let mut items: Vec<super::HeroItem> = Vec::with_capacity(5);

    // Use any channel — prefer ones with a logo URL but don't require it
    for ch in channels_snap.iter() {
        if items.len() >= 5 {
            break;
        }
        items.push(super::HeroItem {
            id: SharedString::from(ch.id.as_str()),
            title: SharedString::from(ch.name.as_str()),
            subtitle: SharedString::from(ch.channel_group.as_deref().unwrap_or("Live TV")),
            backdrop: Default::default(),
            content_type: SharedString::from("live"),
            is_live: true,
        });
    }

    // Fill remaining slots with movies — prefer backdrop URL but fall back to any movie
    for mv in movies_snap
        .iter()
        .filter(|v| v.backdrop_url.is_some())
        .chain(movies_snap.iter().filter(|v| v.backdrop_url.is_none()))
    {
        if items.len() >= 5 {
            break;
        }
        items.push(super::HeroItem {
            id: SharedString::from(mv.id.as_str()),
            title: SharedString::from(mv.name.as_str()),
            subtitle: SharedString::from(
                mv.year.map(|y| y.to_string()).unwrap_or_default().as_str(),
            ),
            backdrop: Default::default(),
            content_type: SharedString::from("movie"),
            is_live: false,
        });
    }

    items
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::events::VodInfo;
    use std::sync::Arc;

    fn make_vod(name: &str, source_id: &str) -> VodInfo {
        VodInfo {
            id: format!("{}-{}", name, source_id),
            name: name.to_string(),
            source_id: Some(source_id.to_string()),
            item_type: "movie".to_string(),
            ..Default::default()
        }
    }

    fn shared_data_with_movies(movies: Vec<VodInfo>) -> SharedData {
        let sd = SharedData::new();
        *sd.movies.lock().unwrap() = Arc::new(movies);
        sd
    }

    // ── quality_label_for ────────────────────────────────────────────────────

    #[test]
    fn test_quality_label_for_4k_patterns() {
        assert_eq!(quality_label_for("", "The Movie 4K"), "4K");
        assert_eq!(quality_label_for("2160p", "Movie"), "4K");
        assert_eq!(quality_label_for("UHD", "Movie"), "4K");
    }

    #[test]
    fn test_quality_label_for_1080p_patterns() {
        assert_eq!(quality_label_for("1080p", "Movie"), "1080p");
        assert_eq!(quality_label_for("", "Movie FHD"), "1080p");
    }

    #[test]
    fn test_quality_label_for_720p_patterns() {
        assert_eq!(quality_label_for("720p", "Movie"), "720p");
    }

    #[test]
    fn test_quality_label_for_sd_fallback() {
        assert_eq!(quality_label_for("", "Movie"), "SD");
        assert_eq!(quality_label_for("480p", "Something"), "SD");
    }

    // ── build_source_badges ──────────────────────────────────────────────────

    #[test]
    fn test_build_source_badges_single_source_returns_one_badge() {
        let sd = shared_data_with_movies(vec![make_vod("Dune", "src-a")]);
        let badges = build_source_badges(&sd, "Dune", "movie", "src-a");
        assert_eq!(badges.len(), 1);
        assert_eq!(badges[0].source_name.as_str(), "src-a");
        assert!(badges[0].is_preferred);
    }

    #[test]
    fn test_build_source_badges_multi_source_deduplicates_per_source() {
        let sd = shared_data_with_movies(vec![
            make_vod("Inception", "src-a"),
            make_vod("Inception", "src-b"),
            make_vod("Inception", "src-b"), // duplicate source_id — must be deduped
        ]);
        let badges = build_source_badges(&sd, "Inception", "movie", "src-a");
        assert_eq!(badges.len(), 2);
    }

    #[test]
    fn test_build_source_badges_preferred_sorts_first() {
        let sd = shared_data_with_movies(vec![
            make_vod("Blade Runner", "src-b"),
            make_vod("Blade Runner", "src-a"),
        ]);
        let badges = build_source_badges(&sd, "Blade Runner", "movie", "src-a");
        assert_eq!(badges.len(), 2);
        assert!(badges[0].is_preferred, "preferred badge must be first");
        assert_eq!(badges[0].source_name.as_str(), "src-a");
    }

    #[test]
    fn test_build_source_badges_title_case_insensitive() {
        let sd = shared_data_with_movies(vec![make_vod("the matrix", "src-a")]);
        let badges = build_source_badges(&sd, "The Matrix", "movie", "src-a");
        // "the matrix" != "The Matrix" after lowercasing both → match
        assert_eq!(badges.len(), 1);
    }

    #[test]
    fn test_build_source_badges_no_match_returns_empty() {
        let sd = shared_data_with_movies(vec![make_vod("Alien", "src-a")]);
        let badges = build_source_badges(&sd, "Predator", "movie", "src-a");
        assert!(badges.is_empty());
    }

    #[test]
    fn test_build_source_badges_has_multi_source_flag() {
        let sd = shared_data_with_movies(vec![
            make_vod("Avatar", "src-a"),
            make_vod("Avatar", "src-b"),
        ]);
        let badges = build_source_badges(&sd, "Avatar", "movie", "src-a");
        let has_multi = badges.len() > 1;
        assert!(has_multi);
    }
}
