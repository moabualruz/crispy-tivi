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

// ── Virtual scroll constants ────────────────────────────────────────────────
const CHANNEL_WINDOW: usize = 15;
const VOD_WINDOW: usize = 45;

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

    app.on_open_vod_detail({
        let tx = high_tx.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        move |vod_id| {
            // Populate detail item from SharedData so the detail screen shows immediately
            let id = vod_id.to_string();
            let found = {
                let movies = sd.movies.lock().unwrap();
                let series = sd.series.lock().unwrap();
                movies
                    .iter()
                    .find(|v| v.id == id)
                    .or_else(|| series.iter().find(|v| v.id == id))
                    .cloned()
            };
            if let Some(vod) = found {
                let ui_w2 = ui_w.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        let app = ui.global::<super::AppState>();
                        app.set_vod_detail_item(vod_info_to_slint(&vod));
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
                let series = sd.series.lock().unwrap();
                series.iter().find(|v| v.id == id).cloned()
            };
            if let Some(s) = found {
                let ui_w2 = ui_w.clone();
                let _ = slint::invoke_from_event_loop(move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        let app = ui.global::<super::AppState>();
                        app.set_series_detail_item(vod_info_to_slint(&s));
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
        move |_season| {
            // Episode list population is future EPG/series module work.
            // Season selection stored in AppState.series-active-season (set by Slint directly).
            tracing::debug!(
                season = _season,
                "SelectSeriesSeason — no-op until series episode API"
            );
        }
    });

    app.on_play_episode({
        let tx = high_tx.clone();
        move |series_id, season, episode| {
            // Construct a synthesized VOD id for the episode
            let ep_id = format!("{series_id}:s{season}e{episode}");
            if let Err(e) = tx.try_send(HighPriorityEvent::PlayVod { vod_id: ep_id }) {
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

    // ── Scroll callbacks: incremental Rc<VecModel> push/remove ─────────
    app.on_scroll_channels({
        let loader = image_loader.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        let model = Rc::clone(&channel_model);
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
            let data = sd.channels.lock().unwrap();
            if data.is_empty() {
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                return;
            }

            let window_size = CHANNEL_WINDOW * 3;

            if delta == 0 {
                // Full reset: clear and repopulate
                let start = app.get_channel_window_start() as usize;
                let end = (start + window_size).min(data.len());
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                for item in data[start..end].iter() {
                    model.push(channel_info_to_slint(item));
                }
                tracing::debug!(start, end, count = end - start, "[SCROLL] channels RESET");
            } else {
                let old_start = app.get_channel_window_start() as usize;
                let max_start = data.len().saturating_sub(CHANNEL_WINDOW);
                let new_start = if delta > 0 {
                    (old_start + delta as usize).min(max_start)
                } else {
                    old_start.saturating_sub((-delta) as usize)
                };

                if new_start != old_start {
                    let old_end = (old_start + window_size).min(data.len());
                    let new_end = (new_start + window_size).min(data.len());

                    if new_start > old_start {
                        // Forward: push new items at end, then remove old from start
                        for i in old_end..new_end {
                            model.push(channel_info_to_slint(&data[i]));
                        }
                        let remove_count = (new_start - old_start).min(model.row_count());
                        for _ in 0..remove_count {
                            model.remove(0);
                        }
                    } else {
                        // Backward: insert at start, remove from end
                        for i in (new_start..old_start).rev() {
                            model.insert(0, channel_info_to_slint(&data[i]));
                        }
                        while model.row_count() > new_end.saturating_sub(new_start) {
                            model.remove(model.row_count() - 1);
                        }
                    }

                    app.set_channel_window_start(new_start as i32);
                    tracing::debug!(
                        old_start,
                        new_start,
                        max_start,
                        "[SCROLL] channels window SHIFT"
                    );
                } else {
                    tracing::debug!(old_start, "[SCROLL] channels no shift needed");
                }
            }
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
            let data = sd.movies.lock().unwrap();
            if data.is_empty() {
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                return;
            }

            let window_size = VOD_WINDOW * 3;

            if delta == 0 {
                let start = app.get_movie_window_start() as usize;
                let end = (start + window_size).min(data.len());
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                for item in data[start..end].iter() {
                    model.push(vod_info_to_slint(item));
                }
                tracing::debug!(start, end, count = end - start, "[SCROLL] movies RESET");
            } else {
                let old_start = app.get_movie_window_start() as usize;
                let max_start = data.len().saturating_sub(VOD_WINDOW);
                let new_start = if delta > 0 {
                    (old_start + delta as usize).min(max_start)
                } else {
                    old_start.saturating_sub((-delta) as usize)
                };

                if new_start != old_start {
                    let old_end = (old_start + window_size).min(data.len());
                    let new_end = (new_start + window_size).min(data.len());

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

                    app.set_movie_window_start(new_start as i32);
                    tracing::debug!(
                        old_start,
                        new_start,
                        max_start,
                        "[SCROLL] movies window SHIFT"
                    );
                }
            }
            drop(data);
            tracing::debug!("[IMG] movies image load for VecModel window");
            loader.load_movies(&ui_w, None);
        }
    });

    app.on_scroll_series({
        let loader = image_loader.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        let model = Rc::clone(&series_model);
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
            let data = sd.series.lock().unwrap();
            if data.is_empty() {
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                return;
            }

            let window_size = VOD_WINDOW * 3;

            if delta == 0 {
                let start = app.get_series_window_start() as usize;
                let end = (start + window_size).min(data.len());
                while model.row_count() > 0 {
                    model.remove(model.row_count() - 1);
                }
                for item in data[start..end].iter() {
                    model.push(vod_info_to_slint(item));
                }
                tracing::debug!(start, end, count = end - start, "[SCROLL] series RESET");
            } else {
                let old_start = app.get_series_window_start() as usize;
                let max_start = data.len().saturating_sub(VOD_WINDOW);
                let new_start = if delta > 0 {
                    (old_start + delta as usize).min(max_start)
                } else {
                    old_start.saturating_sub((-delta) as usize)
                };

                if new_start != old_start {
                    let old_end = (old_start + window_size).min(data.len());
                    let new_end = (new_start + window_size).min(data.len());

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

                    app.set_series_window_start(new_start as i32);
                    tracing::debug!(
                        old_start,
                        new_start,
                        max_start,
                        "[SCROLL] series window SHIFT"
                    );
                }
            }
            drop(data);
            tracing::debug!("[IMG] series image load for VecModel window");
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
                let channels = sd.channels.lock().unwrap();
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
                let channels = sd.channels.lock().unwrap();
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
        let tx = normal_tx.clone();
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
        move |profile_id| {
            let id = profile_id.to_string();
            // Update active profile in SharedData immediately
            {
                *sd.active_profile_id.lock().unwrap() = id.clone();
            }
            // Find profile name and update Slint on UI thread
            let profile_name = {
                let profiles = sd.profiles.lock().unwrap();
                profiles
                    .iter()
                    .find(|p| p.id == id)
                    .map(|p| p.name.clone())
                    .unwrap_or_default()
            };
            let ui_w2 = ui_w.clone();
            let _ = slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_w2.upgrade() {
                    let app = ui.global::<super::AppState>();
                    app.set_active_profile_name(SharedString::from(profile_name.as_str()));
                    app.set_show_profile_picker(false);
                }
            });
            // Persist via NormalEvent (reload content for new profile)
            if let Err(e) = tx.try_send(NormalEvent::SyncAll) {
                tracing::warn!(error = %e, "normal_tx full: SwitchProfile→SyncAll dropped");
            }
        }
    });

    app.on_create_profile({
        let ui_w = ui.as_weak();
        let sd = Arc::clone(&shared_data);
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
            {
                sd.profiles.lock().unwrap().push(new_profile);
            }
            // Refresh profiles list in Slint
            let slint_profiles = build_slint_profiles(&sd);
            let active_name = {
                let id = sd.active_profile_id.lock().unwrap().clone();
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
                }
            });
        }
    });

    // ── Channel overlay callback ──────────────────────────────────────────

    app.on_toggle_channel_overlay({
        let ui_w = ui.as_weak();
        move || {
            let _ = slint::invoke_from_event_loop({
                let ui_w2 = ui_w.clone();
                move || {
                    if let Some(ui) = ui_w2.upgrade() {
                        let app = ui.global::<super::AppState>();
                        let current = app.get_show_channel_overlay();
                        app.set_show_channel_overlay(!current);
                        tracing::debug!(now = !current, "toggle-channel-overlay");
                    }
                }
            });
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
                            ps.set_is_fullscreen(false);
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
                    let result = {
                        let guard = backend.lock().unwrap();
                        guard.as_ref().map(|b| b.seek_relative(delta))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, delta, "SeekRelative failed");
                    }
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
                    // M-034: reset OSD auto-hide timer on ShowControls
                    if v {
                        let ui_w2 = ui_weak.clone();
                        tokio::spawn(async move {
                            tokio::time::sleep(std::time::Duration::from_secs(3)).await;
                            let _ = slint::invoke_from_event_loop(move || {
                                if let Some(ui) = ui_w2.upgrade() {
                                    let ps = ui.global::<super::PlayerState>();
                                    // Only hide if still showing OSD and not paused
                                    if ps.get_show_osd() && !ps.get_is_paused() {
                                        ps.set_show_osd(false);
                                    }
                                }
                            });
                        });
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
                    let guard = backend.lock().unwrap();
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
                    let guard = backend.lock().unwrap();
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
                    tracing::debug!(speed, "SetSpeed (no-op until speed property exposed)");
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

            let (playing, pos, dur) = {
                let guard = backend.lock().unwrap();
                if let Some(b) = guard.as_ref() {
                    let pos = b.get_position() as f32;
                    let dur = b.get_duration() as f32;
                    (true, pos, dur)
                } else {
                    (false, 0.0f32, 0.0f32)
                }
            };

            if !playing {
                continue;
            }

            let ui_w = ui_weak.clone();
            let _ = slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui_w.upgrade() {
                    let ps = ui.global::<super::PlayerState>();
                    if ps.get_is_playing() {
                        ps.set_position(pos);
                        ps.set_duration(dur);
                        // M-006: live = no finite duration (duration == 0 or NaN for live streams)
                        ps.set_is_live(dur <= 0.0 || dur.is_nan());
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
                    *shared_data.channels.lock().unwrap() = Arc::clone(channels);
                }
                DataEvent::MoviesReady { movies, .. } => {
                    tracing::debug!(
                        count = movies.len(),
                        "[DATA] MoviesReady → SharedData stored"
                    );
                    *shared_data.movies.lock().unwrap() = Arc::clone(movies);
                }
                DataEvent::SeriesReady { series, .. } => {
                    tracing::debug!(
                        count = series.len(),
                        "[DATA] SeriesReady → SharedData stored"
                    );
                    *shared_data.series.lock().unwrap() = Arc::clone(series);
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
                        let guard = backend.lock().unwrap();
                        guard.as_ref().map(|b| b.play(&url))
                    };
                    if let Some(Err(e)) = result {
                        tracing::error!(error = %e, url = %url, "PlaybackReady: play failed");
                    }
                    let title_clone = title.clone();
                    // M-007: look up group from SharedData by matching stream url or title
                    let group_str = {
                        let channels = shared_data.channels.lock().unwrap();
                        channels
                            .iter()
                            .find(|c| c.stream_url == url || c.name == title)
                            .and_then(|c| c.channel_group.clone())
                            .unwrap_or_default()
                    };
                    let ui_w = ui_weak.clone();
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            let ps = ui.global::<super::PlayerState>();
                            ps.set_current_title(SharedString::from(title_clone.as_str()));
                            ps.set_current_group(SharedString::from(group_str.as_str()));
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
                    let _ = slint::invoke_from_event_loop(move || {
                        if let Some(ui) = ui_w.upgrade() {
                            apply_data_event(&ui, other, &sd2);
                        }
                    });
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
                    let active_id = shared_data.active_profile_id.lock().unwrap().clone();
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
            // M-009/010/011: parse counts from report format "sources=N channels=N vod=N ..."
            let diag = ui.global::<super::DiagnosticsState>();
            let mut source_count: i32 = 0;
            let mut channel_count: i32 = 0;
            let mut vod_count: i32 = 0;
            for part in report.split_whitespace() {
                if let Some(v) = part.strip_prefix("sources=") {
                    source_count = v.parse().unwrap_or(0);
                } else if let Some(v) = part.strip_prefix("channels=") {
                    channel_count = v.parse().unwrap_or(0);
                } else if let Some(v) = part.strip_prefix("vod=") {
                    vod_count = v.parse().unwrap_or(0);
                }
            }
            if source_count > 0 || channel_count > 0 || vod_count > 0 {
                diag.set_source_count(source_count);
                diag.set_channel_count(channel_count);
                diag.set_vod_count(vod_count);
            }
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
    }
}

// ── Profile conversion helper ─────────────────────────────────────────────────

/// Convert all profiles in SharedData to Slint ProfileData structs.
///
/// Called on the UI thread — SharedData lock is held briefly.
pub(crate) fn build_slint_profiles(sd: &SharedData) -> Vec<super::ProfileData> {
    // Avatar colour palette — cycles by avatar_index
    const AVATAR_COLORS: &[u32] = &[
        0xFF_4B2B_FF, // crispy brand orange/red
        0xFF_2196F3,  // blue
        0xFF_4CAF50,  // green
        0xFF_9C27B0,  // purple
        0xFF_FF9800,  // amber
        0xFF_00BCD4,  // cyan
    ];

    let active_id = sd.active_profile_id.lock().unwrap().clone();
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

    let channels_snap = sd.channels.lock().unwrap();
    let epg_snap = sd.epg_entries.lock().unwrap();

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
    let channels_snap = sd.channels.lock().unwrap();
    let movies_snap = sd.movies.lock().unwrap();

    let mut items: Vec<super::HeroItem> = Vec::with_capacity(5);

    // Prefer channels that have a logo URL
    for ch in channels_snap.iter().filter(|c| c.logo_url.is_some()) {
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

    // Fill remaining slots with movies that have a backdrop
    for mv in movies_snap.iter().filter(|v| v.backdrop_url.is_some()) {
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
