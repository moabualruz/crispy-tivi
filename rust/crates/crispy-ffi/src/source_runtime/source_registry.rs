use std::collections::{HashMap, HashSet};

use crispy_iptv_tools::normalize_url;
use crispy_m3u::generate_playlist_unique_id;
use serde::{Deserialize, Serialize};

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
pub struct SourceImportDetailsSnapshot {
    pub status: String,
    pub progress: String,
    pub summary: String,
    pub primary_action: String,
    pub secondary_action: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceProviderEntrySnapshot {
    pub provider_key: String,
    pub provider_type: String,
    pub display_name: String,
    pub family: String,
    pub connection_mode: String,
    pub summary: String,
    pub endpoint_label: String,
    pub capabilities: Vec<SourceCapabilitySnapshot>,
    pub health: SourceHealthSnapshot,
    pub auth: SourceAuthSnapshot,
    #[serde(rename = "import")]
    pub import_details: SourceImportDetailsSnapshot,
    pub onboarding_hint: String,
    #[serde(default, skip_serializing_if = "std::collections::HashMap::is_empty")]
    pub runtime_config: std::collections::HashMap<String, String>,
}

impl SourceProviderEntrySnapshot {
    pub fn supports(&self, capability: &str) -> bool {
        self.capabilities
            .iter()
            .any(|item| item.id == capability && item.supported)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceWizardStepDescriptorSnapshot {
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
pub struct SourceOnboardingSnapshot {
    #[serde(rename = "selected_provider_type")]
    pub selected_provider_kind: String,
    #[serde(rename = "active_step")]
    pub active_wizard_step: String,
    pub wizard_active: bool,
    pub wizard_mode: String,
    pub selected_source_index: i32,
    pub field_values: std::collections::HashMap<String, String>,
    pub step_order: Vec<String>,
    pub steps: Vec<SourceWizardStepDescriptorSnapshot>,
    pub provider_copy: Vec<SourceProviderWizardCopySnapshot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceRegistrySnapshot {
    pub title: String,
    pub version: String,
    pub provider_types: Vec<SourceProviderEntrySnapshot>,
    pub configured_providers: Vec<SourceProviderEntrySnapshot>,
    pub onboarding: SourceOnboardingSnapshot,
    pub registry_notes: Vec<String>,
}

pub fn source_registry_snapshot() -> SourceRegistrySnapshot {
    let mut seen_keys = HashSet::new();
    let provider_types = vec![
        provider_template_m3u_url(&mut seen_keys),
        provider_template_local_m3u(&mut seen_keys),
        provider_template_xtream(&mut seen_keys),
        provider_template_stalker(&mut seen_keys),
    ];
    source_registry_snapshot_from_parts(provider_types, Vec::new())
}

pub(crate) fn seeded_source_registry_snapshot() -> SourceRegistrySnapshot {
    let mut seen_keys = HashSet::new();
    let provider_types = vec![
        provider_template_m3u_url(&mut seen_keys),
        provider_template_local_m3u(&mut seen_keys),
        provider_template_xtream(&mut seen_keys),
        provider_template_stalker(&mut seen_keys),
    ];
    let configured_providers = vec![
        configured_home_fiber_provider(&mut seen_keys),
        configured_weekend_cinema_provider(&mut seen_keys),
        configured_local_archive_provider(&mut seen_keys),
        configured_travel_archive_provider(&mut seen_keys),
    ];
    let mut snapshot = source_registry_snapshot_from_parts(provider_types, configured_providers);
    snapshot
        .registry_notes
        .push("Rust-owned demo seeded registry snapshot.".to_owned());
    snapshot
}

fn source_registry_snapshot_from_parts(
    provider_types: Vec<SourceProviderEntrySnapshot>,
    configured_providers: Vec<SourceProviderEntrySnapshot>,
) -> SourceRegistrySnapshot {
    let is_first_run = configured_providers.is_empty();
    SourceRegistrySnapshot {
        title: "CrispyTivi Source Registry".to_owned(),
        version: "1".to_owned(),
        provider_types,
        configured_providers,
        onboarding: SourceOnboardingSnapshot {
            selected_provider_kind: "M3U URL".to_owned(),
            active_wizard_step: "Source Type".to_owned(),
            wizard_active: is_first_run,
            wizard_mode: if is_first_run {
                "add".to_owned()
            } else {
                "idle".to_owned()
            },
            selected_source_index: 0,
            field_values: std::collections::HashMap::new(),
            step_order: vec![
                "Source Type".to_owned(),
                "Connection".to_owned(),
                "Credentials".to_owned(),
                "Import".to_owned(),
                "Finish".to_owned(),
            ],
            steps: vec![
                wizard_step(
                    "Source Type",
                    "Choose source type",
                    "Select the provider family first so the rest of the wizard stays aligned with the real import and auth model.",
                    "Continue",
                    "Back",
                    vec!["Source type", "Display name"],
                    vec![
                        "Keep provider selection inside the Settings-owned source flow.",
                        "Wizard steps stay ordered and reversible.",
                    ],
                ),
                wizard_step(
                    "Connection",
                    "Add connection details",
                    "Capture endpoint details before validation or auth runs.",
                    "Validate connection",
                    "Back",
                    vec!["Connection endpoint", "Headers"],
                    vec![
                        "Connection validation should fail here instead of later import screens.",
                        "Temporary connection state must not auto-restore into a stale step.",
                    ],
                ),
                wizard_step(
                    "Credentials",
                    "Authenticate source",
                    "Sensitive credentials stay in the wizard and should not bleed into other screens.",
                    "Verify access",
                    "Back",
                    vec!["Username", "Password"],
                    vec![
                        "Auth can be entered for new sources or reconnect flows.",
                        "Back from this step returns safely to connection.",
                    ],
                ),
                wizard_step(
                    "Import",
                    "Choose import scope",
                    "Review what the source will bring in before final import begins.",
                    "Start import",
                    "Back",
                    vec!["Import scope", "Validation result"],
                    vec![
                        "Import confirmation is a dedicated step, not a hidden side effect of auth.",
                        "Failures here should unwind cleanly back through the wizard.",
                    ],
                ),
                wizard_step(
                    "Finish",
                    "Finish setup",
                    "Complete the source handoff and return to source overview with health and capability status visible.",
                    "Return to sources",
                    "Back",
                    vec!["Validation result", "Import scope"],
                    vec![
                        "Success returns to the Settings-owned source overview.",
                        "The next domain phases can rely on this onboarding lane being complete.",
                    ],
                ),
            ],
            provider_copy: vec![
                provider_copy(
                    "m3u_url",
                    "M3U URL",
                    "Direct playlist URL",
                    "Remote playlist import keeps live TV and guide data together.",
                    vec![
                        "Direct URLs stay in the provider catalog rather than a separate shell domain.",
                        "Guide pairing is optional but recommended.",
                    ],
                ),
                provider_copy(
                    "local_m3u",
                    "local M3U",
                    "Local playlist import",
                    "File-backed playlist import stays on device.",
                    vec![
                        "Use this lane for attached storage or imported files.",
                        "File validation should happen before import starts.",
                    ],
                ),
                provider_copy(
                    "xtream",
                    "Xtream",
                    "Account-backed provider",
                    "Portal-backed provider with live, movies, and series lanes.",
                    vec![
                        "Authenticate first, then import catalog data and guide fields.",
                        "Account sessions should be retained only once valid.",
                    ],
                ),
                provider_copy(
                    "stalker",
                    "Stalker",
                    "Device-backed portal",
                    "MAG/Stalker sessions use device identity and portal validation.",
                    vec![
                        "Keep portal credentials separate from playlist flows.",
                        "Device-backed sessions must unwind safely if validation fails.",
                    ],
                ),
            ],
        },
        registry_notes: vec![
            "Rust-owned source registry snapshot.".to_owned(),
            "Configured providers are first-class runtime truth, not Flutter-local fallback state."
                .to_owned(),
        ],
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_serial_for_mac(mac_address: &str) -> String {
    crispy_stalker::device::generate_serial(mac_address)
}

#[cfg(target_arch = "wasm32")]
fn stalker_serial_for_mac(mac_address: &str) -> String {
    let suffix = mac_address
        .chars()
        .filter(|character| character.is_ascii_hexdigit())
        .take(13)
        .collect::<String>()
        .to_uppercase();
    format!("WASM{suffix}")
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_device_id_for_mac(mac_address: &str) -> String {
    crispy_stalker::device::generate_device_id(mac_address)
}

#[cfg(target_arch = "wasm32")]
fn stalker_device_id_for_mac(mac_address: &str) -> String {
    format!("wasm-{}", normalize_key(mac_address))
}

pub fn source_registry_json() -> String {
    serde_json::to_string_pretty(&source_registry_snapshot())
        .expect("source registry serialization should succeed")
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct SourceProviderCommitShape {
    pub summary: String,
    pub endpoint_label: String,
    pub health: SourceHealthSnapshot,
    pub auth: SourceAuthSnapshot,
    pub import_details: SourceImportDetailsSnapshot,
    pub runtime_config: HashMap<String, String>,
}

pub(crate) fn build_provider_commit_shape(
    provider_type: &str,
    family: &str,
    connection_mode: &str,
    fallback_endpoint_label: &str,
    wizard_mode: &str,
    field_values: &HashMap<String, String>,
) -> SourceProviderCommitShape {
    let direct_playlist = is_direct_playlist_provider(provider_type);
    let has_credentials = has_required_credentials(provider_type, field_values);
    let connection_ready = is_connection_ready(provider_type, field_values);
    let auth_status = if direct_playlist {
        "Not required"
    } else if has_credentials {
        "Complete"
    } else {
        "Needs auth"
    };
    let import_status = if wizard_mode == "import" || has_credentials {
        "Ready"
    } else {
        "Blocked"
    };
    let health_status = if direct_playlist {
        if connection_ready {
            "Healthy"
        } else {
            "Needs setup"
        }
    } else if has_credentials || connection_ready {
        "Healthy"
    } else {
        "Needs auth"
    };

    SourceProviderCommitShape {
        summary: summary_for_commit(provider_type, family, connection_mode),
        endpoint_label: endpoint_label_for(provider_type, field_values, fallback_endpoint_label),
        health: SourceHealthSnapshot {
            status: health_status.to_owned(),
            summary: if direct_playlist {
                if connection_ready {
                    "Playlist source is ready to import.".to_owned()
                } else {
                    "Playlist URL or file is still required.".to_owned()
                }
            } else if health_status == "Healthy" {
                "Connection validated and ready.".to_owned()
            } else {
                "Provider setup still needs credentials or confirmation.".to_owned()
            },
            last_checked: "just now".to_owned(),
            last_sync: if import_status == "Ready" {
                "Import ready".to_owned()
            } else {
                "Pending import".to_owned()
            },
        },
        auth: SourceAuthSnapshot {
            status: auth_status.to_owned(),
            progress: if direct_playlist || has_credentials {
                "100%"
            } else {
                "0%"
            }
            .to_owned(),
            summary: if direct_playlist {
                "No account credentials are required for this provider.".to_owned()
            } else if has_credentials {
                "Credentials verified on the retained Rust boundary.".to_owned()
            } else {
                "Credentials are still required for this provider.".to_owned()
            },
            primary_action: if direct_playlist {
                "Continue".to_owned()
            } else if has_credentials {
                "Edit provider".to_owned()
            } else {
                "Verify access".to_owned()
            },
            secondary_action: "Back".to_owned(),
            field_labels: field_labels_for(provider_type),
            helper_lines: helper_lines_for(provider_type),
        },
        import_details: SourceImportDetailsSnapshot {
            status: import_status.to_owned(),
            progress: if import_status == "Ready" {
                "Ready"
            } else {
                "0%"
            }
            .to_owned(),
            summary: if direct_playlist {
                if import_status == "Ready" {
                    "Playlist can import into runtime lanes.".to_owned()
                } else {
                    "Import remains blocked until playlist input is provided.".to_owned()
                }
            } else if import_status == "Ready" {
                "Provider is ready to hydrate runtime lanes.".to_owned()
            } else {
                "Import remains blocked until validation succeeds.".to_owned()
            },
            primary_action: if direct_playlist {
                if import_status == "Ready" {
                    "Start import".to_owned()
                } else {
                    "Continue".to_owned()
                }
            } else if import_status == "Ready" {
                "Run import flow".to_owned()
            } else {
                "Continue".to_owned()
            },
            secondary_action: "Review".to_owned(),
        },
        runtime_config: runtime_config_for_provider(provider_type, field_values),
    }
}

fn is_direct_playlist_provider(provider_type: &str) -> bool {
    matches!(provider_type, "M3U URL" | "local M3U")
}

fn summary_for_commit(provider_type: &str, family: &str, connection_mode: &str) -> String {
    format!("{provider_type} provider kept on the Rust-owned {family} / {connection_mode} path.")
}

fn endpoint_label_for(
    provider_type: &str,
    field_values: &HashMap<String, String>,
    fallback: &str,
) -> String {
    let key = match provider_type {
        "M3U URL" => "playlist_url",
        "local M3U" => "playlist_file",
        "Xtream" => "server_url",
        "Stalker" => "portal_url",
        _ => "connection_endpoint",
    };
    value_or_fallback(field_values, key, fallback)
}

fn has_required_credentials(provider_type: &str, field_values: &HashMap<String, String>) -> bool {
    match provider_type {
        "M3U URL" => has_value(field_values, "playlist_url"),
        "local M3U" => has_value(field_values, "playlist_file"),
        "Xtream" => {
            has_value(field_values, "server_url")
                && has_value(field_values, "username")
                && has_value(field_values, "password")
        }
        "Stalker" => {
            has_value(field_values, "portal_url")
                && (has_value(field_values, "mac_address")
                    || (has_value(field_values, "username") && has_value(field_values, "password")))
        }
        _ => false,
    }
}

fn is_connection_ready(provider_type: &str, field_values: &HashMap<String, String>) -> bool {
    match provider_type {
        "M3U URL" => has_value(field_values, "playlist_url"),
        "local M3U" => has_value(field_values, "playlist_file"),
        "Xtream" => has_value(field_values, "server_url"),
        "Stalker" => has_value(field_values, "portal_url"),
        _ => false,
    }
}

fn runtime_config_for_provider(
    provider_type: &str,
    field_values: &HashMap<String, String>,
) -> HashMap<String, String> {
    let keys: &[&str] = match provider_type {
        "M3U URL" => &["playlist_url", "xmltv_url", "display_name"],
        "local M3U" => &["playlist_file", "xmltv_file", "display_name"],
        "Xtream" => &["server_url", "username", "password", "display_name"],
        "Stalker" => &[
            "portal_url",
            "mac_address",
            "username",
            "password",
            "display_name",
        ],
        _ => &["display_name"],
    };

    keys.iter()
        .filter_map(|key| {
            field_values
                .get(*key)
                .map(|value| value.trim())
                .filter(|value| !value.is_empty())
                .map(|value| ((*key).to_owned(), normalize_runtime_value(key, value)))
        })
        .collect()
}

fn normalize_runtime_value(key: &str, value: &str) -> String {
    match key {
        "playlist_url" | "xmltv_url" | "server_url" | "portal_url" => {
            normalize_url(value).unwrap_or_else(|_| value.to_owned())
        }
        _ => value.to_owned(),
    }
}

fn field_labels_for(provider_type: &str) -> Vec<String> {
    match provider_type {
        "M3U URL" => vec!["Playlist URL".to_owned(), "XMLTV URL".to_owned()],
        "local M3U" => vec!["Playlist file".to_owned(), "XMLTV file".to_owned()],
        "Xtream" => vec![
            "Server URL".to_owned(),
            "Username".to_owned(),
            "Password".to_owned(),
        ],
        "Stalker" => vec!["Portal URL".to_owned(), "MAC address".to_owned()],
        _ => vec!["Connection".to_owned()],
    }
}

fn helper_lines_for(provider_type: &str) -> Vec<String> {
    match provider_type {
        "M3U URL" => vec!["Remote playlists stay on the Rust-owned provider path.".to_owned()],
        "local M3U" => vec![
            "Local playlist imports remain a provider lane, not a special Flutter-only branch."
                .to_owned(),
        ],
        "Xtream" => vec![
            "Portal-backed providers keep account and catalog state on the Rust boundary."
                .to_owned(),
        ],
        "Stalker" => {
            vec!["Portal and device identity stay on the Rust-owned integration path.".to_owned()]
        }
        _ => vec!["Provider state stays on the Rust boundary.".to_owned()],
    }
}

fn value_or_fallback(field_values: &HashMap<String, String>, key: &str, fallback: &str) -> String {
    field_values
        .get(key)
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .unwrap_or(fallback)
        .to_owned()
}

fn has_value(field_values: &HashMap<String, String>, key: &str) -> bool {
    field_values
        .get(key)
        .map(|value| !value.trim().is_empty())
        .unwrap_or(false)
}

fn provider_template_m3u_url(seen_keys: &mut HashSet<String>) -> SourceProviderEntrySnapshot {
    let provider_key = stable_provider_key("m3u_url", seen_keys);
    SourceProviderEntrySnapshot {
        provider_key,
        provider_type: "M3U URL".to_owned(),
        display_name: "M3U URL".to_owned(),
        family: "playlist".to_owned(),
        connection_mode: "remote_url".to_owned(),
        summary: "Remote playlist URL with optional guide pairing and catch-up support.".to_owned(),
        endpoint_label: "Playlist URL".to_owned(),
        capabilities: vec![
            capability(
                "live_tv",
                "Live TV",
                "Map playlist rows to channels and categories.",
                true,
            ),
            capability(
                "guide",
                "Guide",
                "Pair XMLTV for EPG coverage and browse context.",
                true,
            ),
            capability(
                "catch_up",
                "Catch-up",
                "Use archive URLs when the source exposes timeshift.",
                true,
            ),
            capability(
                "movies",
                "Movies",
                "Not a native catalog lane for this provider.",
                false,
            ),
            capability(
                "series",
                "Series",
                "Series metadata depends on external pairing.",
                false,
            ),
        ],
        health: health(
            "Healthy",
            "Playlist template is reachable and validation passed.",
            "2 minutes ago",
            "2 minutes ago",
        ),
        auth: auth(
            "Not required",
            "0%",
            "No account credentials are needed for a direct playlist URL.",
            "Continue",
            "Back",
            vec!["Playlist URL", "XMLTV URL"],
            vec![
                "Use this lane for remote playlist URLs.",
                "Guide pairing is optional but recommended.",
            ],
        ),
        import_details: import_details(
            "Ready",
            "100%",
            "Playlist can import once URLs validate.",
            "Start import",
            "Review",
        ),
        onboarding_hint: "Start with a direct URL, then add XMLTV if available.".to_owned(),
        runtime_config: std::collections::HashMap::new(),
    }
}

fn provider_template_local_m3u(seen_keys: &mut HashSet<String>) -> SourceProviderEntrySnapshot {
    let provider_key = stable_provider_key("local_m3u", seen_keys);
    SourceProviderEntrySnapshot {
        provider_key,
        provider_type: "local M3U".to_owned(),
        display_name: "local M3U".to_owned(),
        family: "playlist".to_owned(),
        connection_mode: "local_file".to_owned(),
        summary: "On-device playlist import from a local file or mounted storage path.".to_owned(),
        endpoint_label: "Playlist file".to_owned(),
        capabilities: vec![
            capability(
                "live_tv",
                "Live TV",
                "Load channels from a local playlist file.",
                true,
            ),
            capability(
                "guide",
                "Guide",
                "Pair XMLTV locally or from a nearby import source.",
                true,
            ),
            capability(
                "local_playlist",
                "Local file",
                "Import from a file path or attached storage target.",
                true,
            ),
            capability(
                "catch_up",
                "Catch-up",
                "Not advertised unless the imported playlist carries archive data.",
                false,
            ),
        ],
        health: health(
            "Healthy",
            "Local file template is parsed and ready.",
            "1 minute ago",
            "1 minute ago",
        ),
        auth: auth(
            "Not required",
            "0%",
            "Local files do not require credentials.",
            "Continue",
            "Back",
            vec!["Playlist file", "XMLTV file"],
            vec![
                "Use this lane for attached storage or imported files.",
                "File validation should happen before import starts.",
            ],
        ),
        import_details: import_details(
            "Complete",
            "100%",
            "Local playlist import is complete and ready to browse.",
            "Open sources",
            "Review",
        ),
        onboarding_hint: "Choose a local playlist file, then pair guide data if needed.".to_owned(),
        runtime_config: std::collections::HashMap::new(),
    }
}

fn provider_template_xtream(seen_keys: &mut HashSet<String>) -> SourceProviderEntrySnapshot {
    let provider_key = stable_provider_key("xtream", seen_keys);
    SourceProviderEntrySnapshot {
        provider_key,
        provider_type: "Xtream".to_owned(),
        display_name: "Xtream".to_owned(),
        family: "portal".to_owned(),
        connection_mode: "portal_account".to_owned(),
        summary: "Account-backed provider with live, movies, series, and guide lanes.".to_owned(),
        endpoint_label: "Player API".to_owned(),
        capabilities: vec![
            capability(
                "live_tv",
                "Live TV",
                "Portal groups can surface channel lists and live categories.",
                true,
            ),
            capability(
                "guide",
                "Guide",
                "EPG data can support schedules and browse grids.",
                true,
            ),
            capability(
                "movies",
                "Movies",
                "Catalog data exposes a movie lane with browse and detail views.",
                true,
            ),
            capability(
                "series",
                "Series",
                "Series catalogs can feed seasons, episodes, and resume state.",
                true,
            ),
            capability(
                "catch_up",
                "Catch-up",
                "Archive playback is available when the portal exposes it.",
                true,
            ),
        ],
        health: health(
            "Healthy",
            "Portal template is synchronized and ready.",
            "1 minute ago",
            "1 minute ago",
        ),
        auth: auth(
            "Complete",
            "100%",
            "Credentials are active and catalog sync can continue.",
            "Review",
            "Back",
            vec!["Server URL", "Username", "Password"],
            vec![
                "Use the portal endpoint supplied by the provider.",
                "Validation should happen before import begins.",
            ],
        ),
        import_details: import_details(
            "Ready",
            "100%",
            "Catalog refresh is ready to run after auth completes.",
            "Start import",
            "Review",
        ),
        onboarding_hint: "Authenticate first, then import catalog data and guide fields."
            .to_owned(),
        runtime_config: std::collections::HashMap::new(),
    }
}

fn provider_template_stalker(seen_keys: &mut HashSet<String>) -> SourceProviderEntrySnapshot {
    let provider_key = stable_provider_key("stalker", seen_keys);
    let mac_address = "00:1A:79:AB:CD:EF";
    let serial = stalker_serial_for_mac(mac_address);
    let device_id = stalker_device_id_for_mac(mac_address);
    SourceProviderEntrySnapshot {
        provider_key,
        provider_type: "Stalker".to_owned(),
        display_name: "Stalker".to_owned(),
        family: "portal".to_owned(),
        connection_mode: "portal_device".to_owned(),
        summary: "MAG/Stalker portal with device-backed authentication and live/media lanes."
            .to_owned(),
        endpoint_label: format!("Portal device / serial {serial}"),
        capabilities: vec![
            capability(
                "live_tv",
                "Live TV",
                "Device-backed portals can surface channel lists and browse state.",
                true,
            ),
            capability(
                "guide",
                "Guide",
                "Portal EPG data can drive channel schedules and overlays.",
                true,
            ),
            capability(
                "movies",
                "Movies",
                "Portal catalogs expose movie browsing and detail lanes.",
                true,
            ),
            capability(
                "series",
                "Series",
                "Series catalogs can populate seasons, episodes, and resume behavior.",
                true,
            ),
            capability(
                "catch_up",
                "Catch-up",
                "Archive playback depends on portal support and device session state.",
                true,
            ),
        ],
        health: health(
            "Needs auth",
            "Portal session is waiting for a device reconnect.",
            "Sync blocked",
            "Sync blocked",
        ),
        auth: auth(
            "Needs auth",
            "0%",
            &format!("The portal session requires a reconnect. Device ID {device_id}"),
            "Reconnect",
            "Back",
            vec!["Portal URL", "MAC address", "Device ID"],
            vec![
                "Keep portal credentials separate from playlist flows.",
                "Device-backed sessions must unwind safely if validation fails.",
            ],
        ),
        import_details: import_details(
            "Blocked",
            "0%",
            "Import is paused until auth succeeds.",
            "Continue",
            "Review",
        ),
        onboarding_hint:
            "Reconnect the device, then let the portal refresh its catalog and guide state."
                .to_owned(),
        runtime_config: std::collections::HashMap::new(),
    }
}

fn configured_home_fiber_provider(seen_keys: &mut HashSet<String>) -> SourceProviderEntrySnapshot {
    let provider_key = stable_provider_key("home_fiber_iptv", seen_keys);
    SourceProviderEntrySnapshot {
        provider_key,
        provider_type: "M3U URL".to_owned(),
        display_name: "Home Fiber IPTV".to_owned(),
        family: "playlist".to_owned(),
        connection_mode: "remote_url".to_owned(),
        summary: "Direct playlist source with live, guide, and catch-up coverage.".to_owned(),
        endpoint_label: "fiber.local / lineup-primary".to_owned(),
        capabilities: vec![
            capability(
                "live_tv",
                "Live TV",
                "Live channels hydrate from the configured playlist.",
                true,
            ),
            capability(
                "guide",
                "Guide",
                "Guide rows hydrate from paired XMLTV data.",
                true,
            ),
            capability(
                "catch_up",
                "Catch-up",
                "Archive playback is available when the source exposes it.",
                true,
            ),
            capability(
                "movies",
                "Movies",
                "Not a native catalog lane for this source.",
                false,
            ),
            capability(
                "series",
                "Series",
                "Series metadata depends on external pairing.",
                false,
            ),
        ],
        health: health(
            "Healthy",
            "Playlist reachable and validation passed.",
            "2 minutes ago",
            "2 minutes ago",
        ),
        auth: auth(
            "Not required",
            "0%",
            "No account credentials are needed for this direct playlist.",
            "Continue",
            "Back",
            vec!["Playlist URL", "XMLTV URL"],
            vec![
                "Use this lane for remote playlist URLs.",
                "Guide pairing is optional but recommended.",
            ],
        ),
        import_details: import_details(
            "Ready",
            "100%",
            "Playlist can import once URLs validate.",
            "Open live TV",
            "Review",
        ),
        onboarding_hint: "Start with the fiber playlist, then add XMLTV if available.".to_owned(),
        runtime_config: std::collections::HashMap::new(),
    }
}

fn configured_weekend_cinema_provider(
    seen_keys: &mut HashSet<String>,
) -> SourceProviderEntrySnapshot {
    let provider_key = stable_provider_key("weekend_cinema", seen_keys);
    SourceProviderEntrySnapshot {
        provider_key,
        provider_type: "Xtream".to_owned(),
        display_name: "Weekend Cinema".to_owned(),
        family: "portal".to_owned(),
        connection_mode: "portal_account".to_owned(),
        summary: "Account-backed provider with live, movie, and series lanes.".to_owned(),
        endpoint_label: "cinema.example.net / xtream".to_owned(),
        capabilities: vec![
            capability(
                "live_tv",
                "Live TV",
                "Portal channel lists remain available for browse.",
                true,
            ),
            capability(
                "guide",
                "Guide",
                "EPG data hydrates browse grids and channel detail.",
                true,
            ),
            capability(
                "movies",
                "Movies",
                "Movie catalogs hydrate the active media lane.",
                true,
            ),
            capability(
                "series",
                "Series",
                "Series catalogs hydrate seasons, episodes, and resume state.",
                true,
            ),
            capability(
                "catch_up",
                "Catch-up",
                "Archive playback is available when the portal exposes it.",
                true,
            ),
        ],
        health: health(
            "Healthy",
            "Portal access is ready for catalog sync.",
            "3 minutes ago",
            "3 minutes ago",
        ),
        auth: auth(
            "Complete",
            "100%",
            "Credentials are active and catalog sync can continue.",
            "Review",
            "Back",
            vec!["Server URL", "Username", "Password"],
            vec![
                "Use the portal endpoint supplied by the provider.",
                "Validation should happen before import begins.",
            ],
        ),
        import_details: import_details(
            "Complete",
            "100%",
            "Catalog refresh is complete and ready to browse.",
            "Open media",
            "Review",
        ),
        onboarding_hint: "Authenticate first, then import catalog data and guide fields."
            .to_owned(),
        runtime_config: std::collections::HashMap::new(),
    }
}

fn configured_local_archive_provider(
    seen_keys: &mut HashSet<String>,
) -> SourceProviderEntrySnapshot {
    let provider_key = stable_provider_key("local_archive", seen_keys);
    SourceProviderEntrySnapshot {
        provider_key,
        provider_type: "local M3U".to_owned(),
        display_name: "Local Archive".to_owned(),
        family: "playlist".to_owned(),
        connection_mode: "local_file".to_owned(),
        summary: "On-device playlist import from a mounted archive path.".to_owned(),
        endpoint_label: "/mnt/media/local-archive.m3u".to_owned(),
        capabilities: vec![
            capability(
                "live_tv",
                "Live TV",
                "Local playlists can hydrate live browse state.",
                true,
            ),
            capability(
                "guide",
                "Guide",
                "Local XMLTV data hydrates guide rows.",
                true,
            ),
            capability(
                "local_playlist",
                "Local file",
                "Import from a file path or attached storage target.",
                true,
            ),
            capability(
                "catch_up",
                "Catch-up",
                "Not advertised unless the imported playlist carries archive data.",
                false,
            ),
        ],
        health: health(
            "Healthy",
            "Local file loaded and parsed.",
            "1 minute ago",
            "1 minute ago",
        ),
        auth: auth(
            "Not required",
            "0%",
            "Local files do not require credentials.",
            "Continue",
            "Back",
            vec!["Playlist file", "XMLTV file"],
            vec![
                "Use this lane for attached storage or imported files.",
                "File validation should happen before import starts.",
            ],
        ),
        import_details: import_details(
            "Complete",
            "100%",
            "Local playlist import is complete and ready to browse.",
            "Open sources",
            "Review",
        ),
        onboarding_hint: "Choose a local playlist file, then pair guide data if needed.".to_owned(),
        runtime_config: std::collections::HashMap::new(),
    }
}

fn configured_travel_archive_provider(
    seen_keys: &mut HashSet<String>,
) -> SourceProviderEntrySnapshot {
    let provider_key = stable_provider_key("travel_archive", seen_keys);
    SourceProviderEntrySnapshot {
        provider_key,
        provider_type: "Stalker".to_owned(),
        display_name: "Travel Archive".to_owned(),
        family: "portal".to_owned(),
        connection_mode: "portal_device".to_owned(),
        summary: "Device-backed portal with live/media lanes pending reconnect.".to_owned(),
        endpoint_label: "travel.example.com / portal".to_owned(),
        capabilities: vec![
            capability(
                "live_tv",
                "Live TV",
                "Device-backed portals can surface channel lists.",
                true,
            ),
            capability(
                "guide",
                "Guide",
                "Portal EPG data can drive channel schedules.",
                true,
            ),
            capability(
                "movies",
                "Movies",
                "Portal catalogs expose movie browsing and detail lanes.",
                true,
            ),
            capability(
                "series",
                "Series",
                "Series catalogs can populate seasons and episodes.",
                true,
            ),
            capability(
                "catch_up",
                "Catch-up",
                "Archive playback depends on portal support and reconnect state.",
                true,
            ),
        ],
        health: health(
            "Degraded",
            "Portal session requires reconnect to refresh the device token.",
            "14 minutes ago",
            "Sync pending",
        ),
        auth: auth(
            "Reauth required",
            "35%",
            "The portal session expired and needs a device reconnect.",
            "Reconnect",
            "Back",
            vec!["Portal URL", "MAC address", "Device ID"],
            vec![
                "Keep portal credentials separate from playlist flows.",
                "Device-backed sessions must unwind safely if validation fails.",
            ],
        ),
        import_details: import_details(
            "Blocked",
            "0%",
            "Import is paused until auth succeeds.",
            "Continue",
            "Review",
        ),
        onboarding_hint:
            "Reconnect the device, then let the portal refresh its catalog and guide state."
                .to_owned(),
        runtime_config: std::collections::HashMap::new(),
    }
}

fn capability(id: &str, title: &str, summary: &str, supported: bool) -> SourceCapabilitySnapshot {
    SourceCapabilitySnapshot {
        id: id.to_owned(),
        title: title.to_owned(),
        summary: summary.to_owned(),
        supported,
    }
}

fn health(
    status: &str,
    summary: &str,
    last_checked: &str,
    last_sync: &str,
) -> SourceHealthSnapshot {
    SourceHealthSnapshot {
        status: status.to_owned(),
        summary: summary.to_owned(),
        last_checked: last_checked.to_owned(),
        last_sync: last_sync.to_owned(),
    }
}

fn auth(
    status: &str,
    progress: &str,
    summary: &str,
    primary_action: &str,
    secondary_action: &str,
    field_labels: Vec<&str>,
    helper_lines: Vec<&str>,
) -> SourceAuthSnapshot {
    SourceAuthSnapshot {
        status: status.to_owned(),
        progress: progress.to_owned(),
        summary: summary.to_owned(),
        primary_action: primary_action.to_owned(),
        secondary_action: secondary_action.to_owned(),
        field_labels: field_labels.into_iter().map(str::to_owned).collect(),
        helper_lines: helper_lines.into_iter().map(str::to_owned).collect(),
    }
}

fn import_details(
    status: &str,
    progress: &str,
    summary: &str,
    primary_action: &str,
    secondary_action: &str,
) -> SourceImportDetailsSnapshot {
    SourceImportDetailsSnapshot {
        status: status.to_owned(),
        progress: progress.to_owned(),
        summary: summary.to_owned(),
        primary_action: primary_action.to_owned(),
        secondary_action: secondary_action.to_owned(),
    }
}

fn wizard_step(
    step: &str,
    title: &str,
    summary: &str,
    primary_action: &str,
    secondary_action: &str,
    field_labels: Vec<&str>,
    helper_lines: Vec<&str>,
) -> SourceWizardStepDescriptorSnapshot {
    SourceWizardStepDescriptorSnapshot {
        step: step.to_owned(),
        title: title.to_owned(),
        summary: summary.to_owned(),
        primary_action: primary_action.to_owned(),
        secondary_action: secondary_action.to_owned(),
        field_labels: field_labels.into_iter().map(str::to_owned).collect(),
        helper_lines: helper_lines.into_iter().map(str::to_owned).collect(),
    }
}

fn provider_copy(
    provider_key: &str,
    provider_type: &str,
    title: &str,
    summary: &str,
    helper_lines: Vec<&str>,
) -> SourceProviderWizardCopySnapshot {
    SourceProviderWizardCopySnapshot {
        provider_key: provider_key.to_owned(),
        provider_type: provider_type.to_owned(),
        title: title.to_owned(),
        summary: summary.to_owned(),
        helper_lines: helper_lines.into_iter().map(str::to_owned).collect(),
    }
}

fn stable_provider_key(seed: &str, seen_keys: &mut HashSet<String>) -> String {
    let normalized = normalize_key(seed);
    generate_playlist_unique_id(Some(&normalized), None, None, seen_keys)
}

fn normalize_key(input: &str) -> String {
    let mut key = String::with_capacity(input.len());
    let mut last_was_underscore = false;
    for ch in input.chars() {
        let next = if ch.is_ascii_alphanumeric() {
            Some(ch.to_ascii_lowercase())
        } else {
            None
        };
        match next {
            Some(value) => {
                key.push(value);
                last_was_underscore = false;
            }
            None if !last_was_underscore && !key.is_empty() => {
                key.push('_');
                last_was_underscore = true;
            }
            _ => {}
        }
    }
    while key.ends_with('_') {
        key.pop();
    }
    if key.is_empty() {
        "provider".to_owned()
    } else {
        key
    }
}
