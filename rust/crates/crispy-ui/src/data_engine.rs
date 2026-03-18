//! DataEngine — the event-driven data pipeline for CrispyTivi UI.
//!
//! Owns the in-memory cache, processes prioritised event queues, and emits
//! `DataEvent`s back to the EventBridge. Runs entirely on a dedicated tokio
//! task; never touches Slint directly.
//!
//! # Queue priority
//! `tokio::select! { biased; }` drains `high_rx` before `normal_rx`, so
//! navigation and playback feel instantaneous even during background syncs.

use std::sync::{
    Arc,
    atomic::{AtomicU64, Ordering},
};

use chrono::Utc;
use crispy_server::CrispyService;
use crispy_server::models::Source;
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};

use crate::cache::{
    AppDataCache, FilterState, SEARCH_MAX_RESULTS, filter_channels, filter_vod, search_cached,
    source_to_info,
};
use crate::events::{
    DataEvent, HighPriorityEvent, LoadingKind, NormalEvent, Screen, SourceInfo, SyncResult, VodInfo,
};

// ── DataEngine ───────────────────────────────────────────────────────────────

pub struct DataEngine {
    provider: CrispyService,
    cache: AppDataCache,
    filters: FilterState,
    high_rx: mpsc::Receiver<HighPriorityEvent>,
    normal_rx: mpsc::Receiver<NormalEvent>,
    sync_result_rx: mpsc::Receiver<SyncResult>,
    data_tx: mpsc::Sender<DataEvent>,
    sync_result_tx: mpsc::Sender<SyncResult>,
    /// Arc so spawned search tasks can check if they are still current.
    search_generation: Arc<AtomicU64>,
    rt: tokio::runtime::Handle,
}

impl DataEngine {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        provider: CrispyService,
        high_rx: mpsc::Receiver<HighPriorityEvent>,
        normal_rx: mpsc::Receiver<NormalEvent>,
        sync_result_rx: mpsc::Receiver<SyncResult>,
        data_tx: mpsc::Sender<DataEvent>,
        sync_result_tx: mpsc::Sender<SyncResult>,
        rt: tokio::runtime::Handle,
    ) -> Self {
        Self {
            provider,
            cache: AppDataCache::empty(),
            filters: FilterState::default(),
            high_rx,
            normal_rx,
            sync_result_rx,
            data_tx,
            sync_result_tx,
            search_generation: Arc::new(AtomicU64::new(0)),
            rt,
        }
    }

    // ── Public entry-point ────────────────────────────────────────────────

    /// Run the DataEngine event loop. Consumes `self`.
    ///
    /// Call once from a dedicated tokio task.
    pub async fn run(mut self) {
        self.load_all_into_cache().await;
        self.emit_initial_data();

        loop {
            tokio::select! {
                biased;

                Some(event) = self.high_rx.recv() => {
                    self.handle_high(event).await;
                }

                Some(event) = self.normal_rx.recv() => {
                    self.handle_normal(event).await;
                }

                Some(result) = self.sync_result_rx.recv() => {
                    self.merge_sync_result(result);
                }

                // All senders dropped — shut down gracefully.
                else => {
                    info!("DataEngine: all channels closed, shutting down");
                    break;
                }
            }
        }
    }

    // ── Cache population ──────────────────────────────────────────────────

    async fn load_all_into_cache(&mut self) {
        // Sources
        self.cache.sources = self.provider.get_sources().unwrap_or_default();
        self.cache.source_stats = self.provider.get_source_stats().unwrap_or_default();

        // Collect all enabled source IDs
        let source_ids: Vec<String> = self
            .cache
            .sources
            .iter()
            .filter(|s| s.enabled)
            .map(|s| s.id.clone())
            .collect();

        // Channels
        self.cache.all_channels = if source_ids.is_empty() {
            Vec::new()
        } else {
            self.provider
                .get_channels_by_sources(&source_ids)
                .unwrap_or_default()
        };

        // VOD (all types)
        self.cache.all_vod = if source_ids.is_empty() {
            Vec::new()
        } else {
            self.provider
                .get_filtered_vod(&source_ids, None, None, None, "name")
                .unwrap_or_default()
        };

        // Favorites
        let fav_ids = self.provider.get_favorites("default").unwrap_or_default();
        self.cache.favorites = fav_ids.into_iter().collect();

        // Rebuild derived indexes
        self.cache.rebuild_groups();
        self.cache.rebuild_vod_categories();

        debug!(
            sources = self.cache.sources.len(),
            channels = self.cache.all_channels.len(),
            vod = self.cache.all_vod.len(),
            "Cache populated"
        );
    }

    // ── Initial emission ──────────────────────────────────────────────────

    fn emit_initial_data(&self) {
        // Sources
        let source_stats = &self.cache.source_stats;
        let sources: Vec<SourceInfo> = self
            .cache
            .sources
            .iter()
            .map(|s| {
                let stats = source_stats.iter().find(|st| st.source_id == s.id);
                source_to_info(s, stats)
            })
            .collect();
        self.send(DataEvent::SourcesReady { sources });

        // Channels — send ALL (WindowedModel handles windowing)
        self.send(DataEvent::LoadingStarted {
            kind: LoadingKind::Channels,
        });
        let (ch_all, total, _) = filter_channels(
            &self.cache.all_channels,
            &self.filters.active_group,
            &self.cache.favorites,
            0,
            usize::MAX,
        );
        self.send(DataEvent::ChannelsReady {
            channels: Arc::new(ch_all),
            groups: self.cache.channel_groups.clone(),
            total,
        });
        self.send(DataEvent::LoadingFinished {
            kind: LoadingKind::Channels,
        });

        // Movies — send ALL
        self.send(DataEvent::LoadingStarted {
            kind: LoadingKind::Movies,
        });
        let (mov_all, cats, total, _) = filter_vod(
            &self.cache.all_vod,
            "movie",
            &self.filters.active_vod_category,
            0,
            usize::MAX,
        );
        self.send(DataEvent::MoviesReady {
            movies: Arc::new(mov_all),
            categories: cats,
            total,
        });
        self.send(DataEvent::LoadingFinished {
            kind: LoadingKind::Movies,
        });

        // Series — send ALL
        self.send(DataEvent::LoadingStarted {
            kind: LoadingKind::Series,
        });
        let (ser_all, cats, total, _) = filter_vod(
            &self.cache.all_vod,
            "series",
            &self.filters.active_vod_category,
            0,
            usize::MAX,
        );
        self.send(DataEvent::SeriesReady {
            series: Arc::new(ser_all),
            categories: cats,
            total,
        });
        self.send(DataEvent::LoadingFinished {
            kind: LoadingKind::Series,
        });
    }

    // ── High-priority event handler ───────────────────────────────────────

    async fn handle_high(&mut self, event: HighPriorityEvent) {
        match event {
            HighPriorityEvent::Navigate { screen } => {
                self.filters.active_screen = screen;
                self.send(DataEvent::ScreenChanged { screen });
            }

            HighPriorityEvent::PlayChannel { channel_id } => {
                if let Some(ch) = self.cache.find_channel(&channel_id) {
                    let url = ch.stream_url.clone();
                    let title = ch.name.clone();
                    self.send(DataEvent::PlaybackReady { url, title });
                } else {
                    warn!(channel_id, "PlayChannel: channel not found in cache");
                    self.send(DataEvent::Error {
                        message: format!("Channel not found: {channel_id}"),
                    });
                }
            }

            HighPriorityEvent::PlayVod { vod_id } => {
                if let Some(vod) = self.cache.find_vod(&vod_id) {
                    let url = vod.stream_url.clone();
                    let title = vod.name.clone();
                    self.send(DataEvent::PlaybackReady { url, title });
                } else {
                    warn!(vod_id, "PlayVod: item not found in cache");
                    self.send(DataEvent::Error {
                        message: format!("VOD not found: {vod_id}"),
                    });
                }
            }

            HighPriorityEvent::FilterContent { query } => {
                self.filters.active_group = query;

                // Apply as a group filter on channels — send ALL to WindowedModel
                let (ch_all, total, _) = filter_channels(
                    &self.cache.all_channels,
                    &self.filters.active_group,
                    &self.cache.favorites,
                    0,
                    usize::MAX,
                );
                self.send(DataEvent::ChannelsReady {
                    channels: Arc::new(ch_all),
                    groups: self.cache.channel_groups.clone(),
                    total,
                });
            }

            HighPriorityEvent::Search { query } => {
                // Bump generation; spawned task will discard if superseded.
                let search_gen = self.search_generation.fetch_add(1, Ordering::SeqCst) + 1;

                if query.len() < 2 {
                    // Empty / too-short query — return empty results immediately
                    self.send(DataEvent::SearchResults {
                        query,
                        channels: Vec::new(),
                        movies: Vec::new(),
                        series: Vec::new(),
                    });
                    return;
                }

                self.send(DataEvent::LoadingStarted {
                    kind: LoadingKind::Search,
                });

                let channels_snap = self.cache.all_channels.clone();
                let vod_snap = self.cache.all_vod.clone();
                let gen_arc = Arc::clone(&self.search_generation);
                let data_tx = self.data_tx.clone();

                // Spawned task: 300ms debounce, then search_cached
                self.rt.spawn(async move {
                    tokio::time::sleep(std::time::Duration::from_millis(300)).await;

                    // Check if a newer search superseded this one
                    if gen_arc.load(Ordering::SeqCst) != search_gen {
                        debug!(search_gen, "Search superseded — discarding");
                        return;
                    }

                    let (ch_results, vod_results) =
                        search_cached(&channels_snap, &vod_snap, &query, SEARCH_MAX_RESULTS);

                    // Second generation check before emitting
                    if gen_arc.load(Ordering::SeqCst) != search_gen {
                        return;
                    }

                    let (movies, series): (Vec<VodInfo>, Vec<VodInfo>) = vod_results
                        .into_iter()
                        .partition(|v| v.item_type == "movie");

                    let event = DataEvent::SearchResults {
                        query,
                        channels: ch_results,
                        movies,
                        series,
                    };
                    let _ = data_tx.send(event).await;
                    let _ = data_tx
                        .send(DataEvent::LoadingFinished {
                            kind: LoadingKind::Search,
                        })
                        .await;
                });
            }

            HighPriorityEvent::ToggleChannelFavorite { channel_id } => {
                let is_now_fav = self.cache.toggle_favorite(&channel_id);
                debug!(channel_id, is_now_fav, "ToggleChannelFavorite");

                // Re-emit current channel page reflecting the change
                self.emit_filtered_channels();

                // Persist in background
                let svc = self.provider.clone();
                let cid = channel_id.clone();
                self.rt.spawn_blocking(move || {
                    let result = if is_now_fav {
                        svc.add_favorite("default", &cid)
                    } else {
                        svc.remove_favorite("default", &cid)
                    };
                    if let Err(e) = result {
                        error!(error = %e, channel_id = cid, "Failed to persist favorite");
                    }
                });
            }

            HighPriorityEvent::ToggleVodFavorite { vod_id } => {
                // VOD favorites use same toggle mechanism on the favorites set
                let is_now_fav = self.cache.toggle_favorite(&vod_id);
                debug!(vod_id, is_now_fav, "ToggleVodFavorite");

                self.emit_filtered_vod();

                let svc = self.provider.clone();
                let vid = vod_id.clone();
                self.rt.spawn_blocking(move || {
                    let result = if is_now_fav {
                        svc.add_favorite("default", &vid)
                    } else {
                        svc.remove_favorite("default", &vid)
                    };
                    if let Err(e) = result {
                        error!(error = %e, vod_id = vid, "Failed to persist VOD favorite");
                    }
                });
            }

            HighPriorityEvent::ChangeTheme { theme_name } => {
                let svc = self.provider.clone();
                let tn = theme_name.clone();
                self.rt.spawn_blocking(move || {
                    if let Err(e) = svc.set_setting("theme", &tn) {
                        error!(error = %e, "Failed to persist theme setting");
                    }
                });
                self.send(DataEvent::ThemeApplied { theme_name });
            }

            HighPriorityEvent::ChangeLanguage { language_tag } => {
                let svc = self.provider.clone();
                let lt = language_tag.clone();
                self.rt.spawn_blocking(move || {
                    if let Err(e) = svc.set_setting("language", &lt) {
                        error!(error = %e, "Failed to persist language setting");
                    }
                });
                self.send(DataEvent::LanguageApplied { language_tag });
            }

            HighPriorityEvent::OpenVodDetail { vod_id } => {
                // Navigation to detail screen is handled by EventBridge; DataEngine
                // just updates the active screen state.
                debug!(vod_id, "OpenVodDetail — navigating to detail");
                self.filters.active_screen = Screen::Movies;
                self.send(DataEvent::ScreenChanged {
                    screen: Screen::Movies,
                });
            }

            HighPriorityEvent::OpenSeriesDetail { series_id } => {
                debug!(series_id, "OpenSeriesDetail — navigating to detail");
                self.filters.active_screen = Screen::Series;
                self.send(DataEvent::ScreenChanged {
                    screen: Screen::Series,
                });
            }

            HighPriorityEvent::SelectEpgDate { offset_days } => {
                debug!(offset_days, "SelectEpgDate — EPG date navigation");
                // EPG data loading is handled by a future EPG module;
                // ScreenChanged drives the UI to refresh.
                self.send(DataEvent::ScreenChanged {
                    screen: Screen::Epg,
                });
            }

            HighPriorityEvent::JumpEpgToChannel { channel_id } => {
                debug!(channel_id, "JumpEpgToChannel");
                self.send(DataEvent::ScreenChanged {
                    screen: Screen::Epg,
                });
            }

            HighPriorityEvent::FilterVod {
                category,
                item_type,
            } => {
                self.filters.active_vod_category = category;
                match item_type.as_str() {
                    "movie" => {
                        let (all, cats, total, _) = filter_vod(
                            &self.cache.all_vod,
                            "movie",
                            &self.filters.active_vod_category,
                            0,
                            usize::MAX,
                        );
                        self.send(DataEvent::MoviesReady {
                            movies: Arc::new(all),
                            categories: cats,
                            total,
                        });
                    }
                    _ => {
                        let (all, cats, total, _) = filter_vod(
                            &self.cache.all_vod,
                            "series",
                            &self.filters.active_vod_category,
                            0,
                            usize::MAX,
                        );
                        self.send(DataEvent::SeriesReady {
                            series: Arc::new(all),
                            categories: cats,
                            total,
                        });
                    }
                }
            }
        }
    }

    // ── Normal-priority event handler ─────────────────────────────────────

    async fn handle_normal(&mut self, event: NormalEvent) {
        match event {
            NormalEvent::SaveSource { input } => {
                let source = Source {
                    id: format!("src_{}", Utc::now().timestamp_millis()),
                    name: input.name.clone(),
                    source_type: input.source_type.clone(),
                    url: input.url.clone(),
                    username: if input.username.is_empty() {
                        None
                    } else {
                        Some(input.username.clone())
                    },
                    password: if input.password.is_empty() {
                        None
                    } else {
                        Some(input.password.clone())
                    },
                    mac_address: if input.mac_address.is_empty() {
                        None
                    } else {
                        Some(input.mac_address.clone())
                    },
                    epg_url: if input.epg_url.is_empty() {
                        None
                    } else {
                        Some(input.epg_url.clone())
                    },
                    enabled: true,
                    access_token: None,
                    device_id: None,
                    user_id: None,
                    user_agent: None,
                    refresh_interval_minutes: 0,
                    accept_self_signed: false,
                    sort_order: 0,
                    last_sync_time: None,
                    last_sync_status: None,
                    last_sync_error: None,
                    created_at: None,
                    updated_at: None,
                };

                match self.provider.save_source(&source) {
                    Ok(()) => {
                        info!(name = %source.name, source_type = %source.source_type, "Source saved");
                        let source_id = source.id.clone();
                        let source_type = source.source_type.clone();
                        self.load_all_into_cache().await;
                        self.emit_initial_data();
                        // Trigger initial sync for the new source
                        self.spawn_sync(source_id, source_type);
                    }
                    Err(e) => {
                        error!(error = %e, "Failed to save source");
                        self.send(DataEvent::Error {
                            message: format!("Failed to save source: {e}"),
                        });
                    }
                }
            }

            NormalEvent::DeleteSource { source_id } => {
                match self.provider.delete_source(&source_id) {
                    Ok(()) => {
                        info!(source_id, "Source deleted");
                        // Evict from cache
                        self.cache.sources.retain(|s| s.id != source_id);
                        self.cache
                            .all_channels
                            .retain(|c| c.source_id.as_deref() != Some(&source_id));
                        self.cache
                            .all_vod
                            .retain(|v| v.source_id.as_deref() != Some(&source_id));
                        self.cache.rebuild_groups();
                        self.cache.rebuild_vod_categories();
                        self.emit_initial_data();
                    }
                    Err(e) => {
                        error!(error = %e, source_id, "Failed to delete source");
                        self.send(DataEvent::Error {
                            message: format!("Failed to delete source: {e}"),
                        });
                    }
                }
            }

            NormalEvent::SyncSource { source_id } => {
                // Determine source type for the sync dispatcher
                let source_type = self
                    .cache
                    .sources
                    .iter()
                    .find(|s| s.id == source_id)
                    .map(|s| s.source_type.clone())
                    .unwrap_or_default();

                self.send(DataEvent::LoadingStarted {
                    kind: LoadingKind::Sync,
                });
                self.send(DataEvent::SyncStarted {
                    source_id: source_id.clone(),
                });
                self.spawn_sync(source_id, source_type);
            }

            NormalEvent::SyncAll => {
                let sources_snap: Vec<(String, String)> = self
                    .cache
                    .sources
                    .iter()
                    .filter(|s| s.enabled)
                    .map(|s| (s.id.clone(), s.source_type.clone()))
                    .collect();

                self.send(DataEvent::LoadingStarted {
                    kind: LoadingKind::Sync,
                });
                for (source_id, source_type) in sources_snap {
                    self.send(DataEvent::SyncStarted {
                        source_id: source_id.clone(),
                    });
                    self.spawn_sync(source_id, source_type);
                }
            }

            NormalEvent::CompleteOnboarding => {
                if let Err(e) = self.provider.set_setting("onboarding_done", "true") {
                    error!(error = %e, "Failed to persist onboarding_done");
                }
                self.send(DataEvent::OnboardingDismissed);
                self.load_all_into_cache().await;
                self.emit_initial_data();
            }

            NormalEvent::RunDiagnostics => {
                let report = format!(
                    "sources={} channels={} vod={} groups={} categories={} favorites={}",
                    self.cache.sources.len(),
                    self.cache.all_channels.len(),
                    self.cache.all_vod.len(),
                    self.cache.channel_groups.len(),
                    self.cache.vod_categories.len(),
                    self.cache.favorites.len(),
                );
                self.send(DataEvent::DiagnosticsInfo { report });
            }

            NormalEvent::ClearWatchHistory => {
                info!("ClearWatchHistory: no-op until watch history is implemented");
            }

            NormalEvent::ExportSettings { path } => {
                info!(path, "ExportSettings requested — not yet implemented");
            }

            NormalEvent::ImportSettings { path } => {
                info!(path, "ImportSettings requested — not yet implemented");
            }

            NormalEvent::UpdateEpgMapping {
                channel_id,
                epg_channel_id,
            } => {
                info!(
                    channel_id,
                    epg_channel_id, "UpdateEpgMapping — not yet implemented"
                );
            }

            NormalEvent::RefreshEpg => {
                info!("RefreshEpg — not yet implemented");
            }
        }
    }

    // ── Sync result handler ───────────────────────────────────────────────

    fn merge_sync_result(&mut self, result: SyncResult) {
        match result {
            SyncResult::Success {
                ref source_id,
                channel_count,
                vod_count,
            } => {
                info!(
                    source_id,
                    channel_count, vod_count, "Sync completed successfully"
                );

                // Reload all data from DB into cache using the synchronous CrispyService calls.
                // merge_sync_result is called from the select! arm (sync context), so we use
                // the blocking equivalents that CrispyService exposes directly.
                self.cache.sources = self.provider.get_sources().unwrap_or_default();
                self.cache.source_stats = self.provider.get_source_stats().unwrap_or_default();

                let source_ids: Vec<String> = self
                    .cache
                    .sources
                    .iter()
                    .filter(|s| s.enabled)
                    .map(|s| s.id.clone())
                    .collect();

                self.cache.all_channels = if source_ids.is_empty() {
                    Vec::new()
                } else {
                    self.provider
                        .get_channels_by_sources(&source_ids)
                        .unwrap_or_default()
                };

                self.cache.all_vod = if source_ids.is_empty() {
                    Vec::new()
                } else {
                    self.provider
                        .get_filtered_vod(&source_ids, None, None, None, "name")
                        .unwrap_or_default()
                };

                let fav_ids = self.provider.get_favorites("default").unwrap_or_default();
                self.cache.favorites = fav_ids.into_iter().collect();

                self.cache.rebuild_groups();
                self.cache.rebuild_vod_categories();

                self.send(DataEvent::SyncCompleted { result });
                self.send(DataEvent::LoadingFinished {
                    kind: LoadingKind::Sync,
                });
                self.emit_initial_data();
            }

            SyncResult::Failed {
                ref source_id,
                ref error,
            } => {
                error!(source_id, error, "Sync failed");
                let sid = source_id.clone();
                let err = error.clone();
                self.send(DataEvent::SyncFailed {
                    source_id: sid,
                    error: err,
                });
                self.send(DataEvent::LoadingFinished {
                    kind: LoadingKind::Sync,
                });
            }
        }
    }

    // ── Sync task spawner ─────────────────────────────────────────────────

    /// Spawn an async sync task for the given source.
    ///
    /// Delegates to [`crate::sync_task::spawn_sync`] which owns the full
    /// dispatcher logic for M3U / Xtream / Stalker.
    fn spawn_sync(&self, source_id: String, source_type: String) {
        crate::sync_task::spawn_sync(
            &self.rt,
            self.provider.clone(),
            source_id,
            source_type,
            self.sync_result_tx.clone(),
        );
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    /// Send a `DataEvent` to the EventBridge, logging on failure.
    fn send(&self, event: DataEvent) {
        // data_tx is bounded; try_send to avoid blocking the event loop.
        // If the channel is full, the EventBridge is overwhelmed — log and drop.
        if let Err(e) = self.data_tx.try_send(event) {
            warn!(error = %e, "DataEngine: data_tx send failed (channel full or closed)");
        }
    }

    /// Re-emit all filtered channels (for WindowedModel).
    fn emit_filtered_channels(&self) {
        let (all, total, _) = filter_channels(
            &self.cache.all_channels,
            &self.filters.active_group,
            &self.cache.favorites,
            0,
            usize::MAX,
        );
        self.send(DataEvent::ChannelsReady {
            channels: Arc::new(all),
            groups: self.cache.channel_groups.clone(),
            total,
        });
    }

    /// Re-emit all filtered VOD items (movies + series) for WindowedModel.
    fn emit_filtered_vod(&self) {
        let (movies, cats, total, _) = filter_vod(
            &self.cache.all_vod,
            "movie",
            &self.filters.active_vod_category,
            0,
            usize::MAX,
        );
        self.send(DataEvent::MoviesReady {
            movies: Arc::new(movies),
            categories: cats,
            total,
        });

        let (series, cats, total, _) = filter_vod(
            &self.cache.all_vod,
            "series",
            &self.filters.active_vod_category,
            0,
            usize::MAX,
        );
        self.send(DataEvent::SeriesReady {
            series: Arc::new(series),
            categories: cats,
            total,
        });
    }
}
