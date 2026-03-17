//! Async data pipeline — all heavy DB queries run off the UI thread.
//!
//! Architecture:
//! - UI renders immediately with empty/loading state
//! - Data loads in background tokio tasks
//! - Results pushed to Slint via `invoke_from_event_loop`
//! - Pagination: channels/VOD load in pages (append, not replace)
//! - Search: debounced via generation counter

use crispy_server::CrispyService;
use crispy_server::models::{Channel, Source, SourceStats, VodItem};
use slint::{ComponentHandle, Model, ModelRc, SharedString, VecModel};
use std::rc::Rc;
use std::sync::atomic::{AtomicI32, AtomicU64, Ordering};
use std::sync::Arc;

use super::{AppState, AppWindow, ChannelData, SourceData, VodData};

/// Page size for lazy loading
const CHANNEL_PAGE_SIZE: i64 = 200;
const VOD_PAGE_SIZE: i64 = 100;

/// Shared async state — lives across callbacks, Send+Sync safe.
pub(crate) struct AsyncDataState {
    /// Search generation counter — incremented on each search request.
    /// Results from older generations are discarded.
    pub search_generation: AtomicU64,
    /// Current channel page offset
    pub channel_offset: AtomicI32,
    /// Current movie page offset
    pub movie_offset: AtomicI32,
    /// Current series page offset
    pub series_offset: AtomicI32,
}

impl AsyncDataState {
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            search_generation: AtomicU64::new(0),
            channel_offset: AtomicI32::new(0),
            movie_offset: AtomicI32::new(0),
            series_offset: AtomicI32::new(0),
        })
    }

    /// Reset all pagination offsets (e.g., after sync or source change).
    pub fn reset_offsets(&self) {
        self.channel_offset.store(0, Ordering::Relaxed);
        self.movie_offset.store(0, Ordering::Relaxed);
        self.series_offset.store(0, Ordering::Relaxed);
    }
}

// ── Source loading (lightweight — stays sync) ──

/// Load all sources into Slint. Fast (typically <10 sources).
pub(crate) fn load_sources(ui: &AppWindow, svc: &CrispyService) {
    let sources = match svc.get_sources() {
        Ok(s) => s,
        Err(e) => {
            tracing::error!(error = %e, "Failed to load sources");
            return;
        }
    };

    let all_stats = svc.get_source_stats().unwrap_or_default();

    let source_data: Vec<SourceData> = sources
        .iter()
        .map(|s| {
            let stats = all_stats.iter().find(|st| st.source_id == s.id);
            source_to_slint(s, stats)
        })
        .collect();

    let model = Rc::new(VecModel::from(source_data));
    ui.global::<AppState>().set_sources(ModelRc::from(model));

    tracing::debug!(count = sources.len(), "Sources loaded");
}

// ── Channel loading (async + paginated) ──

/// Load the first page of channels + groups. Resets pagination.
pub(crate) fn load_channels_first_page(
    rt: &tokio::runtime::Handle,
    svc: CrispyService,
    ui_weak: slint::Weak<AppWindow>,
    state: Arc<AsyncDataState>,
) {
    state.channel_offset.store(0, Ordering::Relaxed);

    // Set loading flag on UI thread immediately
    let ui_weak_flag = ui_weak.clone();
    slint::invoke_from_event_loop(move || {
        if let Some(ui) = ui_weak_flag.upgrade() {
            ui.global::<AppState>().set_is_loading_channels(true);
        }
    })
    .ok();

    rt.spawn_blocking(move || {
        let source_ids = get_source_ids(&svc);
        if source_ids.is_empty() {
            clear_loading_flag(&ui_weak, "channels");
            return;
        }

        // Load groups (fast — just distinct values)
        let mut groups: Vec<String> = svc
            .get_channels_by_sources(&source_ids)
            .unwrap_or_default()
            .iter()
            .filter_map(|c| c.channel_group.as_deref().map(String::from))
            .collect();
        groups.sort();
        groups.dedup();
        let group_strings: Vec<SharedString> = groups.iter().map(|g| g.into()).collect();

        // Load first page of channels
        let all_channels = svc.get_channels_by_sources(&source_ids).unwrap_or_default();
        let total = all_channels.len() as i32;
        let page: Vec<ChannelData> = all_channels
            .iter()
            .take(CHANNEL_PAGE_SIZE as usize)
            .map(channel_to_slint)
            .collect();
        let page_len = page.len() as i32;
        let has_more = page_len < total;

        state
            .channel_offset
            .store(page_len, Ordering::Relaxed);

        slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let app = ui.global::<AppState>();
                app.set_channels(ModelRc::from(Rc::new(VecModel::from(page))));
                app.set_channel_groups(ModelRc::from(Rc::new(VecModel::from(group_strings))));
                app.set_total_channel_count(total);
                app.set_has_more_channels(has_more);
                app.set_is_loading_channels(false);
            }
        })
        .ok();

        tracing::debug!(total, page = page_len, groups = groups.len(), "Channels first page loaded");
    });
}

/// Load the next page of channels (append to existing model).
pub(crate) fn load_channels_next_page(
    rt: &tokio::runtime::Handle,
    svc: CrispyService,
    ui_weak: slint::Weak<AppWindow>,
    state: Arc<AsyncDataState>,
) {
    let offset = state.channel_offset.load(Ordering::Relaxed);

    rt.spawn_blocking(move || {
        let source_ids = get_source_ids(&svc);
        if source_ids.is_empty() {
            return;
        }

        let all_channels = svc.get_channels_by_sources(&source_ids).unwrap_or_default();
        let total = all_channels.len() as i32;
        let page: Vec<ChannelData> = all_channels
            .iter()
            .skip(offset as usize)
            .take(CHANNEL_PAGE_SIZE as usize)
            .map(channel_to_slint)
            .collect();

        let new_offset = offset + page.len() as i32;
        let has_more = new_offset < total;
        state.channel_offset.store(new_offset, Ordering::Relaxed);

        slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let app = ui.global::<AppState>();
                // Append to existing model
                let existing = app.get_channels();
                let model = VecModel::default();
                for i in 0..existing.row_count() {
                    if let Some(item) = existing.row_data(i) {
                        model.push(item);
                    }
                }
                for item in page {
                    model.push(item);
                }
                app.set_channels(ModelRc::from(Rc::new(model)));
                app.set_has_more_channels(has_more);
            }
        })
        .ok();

        tracing::debug!(offset, new_offset, "Channels next page loaded");
    });
}

// ── VOD loading (async + paginated) ──

/// Load first page of movies and series. Resets pagination.
pub(crate) fn load_vod_first_page(
    rt: &tokio::runtime::Handle,
    svc: CrispyService,
    ui_weak: slint::Weak<AppWindow>,
    state: Arc<AsyncDataState>,
) {
    state.movie_offset.store(0, Ordering::Relaxed);
    state.series_offset.store(0, Ordering::Relaxed);

    let ui_weak_flag = ui_weak.clone();
    slint::invoke_from_event_loop(move || {
        if let Some(ui) = ui_weak_flag.upgrade() {
            ui.global::<AppState>().set_is_loading_vod(true);
        }
    })
    .ok();

    rt.spawn_blocking(move || {
        let source_ids = get_source_ids(&svc);
        if source_ids.is_empty() {
            clear_loading_flag(&ui_weak, "vod");
            return;
        }

        // Load ALL VOD (no type filter) — split by item_type in Rust
        let all_vod = svc
            .get_filtered_vod(&source_ids, None, None, None, "name")
            .unwrap_or_default();

        let mut movies_all: Vec<VodData> = Vec::new();
        let mut series_all: Vec<VodData> = Vec::new();

        for v in &all_vod {
            let item = vod_to_slint(v);
            match v.item_type.as_str() {
                "movie" => movies_all.push(item),
                "series" | "episode" => series_all.push(item),
                _ => movies_all.push(item),
            }
        }

        let total_movies = movies_all.len() as i32;
        let total_series = series_all.len() as i32;

        // First page of each
        let movies_page: Vec<VodData> = movies_all
            .into_iter()
            .take(VOD_PAGE_SIZE as usize)
            .collect();
        let series_page: Vec<VodData> = series_all
            .into_iter()
            .take(VOD_PAGE_SIZE as usize)
            .collect();

        let m_page_len = movies_page.len() as i32;
        let s_page_len = series_page.len() as i32;

        state.movie_offset.store(m_page_len, Ordering::Relaxed);
        state.series_offset.store(s_page_len, Ordering::Relaxed);

        slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let app = ui.global::<AppState>();
                app.set_movies(ModelRc::from(Rc::new(VecModel::from(movies_page))));
                app.set_series(ModelRc::from(Rc::new(VecModel::from(series_page))));
                app.set_total_movie_count(total_movies);
                app.set_total_series_count(total_series);
                app.set_has_more_movies(m_page_len < total_movies);
                app.set_has_more_series(s_page_len < total_series);
                app.set_is_loading_vod(false);
            }
        })
        .ok();

        tracing::debug!(
            total = all_vod.len(),
            movies = total_movies,
            series = total_series,
            "VOD first page loaded"
        );
    });
}

/// Load next page of movies (append).
pub(crate) fn load_more_movies(
    rt: &tokio::runtime::Handle,
    svc: CrispyService,
    ui_weak: slint::Weak<AppWindow>,
    state: Arc<AsyncDataState>,
) {
    let offset = state.movie_offset.load(Ordering::Relaxed);

    rt.spawn_blocking(move || {
        let source_ids = get_source_ids(&svc);
        let all_vod = svc
            .get_filtered_vod(&source_ids, None, None, None, "name")
            .unwrap_or_default();

        let movies: Vec<VodData> = all_vod
            .iter()
            .filter(|v| v.item_type == "movie" || (v.item_type != "series" && v.item_type != "episode"))
            .skip(offset as usize)
            .take(VOD_PAGE_SIZE as usize)
            .map(vod_to_slint)
            .collect();

        let total_movies = all_vod.iter().filter(|v| v.item_type == "movie").count() as i32;
        let new_offset = offset + movies.len() as i32;
        state.movie_offset.store(new_offset, Ordering::Relaxed);

        slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let app = ui.global::<AppState>();
                let existing = app.get_movies();
                let model = VecModel::default();
                for i in 0..existing.row_count() {
                    if let Some(item) = existing.row_data(i) {
                        model.push(item);
                    }
                }
                for item in movies {
                    model.push(item);
                }
                app.set_movies(ModelRc::from(Rc::new(model)));
                app.set_has_more_movies(new_offset < total_movies);
            }
        })
        .ok();
    });
}

/// Load next page of series (append).
pub(crate) fn load_more_series(
    rt: &tokio::runtime::Handle,
    svc: CrispyService,
    ui_weak: slint::Weak<AppWindow>,
    state: Arc<AsyncDataState>,
) {
    let offset = state.series_offset.load(Ordering::Relaxed);

    rt.spawn_blocking(move || {
        let source_ids = get_source_ids(&svc);
        let all_vod = svc
            .get_filtered_vod(&source_ids, None, None, None, "name")
            .unwrap_or_default();

        let series: Vec<VodData> = all_vod
            .iter()
            .filter(|v| v.item_type == "series" || v.item_type == "episode")
            .skip(offset as usize)
            .take(VOD_PAGE_SIZE as usize)
            .map(vod_to_slint)
            .collect();

        let total_series = all_vod
            .iter()
            .filter(|v| v.item_type == "series" || v.item_type == "episode")
            .count() as i32;
        let new_offset = offset + series.len() as i32;
        state.series_offset.store(new_offset, Ordering::Relaxed);

        slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let app = ui.global::<AppState>();
                let existing = app.get_series();
                let model = VecModel::default();
                for i in 0..existing.row_count() {
                    if let Some(item) = existing.row_data(i) {
                        model.push(item);
                    }
                }
                for item in series {
                    model.push(item);
                }
                app.set_series(ModelRc::from(Rc::new(model)));
                app.set_has_more_series(new_offset < total_series);
            }
        })
        .ok();
    });
}

// ── Search (async + generation counter) ──

/// Debounced async search. Discards results from stale generations.
pub(crate) fn search_async(
    rt: &tokio::runtime::Handle,
    svc: CrispyService,
    ui_weak: slint::Weak<AppWindow>,
    state: Arc<AsyncDataState>,
    query: String,
) {
    // Bump generation — any in-flight older search will be discarded
    let generation = state.search_generation.fetch_add(1, Ordering::SeqCst) + 1;

    if query.len() < 2 {
        return;
    }

    // Set searching flag
    let ui_weak_flag = ui_weak.clone();
    slint::invoke_from_event_loop(move || {
        if let Some(ui) = ui_weak_flag.upgrade() {
            ui.global::<AppState>().set_is_searching(true);
        }
    })
    .ok();

    let state_check = state.clone();
    rt.spawn_blocking(move || {
        // Small delay for debounce (300ms)
        std::thread::sleep(std::time::Duration::from_millis(300));

        // Check if a newer search superseded this one
        if state_check.search_generation.load(Ordering::SeqCst) != generation {
            tracing::debug!(generation, "Search superseded — discarding");
            return;
        }

        let source_ids = get_source_ids(&svc);
        let query_lower = query.to_lowercase();

        // Channel search — capped at 100 results
        let matched_channels: Vec<ChannelData> = svc
            .get_channels_by_sources(&source_ids)
            .unwrap_or_default()
            .iter()
            .filter(|c| c.name.to_lowercase().contains(&query_lower))
            .take(100)
            .map(channel_to_slint)
            .collect();

        // VOD search — uses DB LIKE filter
        let matched_vod: Vec<VodData> = svc
            .get_filtered_vod(&source_ids, None, None, Some(&query), "name")
            .unwrap_or_default()
            .iter()
            .take(100)
            .map(vod_to_slint)
            .collect();

        // Final generation check before pushing results
        if state_check.search_generation.load(Ordering::SeqCst) != generation {
            return;
        }

        slint::invoke_from_event_loop(move || {
            if let Some(ui) = ui_weak.upgrade() {
                let app = ui.global::<AppState>();
                app.set_search_channels(ModelRc::from(Rc::new(VecModel::from(matched_channels))));
                app.set_search_vod(ModelRc::from(Rc::new(VecModel::from(matched_vod))));
                app.set_is_searching(false);
            }
        })
        .ok();

        tracing::debug!(generation, query = %query, "Search complete");
    });
}

// ── Reload orchestration ──

/// Initial sync load — called before event loop (sources only, rest async).
pub(crate) fn load_initial(
    ui: &AppWindow,
    svc: &CrispyService,
    rt: &tokio::runtime::Handle,
    state: Arc<AsyncDataState>,
) {
    // Sources are tiny — load sync
    load_sources(ui, svc);

    // Heavy data loads go async — UI shows immediately
    load_channels_first_page(rt, svc.clone(), ui.as_weak(), state.clone());
    load_vod_first_page(rt, svc.clone(), ui.as_weak(), state);
}

/// Full async reload — after sync completion or source changes.
pub(crate) fn reload_all_async(
    rt: &tokio::runtime::Handle,
    svc: CrispyService,
    ui_weak: slint::Weak<AppWindow>,
    state: Arc<AsyncDataState>,
) {
    state.reset_offsets();

    // Sources on event loop (tiny)
    let svc_src = svc.clone();
    let ui_weak_src = ui_weak.clone();
    slint::invoke_from_event_loop(move || {
        if let Some(ui) = ui_weak_src.upgrade() {
            load_sources(&ui, &svc_src);
        }
    })
    .ok();

    // Heavy loads async
    load_channels_first_page(rt, svc.clone(), ui_weak.clone(), state.clone());
    load_vod_first_page(rt, svc, ui_weak, state);
}

// ── Helpers ──

fn get_source_ids(svc: &CrispyService) -> Vec<String> {
    svc.get_sources()
        .unwrap_or_default()
        .iter()
        .map(|s| s.id.clone())
        .collect()
}

fn clear_loading_flag(ui_weak: &slint::Weak<AppWindow>, kind: &str) {
    let ui_weak = ui_weak.clone();
    let kind = kind.to_string();
    slint::invoke_from_event_loop(move || {
        if let Some(ui) = ui_weak.upgrade() {
            let app = ui.global::<AppState>();
            match kind.as_str() {
                "channels" => app.set_is_loading_channels(false),
                "vod" => app.set_is_loading_vod(false),
                _ => {}
            }
        }
    })
    .ok();
}

// ── Conversion helpers ──

fn source_to_slint(s: &Source, stats: Option<&SourceStats>) -> SourceData {
    SourceData {
        id: s.id.clone().into(),
        name: s.name.clone().into(),
        source_type: s.source_type.clone().into(),
        url: s.url.clone().into(),
        username: s.username.clone().unwrap_or_default().into(),
        password: SharedString::default(),
        channel_count: stats.map(|st| st.channel_count as i32).unwrap_or(0),
        vod_count: stats.map(|st| st.vod_count as i32).unwrap_or(0),
        sync_status: s.last_sync_status.clone().unwrap_or_default().into(),
    }
}

fn channel_to_slint(c: &Channel) -> ChannelData {
    ChannelData {
        id: c.id.clone().into(),
        name: c.name.clone().into(),
        group: c.channel_group.clone().unwrap_or_default().into(),
        logo_url: c.logo_url.clone().unwrap_or_default().into(),
        stream_url: c.stream_url.clone().into(),
        source_id: c.source_id.clone().unwrap_or_default().into(),
        number: c.number.unwrap_or(0),
        is_favorite: c.is_favorite,
        now_playing: SharedString::default(),
    }
}

fn vod_to_slint(v: &VodItem) -> VodData {
    VodData {
        id: v.id.clone().into(),
        name: v.name.clone().into(),
        stream_url: v.stream_url.clone().into(),
        item_type: v.item_type.clone().into(),
        poster_url: v.poster_url.clone().unwrap_or_default().into(),
        genre: v.category.clone().unwrap_or_default().into(),
        year: v.year.map(|y| y.to_string()).unwrap_or_default().into(),
        rating: v.rating.clone().unwrap_or_default().into(),
        source_id: v.source_id.clone().unwrap_or_default().into(),
        series_id: v.series_id.clone().unwrap_or_default().into(),
        season: v.season_number.unwrap_or(0),
        episode: v.episode_number.unwrap_or(0),
    }
}
