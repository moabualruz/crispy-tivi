//! Data bridge — loads data from CrispyService into Slint models.

use crispy_server::CrispyService;
use crispy_server::models::{Channel, Source, SourceStats, VodItem};
use slint::{ComponentHandle, ModelRc, SharedString, VecModel};
use std::rc::Rc;

use super::{AppState, AppWindow, ChannelData, SourceData, VodData};

/// Load all sources from DB into Slint model.
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

/// Load channels for all sources.
pub(crate) fn load_channels(ui: &AppWindow, svc: &CrispyService) {
    let sources = match svc.get_sources() {
        Ok(s) => s,
        Err(e) => {
            tracing::error!(error = %e, "Failed to get sources for channels");
            return;
        }
    };

    let source_ids: Vec<String> = sources.iter().map(|s| s.id.clone()).collect();
    if source_ids.is_empty() {
        return;
    }

    let channels = match svc.get_channels_by_sources(&source_ids) {
        Ok(c) => c,
        Err(e) => {
            tracing::error!(error = %e, "Failed to load channels");
            return;
        }
    };

    // Extract unique groups
    let mut groups: Vec<String> = channels
        .iter()
        .filter_map(|c| c.channel_group.as_deref().map(String::from))
        .collect();
    groups.sort();
    groups.dedup();

    let channel_data: Vec<ChannelData> = channels.iter().map(channel_to_slint).collect();
    let group_strings: Vec<SharedString> = groups.iter().map(|g| g.into()).collect();

    let app_state = ui.global::<AppState>();
    app_state.set_channels(ModelRc::from(Rc::new(VecModel::from(channel_data))));
    app_state.set_channel_groups(ModelRc::from(Rc::new(VecModel::from(group_strings))));

    tracing::debug!(
        count = channels.len(),
        groups = groups.len(),
        "Channels loaded"
    );
}

/// Load VOD items (movies and series separately).
pub(crate) fn load_vod(ui: &AppWindow, svc: &CrispyService) {
    let sources = match svc.get_sources() {
        Ok(s) => s,
        Err(e) => {
            tracing::error!(error = %e, "Failed to get sources for VOD");
            return;
        }
    };

    let source_ids: Vec<String> = sources.iter().map(|s| s.id.clone()).collect();
    if source_ids.is_empty() {
        return;
    }

    // Load movies
    let movies = svc
        .get_filtered_vod(&source_ids, Some("movie"), None, None, "name")
        .unwrap_or_default();
    let movie_data: Vec<VodData> = movies.iter().map(vod_to_slint).collect();

    // Load series
    let series = svc
        .get_filtered_vod(&source_ids, Some("series"), None, None, "name")
        .unwrap_or_default();
    let series_data: Vec<VodData> = series.iter().map(vod_to_slint).collect();

    let app_state = ui.global::<AppState>();
    app_state.set_movies(ModelRc::from(Rc::new(VecModel::from(movie_data))));
    app_state.set_series(ModelRc::from(Rc::new(VecModel::from(series_data))));

    tracing::debug!(movies = movies.len(), series = series.len(), "VOD loaded");
}

/// Reload all data after sync or source changes.
pub(crate) fn reload_all(ui: &AppWindow, svc: &CrispyService) {
    load_sources(ui, svc);
    load_channels(ui, svc);
    load_vod(ui, svc);
}

/// Search channels and VOD by query text.
pub(crate) fn perform_search(ui: &AppWindow, svc: &CrispyService, query: &str) {
    let sources = svc.get_sources().unwrap_or_default();
    let source_ids: Vec<String> = sources.iter().map(|s| s.id.clone()).collect();

    let query_lower = query.to_lowercase();

    // Search channels by name
    let all_channels = svc.get_channels_by_sources(&source_ids).unwrap_or_default();
    let matched_channels: Vec<ChannelData> = all_channels
        .iter()
        .filter(|c| c.name.to_lowercase().contains(&query_lower))
        .map(channel_to_slint)
        .collect();

    // Search VOD by name
    let matched_vod: Vec<VodData> = svc
        .get_filtered_vod(&source_ids, None, None, Some(query), "name")
        .unwrap_or_default()
        .iter()
        .map(vod_to_slint)
        .collect();

    let app_state = ui.global::<AppState>();
    app_state.set_search_channels(ModelRc::from(Rc::new(VecModel::from(matched_channels))));
    app_state.set_search_vod(ModelRc::from(Rc::new(VecModel::from(matched_vod))));

    tracing::debug!(query, "Search complete");
}

// ── Conversion helpers ──────────────────────────────

fn source_to_slint(s: &Source, stats: Option<&SourceStats>) -> SourceData {
    SourceData {
        id: s.id.clone().into(),
        name: s.name.clone().into(),
        source_type: s.source_type.clone().into(),
        url: s.url.clone().into(),
        username: s.username.clone().unwrap_or_default().into(),
        password: SharedString::default(), // Never expose passwords to UI
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
