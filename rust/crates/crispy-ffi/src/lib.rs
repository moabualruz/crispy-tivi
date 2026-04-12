use serde::{Deserialize, Serialize};

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

#[cfg(test)]
mod tests {
    use super::{
        ShellContentSnapshot, ShellContract, mock_shell_content, mock_shell_content_json,
        mock_shell_contract, mock_shell_contract_json,
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
            vec!["Source Type", "Connection", "Credentials", "Import", "Finish"]
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
}
