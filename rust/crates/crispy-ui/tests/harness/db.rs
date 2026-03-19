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

// ── Fixture path resolution ───────────────────────────────────────────────────

fn fixtures_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
}

fn load_json<T: serde::de::DeserializeOwned>(path: &PathBuf) -> Result<T, String> {
    let raw = std::fs::read_to_string(path)
        .map_err(|e| format!("read {}: {e}", path.display()))?;
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

        let db = TestDb { service, settings, seed };
        db.insert_sources();
        db.insert_profiles();
        db.insert_seed_channels();
        db.insert_seed_movies();
        db.insert_seed_series();
        db.insert_seed_epg();
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
                    let ep_id = format!(
                        "series_{si}_s{:02}e{:02}",
                        season.number, ep.number
                    );
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

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_load_settings_returns_stub_data() {
        let settings = load_settings();
        // Fixture has 3 sources: m3u, xtream, stalker
        assert!(
            !settings.sources.is_empty(),
            "expected at least one source in test-settings.json"
        );
        assert!(
            !settings.profiles.is_empty(),
            "expected at least one profile in test-settings.json"
        );
        // Verify known fixture values
        let first = &settings.sources[0];
        assert_eq!(first.source_type, "m3u");
        assert_eq!(settings.settings.language, "en");
        assert_eq!(settings.settings.theme, "dark");
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
