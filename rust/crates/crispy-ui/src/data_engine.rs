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
    DataEvent, HighPriorityEvent, LoadingKind, NormalEvent, Screen, SourceInfo, SyncResult,
    VodInfo, WatchHistoryInfo,
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
    /// Receives DataChangeEvent notifications from CrispyService mutations.
    change_rx: mpsc::Receiver<crispy_core::events::DataChangeEvent>,
    /// Receives NetworkState updates from NetworkMonitor's watch channel.
    network_rx: tokio::sync::watch::Receiver<crispy_core::services::network_monitor::NetworkState>,
    /// Arc so spawned search tasks can check if they are still current.
    search_generation: Arc<AtomicU64>,
    rt: tokio::runtime::Handle,
    /// Shared data store — DataEngine populates EPG entries + profiles here
    /// so EventBridge can read them when building Slint property payloads.
    shared_data: std::sync::Arc<crate::event_bridge::SharedData>,
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
        change_rx: mpsc::Receiver<crispy_core::events::DataChangeEvent>,
        network_rx: tokio::sync::watch::Receiver<
            crispy_core::services::network_monitor::NetworkState,
        >,
        rt: tokio::runtime::Handle,
        shared_data: std::sync::Arc<crate::event_bridge::SharedData>,
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
            change_rx,
            network_rx,
            search_generation: Arc::new(AtomicU64::new(0)),
            rt,
            shared_data,
        }
    }

    // ── Public entry-point ────────────────────────────────────────────────

    /// Run the DataEngine event loop. Consumes `self`.
    ///
    /// Call once from a dedicated tokio task.
    pub async fn run(mut self) {
        let t0 = std::time::Instant::now();
        self.load_all_into_cache().await;
        info!(
            elapsed_ms = t0.elapsed().as_millis(),
            "[PERF] load_all_into_cache done"
        );
        let t1 = std::time::Instant::now();
        self.emit_initial_data();
        info!(
            elapsed_ms = t1.elapsed().as_millis(),
            "[PERF] emit_initial_data done"
        );

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

                Some(change) = self.change_rx.recv() => {
                    self.handle_data_change(change);
                }

                Ok(()) = self.network_rx.changed() => {
                    let state = *self.network_rx.borrow_and_update();
                    self.handle_network_change(state);
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

        // ── EPG entries → SharedData ──────────────────────────────────
        match self.provider.load_epg_entries() {
            Ok(epg_map) => {
                let count: usize = epg_map.values().map(|v| v.len()).sum();
                *self
                    .shared_data
                    .epg_entries
                    .lock()
                    .unwrap_or_else(|e| e.into_inner()) = epg_map;
                debug!(
                    entries = count,
                    "[CACHE] EPG entries loaded into SharedData"
                );
            }
            Err(e) => {
                error!(error = %e, "[CACHE] Failed to load EPG entries");
            }
        }

        // ── Profiles → SharedData ─────────────────────────────────────
        match self.provider.load_profiles() {
            Ok(profiles) => {
                // Determine active profile from settings (fallback: first profile)
                let active_id = self
                    .provider
                    .get_setting("crispy_tivi_active_profile_id")
                    .unwrap_or(None)
                    .unwrap_or_default();
                let resolved_active_id = if active_id.is_empty() {
                    profiles.first().map(|p| p.id.clone()).unwrap_or_default()
                } else {
                    active_id
                };
                debug!(
                    count = profiles.len(),
                    active = resolved_active_id,
                    "[CACHE] Profiles loaded into SharedData"
                );
                *self
                    .shared_data
                    .active_profile_id
                    .lock()
                    .unwrap_or_else(|e| e.into_inner()) = resolved_active_id;
                *self
                    .shared_data
                    .profiles
                    .lock()
                    .unwrap_or_else(|e| e.into_inner()) = profiles;
            }
            Err(e) => {
                error!(error = %e, "[CACHE] Failed to load profiles");
            }
        }

        // ── Recent searches → SharedData ──────────────────────────────
        let recent_queries: Vec<String> = self
            .provider
            .get_setting("recent_searches")
            .unwrap_or(None)
            .map(|raw| {
                // Parse a simple JSON string array: ["a","b","c"]
                raw.trim_matches(|c| c == '[' || c == ']')
                    .split(',')
                    .filter_map(|s| {
                        let trimmed = s.trim().trim_matches('"');
                        if trimmed.is_empty() {
                            None
                        } else {
                            Some(trimmed.replace("\\\"", "\""))
                        }
                    })
                    .collect()
            })
            .unwrap_or_default();
        *self
            .shared_data
            .recent_searches
            .lock()
            .unwrap_or_else(|e| e.into_inner()) = recent_queries;

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

        // Channels — send ALL (ScrollBridge handles windowing via VecModel slicing)
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

        // J-25: emit persisted recent searches so EventBridge can populate the UI model
        let queries = self
            .shared_data
            .recent_searches
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone();
        self.send(DataEvent::RecentSearchesReady { queries });
    }

    // ── High-priority event handler ───────────────────────────────────────

    async fn handle_high(&mut self, event: HighPriorityEvent) {
        match event {
            HighPriorityEvent::Navigate { screen } => {
                self.filters.active_screen = screen;
                self.send(DataEvent::ScreenChanged { screen });

                // J-40: load watch history when navigating to Library
                if screen == Screen::Library {
                    let svc = self.provider.clone();
                    match self
                        .rt
                        .spawn_blocking(move || svc.load_watch_history())
                        .await
                    {
                        Ok(Ok(entries)) => {
                            let infos = entries
                                .into_iter()
                                .map(|e| WatchHistoryInfo {
                                    id: e.id,
                                    name: e.name,
                                    media_type: e.media_type,
                                    stream_url: e.stream_url,
                                    position_ms: e.position_ms,
                                    duration_ms: e.duration_ms,
                                    watched_at: e.last_watched.format("%Y-%m-%d %H:%M").to_string(),
                                    poster_url: e.poster_url,
                                })
                                .collect();
                            self.send(DataEvent::WatchHistoryReady { entries: infos });
                        }
                        Ok(Err(e)) => {
                            error!(error = %e, "Failed to load watch history");
                        }
                        Err(e) => {
                            error!(error = %e, "load_watch_history task panicked");
                        }
                    }
                }
            }

            HighPriorityEvent::PlayChannel { channel_id } => {
                if let Some(ch) = self.cache.find_channel(&channel_id) {
                    let url = ch.stream_url.clone();
                    let title = ch.name.clone();
                    self.send(DataEvent::PlaybackReady { url, title });
                } else {
                    warn!(channel_id, "PlayChannel: channel not found in cache");
                    self.send(DataEvent::Error {
                        message: Self::sanitize_error_for_ui(&format!(
                            "Channel not found: {channel_id}"
                        )),
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
                        message: Self::sanitize_error_for_ui(&format!("VOD not found: {vod_id}")),
                    });
                }
            }

            HighPriorityEvent::FilterContent { query } => {
                self.filters.active_group = query;

                // Apply as a group filter on channels — send ALL; ScrollBridge windows the VecModel
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

            HighPriorityEvent::FilterVodCategory { category } => {
                self.filters.active_vod_category = category;
                self.emit_filtered_vod();
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
                self.filters.epg_date_offset = offset_days;
                self.filters.active_screen = Screen::Epg;

                let date_label = if offset_days == 0 {
                    "Today".to_string()
                } else if offset_days == -1 {
                    "Yesterday".to_string()
                } else if offset_days < 0 {
                    format!("{} days ago", -offset_days)
                } else {
                    format!("+{offset_days} days")
                };
                info!(offset_days, date_label, "EPG date selected");

                self.send(DataEvent::ScreenChanged {
                    screen: Screen::Epg,
                });
                self.send(DataEvent::DiagnosticsInfo {
                    report: format!("EPG date: {date_label} (offset {offset_days})"),
                });

                // Compute the [midnight, midnight+24h) UTC window for the selected day
                // and fetch all EPG entries that overlap it via the service layer.
                let now_date = Utc::now().date_naive();
                let target_date = now_date + chrono::Duration::days(i64::from(offset_days));
                let window_start = target_date
                    .and_hms_opt(0, 0, 0)
                    .expect("midnight always valid")
                    .and_utc()
                    .timestamp();
                let window_end = window_start + 86_400; // +24 h

                let channel_ids: Vec<String> = self
                    .cache
                    .all_channels
                    .iter()
                    .map(|c| c.id.clone())
                    .collect();

                if channel_ids.is_empty() {
                    debug!("SelectEpgDate: no channels in cache, skipping EPG fetch");
                } else {
                    let svc = self.provider.clone();
                    let data_tx = self.data_tx.clone();
                    self.rt.spawn_blocking(move || {
                        match svc.get_epgs_for_channels(&channel_ids, window_start, window_end) {
                            Ok(map) => {
                                // Flatten per-channel entries into a single time-sorted Vec.
                                let mut all: Vec<crispy_server::models::EpgEntry> =
                                    map.into_values().flatten().collect();
                                all.sort_by_key(|e| e.start_time);
                                let _ = data_tx.try_send(DataEvent::EpgProgrammesReady {
                                    window_start,
                                    window_end,
                                    programmes: Arc::new(all),
                                });
                            }
                            Err(e) => {
                                error!(error = %e, offset_days, "SelectEpgDate: EPG fetch failed");
                                let _ = data_tx.try_send(DataEvent::Error {
                                    message: Self::sanitize_error_for_ui(&format!(
                                        "EPG load failed for {date_label}: {e}"
                                    )),
                                });
                            }
                        }
                    });
                }
            }

            HighPriorityEvent::JumpEpgToChannel { channel_id } => {
                debug!(channel_id, "JumpEpgToChannel");
                self.filters.epg_focused_channel_id = channel_id.clone();
                self.filters.active_screen = Screen::Epg;
                // Look up the channel name for a more helpful log/diagnostic.
                let ch_name = self
                    .cache
                    .all_channels
                    .iter()
                    .find(|c| c.id == channel_id)
                    .map(|c| c.name.as_str())
                    .unwrap_or("unknown");
                info!(channel_id, ch_name, "EPG jump-to-channel");
                self.send(DataEvent::ScreenChanged {
                    screen: Screen::Epg,
                });
                // EpgFocusChannel tells EventBridge which channel the EPG grid
                // should scroll to and highlight.
                self.send(DataEvent::EpgFocusChannel {
                    channel_id: channel_id.clone(),
                });
                self.send(DataEvent::DiagnosticsInfo {
                    report: format!("EPG focus: channel '{ch_name}' ({channel_id})"),
                });
            }

            HighPriorityEvent::SearchEpg { query } => {
                let q = query.to_lowercase();
                let epg_map = self
                    .shared_data
                    .epg_entries
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .clone();

                let results: Vec<crispy_server::models::EpgEntry> = if q.is_empty() {
                    Vec::new()
                } else {
                    epg_map
                        .into_values()
                        .flatten()
                        .filter(|e| e.title.to_lowercase().contains(&q))
                        .collect()
                };

                debug!(query, count = results.len(), "SearchEpg: results filtered");
                self.send(DataEvent::EpgSearchResults {
                    query,
                    results: Arc::new(results),
                });
            }

            HighPriorityEvent::SelectSeriesSeason { series_id, season } => {
                debug!(series_id, season, "SelectSeriesSeason — loading episodes");
                let svc = self.provider.clone();
                let sid = series_id.clone();
                match self.rt.spawn_blocking(move || svc.load_vod_items()).await {
                    Ok(Ok(all_items)) => {
                        let episodes: Vec<VodInfo> = all_items
                            .iter()
                            .filter(|v| {
                                v.series_id.as_deref() == Some(sid.as_str())
                                    && v.season_number == Some(season)
                                    && v.item_type == "episode"
                            })
                            .map(crate::cache::vod_to_info)
                            .collect();
                        info!(
                            series_id,
                            season,
                            episode_count = episodes.len(),
                            "SelectSeriesSeason: episodes loaded"
                        );
                        // Episodes are delivered as a SeriesReady payload so EventBridge
                        // can populate the series_episodes VecModel without a new DataEvent
                        // variant (events.rs is frozen for new variants beyond this file).
                        self.send(DataEvent::SeriesReady {
                            series: Arc::new(episodes),
                            categories: vec![],
                            total: 0,
                        });
                    }
                    Ok(Err(e)) => {
                        error!(error = %e, series_id, season, "Failed to load episodes for season");
                        self.send(DataEvent::Error {
                            message: Self::sanitize_error_for_ui(&format!(
                                "Failed to load episodes for series {series_id} season {season}: {e}"
                            )),
                        });
                    }
                    Err(e) => {
                        error!(error = %e, "select_series_season task panicked");
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
                    credentials_encrypted: false,
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
                            message: Self::sanitize_error_for_ui(&format!(
                                "Failed to save source: {e}"
                            )),
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
                            message: Self::sanitize_error_for_ui(&format!(
                                "Failed to delete source: {e}"
                            )),
                        });
                    }
                }
            }

            NormalEvent::ToggleSourceEnabled { source_id } => {
                match self.provider.get_source(&source_id) {
                    Ok(Some(mut source)) => {
                        source.enabled = !source.enabled;
                        let new_state = source.enabled;
                        match self.provider.save_source(&source) {
                            Ok(()) => {
                                info!(source_id, enabled = new_state, "Source toggled");
                                if let Some(cached) =
                                    self.cache.sources.iter_mut().find(|s| s.id == source_id)
                                {
                                    cached.enabled = new_state;
                                }
                                // Re-emit sources list so the UI toggle button label updates.
                                let source_stats = &self.cache.source_stats;
                                let sources: Vec<SourceInfo> = self
                                    .cache
                                    .sources
                                    .iter()
                                    .map(|s| {
                                        let stats =
                                            source_stats.iter().find(|st| st.source_id == s.id);
                                        source_to_info(s, stats)
                                    })
                                    .collect();
                                self.send(DataEvent::SourcesReady { sources });
                            }
                            Err(e) => {
                                error!(error = %e, source_id, "Failed to toggle source");
                                self.send(DataEvent::Error {
                                    message: Self::sanitize_error_for_ui(&format!(
                                        "Failed to toggle source: {e}"
                                    )),
                                });
                            }
                        }
                    }
                    Ok(None) => {
                        error!(source_id, "ToggleSourceEnabled: source not found");
                    }
                    Err(e) => {
                        error!(error = %e, source_id, "ToggleSourceEnabled: DB error");
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

            NormalEvent::SaveProfile {
                id,
                name,
                is_child,
                max_allowed_rating,
                role,
            } => {
                let profile_id = id.clone();
                let profile = crispy_server::models::UserProfile {
                    id,
                    name,
                    avatar_index: 0,
                    pin: None,
                    is_child,
                    pin_version: 0,
                    max_allowed_rating,
                    role,
                    dvr_permission: 1,
                    dvr_quota_mb: None,
                };
                let svc = self.provider.clone();
                match self
                    .rt
                    .spawn_blocking(move || svc.save_profile(&profile))
                    .await
                {
                    Ok(Ok(())) => {
                        info!(profile_id = %profile_id, "Profile saved to DB");
                    }
                    Ok(Err(e)) => {
                        error!(error = %e, "Failed to save profile");
                        self.send(DataEvent::Error {
                            message: Self::sanitize_error_for_ui(&format!(
                                "Failed to save profile: {e}"
                            )),
                        });
                    }
                    Err(e) => {
                        error!(error = %e, "save_profile task panicked");
                    }
                }
            }

            NormalEvent::SavePreference { key, value } => {
                let svc = self.provider.clone();
                let k = key.clone();
                let v = value.clone();
                match self
                    .rt
                    .spawn_blocking(move || svc.set_setting(&k, &v))
                    .await
                {
                    Ok(Ok(())) => {
                        info!(key = %key, value = %value, "Preference saved");
                    }
                    Ok(Err(e)) => {
                        error!(error = %e, key = %key, "Failed to save preference");
                    }
                    Err(e) => {
                        error!(error = %e, "save_preference task panicked");
                    }
                }
            }
            // J-34: Export backup via crispy-core BackupService
            NormalEvent::ExportBackup => {
                let svc = self.provider.clone();
                match self
                    .rt
                    .spawn_blocking(move || crispy_core::backup::export_backup(&svc))
                    .await
                {
                    Ok(Ok(json)) => {
                        let filename = format!(
                            "crispy-backup-{}.json",
                            chrono::Utc::now().format("%Y%m%d-%H%M%S")
                        );
                        let base = std::env::var("HOME")
                            .or_else(|_| std::env::var("USERPROFILE"))
                            .unwrap_or_else(|_| ".".to_string());
                        let full_path = format!("{base}/{filename}");
                        match std::fs::write(&full_path, json.as_bytes()) {
                            Ok(()) => {
                                info!(path = %full_path, "Backup exported");
                                self.send(DataEvent::Error {
                                    message: format!("Backup saved to {full_path}"),
                                });
                            }
                            Err(e) => {
                                error!(error = %e, "Failed to write backup file");
                                self.send(DataEvent::Error {
                                    message: format!("Backup write failed: {e}"),
                                });
                            }
                        }
                    }
                    Ok(Err(e)) => {
                        error!(error = %e, "Backup export failed");
                        self.send(DataEvent::Error {
                            message: format!("Backup failed: {e}"),
                        });
                    }
                    Err(e) => {
                        error!(error = %e, "export_backup task panicked");
                    }
                }
            }

            // J-34: Import backup — merge sources/settings/profiles from JSON file
            NormalEvent::ImportBackup => {
                let base = std::env::var("HOME")
                    .or_else(|_| std::env::var("USERPROFILE"))
                    .unwrap_or_else(|_| ".".to_string());
                let full_path = format!("{base}/crispy-backup-import.json");
                match std::fs::read_to_string(&full_path) {
                    Ok(json) => {
                        let svc = self.provider.clone();
                        match self
                            .rt
                            .spawn_blocking(move || crispy_core::backup::import_backup(&svc, &json))
                            .await
                        {
                            Ok(Ok(summary)) => {
                                info!(?summary, "Backup imported");
                                self.send(DataEvent::Error {
                                    message: format!(
                                        "Backup imported: {} sources, {} profiles",
                                        summary.db_sources, summary.profiles
                                    ),
                                });
                            }
                            Ok(Err(e)) => {
                                error!(error = %e, "Backup import failed");
                                self.send(DataEvent::Error {
                                    message: format!("Import failed: {e}"),
                                });
                            }
                            Err(e) => {
                                error!(error = %e, "import_backup task panicked");
                            }
                        }
                    }
                    Err(e) => {
                        error!(error = %e, path = %full_path, "Cannot read backup file");
                        self.send(DataEvent::Error {
                            message: format!("Cannot read {full_path}: {e}"),
                        });
                    }
                }
            }

            // J-40: persist watch position (auto-save every 30s + on finish)
            NormalEvent::SaveWatchEntry {
                id,
                name,
                media_type,
                stream_url,
                position_ms,
                duration_ms,
                profile_id,
            } => {
                use crispy_core::algorithms::watch_history::derive_watch_history_id;
                use crispy_core::models::WatchHistory;

                let entry = WatchHistory {
                    id: if id.is_empty() {
                        derive_watch_history_id(&stream_url)
                    } else {
                        id
                    },
                    media_type,
                    name,
                    stream_url,
                    poster_url: None,
                    series_poster_url: None,
                    position_ms,
                    duration_ms,
                    last_watched: Utc::now().naive_utc(),
                    series_id: None,
                    season_number: None,
                    episode_number: None,
                    device_id: None,
                    device_name: None,
                    profile_id: Some(profile_id),
                    source_id: None,
                };
                let svc = self.provider.clone();
                match self
                    .rt
                    .spawn_blocking(move || svc.save_watch_history(&entry))
                    .await
                {
                    Ok(Ok(())) => {
                        debug!("Watch entry saved");
                    }
                    Ok(Err(e)) => {
                        error!(error = %e, "Failed to save watch entry");
                    }
                    Err(e) => {
                        error!(error = %e, "save_watch_entry task panicked");
                    }
                }
            }

            // J-47: GDPR Art. 17 — erase all personal data for the active profile
            NormalEvent::DeleteAllUserData { profile_id } => {
                let svc = self.provider.clone();
                match self
                    .rt
                    .spawn_blocking(move || -> Result<(), String> {
                        svc.clear_all()
                            .map_err(|e: crispy_core::database::DbError| e.to_string())?;
                        Ok(())
                    })
                    .await
                {
                    Ok(Ok(())) => {
                        info!(profile_id, "All user data deleted (GDPR)");
                        // Clear continue-watching lane immediately
                        self.send(DataEvent::ContinueWatchingReady { items: vec![] });
                        self.send(DataEvent::WatchHistoryReady { entries: vec![] });
                        self.send(DataEvent::Error {
                            message: "All your data has been deleted.".to_string(),
                        });
                    }
                    Ok(Err(e)) => {
                        error!(error = %e, "DeleteAllUserData failed");
                        self.send(DataEvent::Error {
                            message: format!("Delete failed: {e}"),
                        });
                    }
                    Err(e) => {
                        error!(error = %e, "delete_all_user_data task panicked");
                    }
                }
            }

            // J-17/J-21: load continue-watching items for the home lane
            NormalEvent::LoadContinueWatching { profile_id } => {
                use crispy_core::algorithms::watch_history::filter_continue_watching;
                let svc = self.provider.clone();
                let pid = profile_id.clone();
                match self
                    .rt
                    .spawn_blocking(move || svc.load_watch_history())
                    .await
                {
                    Ok(Ok(history)) => {
                        let items = filter_continue_watching(&history, None, Some(&pid))
                            .into_iter()
                            .map(|e| {
                                let progress = if e.duration_ms > 0 {
                                    (e.position_ms as f32 / e.duration_ms as f32).clamp(0.0, 1.0)
                                } else {
                                    0.0
                                };
                                crate::events::ContinueWatchingInfo {
                                    id: e.id,
                                    title: e.name,
                                    image_url: e.poster_url,
                                    progress,
                                    content_type: e.media_type,
                                }
                            })
                            .collect();
                        self.send(DataEvent::ContinueWatchingReady { items });
                    }
                    Ok(Err(e)) => {
                        error!(error = %e, "Failed to load continue-watching");
                    }
                    Err(e) => {
                        error!(error = %e, "load_continue_watching task panicked");
                    }
                }
            }

            // J-40: clear all watch history and notify UI
            NormalEvent::ClearWatchHistory { profile_id } => {
                let svc = self.provider.clone();
                match self
                    .rt
                    .spawn_blocking(move || svc.clear_all_watch_history())
                    .await
                {
                    Ok(Ok(deleted)) => {
                        info!(deleted, profile_id, "Watch history cleared");
                        self.send(DataEvent::WatchHistoryReady { entries: vec![] });
                    }
                    Ok(Err(e)) => {
                        error!(error = %e, "Failed to clear watch history");
                    }
                    Err(e) => {
                        error!(error = %e, "clear_watch_history task panicked");
                    }
                }
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
            self.data_tx.clone(),
        );
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    /// Sanitize an error string before sending it to the UI.
    ///
    /// Strips filesystem paths and truncates to 200 characters so internal
    /// details (absolute paths, stack traces) never reach the user-facing layer.
    fn sanitize_error_for_ui(error: &str) -> String {
        // Strip filesystem paths and truncate for user-facing display.
        let mut result = String::with_capacity(error.len());
        let mut chars = error.chars().peekable();
        while let Some(c) = chars.next() {
            // Detect Windows path: e.g. C:\...
            if c.is_ascii_alphabetic() {
                if chars.peek() == Some(&':') {
                    let mut lookahead = chars.clone();
                    lookahead.next(); // skip ':'
                    if lookahead.peek() == Some(&'\\') {
                        // Skip until whitespace or end
                        result.push_str("[path]");
                        for nc in chars.by_ref() {
                            if nc.is_whitespace() {
                                result.push(nc);
                                break;
                            }
                        }
                        continue;
                    }
                }
                result.push(c);
            } else if c == '/' {
                // Detect Unix absolute path: /foo/bar
                if chars.peek().is_some_and(|p| p.is_alphanumeric()) {
                    let rest: String = chars.clone().take_while(|ch| !ch.is_whitespace()).collect();
                    if rest.contains('/') {
                        result.push_str("[path]");
                        for nc in chars.by_ref() {
                            if nc.is_whitespace() {
                                result.push(nc);
                                break;
                            }
                        }
                        continue;
                    }
                }
                result.push(c);
            } else {
                result.push(c);
            }
        }
        if result.len() > 200 {
            let mut end = 197;
            while end > 0 && !result.is_char_boundary(end) {
                end -= 1;
            }
            format!("{}...", &result[..end])
        } else {
            result
        }
    }

    // ── DataChangeEvent subscriber ────────────────────────────────────────

    /// Handle a mutation event emitted by CrispyService after a DB write.
    ///
    /// Maps each `DataChangeEvent` variant to the appropriate cache
    /// invalidation + re-emit so the UI stays consistent without a full
    /// reload.
    fn handle_data_change(&mut self, event: crispy_core::events::DataChangeEvent) {
        use crispy_core::events::DataChangeEvent as DCE;
        debug!(?event, "[CHANGE] DataChangeEvent received");

        match event {
            // ── Channel-level mutations ───────────────────────────────
            DCE::ChannelsUpdated { source_id } => {
                debug!(
                    source_id,
                    "[CHANGE] ChannelsUpdated → reloading channel cache"
                );
                // Reload channels for the affected source from DB then re-emit.
                let svc = self.provider.clone();
                let sid = source_id.clone();
                if let Ok(Ok(new_channels)) = self.rt.block_on(
                    self.rt
                        .spawn_blocking(move || svc.get_channels_by_sources(&[sid])),
                ) {
                    // Merge into cache: replace entries for this source.
                    self.cache
                        .all_channels
                        .retain(|c| c.source_id.as_deref() != Some(source_id.as_str()));
                    self.cache.all_channels.extend(new_channels);
                    self.cache.rebuild_groups();
                }
                self.emit_filtered_channels();
            }

            DCE::ChannelOrderChanged => {
                debug!("[CHANGE] ChannelOrderChanged → re-emit channels");
                self.emit_filtered_channels();
            }

            DCE::CategoriesUpdated { .. } => {
                // Categories are derived from channels — re-emit current view.
                self.emit_filtered_channels();
            }

            // ── Favorite mutations ────────────────────────────────────
            DCE::FavoriteToggled {
                item_id,
                is_favorite,
            } => {
                debug!(
                    item_id,
                    is_favorite, "[CHANGE] FavoriteToggled → update cache"
                );
                if is_favorite {
                    self.cache.favorites.insert(item_id);
                } else {
                    self.cache.favorites.remove(&item_id);
                }
                self.emit_filtered_channels();
                self.emit_filtered_vod();
            }

            DCE::FavoriteCategoryToggled { .. } => {
                self.emit_filtered_channels();
                self.emit_filtered_vod();
            }

            DCE::VodFavoriteToggled {
                vod_id,
                is_favorite,
            } => {
                debug!(
                    vod_id,
                    is_favorite, "[CHANGE] VodFavoriteToggled → update cache"
                );
                if is_favorite {
                    self.cache.favorites.insert(vod_id);
                } else {
                    self.cache.favorites.remove(&vod_id);
                }
                self.emit_filtered_vod();
            }

            // ── VOD mutations ─────────────────────────────────────────
            DCE::VodUpdated { .. } => {
                debug!("[CHANGE] VodUpdated → reload VOD cache");
                let svc = self.provider.clone();
                let source_ids: Vec<String> = self
                    .cache
                    .sources
                    .iter()
                    .filter(|s| s.enabled)
                    .map(|s| s.id.clone())
                    .collect();
                if let Ok(Ok(vod)) = self.rt.block_on(self.rt.spawn_blocking(move || {
                    svc.get_filtered_vod(&source_ids, None, None, None, "name")
                })) {
                    self.cache.all_vod = vod;
                    self.cache.rebuild_vod_categories();
                }
                self.emit_filtered_vod();
            }

            DCE::VodWatchProgressUpdated { .. } => {
                // Progress bar update — no cache change needed, just re-emit.
                self.emit_filtered_vod();
            }

            // ── Bookmark mutations ────────────────────────────────────
            DCE::BookmarkChanged => {
                debug!("[CHANGE] BookmarkChanged → re-emit channels + vod");
                // Bookmarks affect both channel and VOD display indicators.
                self.emit_filtered_channels();
                self.emit_filtered_vod();
            }

            // ── Watch history ─────────────────────────────────────────
            DCE::WatchHistoryUpdated { .. } | DCE::WatchHistoryCleared => {
                // History changes affect the continue-watching lane.
                // Fire a LoadContinueWatching to reload with the default profile.
                let active_profile_id = self
                    .shared_data
                    .active_profile_id
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .clone();
                // Enqueue as a normal event so it runs through the standard path.
                let tx = self.data_tx.clone();
                let items_result = {
                    use crispy_core::algorithms::watch_history::filter_continue_watching;
                    let svc = self.provider.clone();
                    let pid = active_profile_id.clone();
                    self.rt.block_on(self.rt.spawn_blocking(move || {
                        svc.load_watch_history().map(|h| {
                            filter_continue_watching(&h, None, Some(&pid))
                                .into_iter()
                                .map(|e| {
                                    let progress = if e.duration_ms > 0 {
                                        (e.position_ms as f32 / e.duration_ms as f32)
                                            .clamp(0.0, 1.0)
                                    } else {
                                        0.0
                                    };
                                    crate::events::ContinueWatchingInfo {
                                        id: e.id,
                                        title: e.name,
                                        image_url: e.poster_url,
                                        progress,
                                        content_type: e.media_type,
                                    }
                                })
                                .collect::<Vec<_>>()
                        })
                    }))
                };
                match items_result {
                    Ok(Ok(items)) => {
                        if let Err(e) = tx.try_send(DataEvent::ContinueWatchingReady { items }) {
                            warn!(error = %e, "[CHANGE] ContinueWatchingReady dropped");
                        }
                    }
                    Ok(Err(e)) => error!(error = %e, "[CHANGE] Failed to reload continue-watching"),
                    Err(e) => error!(error = %e, "[CHANGE] spawn_blocking join error"),
                }
            }

            // ── Settings / UI state mutations ─────────────────────────
            DCE::SettingsUpdated { .. } => {
                // Settings changes are handled by HighPriorityEvent::ChangeTheme /
                // ChangeLanguage through the UI — nothing to re-emit from cache here.
                debug!("[CHANGE] SettingsUpdated (no cache action)");
            }

            DCE::SavedLayoutChanged
            | DCE::SearchHistoryChanged
            | DCE::ReminderChanged
            | DCE::SmartGroupChanged
            | DCE::CloudSyncCompleted => {
                debug!(?event, "[CHANGE] minor mutation — no cache refresh needed");
            }

            // ── Bulk refresh ──────────────────────────────────────────
            DCE::BulkDataRefresh => {
                debug!("[CHANGE] BulkDataRefresh → full reload");
                let rt = self.rt.clone();
                rt.block_on(self.load_all_into_cache());
                self.emit_initial_data();
            }

            // ── DVR / Recording ───────────────────────────────────────
            DCE::RecordingChanged { .. }
            | DCE::WatchlistUpdated { .. }
            | DCE::StorageBackendChanged { .. }
            | DCE::TransferTaskChanged { .. } => {
                debug!("[CHANGE] DVR/Watchlist/Storage change (no UI cache action)");
            }

            // ── Profile changes ───────────────────────────────────────
            DCE::ProfileChanged { .. } => {
                debug!("[CHANGE] ProfileChanged — no direct cache refresh needed");
            }

            // ── Source mutations ──────────────────────────────────────
            DCE::SourceChanged { .. } | DCE::SourceDeleted { .. } => {
                // Source add/edit/delete is handled via NormalEvent::SaveSource /
                // DeleteSource which already calls emit_initial_data(). A
                // DataChangeEvent here is informational — no extra reload needed.
                debug!("[CHANGE] SourceChanged/SourceDeleted (handled by NormalEvent path)");
            }

            // ── EPG ───────────────────────────────────────────────────
            DCE::EpgUpdated { .. } => {
                debug!("[CHANGE] EpgUpdated — EPG will reload on next EPG screen open");
            }
        }
    }

    // ── NetworkMonitor subscriber ─────────────────────────────────────────

    /// Handle a network state transition from `NetworkMonitor`.
    ///
    /// Converts `NetworkState` to the integer code used by `AppState.network-status`
    /// in the Slint UI (0 = online, 1 = offline, 2 = degraded, 3 = source unavailable)
    /// and emits a `DataEvent::NetworkStateChanged` so `apply_data_event` can update
    /// `AppState.is-offline` and `AppState.network-status`.
    fn handle_network_change(&self, state: crispy_core::services::network_monitor::NetworkState) {
        use crispy_core::services::network_monitor::NetworkState;
        let status = match state {
            NetworkState::Online => 0,
            NetworkState::Offline => 1,
            NetworkState::Degraded => 2,
        };
        debug!(status, "[NET] network state changed");
        self.send(DataEvent::NetworkStateChanged { status });
    }

    /// Send a `DataEvent` to the EventBridge, logging on failure.
    fn send(&self, event: DataEvent) {
        // data_tx is bounded; try_send to avoid blocking the event loop.
        // If the channel is full, the EventBridge is overwhelmed — log and drop.
        if let Err(e) = self.data_tx.try_send(event) {
            warn!(error = %e, "DataEngine: data_tx send failed (channel full or closed)");
        }
    }

    /// Re-emit all filtered channels; ScrollBridge in event_bridge.rs handles VecModel windowing.
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

    /// Re-emit all filtered VOD items (movies + series); ScrollBridge in event_bridge.rs windows them.
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
