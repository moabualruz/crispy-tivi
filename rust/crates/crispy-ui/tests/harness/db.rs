//! Test database and settings loader for the screenshot testing pipeline.
//!
//! Provides [`TestDb`] — a freshly seeded in-memory [`CrispyService`] ready
//! for UI harness tests.  Settings and seed data are loaded from JSON fixtures
//! under `tests/fixtures/`, with optional `.local` overrides that are never
//! committed to git.

use std::collections::HashMap;
use std::path::PathBuf;

use crispy_core::models::{Channel, EpgEntry, Source, UserProfile, VodItem};
use crispy_core::services::CrispyService;
use slint::{ComponentHandle, ModelRc, SharedString, VecModel};

// ── Fixture path resolution ───────────────────────────────────────────────────

fn fixtures_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
}

fn load_json<T: serde::de::DeserializeOwned>(path: &PathBuf) -> Result<T, String> {
    let raw = std::fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))?;
    serde_json::from_str(&raw).map_err(|e| format!("parse {}: {e}", path.display()))
}

// ── TestSettings ─────────────────────────────────────────────────────────────

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestSettings {
    pub sources: Vec<TestSource>,
    pub profiles: Vec<TestProfile>,
    pub settings: TestAppSettings,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestSource {
    pub name: String,
    #[serde(rename = "type")]
    pub source_type: String,
    pub url: Option<String>,
    pub server: Option<String>,
    pub username: Option<String>,
    pub password: Option<String>,
    pub portal_url: Option<String>,
    pub mac_address: Option<String>,
    pub epg_url: Option<String>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestProfile {
    pub name: String,
    pub is_kids: bool,
    pub pin: Option<String>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestAppSettings {
    pub language: String,
    pub theme: String,
    pub autoplay_next: bool,
    pub default_quality: String,
}

// ── TestSeed ──────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestSeed {
    pub channels: Vec<TestChannel>,
    pub epg: Vec<TestEpgChannel>,
    pub movies: Vec<TestMovie>,
    pub series: Vec<TestSeries>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestChannel {
    pub name: String,
    pub group: Option<String>,
    pub logo_url: Option<String>,
    pub stream_url: String,
    /// Name of the source in `TestSettings.sources` that owns this channel.
    pub source_ref: String,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestEpgChannel {
    /// Matches `TestChannel.name` to resolve the DB channel id.
    pub channel_ref: String,
    pub programs: Vec<TestEpgProgram>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestEpgProgram {
    pub title: String,
    /// ISO-8601 UTC timestamp, e.g. `"2026-03-19T06:00:00Z"`.
    pub start: String,
    /// ISO-8601 UTC timestamp.
    pub end: String,
    pub category: Option<String>,
    pub description: Option<String>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestMovie {
    pub name: String,
    pub genre: Option<String>,
    pub year: Option<i32>,
    pub rating: Option<f64>,
    pub poster_url: Option<String>,
    pub stream_url: String,
    pub source_ref: String,
    pub description: Option<String>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestSeries {
    pub name: String,
    pub genre: Option<String>,
    pub poster_url: Option<String>,
    pub source_ref: String,
    pub description: Option<String>,
    pub seasons: Vec<TestSeason>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestSeason {
    pub number: i32,
    pub episodes: Vec<TestEpisode>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct TestEpisode {
    pub number: i32,
    pub title: String,
    pub stream_url: String,
}

// ── Loader helpers ────────────────────────────────────────────────────────────

fn load_settings() -> TestSettings {
    let base_path = fixtures_dir().join("test-settings.json");
    let base: TestSettings = load_json(&base_path).expect("test-settings.json must be valid");

    let local_path = fixtures_dir().join("test-settings.local.json");
    match load_json::<TestSettings>(&local_path) {
        Ok(local) => merge_settings(base, local),
        Err(_) => base, // .local file absent or unreadable — not an error
    }
}

fn load_seed() -> TestSeed {
    let base_path = fixtures_dir().join("test-seed.json");
    let base: TestSeed = load_json(&base_path).expect("test-seed.json must be valid");

    let local_path = fixtures_dir().join("test-seed.local.json");
    match load_json::<TestSeed>(&local_path) {
        Ok(local) => merge_seed(base, local),
        Err(_) => base,
    }
}

/// Local overrides replace the entire top-level list when non-empty;
/// if a local list is empty the base list is kept intact.
fn merge_settings(base: TestSettings, local: TestSettings) -> TestSettings {
    TestSettings {
        sources: if local.sources.is_empty() {
            base.sources
        } else {
            local.sources
        },
        profiles: if local.profiles.is_empty() {
            base.profiles
        } else {
            local.profiles
        },
        settings: local.settings, // always override scalar settings block
    }
}

fn merge_seed(base: TestSeed, local: TestSeed) -> TestSeed {
    TestSeed {
        channels: if local.channels.is_empty() {
            base.channels
        } else {
            local.channels
        },
        epg: if local.epg.is_empty() {
            base.epg
        } else {
            local.epg
        },
        movies: if local.movies.is_empty() {
            base.movies
        } else {
            local.movies
        },
        series: if local.series.is_empty() {
            base.series
        } else {
            local.series
        },
    }
}

// ── TestDb ────────────────────────────────────────────────────────────────────

pub struct TestDb {
    service: CrispyService,
    settings: TestSettings,
    seed: TestSeed,
}

impl TestDb {
    /// Create a fresh in-memory service, insert all fixture sources and seed
    /// data, and return a ready-to-use `TestDb`.
    pub fn init() -> Self {
        let service = CrispyService::open_in_memory().expect("in-memory CrispyService");
        let settings = load_settings();
        let seed = load_seed();

        let db = TestDb {
            service,
            settings,
            seed,
        };
        db.insert_sources();
        db.insert_profiles();
        db.insert_seed_channels();
        db.insert_seed_movies();
        db.insert_seed_series();
        db.insert_seed_epg();
        db
    }

    /// Create a fresh in-memory service for E2E testing.
    ///
    /// Sources and profiles are loaded from settings (including `.local`
    /// overrides when present), but **no seed data** is inserted.  The E2E
    /// journey flow is expected to trigger real network sync from scratch.
    ///
    /// If `test-settings.local.json` is absent this method behaves identically
    /// to [`init`] but without seed data — callers should gate E2E runs on the
    /// presence of that file.
    pub fn init_e2e() -> Self {
        let service = CrispyService::open_in_memory().expect("in-memory CrispyService");
        let settings = load_settings();
        let seed = TestSeed {
            channels: vec![],
            epg: vec![],
            movies: vec![],
            series: vec![],
        };
        let db = TestDb {
            service,
            settings,
            seed,
        };
        db.insert_sources();
        db.insert_profiles();
        db.sync_sources_e2e();
        db
    }

    pub fn service(&self) -> &CrispyService {
        &self.service
    }

    pub fn settings(&self) -> &TestSettings {
        &self.settings
    }

    pub fn seed(&self) -> &TestSeed {
        &self.seed
    }

    // ── Private seed helpers ─────────────────────────────────────────────────

    fn insert_sources(&self) {
        for (i, ts) in self.settings.sources.iter().enumerate() {
            let source = Self::map_source(ts, i);
            self.service
                .save_source(&source)
                .unwrap_or_else(|e| panic!("insert source '{}': {e}", ts.name));
        }
    }

    fn insert_profiles(&self) {
        for (i, tp) in self.settings.profiles.iter().enumerate() {
            let profile = UserProfile {
                id: format!("profile_{i}"),
                name: tp.name.clone(),
                avatar_index: 0,
                pin: tp.pin.clone(),
                is_child: tp.is_kids,
                pin_version: 0,
                max_allowed_rating: if tp.is_kids { 2 } else { 4 },
                role: 1,
                dvr_permission: 2,
                dvr_quota_mb: None,
            };
            self.service
                .save_profile(&profile)
                .unwrap_or_else(|e| panic!("insert profile '{}': {e}", tp.name));
        }
    }

    /// Sync all inserted sources against real servers (E2E pipeline only).
    ///
    /// Each source is dispatched to the correct sync backend (M3U, Xtream,
    /// Stalker) based on `source_type`. Network failures and timeouts are
    /// logged via `eprintln!` and skipped — the pipeline continues with
    /// whatever data was successfully fetched.
    fn sync_sources_e2e(&self) {
        use crispy_core::services::{m3u_sync, stalker_sync, xtream_sync};

        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .worker_threads(2)
            .build()
            .expect("tokio runtime for E2E sync");
        let sources = self.service.get_sources().unwrap_or_default();

        for source in &sources {
            eprintln!(
                "[E2E] Syncing source: {} (type={})",
                source.name, source.source_type
            );

            let result: Result<_, String> = match source.source_type.as_str() {
                "m3u" => {
                    let url = source.url.clone();
                    let sid = source.id.clone();
                    let tls = source.accept_self_signed;
                    let svc = &self.service;
                    match rt.block_on(async {
                        tokio::time::timeout(
                            std::time::Duration::from_secs(60),
                            m3u_sync::sync_m3u_source(svc, &url, &sid, tls),
                        )
                        .await
                    }) {
                        Ok(Ok(_report)) => Ok(()),
                        Ok(Err(e)) => Err(format!("{e}")),
                        Err(_) => Err("timeout (60s)".to_string()),
                    }
                }
                "xtream" => {
                    let url = source.url.clone();
                    let user = source.username.clone().unwrap_or_default();
                    let pass = source.password.clone().unwrap_or_default();
                    let sid = source.id.clone();
                    let tls = source.accept_self_signed;
                    let svc = &self.service;
                    match rt.block_on(async {
                        tokio::time::timeout(
                            std::time::Duration::from_secs(60),
                            xtream_sync::sync_xtream_source(svc, &url, &user, &pass, &sid, tls),
                        )
                        .await
                    }) {
                        Ok(Ok(_report)) => Ok(()),
                        Ok(Err(e)) => Err(format!("{e}")),
                        Err(_) => Err("timeout (60s)".to_string()),
                    }
                }
                "stalker" => {
                    let url = source.url.clone();
                    let mac = source.mac_address.clone().unwrap_or_default();
                    let sid = source.id.clone();
                    let tls = source.accept_self_signed;
                    let svc = &self.service;
                    match rt.block_on(async {
                        tokio::time::timeout(
                            std::time::Duration::from_secs(60),
                            stalker_sync::sync_stalker_source(svc, &url, &mac, &sid, tls),
                        )
                        .await
                    }) {
                        Ok(Ok(_report)) => Ok(()),
                        Ok(Err(e)) => Err(format!("{e}")),
                        Err(_) => Err("timeout (60s)".to_string()),
                    }
                }
                other => Err(format!("unsupported source type '{other}' — skipped")),
            };

            match result {
                Ok(()) => eprintln!("[E2E] Sync complete: {}", source.name),
                Err(e) => eprintln!("[E2E] Sync failed for {}: {e}", source.name),
            }
        }
    }

    /// Build a name→source_id lookup from the already-inserted sources.
    fn source_id_map(&self) -> HashMap<String, String> {
        self.service
            .get_sources()
            .unwrap_or_default()
            .into_iter()
            .map(|s| (s.name.clone(), s.id.clone()))
            .collect()
    }

    fn insert_seed_channels(&self) {
        let id_map = self.source_id_map();
        let channels: Vec<Channel> = self
            .seed
            .channels
            .iter()
            .enumerate()
            .map(|(i, tc)| {
                let source_id = id_map.get(&tc.source_ref).cloned();
                Channel {
                    id: format!("ch_{i}"),
                    name: tc.name.clone(),
                    stream_url: tc.stream_url.clone(),
                    number: Some((i + 1) as i32),
                    channel_group: tc.group.clone(),
                    logo_url: tc.logo_url.clone(),
                    tvg_id: None,
                    tvg_name: None,
                    is_favorite: false,
                    user_agent: None,
                    has_catchup: false,
                    catchup_days: 0,
                    catchup_type: None,
                    catchup_source: None,
                    resolution: None,
                    source_id,
                    added_at: None,
                    updated_at: None,
                    is_247: false,
                }
            })
            .collect();

        if !channels.is_empty() {
            self.service
                .save_channels(&channels)
                .expect("insert seed channels");
        }
    }

    fn insert_seed_movies(&self) {
        let id_map = self.source_id_map();
        let movies: Vec<VodItem> = self
            .seed
            .movies
            .iter()
            .enumerate()
            .map(|(i, tm)| {
                let source_id = id_map.get(&tm.source_ref).cloned();
                VodItem {
                    id: format!("movie_{i}"),
                    name: tm.name.clone(),
                    stream_url: tm.stream_url.clone(),
                    item_type: "movie".to_string(),
                    poster_url: tm.poster_url.clone(),
                    backdrop_url: None,
                    description: tm.description.clone(),
                    rating: tm.rating.map(|r| r.to_string()),
                    year: tm.year,
                    duration: None,
                    category: tm.genre.clone(),
                    series_id: None,
                    season_number: None,
                    episode_number: None,
                    ext: None,
                    is_favorite: false,
                    added_at: None,
                    updated_at: None,
                    source_id,
                }
            })
            .collect();

        if !movies.is_empty() {
            self.service
                .save_vod_items(&movies)
                .expect("insert seed movies");
        }
    }

    fn insert_seed_series(&self) {
        let id_map = self.source_id_map();
        let mut episodes: Vec<VodItem> = Vec::new();

        for (si, ts) in self.seed.series.iter().enumerate() {
            let source_id = id_map.get(&ts.source_ref).cloned();
            let series_id = format!("series_{si}");

            for season in &ts.seasons {
                for ep in &season.episodes {
                    let ep_id = format!("series_{si}_s{:02}e{:02}", season.number, ep.number);
                    episodes.push(VodItem {
                        id: ep_id,
                        name: ep.title.clone(),
                        stream_url: ep.stream_url.clone(),
                        item_type: "episode".to_string(),
                        poster_url: ts.poster_url.clone(),
                        backdrop_url: None,
                        description: ts.description.clone(),
                        rating: None,
                        year: None,
                        duration: None,
                        category: ts.genre.clone(),
                        series_id: Some(series_id.clone()),
                        season_number: Some(season.number),
                        episode_number: Some(ep.number),
                        ext: None,
                        is_favorite: false,
                        added_at: None,
                        updated_at: None,
                        source_id: source_id.clone(),
                    });
                }
            }
        }

        if !episodes.is_empty() {
            self.service
                .save_vod_items(&episodes)
                .expect("insert seed episodes");
        }
    }

    fn insert_seed_epg(&self) {
        // Build channel name → DB id lookup from already-inserted channels.
        let channel_name_to_id: HashMap<String, String> = self
            .service
            .load_channels()
            .unwrap_or_default()
            .into_iter()
            .map(|c| (c.name.clone(), c.id.clone()))
            .collect();

        let source_id_map = self.source_id_map();
        // Use the first source id as a fallback for EPG entries.
        let fallback_source_id = source_id_map.values().next().cloned();

        let mut entries_by_channel: HashMap<String, Vec<EpgEntry>> = HashMap::new();

        for tec in &self.seed.epg {
            let channel_id = match channel_name_to_id.get(&tec.channel_ref) {
                Some(id) => id.clone(),
                None => {
                    // Channel not found — skip EPG for it rather than panic.
                    continue;
                }
            };

            let programs: Vec<EpgEntry> = tec
                .programs
                .iter()
                .filter_map(|p| {
                    let start = chrono::DateTime::parse_from_rfc3339(&p.start)
                        .ok()?
                        .naive_utc();
                    let end = chrono::DateTime::parse_from_rfc3339(&p.end)
                        .ok()?
                        .naive_utc();
                    Some(EpgEntry {
                        channel_id: channel_id.clone(),
                        title: p.title.clone(),
                        start_time: start,
                        end_time: end,
                        description: p.description.clone(),
                        category: p.category.clone(),
                        icon_url: None,
                        source_id: fallback_source_id.clone(),
                    })
                })
                .collect();

            entries_by_channel
                .entry(channel_id)
                .or_default()
                .extend(programs);
        }

        if !entries_by_channel.is_empty() {
            self.service
                .save_epg_entries(&entries_by_channel)
                .expect("insert seed EPG");
        }
    }

    // ── Source mapping ───────────────────────────────────────────────────────

    fn map_source(ts: &TestSource, index: usize) -> Source {
        // Xtream: use `server` field as `url`; Stalker: use `portal_url`.
        let url = ts
            .url
            .clone()
            .or_else(|| ts.server.clone())
            .or_else(|| ts.portal_url.clone())
            .unwrap_or_default();

        Source {
            id: format!("test_src_{index}"),
            name: ts.name.clone(),
            source_type: ts.source_type.clone(),
            url,
            username: ts.username.clone(),
            password: ts.password.clone(),
            access_token: None,
            device_id: None,
            user_id: None,
            mac_address: ts.mac_address.clone(),
            epg_url: ts.epg_url.clone(),
            user_agent: None,
            refresh_interval_minutes: 60,
            accept_self_signed: false,
            enabled: true,
            sort_order: index as i32,
            last_sync_time: None,
            last_sync_status: None,
            last_sync_error: None,
            created_at: None,
            updated_at: None,
            credentials_encrypted: false,
        }
    }
}

// ── UI population ─────────────────────────────────────────────────────────────

/// Populate the Slint `AppWindow` globals with data from the `CrispyService` DB.
///
/// This mimics what `DataEngine::load_all_into_cache` + `apply_data_event` do in
/// the real app, but runs synchronously on the UI thread so screenshot journeys
/// start with fully-seeded models rather than empty `VecModel`s.
///
/// Call this right after `AppWindow::new()` and before any journey step runs.
pub fn populate_ui(ui: &crate::AppWindow, service: &CrispyService) {
    use crate::{AppState, OnboardingState};

    let app = ui.global::<AppState>();

    // ── Sources ──────────────────────────────────────────────────────────────
    let sources = service.get_sources().unwrap_or_default();
    let source_count = sources.len() as i32;
    let slint_sources: Vec<crate::SourceData> = sources
        .iter()
        .map(|s| crate::SourceData {
            id: SharedString::from(s.id.as_str()),
            name: SharedString::from(s.name.as_str()),
            source_type: SharedString::from(s.source_type.as_str()),
            url: SharedString::from(s.url.as_str()),
            username: SharedString::default(),
            password: SharedString::default(),
            channel_count: 0,
            vod_count: 0,
            sync_status: SharedString::from(
                s.last_sync_status.as_deref().unwrap_or(""),
            ),
            last_sync_error: SharedString::from(
                s.last_sync_error.as_deref().unwrap_or(""),
            ),
        })
        .collect();
    app.set_sources(ModelRc::new(VecModel::from(slint_sources)));

    // ── Channels ─────────────────────────────────────────────────────────────
    let channels = service.load_channels().unwrap_or_default();
    let channel_count = channels.len() as i32;

    let slint_channels: Vec<crate::ChannelData> = channels
        .iter()
        .map(|c| crate::ChannelData {
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
        })
        .collect();

    // Home preview: first 20 channels
    let home_channels: Vec<crate::ChannelData> =
        slint_channels.iter().take(20).cloned().collect();
    app.set_home_channels(ModelRc::new(VecModel::from(home_channels)));

    // Collect distinct groups
    let mut seen_groups: Vec<String> = Vec::new();
    for ch in &channels {
        let g = ch.channel_group.as_deref().unwrap_or("").to_string();
        if !g.is_empty() && !seen_groups.contains(&g) {
            seen_groups.push(g);
        }
    }
    let slint_groups: Vec<SharedString> = seen_groups
        .iter()
        .map(|g| SharedString::from(g.as_str()))
        .collect();
    app.set_channel_groups(ModelRc::new(VecModel::from(slint_groups)));
    app.set_channels(ModelRc::new(VecModel::from(slint_channels)));
    app.set_total_channel_count(channel_count);
    app.set_channel_window_start(0);

    // ── VOD — Movies ─────────────────────────────────────────────────────────
    let all_vod = service.load_vod_items().unwrap_or_default();

    let movies: Vec<crate::VodData> = all_vod
        .iter()
        .filter(|v| v.item_type == "movie")
        .map(|v| crate::VodData {
            id: SharedString::from(v.id.as_str()),
            name: SharedString::from(v.name.as_str()),
            stream_url: SharedString::from(v.stream_url.as_str()),
            item_type: SharedString::from(v.item_type.as_str()),
            poster_url: SharedString::from(v.poster_url.as_deref().unwrap_or("")),
            backdrop_url: SharedString::from(v.backdrop_url.as_deref().unwrap_or("")),
            description: SharedString::from(v.description.as_deref().unwrap_or("")),
            genre: SharedString::default(),
            year: SharedString::from(
                v.year.map(|y| y.to_string()).unwrap_or_default().as_str(),
            ),
            rating: SharedString::from(v.rating.as_deref().unwrap_or("")),
            duration_minutes: v.duration.unwrap_or(0),
            is_favorite: v.is_favorite,
            source_id: SharedString::from(v.source_id.as_deref().unwrap_or("")),
            series_id: SharedString::default(),
            season: 0,
            episode: 0,
            poster: Default::default(),
        })
        .collect();
    let movie_count = movies.len() as i32;
    app.set_movies(ModelRc::new(VecModel::from(movies)));
    app.set_total_movie_count(movie_count);
    app.set_movie_window_start(0);

    // ── VOD — Series ─────────────────────────────────────────────────────────
    let series: Vec<crate::VodData> = all_vod
        .iter()
        .filter(|v| v.item_type == "series")
        .map(|v| crate::VodData {
            id: SharedString::from(v.id.as_str()),
            name: SharedString::from(v.name.as_str()),
            stream_url: SharedString::from(v.stream_url.as_str()),
            item_type: SharedString::from(v.item_type.as_str()),
            poster_url: SharedString::from(v.poster_url.as_deref().unwrap_or("")),
            backdrop_url: SharedString::from(v.backdrop_url.as_deref().unwrap_or("")),
            description: SharedString::from(v.description.as_deref().unwrap_or("")),
            genre: SharedString::default(),
            year: SharedString::from(
                v.year.map(|y| y.to_string()).unwrap_or_default().as_str(),
            ),
            rating: SharedString::from(v.rating.as_deref().unwrap_or("")),
            duration_minutes: v.duration.unwrap_or(0),
            is_favorite: v.is_favorite,
            source_id: SharedString::from(v.source_id.as_deref().unwrap_or("")),
            series_id: SharedString::default(),
            season: 0,
            episode: 0,
            poster: Default::default(),
        })
        .collect();
    let series_count = series.len() as i32;
    app.set_series(ModelRc::new(VecModel::from(series)));
    app.set_total_series_count(series_count);
    app.set_series_window_start(0);

    // ── Profiles ─────────────────────────────────────────────────────────────
    const AVATAR_COLORS: &[u32] = &[
        0xFF4B_2BFF,
        0xFF_2196F3,
        0xFF_4CAF50,
        0xFF_9C27B0,
        0xFF_FF9800,
        0xFF_00BCD4,
    ];
    let profiles = service.load_profiles().unwrap_or_default();
    let first_profile_name = profiles
        .first()
        .map(|p| p.name.clone())
        .unwrap_or_else(|| "Default".to_string());
    let slint_profiles: Vec<crate::ProfileData> = profiles
        .iter()
        .enumerate()
        .map(|(i, p)| {
            let color_argb =
                AVATAR_COLORS[p.avatar_index.unsigned_abs() as usize % AVATAR_COLORS.len()];
            crate::ProfileData {
                id: SharedString::from(p.id.as_str()),
                name: SharedString::from(p.name.as_str()),
                avatar_color: slint::Color::from_argb_encoded(color_argb).into(),
                is_kids: p.is_child,
                is_active: i == 0,
                pin_protected: p.pin.is_some(),
            }
        })
        .collect();
    app.set_profiles(ModelRc::new(VecModel::from(slint_profiles)));
    app.set_active_profile_name(SharedString::from(first_profile_name.as_str()));

    // ── Navigation state — skip onboarding, start on Home ────────────────────
    ui.global::<OnboardingState>().set_is_active(false);
    app.set_active_screen(0);

    // Diagnostics counters live on DiagnosticsState, not AppState.
    let diag = ui.global::<crate::DiagnosticsState>();
    diag.set_source_count(source_count);
    diag.set_channel_count(channel_count);

    tracing::debug!(
        sources = source_count,
        channels = channel_count,
        movies = movie_count,
        series = series_count,
        profiles = profiles.len(),
        "[TEST] populate_ui: models seeded"
    );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_load_settings_returns_data() {
        let settings = load_settings();
        // Must have at least one source (from base or .local override)
        assert!(
            !settings.sources.is_empty(),
            "expected at least one source"
        );
        assert!(
            !settings.profiles.is_empty(),
            "expected at least one profile"
        );
        // Settings block must have valid values regardless of override
        assert!(!settings.settings.language.is_empty());
        assert!(!settings.settings.theme.is_empty());
    }

    #[test]
    fn test_load_settings_local_overrides_base() {
        // tempfile/std::io::Write not needed — we parse the JSON string directly

        // Write a minimal local-override JSON to a temp file.
        let local_json = r#"{
            "sources": [{"name":"LocalOnly","type":"m3u","url":"http://local.example.com/local.m3u"}],
            "profiles": [{"name":"LocalProfile","is_kids":false,"pin":null}],
            "settings": {"language":"de","theme":"light","autoplay_next":false,"default_quality":"720p"}
        }"#;

        // Verify the JSON round-trips through TestSettings.
        let parsed: TestSettings =
            serde_json::from_str(local_json).expect("local override must parse");
        assert_eq!(parsed.sources.len(), 1);
        assert_eq!(parsed.sources[0].name, "LocalOnly");
        assert_eq!(parsed.settings.language, "de");

        // merge_settings: local takes precedence.
        let base = load_settings();
        let merged = merge_settings(base, parsed);
        assert_eq!(merged.sources.len(), 1);
        assert_eq!(merged.sources[0].name, "LocalOnly");
        assert_eq!(merged.settings.language, "de");
    }

    #[test]
    fn test_db_init_creates_service_with_sources() {
        let db = TestDb::init();
        let sources = db.service().get_sources().expect("get_sources");
        // Fixture has 3 sources.
        assert_eq!(
            sources.len(),
            db.settings().sources.len(),
            "DB source count must match fixture source count"
        );
        // Verify first source name round-trips.
        let first_name = &db.settings().sources[0].name;
        assert!(
            sources.iter().any(|s| &s.name == first_name),
            "first fixture source '{}' not found in DB",
            first_name
        );
    }

    #[test]
    fn test_db_seed_inserts_channels() {
        let db = TestDb::init();
        let channels = db.service().load_channels().expect("load_channels");
        assert_eq!(
            channels.len(),
            db.seed().channels.len(),
            "DB channel count must match seed channel count"
        );
        // Spot-check first channel name.
        let first_name = &db.seed().channels[0].name;
        assert!(
            channels.iter().any(|c| &c.name == first_name),
            "first seed channel '{}' not found in DB",
            first_name
        );
    }
}
