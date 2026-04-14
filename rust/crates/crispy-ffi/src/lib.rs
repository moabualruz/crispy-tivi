// CrispyTivi runtime FFI boundary.
//
// This crate is the Rust-owned bridge for source setup, runtime hydration,
// playback metadata, and diagnostics. Shared `crispy-*` crates remain the
// default foundation for provider parsing and translation responsibilities.
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

#[cfg(not(target_arch = "wasm32"))]
use crispy_media_probe::{is_ffmpeg_available, is_ffprobe_available};
use serde::{Deserialize, Serialize};

pub mod api;
pub mod diagnostics_runtime;
pub mod playback_runtime;
pub mod source_runtime;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ShellContract {
    pub startup_route: String,
    pub top_level_routes: Vec<String>,
    pub settings_groups: Vec<String>,
    pub live_tv_panels: Vec<String>,
    pub live_tv_groups: Vec<String>,
    pub media_panels: Vec<String>,
    pub media_scopes: Vec<String>,
    pub home_quick_access: Vec<String>,
    pub source_wizard_steps: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArtworkSource {
    pub kind: String,
    pub value: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlaybackSourceSnapshot {
    pub kind: String,
    pub source_key: String,
    pub content_key: String,
    pub source_label: String,
    pub handoff_label: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlaybackStreamSnapshot {
    pub uri: String,
    pub transport: String,
    pub live: bool,
    pub seekable: bool,
    pub resume_position_seconds: u32,
    pub source_options: Vec<PlaybackVariantOptionSnapshot>,
    pub quality_options: Vec<PlaybackVariantOptionSnapshot>,
    pub audio_options: Vec<PlaybackTrackOptionSnapshot>,
    pub subtitle_options: Vec<PlaybackTrackOptionSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlaybackVariantOptionSnapshot {
    pub id: String,
    pub label: String,
    pub uri: String,
    pub transport: String,
    pub live: bool,
    pub seekable: bool,
    pub resume_position_seconds: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlaybackTrackOptionSnapshot {
    pub id: String,
    pub label: String,
    pub uri: String,
    pub language: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HeroFeature {
    pub kicker: String,
    pub title: String,
    pub summary: String,
    pub primary_action: String,
    pub secondary_action: String,
    pub artwork: ArtworkSource,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ShelfItem {
    pub title: String,
    pub caption: String,
    pub rank: Option<u8>,
    pub artwork: ArtworkSource,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChannelEntry {
    pub number: String,
    pub name: String,
    pub program: String,
    pub time_range: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchResultGroup {
    pub title: String,
    pub results: Vec<SearchResultItem>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchResultItem {
    pub title: String,
    pub caption: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SettingsItem {
    pub title: String,
    pub summary: String,
    pub value: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceHealthItem {
    pub name: String,
    pub status: String,
    pub summary: String,
    pub source_type: String,
    pub endpoint: String,
    pub last_sync: String,
    pub capabilities: Vec<String>,
    pub primary_action: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceWizardStepContent {
    pub step: String,
    pub title: String,
    pub summary: String,
    pub primary_action: String,
    pub secondary_action: String,
    pub field_labels: Vec<String>,
    pub helper_lines: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceCapabilityModelSnapshot {
    pub live_tv: bool,
    pub guide: bool,
    pub movies: bool,
    pub series: bool,
    pub catch_up: bool,
    pub archive_playback: bool,
    pub remote_playlist_url: bool,
    pub local_playlist_file: bool,
    pub account_authentication: bool,
    pub epg_import: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceCapabilitySnapshot {
    pub id: String,
    pub title: String,
    pub summary: String,
    pub supported: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceHealthSnapshot {
    pub status: String,
    pub summary: String,
    pub last_checked: String,
    pub last_sync: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceAuthSnapshot {
    pub status: String,
    pub progress: String,
    pub summary: String,
    pub primary_action: String,
    pub secondary_action: String,
    pub field_labels: Vec<String>,
    pub helper_lines: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceImportSnapshot {
    pub status: String,
    pub progress: String,
    pub summary: String,
    pub primary_action: String,
    pub secondary_action: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceProviderSnapshot {
    pub provider_key: String,
    pub provider_type: String,
    pub family: String,
    pub connection_mode: String,
    pub summary: String,
    pub capability_model: SourceCapabilityModelSnapshot,
    pub capabilities: Vec<SourceCapabilitySnapshot>,
    pub health: SourceHealthSnapshot,
    pub auth: SourceAuthSnapshot,
    pub import: SourceImportSnapshot,
    pub onboarding_hint: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceOnboardingWizardStepSnapshot {
    pub step: String,
    pub title: String,
    pub summary: String,
    pub primary_action: String,
    pub secondary_action: String,
    pub field_labels: Vec<String>,
    pub helper_lines: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceProviderWizardCopySnapshot {
    pub provider_key: String,
    pub provider_type: String,
    pub title: String,
    pub summary: String,
    pub helper_lines: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceOnboardingWizardSnapshot {
    pub selected_provider_type: String,
    pub active_step: String,
    pub step_order: Vec<String>,
    pub steps: Vec<SourceOnboardingWizardStepSnapshot>,
    pub provider_copy: Vec<SourceProviderWizardCopySnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceRegistrySnapshot {
    pub title: String,
    pub version: String,
    pub provider_types: Vec<SourceProviderSnapshot>,
    pub onboarding: SourceOnboardingWizardSnapshot,
    pub registry_notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeSnapshot {
    pub title: String,
    pub version: String,
    pub provider: LiveTvRuntimeProviderSnapshot,
    pub browsing: LiveTvRuntimeBrowsingSnapshot,
    pub channels: Vec<LiveTvRuntimeChannelSnapshot>,
    pub guide: LiveTvRuntimeGuideSnapshot,
    pub selection: LiveTvRuntimeSelectionSnapshot,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeProviderSnapshot {
    pub provider_key: String,
    pub provider_type: String,
    pub family: String,
    pub connection_mode: String,
    pub source_name: String,
    pub status: String,
    pub summary: String,
    pub last_sync: String,
    pub guide_health: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeBrowsingSnapshot {
    pub active_panel: String,
    pub selected_group: String,
    pub selected_channel: String,
    pub group_order: Vec<String>,
    pub groups: Vec<LiveTvRuntimeGroupSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeGroupSnapshot {
    pub id: String,
    pub title: String,
    pub summary: String,
    pub channel_count: u16,
    pub selected: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeProgramSnapshot {
    pub title: String,
    pub summary: String,
    pub start: String,
    pub end: String,
    pub progress_percent: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeGuideSlotSnapshot {
    pub start: String,
    pub end: String,
    pub title: String,
    pub state: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeGuideRowSnapshot {
    pub channel_number: String,
    pub channel_name: String,
    pub slots: Vec<LiveTvRuntimeGuideSlotSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeGuideSnapshot {
    pub title: String,
    pub window_start: String,
    pub window_end: String,
    pub time_slots: Vec<String>,
    pub rows: Vec<LiveTvRuntimeGuideRowSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeChannelSnapshot {
    pub number: String,
    pub name: String,
    pub group: String,
    pub state: String,
    pub live_edge: bool,
    pub catch_up: bool,
    pub archive: bool,
    pub playback_source: PlaybackSourceSnapshot,
    pub playback_stream: PlaybackStreamSnapshot,
    pub current: LiveTvRuntimeProgramSnapshot,
    pub next: LiveTvRuntimeProgramSnapshot,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTvRuntimeSelectionSnapshot {
    pub channel_number: String,
    pub channel_name: String,
    pub status: String,
    pub live_edge: bool,
    pub catch_up: bool,
    pub archive: bool,
    pub now: LiveTvRuntimeProgramSnapshot,
    pub next: LiveTvRuntimeProgramSnapshot,
    pub primary_action: String,
    pub secondary_action: String,
    pub badges: Vec<String>,
    pub detail_lines: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MediaRuntimeSnapshot {
    pub title: String,
    pub version: String,
    pub active_panel: String,
    pub active_scope: String,
    pub movie_hero: MediaRuntimeHeroSnapshot,
    pub series_hero: MediaRuntimeHeroSnapshot,
    pub movie_collections: Vec<MediaRuntimeCollectionSnapshot>,
    pub series_collections: Vec<MediaRuntimeCollectionSnapshot>,
    pub series_detail: MediaRuntimeSeriesDetailSnapshot,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MediaRuntimeHeroSnapshot {
    pub kicker: String,
    pub title: String,
    pub summary: String,
    pub primary_action: String,
    pub secondary_action: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MediaRuntimeCollectionSnapshot {
    pub title: String,
    pub summary: String,
    pub items: Vec<MediaRuntimeItemSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MediaRuntimeItemSnapshot {
    pub title: String,
    pub caption: String,
    pub rank: Option<u16>,
    pub playback_source: PlaybackSourceSnapshot,
    pub playback_stream: PlaybackStreamSnapshot,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MediaRuntimeSeriesDetailSnapshot {
    pub summary_title: String,
    pub summary_body: String,
    pub handoff_label: String,
    pub seasons: Vec<MediaRuntimeSeasonSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MediaRuntimeSeasonSnapshot {
    pub label: String,
    pub summary: String,
    pub episodes: Vec<MediaRuntimeEpisodeSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MediaRuntimeEpisodeSnapshot {
    pub code: String,
    pub title: String,
    pub summary: String,
    pub duration_label: String,
    pub handoff_label: String,
    pub playback_source: PlaybackSourceSnapshot,
    pub playback_stream: PlaybackStreamSnapshot,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchRuntimeSnapshot {
    pub title: String,
    pub version: String,
    pub query: String,
    pub active_group_title: String,
    pub groups: Vec<SearchRuntimeGroupSnapshot>,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchRuntimeGroupSnapshot {
    pub title: String,
    pub summary: String,
    pub selected: bool,
    pub results: Vec<SearchRuntimeResultSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchRuntimeResultSnapshot {
    pub title: String,
    pub caption: String,
    pub source_label: String,
    pub handoff_label: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PersonalizationRuntimeSnapshot {
    pub title: String,
    pub version: String,
    pub startup_route: String,
    pub continue_watching: Vec<PersistentPlaybackEntry>,
    pub recently_viewed: Vec<PersistentPlaybackEntry>,
    pub favorite_media_keys: Vec<String>,
    pub favorite_channel_numbers: Vec<String>,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PersistentPlaybackEntry {
    pub kind: String,
    pub content_key: String,
    pub channel_number: Option<String>,
    pub title: String,
    pub caption: String,
    pub summary: String,
    pub progress_label: String,
    pub progress_value: f64,
    pub resume_position_seconds: u32,
    pub last_viewed_at: String,
    pub detail_lines: Vec<String>,
    pub artwork: Option<ArtworkSource>,
    pub playback_source: Option<PlaybackSourceSnapshot>,
    pub playback_stream: Option<PlaybackStreamSnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiagnosticsRuntimeSnapshot {
    pub title: String,
    pub version: String,
    pub validation_summary: String,
    pub ffprobe_available: bool,
    pub ffmpeg_available: bool,
    pub reports: Vec<DiagnosticsReportSnapshot>,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiagnosticsHostToolingSnapshot {
    pub ffprobe_available: bool,
    pub ffmpeg_available: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiagnosticsReportSnapshot {
    pub source_name: String,
    pub stream_title: String,
    pub category: String,
    pub status_code: u16,
    pub response_time_ms: u64,
    pub url_hash: String,
    pub resume_hash: String,
    pub resolution_label: String,
    pub probe_backend: String,
    pub mismatch_warnings: Vec<String>,
    pub detail_lines: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ShellContentSnapshot {
    pub home_hero: HeroFeature,
    pub continue_watching: Vec<ShelfItem>,
    pub live_now: Vec<ShelfItem>,
    pub movie_hero: HeroFeature,
    pub series_hero: HeroFeature,
    pub top_films: Vec<ShelfItem>,
    pub top_series: Vec<ShelfItem>,
    pub live_tv_channels: Vec<ChannelEntry>,
    pub guide_rows: Vec<Vec<String>>,
    pub search_groups: Vec<SearchResultGroup>,
    pub general_settings: Vec<SettingsItem>,
    pub playback_settings: Vec<SettingsItem>,
    pub appearance_settings: Vec<SettingsItem>,
    pub system_settings: Vec<SettingsItem>,
    pub source_health_items: Vec<SourceHealthItem>,
    pub source_wizard_steps: Vec<SourceWizardStepContent>,
}

pub fn mock_shell_contract() -> ShellContract {
    ShellContract {
        startup_route: "Home".to_owned(),
        top_level_routes: vec![
            "Home".to_owned(),
            "Live TV".to_owned(),
            "Media".to_owned(),
            "Search".to_owned(),
            "Settings".to_owned(),
        ],
        settings_groups: vec![
            "General".to_owned(),
            "Playback".to_owned(),
            "Sources".to_owned(),
            "Appearance".to_owned(),
            "System".to_owned(),
        ],
        live_tv_panels: vec!["Channels".to_owned(), "Guide".to_owned()],
        live_tv_groups: vec![
            "All".to_owned(),
            "Favorites".to_owned(),
            "News".to_owned(),
            "Sports".to_owned(),
            "Movies".to_owned(),
            "Kids".to_owned(),
        ],
        media_panels: vec!["Movies".to_owned(), "Series".to_owned()],
        media_scopes: vec![
            "Featured".to_owned(),
            "Trending".to_owned(),
            "Recent".to_owned(),
            "Library".to_owned(),
        ],
        home_quick_access: vec![
            "Search".to_owned(),
            "Settings".to_owned(),
            "Series".to_owned(),
            "Live TV Guide".to_owned(),
        ],
        source_wizard_steps: vec![
            "Source Type".to_owned(),
            "Connection".to_owned(),
            "Credentials".to_owned(),
            "Import".to_owned(),
            "Finish".to_owned(),
        ],
    }
}

pub fn mock_shell_contract_json() -> String {
    serde_json::to_string_pretty(&mock_shell_contract())
        .expect("mock shell contract serialization should succeed")
}

pub fn mock_shell_content() -> ShellContentSnapshot {
    ShellContentSnapshot {
        home_hero: HeroFeature {
            kicker: "Tonight on CrispyTivi".to_owned(),
            title: "City Lights at Midnight".to_owned(),
            summary: "A dramatic featured rail with quiet chrome, clear hierarchy, and room-readable action placement.".to_owned(),
            primary_action: "Resume watching".to_owned(),
            secondary_action: "Open details".to_owned(),
            artwork: ArtworkSource {
                kind: "asset".to_owned(),
                value: "assets/mocks/home-hero-shell.jpg".to_owned(),
            },
        },
        continue_watching: vec![
            ShelfItem {
                title: "Neon District".to_owned(),
                caption: "42 min left".to_owned(),
                rank: None,
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-1.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Chef After Dark".to_owned(),
                caption: "Resume S2:E4".to_owned(),
                rank: None,
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-2.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Morning Live".to_owned(),
                caption: "Live now".to_owned(),
                rank: None,
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-3.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "The Signal".to_owned(),
                caption: "Start over".to_owned(),
                rank: None,
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-4.jpg".to_owned(),
                },
            },
        ],
        live_now: vec![
            ShelfItem {
                title: "World Report".to_owned(),
                caption: "Newsroom".to_owned(),
                rank: None,
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-5.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Match Night".to_owned(),
                caption: "Sports Central".to_owned(),
                rank: None,
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-1.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Cinema Vault".to_owned(),
                caption: "Classic movies".to_owned(),
                rank: None,
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-2.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Planet North".to_owned(),
                caption: "Nature HD".to_owned(),
                rank: None,
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-3.jpg".to_owned(),
                },
            },
        ],
        movie_hero: HeroFeature {
            kicker: "Featured film".to_owned(),
            title: "The Last Harbor".to_owned(),
            summary: "A cinematic detail state with clear action hierarchy, restrained metadata, and content-first framing.".to_owned(),
            primary_action: "Play trailer".to_owned(),
            secondary_action: "Add to watchlist".to_owned(),
            artwork: ArtworkSource {
                kind: "asset".to_owned(),
                value: "assets/mocks/media-movie-hero-shell.jpg".to_owned(),
            },
        },
        series_hero: HeroFeature {
            kicker: "Series spotlight".to_owned(),
            title: "Shadow Signals".to_owned(),
            summary: "Season-driven browsing stays inside the media domain with episode context and tight focus separation.".to_owned(),
            primary_action: "Resume S1:E6".to_owned(),
            secondary_action: "Browse episodes".to_owned(),
            artwork: ArtworkSource {
                kind: "asset".to_owned(),
                value: "assets/mocks/media-series-hero-shell.jpg".to_owned(),
            },
        },
        top_films: vec![
            ShelfItem {
                title: "The Last Harbor".to_owned(),
                caption: "Thriller".to_owned(),
                rank: Some(1),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-1.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Glass Minute".to_owned(),
                caption: "Drama".to_owned(),
                rank: Some(2),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-2.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Wired North".to_owned(),
                caption: "Sci-fi".to_owned(),
                rank: Some(3),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-3.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Quiet Ember".to_owned(),
                caption: "Mystery".to_owned(),
                rank: Some(4),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-4.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Atlas Run".to_owned(),
                caption: "Action".to_owned(),
                rank: Some(5),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-5.jpg".to_owned(),
                },
            },
        ],
        top_series: vec![
            ShelfItem {
                title: "Shadow Signals".to_owned(),
                caption: "New episode".to_owned(),
                rank: Some(1),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-5.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Northline".to_owned(),
                caption: "Season finale".to_owned(),
                rank: Some(2),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-4.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Open Range".to_owned(),
                caption: "Continue watching".to_owned(),
                rank: Some(3),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-3.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "Fifth Harbor".to_owned(),
                caption: "New season".to_owned(),
                rank: Some(4),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-2.jpg".to_owned(),
                },
            },
            ShelfItem {
                title: "After Current".to_owned(),
                caption: "Trending".to_owned(),
                rank: Some(5),
                artwork: ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-1.jpg".to_owned(),
                },
            },
        ],
        live_tv_channels: vec![
            ChannelEntry {
                number: "101".to_owned(),
                name: "Crispy One".to_owned(),
                program: "Midnight Bulletin".to_owned(),
                time_range: "21:00 - 22:00".to_owned(),
            },
            ChannelEntry {
                number: "118".to_owned(),
                name: "Arena Live".to_owned(),
                program: "Championship Replay".to_owned(),
                time_range: "21:30 - 23:30".to_owned(),
            },
            ChannelEntry {
                number: "205".to_owned(),
                name: "Cinema Vault".to_owned(),
                program: "Coastal Drive".to_owned(),
                time_range: "20:45 - 22:35".to_owned(),
            },
            ChannelEntry {
                number: "311".to_owned(),
                name: "Nature Atlas".to_owned(),
                program: "Winter Oceans".to_owned(),
                time_range: "21:15 - 22:15".to_owned(),
            },
        ],
        guide_rows: vec![
            vec![
                "Now".to_owned(),
                "21:30".to_owned(),
                "22:00".to_owned(),
                "22:30".to_owned(),
                "23:00".to_owned(),
            ],
            vec![
                "Crispy One".to_owned(),
                "Bulletin".to_owned(),
                "Market Close".to_owned(),
                "Nightline".to_owned(),
                "Forecast".to_owned(),
            ],
            vec![
                "Arena Live".to_owned(),
                "Replay".to_owned(),
                "Analysis".to_owned(),
                "Locker Room".to_owned(),
                "Highlights".to_owned(),
            ],
            vec![
                "Cinema Vault".to_owned(),
                "Coastal Drive".to_owned(),
                "Coastal Drive".to_owned(),
                "Studio Cut".to_owned(),
                "Trailer Reel".to_owned(),
            ],
            vec![
                "Nature Atlas".to_owned(),
                "Winter Oceans".to_owned(),
                "Arctic Voices".to_owned(),
                "Wild Frontiers".to_owned(),
                "Night Shift".to_owned(),
            ],
        ],
        search_groups: vec![
            SearchResultGroup {
                title: "Live TV".to_owned(),
                results: vec![
                    SearchResultItem {
                        title: "Arena Live".to_owned(),
                        caption: "Channel 118".to_owned(),
                    },
                    SearchResultItem {
                        title: "Cinema Vault".to_owned(),
                        caption: "Channel 205".to_owned(),
                    },
                ],
            },
            SearchResultGroup {
                title: "Movies".to_owned(),
                results: vec![
                    SearchResultItem {
                        title: "The Last Harbor".to_owned(),
                        caption: "Thriller".to_owned(),
                    },
                    SearchResultItem {
                        title: "Atlas Run".to_owned(),
                        caption: "Action".to_owned(),
                    },
                ],
            },
            SearchResultGroup {
                title: "Series".to_owned(),
                results: vec![
                    SearchResultItem {
                        title: "Shadow Signals".to_owned(),
                        caption: "Sci-fi drama".to_owned(),
                    },
                    SearchResultItem {
                        title: "Northline".to_owned(),
                        caption: "New season".to_owned(),
                    },
                ],
            },
        ],
        general_settings: vec![
            SettingsItem {
                title: "Startup target".to_owned(),
                summary: "Choose the first screen after launch.".to_owned(),
                value: "Home".to_owned(),
            },
            SettingsItem {
                title: "Recommendations".to_owned(),
                summary: "Show history-based rails on Home.".to_owned(),
                value: "On".to_owned(),
            },
        ],
        playback_settings: vec![
            SettingsItem {
                title: "Quick play confirmation".to_owned(),
                summary: "Require explicit play confirmation for channel tune.".to_owned(),
                value: "On".to_owned(),
            },
            SettingsItem {
                title: "Preferred quality".to_owned(),
                summary: "Default target for supported movie streams.".to_owned(),
                value: "Auto".to_owned(),
            },
        ],
        appearance_settings: vec![
            SettingsItem {
                title: "Focus intensity".to_owned(),
                summary: "Boost focus glow for brighter rooms.".to_owned(),
                value: "Balanced".to_owned(),
            },
            SettingsItem {
                title: "Clock display".to_owned(),
                summary: "Show current time in the top shell area.".to_owned(),
                value: "On".to_owned(),
            },
        ],
        system_settings: vec![
            SettingsItem {
                title: "Storage".to_owned(),
                summary: "Inspect cache and offline data.".to_owned(),
                value: "4.2 GB".to_owned(),
            },
            SettingsItem {
                title: "About".to_owned(),
                summary: "Version, diagnostics, and environment.".to_owned(),
                value: "v0.1.0-alpha".to_owned(),
            },
        ],
        source_health_items: vec![
            SourceHealthItem {
                name: "Home Fiber IPTV".to_owned(),
                status: "Healthy".to_owned(),
                summary: "Live, guide, and catch-up verified 2 min ago.".to_owned(),
                source_type: "M3U + XMLTV".to_owned(),
                endpoint: "fiber.local / lineup-primary".to_owned(),
                last_sync: "2 minutes ago".to_owned(),
                capabilities: vec![
                    "Live TV".to_owned(),
                    "Guide".to_owned(),
                    "Catch-up".to_owned(),
                ],
                primary_action: "Re-import source".to_owned(),
            },
            SourceHealthItem {
                name: "Weekend Cinema".to_owned(),
                status: "Degraded".to_owned(),
                summary: "Guide present, posters delayed.".to_owned(),
                source_type: "Stalker".to_owned(),
                endpoint: "cinema.example.net / portal".to_owned(),
                last_sync: "14 minutes ago".to_owned(),
                capabilities: vec![
                    "Movies".to_owned(),
                    "Series".to_owned(),
                    "Guide".to_owned(),
                ],
                primary_action: "Review import".to_owned(),
            },
            SourceHealthItem {
                name: "Travel Archive".to_owned(),
                status: "Needs auth".to_owned(),
                summary: "Reconnect credentials to resume sync.".to_owned(),
                source_type: "Xtream Codes".to_owned(),
                endpoint: "travel.example.com / xtream".to_owned(),
                last_sync: "Sync blocked".to_owned(),
                capabilities: vec![
                    "Live TV".to_owned(),
                    "Movies".to_owned(),
                    "Series".to_owned(),
                ],
                primary_action: "Reconnect".to_owned(),
            },
        ],
        source_wizard_steps: vec![
            SourceWizardStepContent {
                step: "Source Type".to_owned(),
                title: "Choose source type".to_owned(),
                summary: "Pick the provider integration first so connection, auth, and import rules stay accurate for the rest of the wizard.".to_owned(),
                primary_action: "Continue".to_owned(),
                secondary_action: "Back".to_owned(),
                field_labels: vec![
                    "Source type".to_owned(),
                    "Display name".to_owned(),
                ],
                helper_lines: vec![
                    "Keep provider-specific flow inside Settings rather than exposing Sources as a separate app domain.".to_owned(),
                    "Wizard steps stay ordered and safe to unwind.".to_owned(),
                ],
            },
            SourceWizardStepContent {
                step: "Connection".to_owned(),
                title: "Add connection details".to_owned(),
                summary: "Capture the endpoint and source-specific path before auth or validation runs.".to_owned(),
                primary_action: "Validate connection".to_owned(),
                secondary_action: "Back".to_owned(),
                field_labels: vec![
                    "Connection endpoint".to_owned(),
                    "Headers".to_owned(),
                ],
                helper_lines: vec![
                    "Connection validation should fail here instead of later import screens.".to_owned(),
                    "Temporary connection state must not auto-restore into an unsafe stale step.".to_owned(),
                ],
            },
            SourceWizardStepContent {
                step: "Credentials".to_owned(),
                title: "Authenticate source".to_owned(),
                summary: "Sensitive credentials stay in the wizard and should never auto-restore into the middle of the secret-bearing step.".to_owned(),
                primary_action: "Verify access".to_owned(),
                secondary_action: "Back".to_owned(),
                field_labels: vec![
                    "Username".to_owned(),
                    "Password".to_owned(),
                ],
                helper_lines: vec![
                    "Auth can be entered for new sources or reconnect flows on existing sources.".to_owned(),
                    "Back from this step returns safely to connection rather than leaving the user in a broken state.".to_owned(),
                ],
            },
            SourceWizardStepContent {
                step: "Import".to_owned(),
                title: "Choose import scope".to_owned(),
                summary: "Review what the source will bring in and confirm the validation result before final import begins.".to_owned(),
                primary_action: "Start import".to_owned(),
                secondary_action: "Back".to_owned(),
                field_labels: vec![
                    "Import scope".to_owned(),
                    "Validation result".to_owned(),
                ],
                helper_lines: vec![
                    "Import confirmation is a dedicated step, not a hidden side effect of auth.".to_owned(),
                    "Failures here should unwind cleanly back through the wizard.".to_owned(),
                ],
            },
            SourceWizardStepContent {
                step: "Finish".to_owned(),
                title: "Finish setup".to_owned(),
                summary: "Complete the source handoff and return to source overview with health and capability status visible.".to_owned(),
                primary_action: "Return to sources".to_owned(),
                secondary_action: "Back".to_owned(),
                field_labels: vec![
                    "Validation result".to_owned(),
                    "Import scope".to_owned(),
                ],
                helper_lines: vec![
                    "Success returns to the Settings-owned source overview, not to a detached source domain.".to_owned(),
                    "The next domain phases can rely on this onboarding lane being complete.".to_owned(),
                ],
            },
        ],
    }
}

pub fn mock_shell_content_json() -> String {
    serde_json::to_string_pretty(&mock_shell_content())
        .expect("mock shell content serialization should succeed")
}

pub fn source_registry_snapshot() -> SourceRegistrySnapshot {
    SourceRegistrySnapshot {
        title: "CrispyTivi Source Registry".to_owned(),
        version: "1".to_owned(),
        provider_types: vec![
            SourceProviderSnapshot {
                provider_key: "m3u_url".to_owned(),
                provider_type: "M3U URL".to_owned(),
                family: "playlist".to_owned(),
                connection_mode: "remote_url".to_owned(),
                summary: "Direct playlist URL with optional guide pairing and catch-up support.".to_owned(),
                capability_model: SourceCapabilityModelSnapshot {
                    live_tv: true,
                    guide: true,
                    movies: false,
                    series: false,
                    catch_up: true,
                    archive_playback: true,
                    remote_playlist_url: true,
                    local_playlist_file: false,
                    account_authentication: false,
                    epg_import: true,
                },
                capabilities: vec![
                    SourceCapabilitySnapshot {
                        id: "live_tv".to_owned(),
                        title: "Live TV".to_owned(),
                        summary: "Map playlist rows to channels and categories.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "guide".to_owned(),
                        title: "Guide".to_owned(),
                        summary: "Pair XMLTV for EPG coverage and better browse context.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "catch_up".to_owned(),
                        title: "Catch-up".to_owned(),
                        summary: "Use archive URLs when the source exposes timeshift.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "movies".to_owned(),
                        title: "Movies".to_owned(),
                        summary: "Not a native catalog lane, but playable media can still surface.".to_owned(),
                        supported: false,
                    },
                    SourceCapabilitySnapshot {
                        id: "series".to_owned(),
                        title: "Series".to_owned(),
                        summary: "Series metadata depends on the external playlist and guide pairing.".to_owned(),
                        supported: false,
                    },
                ],
                health: SourceHealthSnapshot {
                    status: "Healthy".to_owned(),
                    summary: "Playlist reachable and validation passed.".to_owned(),
                    last_checked: "2 minutes ago".to_owned(),
                    last_sync: "2 minutes ago".to_owned(),
                },
                auth: SourceAuthSnapshot {
                    status: "Not required".to_owned(),
                    progress: "0%".to_owned(),
                    summary: "No account credentials are needed for a direct playlist URL.".to_owned(),
                    primary_action: "Continue".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Playlist URL".to_owned(),
                        "XMLTV URL".to_owned(),
                    ],
                    helper_lines: vec![
                        "Use this lane for remote playlist URLs.".to_owned(),
                        "Guide pairing is optional but recommended.".to_owned(),
                    ],
                },
                import: SourceImportSnapshot {
                    status: "Ready".to_owned(),
                    progress: "100%".to_owned(),
                    summary: "Playlist can import once URLs validate.".to_owned(),
                    primary_action: "Start import".to_owned(),
                    secondary_action: "Review".to_owned(),
                },
                onboarding_hint: "Start with a direct URL, then add XMLTV if available.".to_owned(),
            },
            SourceProviderSnapshot {
                provider_key: "local_m3u".to_owned(),
                provider_type: "local M3U".to_owned(),
                family: "playlist".to_owned(),
                connection_mode: "local_file".to_owned(),
                summary: "On-device playlist import from a local file or mounted storage path.".to_owned(),
                capability_model: SourceCapabilityModelSnapshot {
                    live_tv: true,
                    guide: true,
                    movies: false,
                    series: false,
                    catch_up: false,
                    archive_playback: false,
                    remote_playlist_url: false,
                    local_playlist_file: true,
                    account_authentication: false,
                    epg_import: true,
                },
                capabilities: vec![
                    SourceCapabilitySnapshot {
                        id: "live_tv".to_owned(),
                        title: "Live TV".to_owned(),
                        summary: "Load channels from a local playlist file.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "guide".to_owned(),
                        title: "Guide".to_owned(),
                        summary: "Pair XMLTV locally or from a nearby import source.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "local_playlist".to_owned(),
                        title: "Local file".to_owned(),
                        summary: "Import from a file path or attached storage target.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "catch_up".to_owned(),
                        title: "Catch-up".to_owned(),
                        summary: "Not advertised unless the imported playlist carries archive data.".to_owned(),
                        supported: false,
                    },
                ],
                health: SourceHealthSnapshot {
                    status: "Healthy".to_owned(),
                    summary: "Local file loaded and parsed.".to_owned(),
                    last_checked: "1 minute ago".to_owned(),
                    last_sync: "1 minute ago".to_owned(),
                },
                auth: SourceAuthSnapshot {
                    status: "Not required".to_owned(),
                    progress: "0%".to_owned(),
                    summary: "Local files do not require credentials.".to_owned(),
                    primary_action: "Continue".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Playlist file".to_owned(),
                        "XMLTV file".to_owned(),
                    ],
                    helper_lines: vec![
                        "Use this lane for attached storage or imported files.".to_owned(),
                        "File validation should happen before import starts.".to_owned(),
                    ],
                },
                import: SourceImportSnapshot {
                    status: "Complete".to_owned(),
                    progress: "100%".to_owned(),
                    summary: "Local playlist import is complete and ready to browse.".to_owned(),
                    primary_action: "Open sources".to_owned(),
                    secondary_action: "Review".to_owned(),
                },
                onboarding_hint: "Choose a local playlist file, then pair guide data if needed.".to_owned(),
            },
            SourceProviderSnapshot {
                provider_key: "xtream".to_owned(),
                provider_type: "Xtream".to_owned(),
                family: "portal".to_owned(),
                connection_mode: "portal_account".to_owned(),
                summary: "Account-backed provider with live, movies, series, and guide lanes.".to_owned(),
                capability_model: SourceCapabilityModelSnapshot {
                    live_tv: true,
                    guide: true,
                    movies: true,
                    series: true,
                    catch_up: true,
                    archive_playback: true,
                    remote_playlist_url: false,
                    local_playlist_file: false,
                    account_authentication: true,
                    epg_import: true,
                },
                capabilities: vec![
                    SourceCapabilitySnapshot {
                        id: "live_tv".to_owned(),
                        title: "Live TV".to_owned(),
                        summary: "Portal groups can surface channel lists and live categories.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "movies".to_owned(),
                        title: "Movies".to_owned(),
                        summary: "Catalog data exposes a movie lane with browse and detail views.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "series".to_owned(),
                        title: "Series".to_owned(),
                        summary: "Series catalogs can feed seasons, episodes, and resume state.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "guide".to_owned(),
                        title: "Guide".to_owned(),
                        summary: "EPG data can support channel schedule overlays and browse grids.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "catch_up".to_owned(),
                        title: "Catch-up".to_owned(),
                        summary: "Archive playback is available when the portal exposes it.".to_owned(),
                        supported: true,
                    },
                ],
                health: SourceHealthSnapshot {
                    status: "Needs auth".to_owned(),
                    summary: "Portal access is waiting for valid credentials.".to_owned(),
                    last_checked: "Sync blocked".to_owned(),
                    last_sync: "Sync blocked".to_owned(),
                },
                auth: SourceAuthSnapshot {
                    status: "Needs auth".to_owned(),
                    progress: "0%".to_owned(),
                    summary: "Credentials are required before catalog sync can continue.".to_owned(),
                    primary_action: "Verify access".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Server URL".to_owned(),
                        "Username".to_owned(),
                        "Password".to_owned(),
                    ],
                    helper_lines: vec![
                        "Use the portal endpoint supplied by the provider.".to_owned(),
                        "Validation should happen before import begins.".to_owned(),
                    ],
                },
                import: SourceImportSnapshot {
                    status: "Blocked".to_owned(),
                    progress: "0%".to_owned(),
                    summary: "Import is paused until auth succeeds.".to_owned(),
                    primary_action: "Continue".to_owned(),
                    secondary_action: "Review".to_owned(),
                },
                onboarding_hint: "Authenticate first, then import catalog data and guide fields.".to_owned(),
            },
            SourceProviderSnapshot {
                provider_key: "stalker".to_owned(),
                provider_type: "Stalker".to_owned(),
                family: "portal".to_owned(),
                connection_mode: "portal_device".to_owned(),
                summary: "MAG/Stalker portal with device-backed authentication and live/media lanes.".to_owned(),
                capability_model: SourceCapabilityModelSnapshot {
                    live_tv: true,
                    guide: true,
                    movies: true,
                    series: true,
                    catch_up: true,
                    archive_playback: true,
                    remote_playlist_url: false,
                    local_playlist_file: false,
                    account_authentication: true,
                    epg_import: true,
                },
                capabilities: vec![
                    SourceCapabilitySnapshot {
                        id: "live_tv".to_owned(),
                        title: "Live TV".to_owned(),
                        summary: "Device-backed portals can surface channel lists and current-state browse.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "movies".to_owned(),
                        title: "Movies".to_owned(),
                        summary: "Portal catalogs expose movie browsing and detail lanes.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "series".to_owned(),
                        title: "Series".to_owned(),
                        summary: "Series catalogs can populate seasons, episodes, and resume behavior.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "guide".to_owned(),
                        title: "Guide".to_owned(),
                        summary: "Portal EPG data can drive channel schedules and overlays.".to_owned(),
                        supported: true,
                    },
                    SourceCapabilitySnapshot {
                        id: "catch_up".to_owned(),
                        title: "Catch-up".to_owned(),
                        summary: "Archive playback depends on portal support and device session state.".to_owned(),
                        supported: true,
                    },
                ],
                health: SourceHealthSnapshot {
                    status: "Degraded".to_owned(),
                    summary: "Portal session requires reconnect to refresh the device token.".to_owned(),
                    last_checked: "14 minutes ago".to_owned(),
                    last_sync: "Sync pending".to_owned(),
                },
                auth: SourceAuthSnapshot {
                    status: "Reauth required".to_owned(),
                    progress: "35%".to_owned(),
                    summary: "The portal session expired and needs a device reconnect.".to_owned(),
                    primary_action: "Reconnect".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Portal URL".to_owned(),
                        "MAC address".to_owned(),
                        "Device ID".to_owned(),
                    ],
                    helper_lines: vec![
                        "Keep portal credentials separate from playlist flows.".to_owned(),
                        "Device-backed sessions must unwind safely if validation fails.".to_owned(),
                    ],
                },
                import: SourceImportSnapshot {
                    status: "Importing".to_owned(),
                    progress: "68%".to_owned(),
                    summary: "Catalog refresh is running after reconnect.".to_owned(),
                    primary_action: "Continue".to_owned(),
                    secondary_action: "Pause".to_owned(),
                },
                onboarding_hint: "Reconnect the device, then let the portal refresh its catalog and guide state.".to_owned(),
            },
        ],
        onboarding: SourceOnboardingWizardSnapshot {
            selected_provider_type: "M3U URL".to_owned(),
            active_step: "Source Type".to_owned(),
            step_order: vec![
                "Source Type".to_owned(),
                "Connection".to_owned(),
                "Credentials".to_owned(),
                "Import".to_owned(),
                "Finish".to_owned(),
            ],
            steps: vec![
                SourceOnboardingWizardStepSnapshot {
                    step: "Source Type".to_owned(),
                    title: "Choose source type".to_owned(),
                    summary: "Select the provider family first so later fields match the right import and auth model.".to_owned(),
                    primary_action: "Continue".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Source type".to_owned(),
                        "Display name".to_owned(),
                    ],
                    helper_lines: vec![
                        "Keep source/provider selection inside Settings-owned flows.".to_owned(),
                        "Wizard steps stay ordered and reversible.".to_owned(),
                    ],
                },
                SourceOnboardingWizardStepSnapshot {
                    step: "Connection".to_owned(),
                    title: "Add connection details".to_owned(),
                    summary: "Capture the endpoint and source-specific path before auth or validation runs.".to_owned(),
                    primary_action: "Validate connection".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Connection endpoint".to_owned(),
                        "Headers".to_owned(),
                    ],
                    helper_lines: vec![
                        "Connection validation should fail here instead of later import screens.".to_owned(),
                        "Temporary connection state must not auto-restore into a stale step.".to_owned(),
                    ],
                },
                SourceOnboardingWizardStepSnapshot {
                    step: "Credentials".to_owned(),
                    title: "Authenticate source".to_owned(),
                    summary: "Sensitive credentials stay in the wizard and should never auto-restore into a secret-bearing step.".to_owned(),
                    primary_action: "Verify access".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Username".to_owned(),
                        "Password".to_owned(),
                    ],
                    helper_lines: vec![
                        "Auth can be entered for new sources or reconnect flows on existing sources.".to_owned(),
                        "Back from this step returns safely to connection rather than leaving the user in a broken state.".to_owned(),
                    ],
                },
                SourceOnboardingWizardStepSnapshot {
                    step: "Import".to_owned(),
                    title: "Choose import scope".to_owned(),
                    summary: "Review what the source will bring in and confirm the validation result before final import begins.".to_owned(),
                    primary_action: "Start import".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Import scope".to_owned(),
                        "Validation result".to_owned(),
                    ],
                    helper_lines: vec![
                        "Import confirmation is a dedicated step, not a hidden side effect of auth.".to_owned(),
                        "Failures here should unwind cleanly back through the wizard.".to_owned(),
                    ],
                },
                SourceOnboardingWizardStepSnapshot {
                    step: "Finish".to_owned(),
                    title: "Finish setup".to_owned(),
                    summary: "Complete the source handoff and return to source overview with health and capability status visible.".to_owned(),
                    primary_action: "Return to sources".to_owned(),
                    secondary_action: "Back".to_owned(),
                    field_labels: vec![
                        "Validation result".to_owned(),
                        "Import scope".to_owned(),
                    ],
                    helper_lines: vec![
                        "Success returns to the Settings-owned source overview, not to a detached source domain.".to_owned(),
                        "The next runtime phases can rely on this onboarding lane being complete.".to_owned(),
                    ],
                },
            ],
            provider_copy: vec![
                SourceProviderWizardCopySnapshot {
                    provider_key: "m3u_url".to_owned(),
                    provider_type: "M3U URL".to_owned(),
                    title: "Remote playlist".to_owned(),
                    summary: "Use a direct M3U URL when the provider exposes a playlist endpoint.".to_owned(),
                    helper_lines: vec![
                        "Best for direct playlist URLs and optional guide pairing.".to_owned(),
                        "No account credentials are required unless the playlist is gated.".to_owned(),
                    ],
                },
                SourceProviderWizardCopySnapshot {
                    provider_key: "local_m3u".to_owned(),
                    provider_type: "local M3U".to_owned(),
                    title: "Local file".to_owned(),
                    summary: "Use a local file when the playlist is stored on device or mounted storage.".to_owned(),
                    helper_lines: vec![
                        "Good for offline or imported playlist workflows.".to_owned(),
                        "Guide data can be paired after the file is validated.".to_owned(),
                    ],
                },
                SourceProviderWizardCopySnapshot {
                    provider_key: "xtream".to_owned(),
                    provider_type: "Xtream".to_owned(),
                    title: "Account-backed portal".to_owned(),
                    summary: "Use Xtream when the provider exposes a username/password portal model.".to_owned(),
                    helper_lines: vec![
                        "Credentials are required before catalog import can begin.".to_owned(),
                        "Live TV, movies, series, and EPG can all be populated from the portal.".to_owned(),
                    ],
                },
                SourceProviderWizardCopySnapshot {
                    provider_key: "stalker".to_owned(),
                    provider_type: "Stalker".to_owned(),
                    title: "Device-backed portal".to_owned(),
                    summary: "Use Stalker when the provider expects a MAG-style device portal connection.".to_owned(),
                    helper_lines: vec![
                        "Portal URL plus device identifiers are required.".to_owned(),
                        "Reconnect and refresh should happen safely inside the wizard.".to_owned(),
                    ],
                },
            ],
        },
        registry_notes: vec![
            "Provider metadata stays Rust-owned so Flutter can consume a stable snapshot later.".to_owned(),
            "The registry models both capability support and current state for each provider family.".to_owned(),
            "Auth and import progress are explicit so the onboarding wizard can render status without guessing.".to_owned(),
        ],
    }
}

pub fn source_registry_json() -> String {
    serde_json::to_string_pretty(&source_registry_snapshot())
        .expect("source registry serialization should succeed")
}

fn playback_source(
    kind: &str,
    source_key: &str,
    content_key: &str,
    source_label: &str,
    handoff_label: &str,
) -> PlaybackSourceSnapshot {
    PlaybackSourceSnapshot {
        kind: kind.to_owned(),
        source_key: source_key.to_owned(),
        content_key: content_key.to_owned(),
        source_label: source_label.to_owned(),
        handoff_label: handoff_label.to_owned(),
    }
}

fn playback_stream(
    uri: &str,
    transport: &str,
    live: bool,
    seekable: bool,
    resume_position_seconds: u32,
) -> PlaybackStreamSnapshot {
    let mirror_uri = uri.replace(".m3u8", "-mirror.m3u8");
    let quality_1080_uri = uri.replace(".m3u8", "-1080.m3u8");
    let quality_720_uri = uri.replace(".m3u8", "-720.m3u8");
    let audio_main_uri = uri.replace(".m3u8", "/audio-main.aac");
    let audio_commentary_uri = uri.replace(".m3u8", "/audio-commentary.aac");
    let subtitle_cc_uri = uri.replace(".m3u8", "/subtitles-en.vtt");
    let subtitle_de_uri = uri.replace(".m3u8", "/subtitles-de.vtt");
    PlaybackStreamSnapshot {
        uri: uri.to_owned(),
        transport: transport.to_owned(),
        live,
        seekable,
        resume_position_seconds,
        source_options: vec![
            PlaybackVariantOptionSnapshot {
                id: "primary".to_owned(),
                label: "Primary source".to_owned(),
                uri: uri.to_owned(),
                transport: transport.to_owned(),
                live,
                seekable,
                resume_position_seconds,
            },
            PlaybackVariantOptionSnapshot {
                id: "mirror".to_owned(),
                label: "Mirror source".to_owned(),
                uri: mirror_uri,
                transport: transport.to_owned(),
                live,
                seekable,
                resume_position_seconds,
            },
        ],
        quality_options: vec![
            PlaybackVariantOptionSnapshot {
                id: "auto".to_owned(),
                label: "Auto".to_owned(),
                uri: uri.to_owned(),
                transport: transport.to_owned(),
                live,
                seekable,
                resume_position_seconds,
            },
            PlaybackVariantOptionSnapshot {
                id: "1080p".to_owned(),
                label: "1080p".to_owned(),
                uri: quality_1080_uri,
                transport: transport.to_owned(),
                live,
                seekable,
                resume_position_seconds,
            },
            PlaybackVariantOptionSnapshot {
                id: "720p".to_owned(),
                label: "720p".to_owned(),
                uri: quality_720_uri,
                transport: transport.to_owned(),
                live,
                seekable,
                resume_position_seconds,
            },
        ],
        audio_options: vec![
            PlaybackTrackOptionSnapshot {
                id: "auto".to_owned(),
                label: "Main mix".to_owned(),
                uri: audio_main_uri,
                language: Some("en".to_owned()),
            },
            PlaybackTrackOptionSnapshot {
                id: "commentary".to_owned(),
                label: "Commentary".to_owned(),
                uri: audio_commentary_uri,
                language: Some("en".to_owned()),
            },
        ],
        subtitle_options: vec![
            PlaybackTrackOptionSnapshot {
                id: "off".to_owned(),
                label: "Off".to_owned(),
                uri: String::new(),
                language: None,
            },
            PlaybackTrackOptionSnapshot {
                id: "en-cc".to_owned(),
                label: "English CC".to_owned(),
                uri: subtitle_cc_uri,
                language: Some("en".to_owned()),
            },
            PlaybackTrackOptionSnapshot {
                id: "de".to_owned(),
                label: "Deutsch".to_owned(),
                uri: subtitle_de_uri,
                language: Some("de".to_owned()),
            },
        ],
    }
}

pub fn live_tv_runtime_snapshot() -> LiveTvRuntimeSnapshot {
    LiveTvRuntimeSnapshot {
        title: "CrispyTivi Live TV Runtime".to_owned(),
        version: "1".to_owned(),
        provider: LiveTvRuntimeProviderSnapshot {
            provider_key: "home_fiber_iptv".to_owned(),
            provider_type: "M3U + XMLTV".to_owned(),
            family: "playlist".to_owned(),
            connection_mode: "remote_url".to_owned(),
            source_name: "Home Fiber IPTV".to_owned(),
            status: "Healthy".to_owned(),
            summary: "Live channels and guide data are synchronized for browse and playback.".to_owned(),
            last_sync: "2 minutes ago".to_owned(),
            guide_health: "EPG verified".to_owned(),
        },
        browsing: LiveTvRuntimeBrowsingSnapshot {
            active_panel: "Channels".to_owned(),
            selected_group: "All".to_owned(),
            selected_channel: "118 Arena Live".to_owned(),
            group_order: vec![
                "All".to_owned(),
                "News".to_owned(),
                "Sports".to_owned(),
                "Movies".to_owned(),
                "Kids".to_owned(),
            ],
            groups: vec![
                LiveTvRuntimeGroupSnapshot {
                    id: "all".to_owned(),
                    title: "All".to_owned(),
                    summary: "Every available live channel".to_owned(),
                    channel_count: 4,
                    selected: true,
                },
                LiveTvRuntimeGroupSnapshot {
                    id: "news".to_owned(),
                    title: "News".to_owned(),
                    summary: "Channel rows focused on news and current affairs".to_owned(),
                    channel_count: 1,
                    selected: false,
                },
                LiveTvRuntimeGroupSnapshot {
                    id: "sports".to_owned(),
                    title: "Sports".to_owned(),
                    summary: "Live sports and replay-heavy channels".to_owned(),
                    channel_count: 1,
                    selected: false,
                },
                LiveTvRuntimeGroupSnapshot {
                    id: "movies".to_owned(),
                    title: "Movies".to_owned(),
                    summary: "Cinematic channels and film blocks".to_owned(),
                    channel_count: 1,
                    selected: false,
                },
                LiveTvRuntimeGroupSnapshot {
                    id: "kids".to_owned(),
                    title: "Kids".to_owned(),
                    summary: "Family and daytime channels".to_owned(),
                    channel_count: 1,
                    selected: false,
                },
            ],
        },
        channels: vec![
            LiveTvRuntimeChannelSnapshot {
                number: "101".to_owned(),
                name: "Crispy One".to_owned(),
                group: "News".to_owned(),
                state: "selected".to_owned(),
                live_edge: true,
                catch_up: true,
                archive: true,
                playback_source: playback_source(
                    "live_channel",
                    "home_fiber_iptv",
                    "101",
                    "Home Fiber IPTV",
                    "Watch live",
                ),
                playback_stream: playback_stream(
                    "https://stream.crispy-tivi.test/live/101.m3u8",
                    "hls",
                    true,
                    true,
                    0,
                ),
                current: LiveTvRuntimeProgramSnapshot {
                    title: "Midnight Bulletin".to_owned(),
                    summary: "Top stories, business close, and late headlines.".to_owned(),
                    start: "21:00".to_owned(),
                    end: "22:00".to_owned(),
                    progress_percent: 55,
                },
                next: LiveTvRuntimeProgramSnapshot {
                    title: "Market Close".to_owned(),
                    summary: "Wrap-up analysis and overnight context.".to_owned(),
                    start: "22:00".to_owned(),
                    end: "22:30".to_owned(),
                    progress_percent: 0,
                },
            },
            LiveTvRuntimeChannelSnapshot {
                number: "118".to_owned(),
                name: "Arena Live".to_owned(),
                group: "Sports".to_owned(),
                state: "playing".to_owned(),
                live_edge: true,
                catch_up: true,
                archive: true,
                playback_source: playback_source(
                    "live_channel",
                    "home_fiber_iptv",
                    "118",
                    "Home Fiber IPTV",
                    "Watch live",
                ),
                playback_stream: playback_stream(
                    "https://stream.crispy-tivi.test/live/118.m3u8",
                    "hls",
                    true,
                    true,
                    0,
                ),
                current: LiveTvRuntimeProgramSnapshot {
                    title: "Championship Replay".to_owned(),
                    summary: "A full replay block with halftime detail and tactical breakdown.".to_owned(),
                    start: "21:30".to_owned(),
                    end: "23:30".to_owned(),
                    progress_percent: 33,
                },
                next: LiveTvRuntimeProgramSnapshot {
                    title: "Locker Room".to_owned(),
                    summary: "Postgame reaction and highlights.".to_owned(),
                    start: "23:30".to_owned(),
                    end: "00:00".to_owned(),
                    progress_percent: 0,
                },
            },
            LiveTvRuntimeChannelSnapshot {
                number: "205".to_owned(),
                name: "Cinema Vault".to_owned(),
                group: "Movies".to_owned(),
                state: "browse".to_owned(),
                live_edge: false,
                catch_up: true,
                archive: true,
                playback_source: playback_source(
                    "live_channel",
                    "home_fiber_iptv",
                    "205",
                    "Home Fiber IPTV",
                    "Watch live",
                ),
                playback_stream: playback_stream(
                    "https://stream.crispy-tivi.test/live/205.m3u8",
                    "hls",
                    false,
                    true,
                    0,
                ),
                current: LiveTvRuntimeProgramSnapshot {
                    title: "Coastal Drive".to_owned(),
                    summary: "A movie block tuned for late-night browsing.".to_owned(),
                    start: "20:45".to_owned(),
                    end: "22:35".to_owned(),
                    progress_percent: 71,
                },
                next: LiveTvRuntimeProgramSnapshot {
                    title: "Trailer Reel".to_owned(),
                    summary: "A trailer-led follow-up block.".to_owned(),
                    start: "22:35".to_owned(),
                    end: "23:00".to_owned(),
                    progress_percent: 0,
                },
            },
            LiveTvRuntimeChannelSnapshot {
                number: "311".to_owned(),
                name: "Nature Atlas".to_owned(),
                group: "Kids".to_owned(),
                state: "browse".to_owned(),
                live_edge: false,
                catch_up: false,
                archive: true,
                playback_source: playback_source(
                    "live_channel",
                    "home_fiber_iptv",
                    "311",
                    "Home Fiber IPTV",
                    "Watch live",
                ),
                playback_stream: playback_stream(
                    "https://stream.crispy-tivi.test/live/311.m3u8",
                    "hls",
                    false,
                    true,
                    0,
                ),
                current: LiveTvRuntimeProgramSnapshot {
                    title: "Winter Oceans".to_owned(),
                    summary: "A slow documentary block with broad landscape framing.".to_owned(),
                    start: "21:15".to_owned(),
                    end: "22:15".to_owned(),
                    progress_percent: 41,
                },
                next: LiveTvRuntimeProgramSnapshot {
                    title: "Arctic Voices".to_owned(),
                    summary: "Glacial wildlife and ambient field footage.".to_owned(),
                    start: "22:15".to_owned(),
                    end: "22:45".to_owned(),
                    progress_percent: 0,
                },
            },
        ],
        guide: LiveTvRuntimeGuideSnapshot {
            title: "Live TV Guide".to_owned(),
            window_start: "21:00".to_owned(),
            window_end: "23:00".to_owned(),
            time_slots: vec![
                "Now".to_owned(),
                "21:30".to_owned(),
                "22:00".to_owned(),
                "22:30".to_owned(),
                "23:00".to_owned(),
            ],
            rows: vec![
                LiveTvRuntimeGuideRowSnapshot {
                    channel_number: "101".to_owned(),
                    channel_name: "Crispy One".to_owned(),
                    slots: vec![
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "21:00".to_owned(),
                            end: "22:00".to_owned(),
                            title: "Midnight Bulletin".to_owned(),
                            state: "current".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "22:00".to_owned(),
                            end: "22:30".to_owned(),
                            title: "Market Close".to_owned(),
                            state: "next".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "22:30".to_owned(),
                            end: "23:00".to_owned(),
                            title: "Nightline".to_owned(),
                            state: "future".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "23:00".to_owned(),
                            end: "23:30".to_owned(),
                            title: "Forecast".to_owned(),
                            state: "future".to_owned(),
                        },
                    ],
                },
                LiveTvRuntimeGuideRowSnapshot {
                    channel_number: "118".to_owned(),
                    channel_name: "Arena Live".to_owned(),
                    slots: vec![
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "21:30".to_owned(),
                            end: "23:30".to_owned(),
                            title: "Championship Replay".to_owned(),
                            state: "current".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "23:30".to_owned(),
                            end: "00:00".to_owned(),
                            title: "Locker Room".to_owned(),
                            state: "next".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "00:00".to_owned(),
                            end: "00:30".to_owned(),
                            title: "Highlights".to_owned(),
                            state: "future".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "00:30".to_owned(),
                            end: "01:00".to_owned(),
                            title: "Analysis".to_owned(),
                            state: "future".to_owned(),
                        },
                    ],
                },
                LiveTvRuntimeGuideRowSnapshot {
                    channel_number: "205".to_owned(),
                    channel_name: "Cinema Vault".to_owned(),
                    slots: vec![
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "20:45".to_owned(),
                            end: "22:35".to_owned(),
                            title: "Coastal Drive".to_owned(),
                            state: "current".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "22:35".to_owned(),
                            end: "23:00".to_owned(),
                            title: "Trailer Reel".to_owned(),
                            state: "next".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "23:00".to_owned(),
                            end: "23:30".to_owned(),
                            title: "Studio Cut".to_owned(),
                            state: "future".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "23:30".to_owned(),
                            end: "00:00".to_owned(),
                            title: "Encore".to_owned(),
                            state: "future".to_owned(),
                        },
                    ],
                },
                LiveTvRuntimeGuideRowSnapshot {
                    channel_number: "311".to_owned(),
                    channel_name: "Nature Atlas".to_owned(),
                    slots: vec![
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "21:15".to_owned(),
                            end: "22:15".to_owned(),
                            title: "Winter Oceans".to_owned(),
                            state: "current".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "22:15".to_owned(),
                            end: "22:45".to_owned(),
                            title: "Arctic Voices".to_owned(),
                            state: "next".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "22:45".to_owned(),
                            end: "23:15".to_owned(),
                            title: "Wild Frontiers".to_owned(),
                            state: "future".to_owned(),
                        },
                        LiveTvRuntimeGuideSlotSnapshot {
                            start: "23:15".to_owned(),
                            end: "23:45".to_owned(),
                            title: "Night Shift".to_owned(),
                            state: "future".to_owned(),
                        },
                    ],
                },
            ],
        },
        selection: LiveTvRuntimeSelectionSnapshot {
            channel_number: "118".to_owned(),
            channel_name: "Arena Live".to_owned(),
            status: "Live".to_owned(),
            live_edge: true,
            catch_up: true,
            archive: true,
            now: LiveTvRuntimeProgramSnapshot {
                title: "Championship Replay".to_owned(),
                summary: "A replay block with postgame analysis and on-screen highlights.".to_owned(),
                start: "21:30".to_owned(),
                end: "23:30".to_owned(),
                progress_percent: 33,
            },
            next: LiveTvRuntimeProgramSnapshot {
                title: "Locker Room".to_owned(),
                summary: "Reaction, interviews, and clipped highlights.".to_owned(),
                start: "23:30".to_owned(),
                end: "00:00".to_owned(),
                progress_percent: 0,
            },
            primary_action: "Watch live".to_owned(),
            secondary_action: "Start over".to_owned(),
            badges: vec![
                "Live".to_owned(),
                "Sports".to_owned(),
                "Catch-up".to_owned(),
            ],
            detail_lines: vec![
                "Selected detail stays in the right lane while browse remains on the left.".to_owned(),
                "EPG and playback metadata remain synchronized to the same channel selection.".to_owned(),
            ],
        },
        notes: vec![
            "The runtime snapshot stays asset-backed for now so later provider/EPG replacement can preserve shape.".to_owned(),
            "Live browse and guide rows are modeled separately from legacy shell content.".to_owned(),
            "The schema keeps channel, guide, and selection state typed for later Rust provider wiring.".to_owned(),
        ],
    }
}

pub fn live_tv_runtime_json() -> String {
    serde_json::to_string_pretty(&live_tv_runtime_snapshot())
        .expect("live tv runtime serialization should succeed")
}

pub fn media_runtime_snapshot() -> MediaRuntimeSnapshot {
    MediaRuntimeSnapshot {
        title: "CrispyTivi Media Runtime".to_owned(),
        version: "1".to_owned(),
        active_panel: "Movies".to_owned(),
        active_scope: "Featured".to_owned(),
        movie_hero: MediaRuntimeHeroSnapshot {
            kicker: "Featured film".to_owned(),
            title: "The Last Harbor".to_owned(),
            summary:
                "A cinematic detail state with clear action hierarchy, restrained metadata, and content-first framing."
                    .to_owned(),
            primary_action: "Play trailer".to_owned(),
            secondary_action: "Add to watchlist".to_owned(),
        },
        series_hero: MediaRuntimeHeroSnapshot {
            kicker: "Series spotlight".to_owned(),
            title: "Shadow Signals".to_owned(),
            summary: "Season-driven browsing stays inside the media domain with episode context and tight focus separation."
                .to_owned(),
            primary_action: "Resume S1:E6".to_owned(),
            secondary_action: "Browse episodes".to_owned(),
        },
        movie_collections: vec![
            MediaRuntimeCollectionSnapshot {
                title: "Featured Films".to_owned(),
                summary: "Featured runtime films.".to_owned(),
                items: vec![
                    MediaRuntimeItemSnapshot {
                        title: "The Last Harbor".to_owned(),
                        caption: "Thriller".to_owned(),
                        rank: Some(1),
                        playback_source: playback_source(
                            "movie",
                            "media_library",
                            "the-last-harbor",
                            "Media Library",
                            "Play movie",
                        ),
                        playback_stream: playback_stream(
                            "https://stream.crispy-tivi.test/media/the-last-harbor.m3u8",
                            "hls",
                            false,
                            true,
                            0,
                        ),
                    },
                    MediaRuntimeItemSnapshot {
                        title: "Atlas Run".to_owned(),
                        caption: "Action".to_owned(),
                        rank: Some(2),
                        playback_source: playback_source(
                            "movie",
                            "media_library",
                            "atlas-run",
                            "Media Library",
                            "Play movie",
                        ),
                        playback_stream: playback_stream(
                            "https://stream.crispy-tivi.test/media/atlas-run.m3u8",
                            "hls",
                            false,
                            true,
                            0,
                        ),
                    },
                ],
            },
            MediaRuntimeCollectionSnapshot {
                title: "Continue Watching Films".to_owned(),
                summary: "Resume-ready film items.".to_owned(),
                items: vec![
                    MediaRuntimeItemSnapshot {
                        title: "Neon District".to_owned(),
                        caption: "42 min left".to_owned(),
                        rank: None,
                        playback_source: playback_source(
                            "movie",
                            "media_library",
                            "neon-district",
                            "Media Library",
                            "Resume movie",
                        ),
                        playback_stream: playback_stream(
                            "https://stream.crispy-tivi.test/media/neon-district.m3u8",
                            "hls",
                            false,
                            true,
                            2520,
                        ),
                    },
                    MediaRuntimeItemSnapshot {
                        title: "Chef After Dark".to_owned(),
                        caption: "Resume S2:E4".to_owned(),
                        rank: None,
                        playback_source: playback_source(
                            "movie",
                            "media_library",
                            "chef-after-dark",
                            "Media Library",
                            "Resume movie",
                        ),
                        playback_stream: playback_stream(
                            "https://stream.crispy-tivi.test/media/chef-after-dark.m3u8",
                            "hls",
                            false,
                            true,
                            3480,
                        ),
                    },
                ],
            },
        ],
        series_collections: vec![
            MediaRuntimeCollectionSnapshot {
                title: "Featured Series".to_owned(),
                summary: "Featured runtime series.".to_owned(),
                items: vec![
                    MediaRuntimeItemSnapshot {
                        title: "Shadow Signals".to_owned(),
                        caption: "New episode".to_owned(),
                        rank: Some(1),
                        playback_source: playback_source(
                            "series",
                            "media_library",
                            "shadow-signals",
                            "Media Library",
                            "Browse series",
                        ),
                        playback_stream: playback_stream(
                            "https://stream.crispy-tivi.test/media/shadow-signals.m3u8",
                            "hls",
                            false,
                            true,
                            0,
                        ),
                    },
                    MediaRuntimeItemSnapshot {
                        title: "Northline".to_owned(),
                        caption: "New season".to_owned(),
                        rank: Some(2),
                        playback_source: playback_source(
                            "series",
                            "media_library",
                            "northline",
                            "Media Library",
                            "Browse series",
                        ),
                        playback_stream: playback_stream(
                            "https://stream.crispy-tivi.test/media/northline.m3u8",
                            "hls",
                            false,
                            true,
                            0,
                        ),
                    },
                ],
            },
            MediaRuntimeCollectionSnapshot {
                title: "Continue Watching Series".to_owned(),
                summary: "Resume-ready series items.".to_owned(),
                items: vec![
                    MediaRuntimeItemSnapshot {
                        title: "Neon District".to_owned(),
                        caption: "42 min left".to_owned(),
                        rank: None,
                        playback_source: playback_source(
                            "series",
                            "media_library",
                            "neon-district",
                            "Media Library",
                            "Resume series",
                        ),
                        playback_stream: playback_stream(
                            "https://stream.crispy-tivi.test/media/neon-district-series.m3u8",
                            "hls",
                            false,
                            true,
                            2520,
                        ),
                    },
                    MediaRuntimeItemSnapshot {
                        title: "Chef After Dark".to_owned(),
                        caption: "Resume S2:E4".to_owned(),
                        rank: None,
                        playback_source: playback_source(
                            "series",
                            "media_library",
                            "chef-after-dark",
                            "Media Library",
                            "Resume series",
                        ),
                        playback_stream: playback_stream(
                            "https://stream.crispy-tivi.test/media/chef-after-dark-series.m3u8",
                            "hls",
                            false,
                            true,
                            3480,
                        ),
                    },
                ],
            },
        ],
        series_detail: MediaRuntimeSeriesDetailSnapshot {
            summary_title: "Season and episode playback".to_owned(),
            summary_body:
                "Shadow Signals keeps season choice above episode choice and keeps playback inside the player."
                    .to_owned(),
            handoff_label: "Play episode".to_owned(),
            seasons: vec![
                MediaRuntimeSeasonSnapshot {
                    label: "Season 1".to_owned(),
                    summary: "Entry season for the current series surface.".to_owned(),
                    episodes: vec![
                        MediaRuntimeEpisodeSnapshot {
                            code: "S1:E1".to_owned(),
                            title: "Shadow Signals".to_owned(),
                            summary: "The signal appears in the harbor network.".to_owned(),
                            duration_label: "45 min".to_owned(),
                            handoff_label: "Play episode".to_owned(),
                            playback_source: playback_source(
                                "episode",
                                "shadow-signals",
                                "S1:E1",
                                "Shadow Signals",
                                "Play episode",
                            ),
                            playback_stream: playback_stream(
                                "https://stream.crispy-tivi.test/series/shadow-signals/s1e1.m3u8",
                                "hls",
                                false,
                                true,
                                0,
                            ),
                        },
                        MediaRuntimeEpisodeSnapshot {
                            code: "S1:E2".to_owned(),
                            title: "After Current".to_owned(),
                            summary: "Continue the season flow from the previous episode."
                                .to_owned(),
                            duration_label: "42 min".to_owned(),
                            handoff_label: "Play episode".to_owned(),
                            playback_source: playback_source(
                                "episode",
                                "shadow-signals",
                                "S1:E2",
                                "Shadow Signals",
                                "Play episode",
                            ),
                            playback_stream: playback_stream(
                                "https://stream.crispy-tivi.test/series/shadow-signals/s1e2.m3u8",
                                "hls",
                                false,
                                true,
                                0,
                            ),
                        },
                    ],
                },
                MediaRuntimeSeasonSnapshot {
                    label: "Season 2".to_owned(),
                    summary: "Continuation season with playback ready for the next episode."
                        .to_owned(),
                    episodes: vec![
                        MediaRuntimeEpisodeSnapshot {
                            code: "S2:E1".to_owned(),
                            title: "Northline".to_owned(),
                            summary: "The next chapter opens on a drifting transmission."
                                .to_owned(),
                            duration_label: "47 min".to_owned(),
                            handoff_label: "Play episode".to_owned(),
                            playback_source: playback_source(
                                "episode",
                                "shadow-signals",
                                "S2:E1",
                                "Shadow Signals",
                                "Play episode",
                            ),
                            playback_stream: playback_stream(
                                "https://stream.crispy-tivi.test/series/shadow-signals/s2e1.m3u8",
                                "hls",
                                false,
                                true,
                                0,
                            ),
                        },
                    ],
                },
            ],
        },
        notes: vec!["Rust-owned media runtime snapshot.".to_owned()],
    }
}

pub fn media_runtime_json() -> String {
    serde_json::to_string_pretty(&media_runtime_snapshot())
        .expect("media runtime serialization should succeed")
}

pub fn search_runtime_snapshot() -> SearchRuntimeSnapshot {
    SearchRuntimeSnapshot {
        title: "CrispyTivi Search Runtime".to_owned(),
        version: "1".to_owned(),
        query: String::new(),
        active_group_title: "Live TV".to_owned(),
        groups: vec![
            SearchRuntimeGroupSnapshot {
                title: "Live TV".to_owned(),
                summary: "Live channels and guide-linked results.".to_owned(),
                selected: true,
                results: vec![
                    SearchRuntimeResultSnapshot {
                        title: "Arena Live".to_owned(),
                        caption: "Channel 118".to_owned(),
                        source_label: "Live TV".to_owned(),
                        handoff_label: "Open channel".to_owned(),
                    },
                    SearchRuntimeResultSnapshot {
                        title: "Cinema Vault".to_owned(),
                        caption: "Channel 205".to_owned(),
                        source_label: "Live TV".to_owned(),
                        handoff_label: "Open channel".to_owned(),
                    },
                ],
            },
            SearchRuntimeGroupSnapshot {
                title: "Movies".to_owned(),
                summary: "Film results and featured rails.".to_owned(),
                selected: false,
                results: vec![
                    SearchRuntimeResultSnapshot {
                        title: "The Last Harbor".to_owned(),
                        caption: "Thriller".to_owned(),
                        source_label: "Movies".to_owned(),
                        handoff_label: "Open movie".to_owned(),
                    },
                    SearchRuntimeResultSnapshot {
                        title: "Atlas Run".to_owned(),
                        caption: "Action".to_owned(),
                        source_label: "Movies".to_owned(),
                        handoff_label: "Open movie".to_owned(),
                    },
                ],
            },
            SearchRuntimeGroupSnapshot {
                title: "Series".to_owned(),
                summary: "Series results and episode-ready handoff.".to_owned(),
                selected: false,
                results: vec![
                    SearchRuntimeResultSnapshot {
                        title: "Shadow Signals".to_owned(),
                        caption: "Sci-fi drama".to_owned(),
                        source_label: "Series".to_owned(),
                        handoff_label: "Open series".to_owned(),
                    },
                    SearchRuntimeResultSnapshot {
                        title: "Northline".to_owned(),
                        caption: "New season".to_owned(),
                        source_label: "Series".to_owned(),
                        handoff_label: "Open series".to_owned(),
                    },
                ],
            },
        ],
        notes: vec!["Rust-owned search runtime snapshot.".to_owned()],
    }
}

pub fn search_runtime_json() -> String {
    serde_json::to_string_pretty(&search_runtime_snapshot())
        .expect("search runtime serialization should succeed")
}

pub fn personalization_runtime_snapshot() -> PersonalizationRuntimeSnapshot {
    PersonalizationRuntimeSnapshot {
        title: "CrispyTivi Personalization Runtime".to_owned(),
        version: "1".to_owned(),
        startup_route: "Home".to_owned(),
        continue_watching: vec![
            PersistentPlaybackEntry {
                kind: "movie".to_owned(),
                content_key: "the-last-harbor".to_owned(),
                channel_number: None,
                title: "The Last Harbor".to_owned(),
                caption: "01:24 / 02:11 · Resume".to_owned(),
                summary: "Continue from your last movie position.".to_owned(),
                progress_label: "01:24 / 02:11 · Resume".to_owned(),
                progress_value: 0.64,
                resume_position_seconds: 5040,
                last_viewed_at: "2026-04-12T21:15:00Z".to_owned(),
                detail_lines: vec![
                    "Movie · Thriller".to_owned(),
                    "Resume from your last position.".to_owned(),
                ],
                artwork: Some(ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-1.jpg".to_owned(),
                }),
                playback_source: Some(PlaybackSourceSnapshot {
                    kind: "movie".to_owned(),
                    source_key: "media_library".to_owned(),
                    content_key: "the-last-harbor".to_owned(),
                    source_label: "Movies".to_owned(),
                    handoff_label: "Open movie".to_owned(),
                }),
                playback_stream: Some(PlaybackStreamSnapshot {
                    uri: "https://stream.crispy-tivi.test/media/the-last-harbor.m3u8".to_owned(),
                    transport: "hls".to_owned(),
                    live: false,
                    seekable: true,
                    resume_position_seconds: 5040,
                    source_options: vec![PlaybackVariantOptionSnapshot {
                        id: "primary".to_owned(),
                        label: "Preferred source".to_owned(),
                        uri: "https://stream.crispy-tivi.test/media/the-last-harbor.m3u8"
                            .to_owned(),
                        transport: "hls".to_owned(),
                        live: false,
                        seekable: true,
                        resume_position_seconds: 5040,
                    }],
                    quality_options: vec![PlaybackVariantOptionSnapshot {
                        id: "auto".to_owned(),
                        label: "Auto".to_owned(),
                        uri: "https://stream.crispy-tivi.test/media/the-last-harbor.m3u8"
                            .to_owned(),
                        transport: "hls".to_owned(),
                        live: false,
                        seekable: true,
                        resume_position_seconds: 5040,
                    }],
                    audio_options: vec![PlaybackTrackOptionSnapshot {
                        id: "audio-main".to_owned(),
                        label: "English 5.1".to_owned(),
                        uri: "https://stream.crispy-tivi.test/media/the-last-harbor/audio-main.aac"
                            .to_owned(),
                        language: Some("en".to_owned()),
                    }],
                    subtitle_options: vec![PlaybackTrackOptionSnapshot {
                        id: "subs-en".to_owned(),
                        label: "English CC".to_owned(),
                        uri: "https://stream.crispy-tivi.test/media/the-last-harbor/subtitles-en.vtt"
                            .to_owned(),
                        language: Some("en".to_owned()),
                    }],
                }),
            },
            PersistentPlaybackEntry {
                kind: "episode".to_owned(),
                content_key: "S1:E2".to_owned(),
                channel_number: None,
                title: "Shadow Signals".to_owned(),
                caption: "S1:E2 · 18 min left".to_owned(),
                summary: "Continue the current episode from the saved position."
                    .to_owned(),
                progress_label: "31:00 / 49:00 · Resume".to_owned(),
                progress_value: 0.63,
                resume_position_seconds: 1860,
                last_viewed_at: "2026-04-12T22:40:00Z".to_owned(),
                detail_lines: vec![
                    "Season 1 · Episode 2".to_owned(),
                    "Resume from your last episode position.".to_owned(),
                ],
                artwork: Some(ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-5.jpg".to_owned(),
                }),
                playback_source: Some(PlaybackSourceSnapshot {
                    kind: "episode".to_owned(),
                    source_key: "shadow-signals".to_owned(),
                    content_key: "S1:E2".to_owned(),
                    source_label: "Series".to_owned(),
                    handoff_label: "Open episode".to_owned(),
                }),
                playback_stream: Some(PlaybackStreamSnapshot {
                    uri: "https://stream.crispy-tivi.test/series/shadow-signals/s1e2.m3u8"
                        .to_owned(),
                    transport: "hls".to_owned(),
                    live: false,
                    seekable: true,
                    resume_position_seconds: 1860,
                    source_options: vec![PlaybackVariantOptionSnapshot {
                        id: "primary".to_owned(),
                        label: "Preferred source".to_owned(),
                        uri: "https://stream.crispy-tivi.test/series/shadow-signals/s1e2.m3u8"
                            .to_owned(),
                        transport: "hls".to_owned(),
                        live: false,
                        seekable: true,
                        resume_position_seconds: 1860,
                    }],
                    quality_options: vec![PlaybackVariantOptionSnapshot {
                        id: "auto".to_owned(),
                        label: "Auto".to_owned(),
                        uri: "https://stream.crispy-tivi.test/series/shadow-signals/s1e2.m3u8"
                            .to_owned(),
                        transport: "hls".to_owned(),
                        live: false,
                        seekable: true,
                        resume_position_seconds: 1860,
                    }],
                    audio_options: vec![PlaybackTrackOptionSnapshot {
                        id: "audio-main".to_owned(),
                        label: "English 5.1".to_owned(),
                        uri:
                            "https://stream.crispy-tivi.test/series/shadow-signals/s1e2/audio-main.aac"
                                .to_owned(),
                        language: Some("en".to_owned()),
                    }],
                    subtitle_options: vec![PlaybackTrackOptionSnapshot {
                        id: "subs-en".to_owned(),
                        label: "English CC".to_owned(),
                        uri:
                            "https://stream.crispy-tivi.test/series/shadow-signals/s1e2/subtitles-en.vtt"
                                .to_owned(),
                        language: Some("en".to_owned()),
                    }],
                }),
            },
        ],
        recently_viewed: vec![
            PersistentPlaybackEntry {
                kind: "movie".to_owned(),
                content_key: "the-last-harbor".to_owned(),
                channel_number: None,
                title: "The Last Harbor".to_owned(),
                caption: "Thriller".to_owned(),
                summary: "Recently viewed film.".to_owned(),
                progress_label: "01:24 / 02:11 · Resume".to_owned(),
                progress_value: 0.64,
                resume_position_seconds: 5040,
                last_viewed_at: "2026-04-12T21:15:00Z".to_owned(),
                detail_lines: vec!["Movie · Thriller".to_owned()],
                artwork: Some(ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-1.jpg".to_owned(),
                }),
                playback_source: None,
                playback_stream: None,
            },
            PersistentPlaybackEntry {
                kind: "episode".to_owned(),
                content_key: "S1:E2".to_owned(),
                channel_number: None,
                title: "Shadow Signals".to_owned(),
                caption: "Sci-fi drama".to_owned(),
                summary: "Recently viewed episode.".to_owned(),
                progress_label: "31:00 / 49:00 · Resume".to_owned(),
                progress_value: 0.63,
                resume_position_seconds: 1860,
                last_viewed_at: "2026-04-12T22:40:00Z".to_owned(),
                detail_lines: vec!["Season 1 · Episode 2".to_owned()],
                artwork: Some(ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-5.jpg".to_owned(),
                }),
                playback_source: None,
                playback_stream: None,
            },
            PersistentPlaybackEntry {
                kind: "series".to_owned(),
                content_key: "chef-after-dark".to_owned(),
                channel_number: None,
                title: "Chef After Dark".to_owned(),
                caption: "Food series".to_owned(),
                summary: "Recently viewed series lane.".to_owned(),
                progress_label: "Fresh episode available".to_owned(),
                progress_value: 0.0,
                resume_position_seconds: 0,
                last_viewed_at: "2026-04-11T20:30:00Z".to_owned(),
                detail_lines: vec!["Series · Food".to_owned()],
                artwork: Some(ArtworkSource {
                    kind: "asset".to_owned(),
                    value: "assets/mocks/poster-shell-2.jpg".to_owned(),
                }),
                playback_source: None,
                playback_stream: None,
            },
        ],
        favorite_media_keys: vec![
            "the-last-harbor".to_owned(),
            "chef-after-dark".to_owned(),
        ],
        favorite_channel_numbers: vec!["118".to_owned()],
        notes: vec![
            "Asset-backed personalization defaults for the retained runtime boundary."
                .to_owned(),
        ],
    }
}

pub fn personalization_runtime_json() -> String {
    serde_json::to_string_pretty(&personalization_runtime_snapshot())
        .expect("personalization runtime serialization should succeed")
}

#[cfg(not(target_arch = "wasm32"))]
fn block_on_diagnostics_probe<F>(future: F) -> bool
where
    F: std::future::Future<Output = bool>,
{
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("diagnostics probe runtime should initialize")
        .block_on(future)
}

#[cfg(not(target_arch = "wasm32"))]
fn block_on_source_runtime<F, T, E>(future: F) -> Result<T, E>
where
    F: std::future::Future<Output = Result<T, E>>,
{
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("source runtime async bridge should initialize")
        .block_on(future)
}

#[cfg(not(target_arch = "wasm32"))]
pub use diagnostics_runtime::diagnostics_runtime_snapshot;

#[cfg(not(target_arch = "wasm32"))]
pub fn diagnostics_host_tooling_snapshot() -> DiagnosticsHostToolingSnapshot {
    DiagnosticsHostToolingSnapshot {
        ffprobe_available: block_on_diagnostics_probe(is_ffprobe_available()),
        ffmpeg_available: block_on_diagnostics_probe(is_ffmpeg_available()),
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub fn diagnostics_host_tooling_json() -> String {
    serde_json::to_string_pretty(&diagnostics_host_tooling_snapshot())
        .expect("diagnostics host tooling serialization should succeed")
}

#[cfg(test)]
mod tests {
    use super::{
        DiagnosticsRuntimeSnapshot, LiveTvRuntimeSnapshot, MediaRuntimeSnapshot,
        PersonalizationRuntimeSnapshot, SearchRuntimeSnapshot, ShellContentSnapshot, ShellContract,
        SourceRegistrySnapshot, diagnostics_runtime_snapshot, live_tv_runtime_json,
        live_tv_runtime_snapshot, media_runtime_json, media_runtime_snapshot, mock_shell_content,
        mock_shell_content_json, mock_shell_contract, mock_shell_contract_json,
        personalization_runtime_json, personalization_runtime_snapshot, search_runtime_json,
        search_runtime_snapshot, source_registry_json, source_registry_snapshot,
    };

    #[test]
    fn json_contract_round_trips() {
        let json = mock_shell_contract_json();
        let parsed: ShellContract =
            serde_json::from_str(&json).expect("mock shell contract should parse");

        assert_eq!(parsed, mock_shell_contract());
        assert!(
            !parsed
                .top_level_routes
                .iter()
                .any(|route| route == "Sources")
        );
        assert!(
            !parsed
                .top_level_routes
                .iter()
                .any(|route| route == "Player")
        );
        assert!(
            parsed
                .settings_groups
                .iter()
                .any(|group| group == "Sources")
        );
        assert!(
            parsed
                .home_quick_access
                .iter()
                .all(|entry| entry != "Sources")
        );
        assert_eq!(parsed.live_tv_panels, vec!["Channels", "Guide"]);
        assert_eq!(parsed.media_panels, vec!["Movies", "Series"]);
        assert_eq!(
            parsed.source_wizard_steps,
            vec![
                "Source Type",
                "Connection",
                "Credentials",
                "Import",
                "Finish"
            ]
        );
    }

    #[test]
    fn json_content_round_trips() {
        let json = mock_shell_content_json();
        let parsed: ShellContentSnapshot =
            serde_json::from_str(&json).expect("mock shell content should parse");

        assert_eq!(parsed, mock_shell_content());
        assert_eq!(parsed.home_hero.artwork.kind, "asset");
        assert_eq!(parsed.movie_hero.title, "The Last Harbor");
        assert_eq!(parsed.top_films.first().and_then(|item| item.rank), Some(1));
        assert_eq!(
            parsed
                .live_tv_channels
                .first()
                .map(|item| item.number.as_str()),
            Some("101")
        );
        assert_eq!(
            parsed
                .search_groups
                .first()
                .map(|group| group.title.as_str()),
            Some("Live TV")
        );
        assert_eq!(
            parsed
                .general_settings
                .first()
                .map(|item| item.title.as_str()),
            Some("Startup target")
        );
        assert!(
            parsed
                .continue_watching
                .iter()
                .all(|item| item.artwork.value.starts_with("assets/mocks/"))
        );
        assert_eq!(
            parsed
                .source_wizard_steps
                .first()
                .map(|item| item.step.as_str()),
            Some("Source Type")
        );
        assert_eq!(
            parsed
                .source_health_items
                .last()
                .map(|item| item.primary_action.as_str()),
            Some("Reconnect")
        );
    }

    #[test]
    fn json_source_registry_round_trips() {
        let json = source_registry_json();
        let parsed: SourceRegistrySnapshot =
            serde_json::from_str(&json).expect("source registry should parse");

        assert_eq!(parsed, source_registry_snapshot());
        assert_eq!(parsed.version, "1");
        assert_eq!(parsed.provider_types.len(), 4);
        assert_eq!(
            parsed
                .provider_types
                .first()
                .map(|provider| provider.provider_type.as_str()),
            Some("M3U URL")
        );
        assert_eq!(
            parsed
                .provider_types
                .iter()
                .map(|provider| provider.provider_type.as_str())
                .collect::<Vec<_>>(),
            vec!["M3U URL", "local M3U", "Xtream", "Stalker"]
        );
        assert!(
            parsed
                .provider_types
                .iter()
                .any(|provider| provider.capability_model.account_authentication)
        );
        assert!(
            parsed
                .provider_types
                .iter()
                .any(|provider| provider.health.status == "Needs auth")
        );
        assert_eq!(parsed.onboarding.active_step, "Source Type");
        assert_eq!(parsed.onboarding.step_order.len(), 5);
        assert_eq!(parsed.onboarding.provider_copy.len(), 4);
    }

    #[test]
    fn asset_source_registry_snapshot_matches_producer() {
        let asset_json =
            include_str!("../../../../app/flutter/assets/contracts/asset_source_registry.json");
        let parsed: SourceRegistrySnapshot =
            serde_json::from_str(asset_json).expect("asset source registry should parse");

        assert_eq!(parsed, source_registry_snapshot());
    }

    #[test]
    fn json_live_tv_runtime_round_trips() {
        let json = live_tv_runtime_json();
        let parsed: LiveTvRuntimeSnapshot =
            serde_json::from_str(&json).expect("live tv runtime should parse");

        assert_eq!(parsed, live_tv_runtime_snapshot());
        assert_eq!(parsed.version, "1");
        assert_eq!(parsed.provider.provider_type, "M3U + XMLTV");
        assert_eq!(parsed.browsing.active_panel, "Channels");
        assert_eq!(parsed.browsing.selected_channel, "118 Arena Live");
        assert_eq!(parsed.channels.len(), 4);
        assert_eq!(parsed.guide.rows.len(), 4);
        assert_eq!(parsed.selection.channel_number, "118");
        assert_eq!(parsed.selection.primary_action, "Watch live");
        assert!(parsed.selection.badges.iter().any(|badge| badge == "Live"));
        assert_eq!(
            parsed
                .channels
                .first()
                .map(|channel| channel.playback_source.kind.as_str()),
            Some("live_channel")
        );
        assert_eq!(
            parsed
                .channels
                .first()
                .map(|channel| channel.playback_stream.transport.as_str()),
            Some("hls")
        );
    }

    #[test]
    fn asset_live_tv_runtime_snapshot_matches_producer() {
        let asset_json =
            include_str!("../../../../app/flutter/assets/contracts/asset_live_tv_runtime.json");
        let parsed: LiveTvRuntimeSnapshot =
            serde_json::from_str(asset_json).expect("live tv runtime asset should parse");

        assert_eq!(parsed, live_tv_runtime_snapshot());
        assert_eq!(parsed.provider.source_name, "Home Fiber IPTV");
        assert_eq!(
            parsed
                .channels
                .last()
                .map(|channel| channel.playback_source.content_key.as_str()),
            Some("311")
        );
        assert_eq!(
            parsed.guide.time_slots,
            vec!["Now", "21:30", "22:00", "22:30", "23:00"]
        );
        assert_eq!(
            parsed
                .guide
                .rows
                .first()
                .map(|row| row.channel_number.as_str()),
            Some("101")
        );
        assert_eq!(parsed.selection.secondary_action, "Start over");
    }

    #[test]
    fn json_media_runtime_round_trips() {
        let json = media_runtime_json();
        let parsed: MediaRuntimeSnapshot =
            serde_json::from_str(&json).expect("media runtime should parse");

        assert_eq!(parsed.title, media_runtime_snapshot().title);
        assert_eq!(parsed.version, "1");
        assert_eq!(parsed.active_panel, "Movies");
        assert_eq!(parsed.active_scope, "Featured");
        assert_eq!(parsed.movie_hero.title, "The Last Harbor");
        assert_eq!(parsed.series_hero.primary_action, "Resume S1:E6");
        assert_eq!(parsed.movie_collections.len(), 2);
        assert_eq!(parsed.series_collections.len(), 2);
        assert_eq!(parsed.series_detail.seasons.len(), 2);
        assert_eq!(
            parsed
                .movie_collections
                .first()
                .and_then(|collection| collection.items.first())
                .map(|item| item.playback_source.kind.as_str()),
            Some("movie")
        );
        assert_eq!(
            parsed
                .series_collections
                .first()
                .and_then(|collection| collection.items.first())
                .map(|item| item.playback_source.kind.as_str()),
            Some("series")
        );
        assert_eq!(
            parsed
                .series_detail
                .seasons
                .first()
                .and_then(|season| season.episodes.first())
                .map(|episode| episode.code.as_str()),
            Some("S1:E1")
        );
    }

    #[test]
    fn asset_media_runtime_snapshot_matches_producer() {
        let asset_json =
            include_str!("../../../../app/flutter/assets/contracts/asset_media_runtime.json");
        let parsed: MediaRuntimeSnapshot =
            serde_json::from_str(asset_json).expect("media runtime asset should parse");

        assert_eq!(parsed, media_runtime_snapshot());
        assert_eq!(parsed.movie_hero.title, "The Last Harbor");
        assert_eq!(
            parsed
                .movie_collections
                .first()
                .and_then(|collection| collection.items.first())
                .map(|item| item.playback_stream.transport.as_str()),
            Some("hls")
        );
        assert_eq!(
            parsed
                .series_collections
                .first()
                .map(|collection| collection.title.as_str()),
            Some("Featured Series")
        );
        assert_eq!(
            parsed
                .series_detail
                .seasons
                .first()
                .map(|season| season.label.as_str()),
            Some("Season 1")
        );
    }

    #[test]
    fn json_search_runtime_round_trips() {
        let json = search_runtime_json();
        let parsed: SearchRuntimeSnapshot =
            serde_json::from_str(&json).expect("search runtime should parse");

        assert_eq!(parsed.title, search_runtime_snapshot().title);
        assert_eq!(parsed.version, "1");
        assert!(parsed.query.is_empty());
        assert_eq!(parsed.active_group_title, "Live TV");
        assert_eq!(parsed.groups.len(), 3);
        assert!(
            parsed
                .groups
                .first()
                .map(|group| group.selected)
                .unwrap_or(false)
        );
        assert_eq!(
            parsed
                .groups
                .first()
                .and_then(|group| group.results.first())
                .map(|result| result.handoff_label.as_str()),
            Some("Open channel")
        );
    }

    #[test]
    fn asset_search_runtime_snapshot_matches_producer() {
        let asset_json =
            include_str!("../../../../app/flutter/assets/contracts/asset_search_runtime.json");
        let parsed: SearchRuntimeSnapshot =
            serde_json::from_str(asset_json).expect("search runtime asset should parse");

        assert_eq!(parsed, search_runtime_snapshot());
        assert_eq!(
            parsed.groups.first().map(|group| group.title.as_str()),
            Some("Live TV")
        );
        assert_eq!(
            parsed
                .groups
                .last()
                .and_then(|group| group.results.last())
                .map(|result| result.title.as_str()),
            Some("Northline")
        );
    }

    #[test]
    fn json_personalization_runtime_round_trips() {
        let json = personalization_runtime_json();
        let parsed: PersonalizationRuntimeSnapshot =
            serde_json::from_str(&json).expect("personalization runtime should parse");

        assert_eq!(parsed, personalization_runtime_snapshot());
        assert_eq!(parsed.startup_route, "Home");
        assert_eq!(parsed.continue_watching.len(), 2);
        assert_eq!(parsed.recently_viewed.len(), 3);
        assert!(
            parsed
                .favorite_media_keys
                .iter()
                .any(|key| key == "the-last-harbor")
        );
        assert_eq!(parsed.favorite_channel_numbers, vec!["118"]);
        assert_eq!(
            parsed
                .continue_watching
                .first()
                .and_then(|entry| entry.playback_stream.as_ref())
                .map(|stream| stream.transport.as_str()),
            Some("hls")
        );
    }

    #[test]
    fn asset_personalization_runtime_snapshot_matches_producer() {
        let asset_json = include_str!(
            "../../../../app/flutter/assets/contracts/asset_personalization_runtime.json"
        );
        let parsed: PersonalizationRuntimeSnapshot =
            serde_json::from_str(asset_json).expect("personalization runtime asset should parse");

        assert_eq!(parsed, personalization_runtime_snapshot());
        assert_eq!(parsed.startup_route, "Home");
        assert_eq!(
            parsed
                .continue_watching
                .last()
                .map(|entry| entry.content_key.as_str()),
            Some("S1:E2")
        );
        assert_eq!(
            parsed
                .recently_viewed
                .last()
                .map(|entry| entry.content_key.as_str()),
            Some("chef-after-dark")
        );
    }

    #[test]
    fn json_diagnostics_runtime_round_trips() {
        let json = crate::diagnostics_runtime::diagnostics_runtime_json();
        let parsed: DiagnosticsRuntimeSnapshot =
            serde_json::from_str(&json).expect("diagnostics runtime should parse");

        assert_eq!(parsed, diagnostics_runtime_snapshot());
        assert_eq!(parsed.version, "1");
        assert_eq!(parsed.reports.len(), 2);
        assert_eq!(
            parsed.reports.first().map(|entry| entry.category.as_str()),
            Some("alive")
        );
        assert_eq!(
            parsed
                .reports
                .last()
                .map(|entry| entry.resolution_label.as_str()),
            Some("1080p")
        );
    }

    #[test]
    fn asset_diagnostics_runtime_snapshot_matches_producer() {
        let asset_json =
            include_str!("../../../../app/flutter/assets/contracts/asset_diagnostics_runtime.json");
        let parsed: DiagnosticsRuntimeSnapshot =
            serde_json::from_str(asset_json).expect("diagnostics runtime asset should parse");

        assert_eq!(parsed, diagnostics_runtime_snapshot());
        assert_eq!(
            parsed
                .reports
                .first()
                .map(|entry| entry.source_name.as_str()),
            Some("Home Fiber IPTV")
        );
        assert_eq!(
            parsed
                .reports
                .last()
                .and_then(|entry| entry.mismatch_warnings.first())
                .map(|entry| entry.as_str()),
            Some("Expected 4K, got FHD")
        );
    }
}
