use std::collections::{HashMap, HashSet};

use chrono::{TimeZone, Utc};
use crispy_catchup::{CatchupMode, configure_catchup, process_channel_for_live};
use crispy_m3u::{M3uEntry, M3uPlaylist, generate_playlist_unique_id, parse};
#[cfg(not(target_arch = "wasm32"))]
use crispy_stalker::{
    StalkerCategory, StalkerChannel, StalkerClient, StalkerCredentials, StalkerEpgEntry,
    StalkerSeriesDetail, StalkerSeriesItem, StalkerVodItem, resolve_stream_url,
};
use crispy_xmltv::{
    XmltvDocument, parse as parse_xmltv, parse_compressed as parse_xmltv_compressed,
};
#[cfg(not(target_arch = "wasm32"))]
use crispy_xtream::{
    client::{XtreamClient, XtreamClientConfig, XtreamCredentials},
    types::{
        XtreamCategory, XtreamChannel, XtreamEpgListing, XtreamEpisode, XtreamMovieListing,
        XtreamSeason, XtreamShortEpg, XtreamShow, XtreamShowListing,
    },
};
use serde::{Deserialize, Serialize};

use crate::{
    LiveTvRuntimeBrowsingSnapshot, LiveTvRuntimeChannelSnapshot, LiveTvRuntimeGuideRowSnapshot,
    LiveTvRuntimeGuideSlotSnapshot, LiveTvRuntimeGuideSnapshot, LiveTvRuntimeProgramSnapshot,
    LiveTvRuntimeProviderSnapshot, LiveTvRuntimeSelectionSnapshot, LiveTvRuntimeSnapshot,
    MediaRuntimeCollectionSnapshot, MediaRuntimeEpisodeSnapshot, MediaRuntimeHeroSnapshot,
    MediaRuntimeItemSnapshot, MediaRuntimeSeasonSnapshot, MediaRuntimeSeriesDetailSnapshot,
    MediaRuntimeSnapshot, PersonalizationRuntimeSnapshot, PlaybackSourceSnapshot,
    PlaybackStreamSnapshot, PlaybackTrackOptionSnapshot, PlaybackVariantOptionSnapshot,
    SearchRuntimeGroupSnapshot, SearchRuntimeResultSnapshot, SearchRuntimeSnapshot,
};

use super::source_registry::{SourceProviderEntrySnapshot, SourceRegistrySnapshot};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HydratedRuntimeSnapshot {
    pub live_tv: LiveTvRuntimeSnapshot,
    pub media: MediaRuntimeSnapshot,
    pub search: SearchRuntimeSnapshot,
    pub personalization: PersonalizationRuntimeSnapshot,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RuntimeBundleSnapshot {
    pub source_registry: SourceRegistrySnapshot,
    pub runtime: HydratedRuntimeSnapshot,
}

pub fn runtime_bundle_snapshot() -> RuntimeBundleSnapshot {
    let source_registry = crate::source_runtime::source_registry_snapshot();
    runtime_bundle_snapshot_from_source_registry(source_registry)
}

pub fn runtime_bundle_json() -> String {
    serde_json::to_string_pretty(&runtime_bundle_snapshot())
        .expect("runtime bundle serialization should succeed")
}

pub fn runtime_bundle_snapshot_from_source_registry(
    source_registry: SourceRegistrySnapshot,
) -> RuntimeBundleSnapshot {
    let runtime = hydrate_runtime_from_configured_providers(&source_registry);
    RuntimeBundleSnapshot {
        source_registry,
        runtime,
    }
}

pub fn runtime_bundle_json_from_source_registry_json(
    source_registry_json: Option<&str>,
) -> Result<String, String> {
    let source_registry = match source_registry_json {
        Some(json) if !json.trim().is_empty() => serde_json::from_str(json)
            .map_err(|error| format!("source runtime registry JSON parse failed: {error}"))?,
        _ => crate::source_runtime::source_registry_snapshot(),
    };
    serde_json::to_string_pretty(&runtime_bundle_snapshot_from_source_registry(
        source_registry,
    ))
    .map_err(|error| format!("source runtime bundle serialization failed: {error}"))
}

pub(crate) fn hydrate_runtime_from_configured_providers(
    source_registry: &SourceRegistrySnapshot,
) -> HydratedRuntimeSnapshot {
    let live_provider = first_ready_provider(source_registry, &["live_tv"]);
    let media_provider = first_ready_provider(source_registry, &["movies", "series"]);

    let live_tv = build_live_tv_runtime(source_registry, live_provider);
    let media = build_media_runtime(source_registry, media_provider);
    let search = build_search_runtime(source_registry, &live_tv, &media);
    let personalization = build_personalization_runtime();

    HydratedRuntimeSnapshot {
        live_tv,
        media,
        search,
        personalization,
    }
}

fn demo_seeded_runtime_enabled(source_registry: &SourceRegistrySnapshot) -> bool {
    source_registry
        .registry_notes
        .iter()
        .any(|note| note.contains("Rust-owned demo seeded registry snapshot"))
}

fn build_live_tv_runtime(
    source_registry: &SourceRegistrySnapshot,
    live_provider: Option<&SourceProviderEntrySnapshot>,
) -> LiveTvRuntimeSnapshot {
    let Some(provider) = live_provider else {
        return empty_live_tv_runtime();
    };

    if provider.provider_type == "Xtream" {
        if let Some(runtime) = try_build_xtream_live_tv_runtime(provider) {
            return runtime;
        }
    }
    if provider.provider_type == "Stalker" {
        if let Some(runtime) = try_build_stalker_live_tv_runtime(provider) {
            return runtime;
        }
    }
    if matches!(provider.provider_type.as_str(), "M3U URL" | "local M3U") {
        if let Some(runtime) = try_build_m3u_live_tv_runtime(provider) {
            return runtime;
        }
    }

    if demo_seeded_runtime_enabled(source_registry) {
        return demo_seeded_live_tv_runtime(provider);
    }

    provider_error_live_tv_runtime(
        provider,
        "Live TV failed to hydrate from the configured provider.",
    )
}

#[cfg(not(target_arch = "wasm32"))]
fn try_build_xtream_live_tv_runtime(
    provider: &SourceProviderEntrySnapshot,
) -> Option<LiveTvRuntimeSnapshot> {
    let client = xtream_client_from_provider(provider)?;
    let raw_channels = crate::block_on_source_runtime(client.get_live_streams(None)).ok()?;
    let mut channels = xtream_live_channels(provider, &raw_channels);
    if guide_hydration_enabled(provider)
        && let (Some(raw_selected_channel), Some(selected_channel)) =
            (raw_channels.first(), channels.first_mut())
        && let Ok(Some(epg)) = crate::block_on_source_runtime(fetch_xtream_short_epg(
            &client,
            raw_selected_channel.stream_id,
        ))
    {
        apply_xtream_short_epg(provider, selected_channel, &epg);
    }
    if channels.is_empty() {
        return None;
    }

    let selected_channel = channels.first()?.clone();

    Some(LiveTvRuntimeSnapshot {
        title: "CrispyTivi Live TV Runtime".to_owned(),
        version: "1".to_owned(),
        provider: LiveTvRuntimeProviderSnapshot {
            provider_key: provider.provider_key.clone(),
            provider_type: provider.provider_type.clone(),
            family: provider.family.clone(),
            connection_mode: provider.connection_mode.clone(),
            source_name: provider.display_name.clone(),
            status: provider.health.status.clone(),
            summary: provider.summary.clone(),
            last_sync: provider.health.last_sync.clone(),
            guide_health: if provider.supports("guide") {
                "Guide available".to_owned()
            } else {
                "Guide unavailable".to_owned()
            },
        },
        browsing: LiveTvRuntimeBrowsingSnapshot {
            active_panel: "Channels".to_owned(),
            selected_group: "All".to_owned(),
            selected_channel: format!("{} {}", selected_channel.number, selected_channel.name),
            group_order: vec!["All".to_owned()],
            groups: vec![group_snapshot(
                "all",
                "All",
                "Live channels from the active Xtream provider",
                channels.len() as u16,
                true,
            )],
        },
        guide: xtream_guide_snapshot(&channels),
        selection: build_live_selection(provider, &selected_channel),
        channels,
        notes: vec![
            "Hydrated from Xtream provider runtime config via the shared Xtream client."
                .to_owned(),
            "If the real provider fetch fails, Rust falls back to deterministic retained scaffolding."
                .to_owned(),
        ],
    })
}

#[cfg(target_arch = "wasm32")]
fn try_build_xtream_live_tv_runtime(
    _provider: &SourceProviderEntrySnapshot,
) -> Option<LiveTvRuntimeSnapshot> {
    None
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_client_from_provider(provider: &SourceProviderEntrySnapshot) -> Option<XtreamClient> {
    let server_url = provider.runtime_config.get("server_url")?;
    let username = provider.runtime_config.get("username")?;
    let password = provider.runtime_config.get("password")?;
    XtreamClient::with_config(
        XtreamCredentials::new(server_url.clone(), username.clone(), password.clone()),
        XtreamClientConfig::default(),
    )
    .ok()
}

#[cfg(not(target_arch = "wasm32"))]
fn try_build_stalker_live_tv_runtime(
    provider: &SourceProviderEntrySnapshot,
) -> Option<LiveTvRuntimeSnapshot> {
    crate::block_on_source_runtime(fetch_stalker_live_tv_runtime(provider))
        .ok()
        .flatten()
}

#[cfg(target_arch = "wasm32")]
fn try_build_stalker_live_tv_runtime(
    _provider: &SourceProviderEntrySnapshot,
) -> Option<LiveTvRuntimeSnapshot> {
    None
}

#[cfg(not(target_arch = "wasm32"))]
async fn fetch_stalker_live_tv_runtime(
    provider: &SourceProviderEntrySnapshot,
) -> Result<Option<LiveTvRuntimeSnapshot>, String> {
    let mut client = stalker_client_from_provider(provider)
        .ok_or_else(|| "missing stalker runtime config".to_owned())?;
    client
        .authenticate()
        .await
        .map_err(|error| error.to_string())?;
    let genres = client
        .get_genres()
        .await
        .map_err(|error| error.to_string())?;
    let Some(genre) = genres.iter().find(|genre| !genre.is_adult) else {
        return Ok(None);
    };
    let channels = client
        .get_all_channels(&genre.id, None)
        .await
        .map_err(|error| error.to_string())?;
    let raw_selected_channel = channels.first().cloned();
    let mut channels = stalker_live_channels(provider, genre, &channels);
    if guide_hydration_enabled(provider)
        && let (Some(raw_selected_channel), Some(selected_channel)) =
            (raw_selected_channel.as_ref(), channels.first_mut())
        && let Some(epg) = fetch_stalker_epg(&client, &raw_selected_channel.id).await?
    {
        apply_stalker_epg(provider, selected_channel, &epg);
    }
    if channels.is_empty() {
        return Ok(None);
    }

    let selected_channel = channels
        .first()
        .cloned()
        .ok_or_else(|| "missing stalker channel".to_owned())?;
    Ok(Some(LiveTvRuntimeSnapshot {
        title: "CrispyTivi Live TV Runtime".to_owned(),
        version: "1".to_owned(),
        provider: LiveTvRuntimeProviderSnapshot {
            provider_key: provider.provider_key.clone(),
            provider_type: provider.provider_type.clone(),
            family: provider.family.clone(),
            connection_mode: provider.connection_mode.clone(),
            source_name: provider.display_name.clone(),
            status: provider.health.status.clone(),
            summary: provider.summary.clone(),
            last_sync: provider.health.last_sync.clone(),
            guide_health: if provider.supports("guide") {
                "Guide available".to_owned()
            } else {
                "Guide unavailable".to_owned()
            },
        },
        browsing: LiveTvRuntimeBrowsingSnapshot {
            active_panel: "Channels".to_owned(),
            selected_group: genre.title.clone(),
            selected_channel: format!("{} {}", selected_channel.number, selected_channel.name),
            group_order: vec![genre.title.clone()],
            groups: vec![group_snapshot(
                &normalize_key(&genre.title),
                &genre.title,
                "Live channels from the active Stalker provider",
                channels.len() as u16,
                true,
            )],
        },
        guide: stalker_guide_snapshot(&channels),
        selection: build_live_selection(provider, &selected_channel),
        channels,
        notes: vec![
            "Hydrated from Stalker provider runtime config via the shared Stalker client."
                .to_owned(),
            "If the real provider fetch fails, Rust falls back to deterministic retained scaffolding."
                .to_owned(),
        ],
    }))
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_client_from_provider(provider: &SourceProviderEntrySnapshot) -> Option<StalkerClient> {
    let portal_url = provider.runtime_config.get("portal_url")?;
    let mac_address = provider.runtime_config.get("mac_address")?;
    StalkerClient::new(
        StalkerCredentials {
            base_url: portal_url.clone(),
            mac_address: mac_address.clone(),
            timezone: None,
        },
        false,
    )
    .ok()
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_live_channels(
    provider: &SourceProviderEntrySnapshot,
    genre: &StalkerCategory,
    channels: &[StalkerChannel],
) -> Vec<LiveTvRuntimeChannelSnapshot> {
    channels
        .iter()
        .take(24)
        .map(|channel| stalker_live_channel(provider, genre, channel))
        .collect()
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_live_channel(
    provider: &SourceProviderEntrySnapshot,
    genre: &StalkerCategory,
    channel: &StalkerChannel,
) -> LiveTvRuntimeChannelSnapshot {
    let number = channel
        .number
        .map(|value| value.to_string())
        .unwrap_or_else(|| channel.id.clone());
    let stream_uri = resolve_stream_url(&channel.cmd, &provider.runtime_config["portal_url"])
        .unwrap_or_default();
    let content_key = stable_stalker_content_key(provider, &channel.name, &stream_uri);

    LiveTvRuntimeChannelSnapshot {
        number,
        name: channel.name.clone(),
        group: genre.title.clone(),
        state: "ready".to_owned(),
        live_edge: true,
        catch_up: channel.has_archive,
        archive: channel.has_archive,
        playback_source: playback_source(
            "live_channel",
            &provider.provider_key,
            &content_key,
            &provider.display_name,
            "Watch live",
        ),
        playback_stream: playback_stream(&stream_uri, "ts", true, true, 0),
        current: LiveTvRuntimeProgramSnapshot {
            title: format!("{} live", channel.name),
            summary: format!("Live channel from {}", provider.display_name),
            start: "Now".to_owned(),
            end: "Next".to_owned(),
            progress_percent: 50,
        },
        next: LiveTvRuntimeProgramSnapshot {
            title: format!("Next on {}", channel.name),
            summary: format!("Follow-up block on {}", provider.display_name),
            start: "Next".to_owned(),
            end: "Later".to_owned(),
            progress_percent: 0,
        },
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_guide_snapshot(channels: &[LiveTvRuntimeChannelSnapshot]) -> LiveTvRuntimeGuideSnapshot {
    let (window_start, window_end, time_slots) = guide_window_from_channels(channels);
    LiveTvRuntimeGuideSnapshot {
        title: "Live TV Guide".to_owned(),
        window_start,
        window_end,
        time_slots,
        rows: channels
            .iter()
            .map(|channel| LiveTvRuntimeGuideRowSnapshot {
                channel_number: channel.number.clone(),
                channel_name: channel.name.clone(),
                slots: vec![
                    LiveTvRuntimeGuideSlotSnapshot {
                        start: channel.current.start.clone(),
                        end: channel.current.end.clone(),
                        title: channel.current.title.clone(),
                        state: "current".to_owned(),
                    },
                    LiveTvRuntimeGuideSlotSnapshot {
                        start: channel.next.start.clone(),
                        end: channel.next.end.clone(),
                        title: channel.next.title.clone(),
                        state: "next".to_owned(),
                    },
                ],
            })
            .collect(),
    }
}

fn try_build_m3u_live_tv_runtime(
    provider: &SourceProviderEntrySnapshot,
) -> Option<LiveTvRuntimeSnapshot> {
    let playlist = load_m3u_playlist(provider).ok()??;
    let mut channels = m3u_live_channels(provider, &playlist.entries);
    if channels.is_empty() {
        return None;
    }

    let xmltv_guide = load_xmltv_document(provider)
        .ok()
        .flatten()
        .and_then(|document| {
            apply_xmltv_to_m3u_channels(&mut channels, &playlist.entries, &document)
        });
    let guide = xmltv_guide.clone().unwrap_or_else(|| {
        let (window_start, window_end, time_slots) = guide_window_from_channels(&channels);
        m3u_guide_snapshot(&channels, window_start, window_end, time_slots)
    });
    let selected_channel = channels.first()?.clone();
    let guide_health = if guide.rows.is_empty() {
        "Guide unavailable".to_owned()
    } else if xmltv_guide.is_some() {
        "Guide hydrated from XMLTV".to_owned()
    } else if provider.supports("guide") {
        "Guide available".to_owned()
    } else {
        "Guide unavailable".to_owned()
    };

    Some(LiveTvRuntimeSnapshot {
        title: "CrispyTivi Live TV Runtime".to_owned(),
        version: "1".to_owned(),
        provider: LiveTvRuntimeProviderSnapshot {
            provider_key: provider.provider_key.clone(),
            provider_type: provider.provider_type.clone(),
            family: provider.family.clone(),
            connection_mode: provider.connection_mode.clone(),
            source_name: provider.display_name.clone(),
            status: provider.health.status.clone(),
            summary: provider.summary.clone(),
            last_sync: provider.health.last_sync.clone(),
            guide_health,
        },
        browsing: LiveTvRuntimeBrowsingSnapshot {
            active_panel: "Channels".to_owned(),
            selected_group: selected_channel.group.clone(),
            selected_channel: format!("{} {}", selected_channel.number, selected_channel.name),
            group_order: m3u_group_order(&channels),
            groups: m3u_group_snapshots(&channels),
        },
        guide,
        selection: build_live_selection(provider, &selected_channel),
        channels,
        notes: vec![
            "Hydrated from a parsed M3U playlist via the shared crispy_m3u crate.".to_owned(),
            "Guide hydration uses the shared crispy_xmltv crate when XMLTV input is configured.".to_owned(),
            "If the playlist file is missing or invalid, Rust falls back to deterministic retained scaffolding.".to_owned(),
        ],
    })
}

fn load_m3u_playlist(
    provider: &SourceProviderEntrySnapshot,
) -> Result<Option<M3uPlaylist>, String> {
    let Some(source) = provider
        .runtime_config
        .get("playlist_url")
        .or_else(|| provider.runtime_config.get("playlist_file"))
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
    else {
        return Ok(None);
    };
    let content = if source.starts_with("#EXTM3U") || source.contains('\n') {
        source.to_owned()
    } else {
        let path = source.strip_prefix("file://").unwrap_or(source);
        std::fs::read_to_string(path)
            .map_err(|error| format!("failed to read M3U playlist file {path}: {error}"))?
    };
    let playlist =
        parse(&content).map_err(|error| format!("failed to parse M3U playlist: {error}"))?;
    Ok(Some(playlist))
}

fn load_xmltv_document(
    provider: &SourceProviderEntrySnapshot,
) -> Result<Option<XmltvDocument>, String> {
    let preferred_sources = match provider.provider_type.as_str() {
        "M3U URL" => [
            provider.runtime_config.get("xmltv_url"),
            provider.runtime_config.get("xmltv_file"),
        ],
        "local M3U" => [
            provider.runtime_config.get("xmltv_file"),
            provider.runtime_config.get("xmltv_url"),
        ],
        _ => [
            provider.runtime_config.get("xmltv_url"),
            provider.runtime_config.get("xmltv_file"),
        ],
    };

    let source = preferred_sources
        .into_iter()
        .flatten()
        .map(|value| value.trim())
        .find(|value| !value.is_empty());
    let Some(source) = source else {
        return Ok(None);
    };

    let bytes = load_xmltv_bytes(source)?;
    parse_xmltv_compressed(&bytes)
        .or_else(|_| {
            let content = String::from_utf8(bytes)
                .map_err(|error| format!("failed to decode XMLTV as UTF-8: {error}"))?;
            parse_xmltv(&content).map_err(|error| format!("failed to parse XMLTV: {error}"))
        })
        .map(Some)
}

fn load_xmltv_bytes(source: &str) -> Result<Vec<u8>, String> {
    if source.starts_with("<?xml") || source.starts_with("<tv") || source.contains("<programme") {
        return Ok(source.as_bytes().to_vec());
    }
    if source.starts_with("http://") || source.starts_with("https://") {
        #[cfg(not(target_arch = "wasm32"))]
        {
            let bytes = crate::block_on_source_runtime(async {
                let response = reqwest::get(source)
                    .await
                    .map_err(|error| format!("failed to fetch XMLTV URL {source}: {error}"))?;
                response
                    .bytes()
                    .await
                    .map(|body| body.to_vec())
                    .map_err(|error| {
                        format!("failed to read XMLTV response body {source}: {error}")
                    })
            })?;
            return Ok(bytes);
        }
        #[cfg(target_arch = "wasm32")]
        {
            return Err(format!(
                "remote XMLTV URL {source} is not supported on wasm yet"
            ));
        }
    }

    let path = source.strip_prefix("file://").unwrap_or(source);
    std::fs::read(path).map_err(|error| format!("failed to read XMLTV file {path}: {error}"))
}

fn apply_xmltv_to_m3u_channels(
    channels: &mut [LiveTvRuntimeChannelSnapshot],
    entries: &[M3uEntry],
    document: &XmltvDocument,
) -> Option<LiveTvRuntimeGuideSnapshot> {
    let now = Utc::now().timestamp();
    let channel_lookup = xmltv_channel_lookup(document);
    let mut rows = Vec::new();
    let mut all_slots = Vec::new();

    for (channel, entry) in channels.iter_mut().zip(entries.iter()) {
        let programme_views =
            xmltv_programmes_for_entry(document, &channel_lookup, entry, channel.name.as_str());
        if programme_views.is_empty() {
            continue;
        }

        if let Some(current) = programme_views.first() {
            channel.current = LiveTvRuntimeProgramSnapshot {
                title: current.title.clone(),
                summary: current.summary.clone(),
                start: format_epg_time(current.start),
                end: format_epg_time(current.stop),
                progress_percent: progress_percent(now, current.start, current.stop),
            };
        }
        if let Some(next) = programme_views.get(1) {
            channel.next = LiveTvRuntimeProgramSnapshot {
                title: next.title.clone(),
                summary: next.summary.clone(),
                start: format_epg_time(next.start),
                end: format_epg_time(next.stop),
                progress_percent: 0,
            };
        }

        let slots: Vec<LiveTvRuntimeGuideSlotSnapshot> = programme_views
            .iter()
            .take(4)
            .map(|programme| LiveTvRuntimeGuideSlotSnapshot {
                start: format_epg_time(programme.start),
                end: format_epg_time(programme.stop),
                title: programme.title.clone(),
                state: if now >= programme.start && now < programme.stop {
                    "current".to_owned()
                } else {
                    "future".to_owned()
                },
            })
            .collect();
        all_slots.extend(slots.iter().cloned());
        rows.push(LiveTvRuntimeGuideRowSnapshot {
            channel_number: channel.number.clone(),
            channel_name: channel.name.clone(),
            slots,
        });
    }

    if rows.is_empty() {
        return None;
    }

    let window_start = all_slots
        .first()
        .map(|slot| slot.start.clone())
        .unwrap_or_else(|| "Now".to_owned());
    let window_end = all_slots
        .last()
        .map(|slot| slot.end.clone())
        .unwrap_or_else(|| "Later".to_owned());
    let mut time_slots = Vec::new();
    for slot in &all_slots {
        if !time_slots.contains(&slot.start) {
            time_slots.push(slot.start.clone());
        }
        if time_slots.len() == 4 {
            break;
        }
    }

    Some(LiveTvRuntimeGuideSnapshot {
        title: "Live TV Guide".to_owned(),
        window_start,
        window_end,
        time_slots,
        rows,
    })
}

fn xmltv_channel_lookup(document: &XmltvDocument) -> HashMap<String, Vec<String>> {
    let mut lookup = HashMap::new();
    for channel in &document.channels {
        let id = channel.id.trim();
        if !id.is_empty() {
            lookup
                .entry(normalize_key(id))
                .or_insert_with(Vec::new)
                .push(channel.id.clone());
        }
        for display_name in &channel.display_name {
            let value = display_name.value.trim();
            if value.is_empty() {
                continue;
            }
            lookup
                .entry(normalize_key(value))
                .or_insert_with(Vec::new)
                .push(channel.id.clone());
        }
    }
    lookup
}

fn xmltv_programmes_for_entry(
    document: &XmltvDocument,
    channel_lookup: &HashMap<String, Vec<String>>,
    entry: &M3uEntry,
    fallback_name: &str,
) -> Vec<XmltvProgrammeView> {
    let candidates = [
        entry.tvg_id.as_deref(),
        entry.tvg_name.as_deref(),
        entry.name.as_deref(),
        Some(fallback_name),
    ];
    let mut channel_ids = Vec::new();
    for candidate in candidates.into_iter().flatten() {
        let key = normalize_key(candidate);
        if let Some(ids) = channel_lookup.get(&key) {
            for id in ids {
                if !channel_ids.contains(id) {
                    channel_ids.push(id.clone());
                }
            }
        } else if !key.is_empty() && !channel_ids.contains(&candidate.to_owned()) {
            channel_ids.push(candidate.to_owned());
        }
    }

    let mut programmes: Vec<XmltvProgrammeView> = document
        .programmes
        .iter()
        .filter(|programme| channel_ids.iter().any(|id| id == &programme.channel))
        .filter_map(|programme| {
            let start = programme.start?;
            let stop = programme.stop?;
            let title = programme.title.first()?.value.trim();
            if title.is_empty() {
                return None;
            }
            Some(XmltvProgrammeView {
                start,
                stop,
                title: title.to_owned(),
                summary: programme
                    .desc
                    .first()
                    .map(|desc| desc.value.trim().to_owned())
                    .filter(|summary| !summary.is_empty())
                    .unwrap_or_else(|| title.to_owned()),
            })
        })
        .collect();
    programmes.sort_by_key(|programme| programme.start);
    programmes
}

fn format_epg_time(timestamp: i64) -> String {
    Utc.timestamp_opt(timestamp, 0)
        .single()
        .map(|value| value.format("%H:%M").to_string())
        .unwrap_or_else(|| "Now".to_owned())
}

fn progress_percent(now: i64, start: i64, stop: i64) -> u8 {
    if stop <= start || now <= start {
        return 0;
    }
    if now >= stop {
        return 100;
    }
    let elapsed = now.saturating_sub(start);
    let duration = stop.saturating_sub(start).max(1);
    ((elapsed * 100) / duration).clamp(0, 100) as u8
}

#[derive(Debug, Clone)]
struct XmltvProgrammeView {
    start: i64,
    stop: i64,
    title: String,
    summary: String,
}

fn m3u_live_channels(
    provider: &SourceProviderEntrySnapshot,
    entries: &[M3uEntry],
) -> Vec<LiveTvRuntimeChannelSnapshot> {
    entries
        .iter()
        .enumerate()
        .filter_map(|(index, entry)| m3u_live_channel(provider, entry, index))
        .collect()
}

fn m3u_live_channel(
    provider: &SourceProviderEntrySnapshot,
    entry: &M3uEntry,
    index: usize,
) -> Option<LiveTvRuntimeChannelSnapshot> {
    let stream_uri = entry.primary_url()?.to_owned();
    let number = entry
        .tvg_chno
        .clone()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| (index + 1).to_string());
    let name = entry
        .name
        .clone()
        .or_else(|| entry.tvg_name.clone())
        .or_else(|| entry.tvg_id.clone())
        .unwrap_or_else(|| format!("Channel {}", index + 1));
    let group = entry
        .group_title
        .clone()
        .or_else(|| entry.groups.first().cloned())
        .unwrap_or_else(|| "All".to_owned());
    let content_key = stable_m3u_content_key(provider, entry, &stream_uri);
    let title = name.clone();
    let mut playback_stream = playback_stream(
        &stream_uri,
        m3u_transport_for_uri(&stream_uri),
        true,
        true,
        0,
    );
    if let Some(archive_option) = m3u_archive_source_option(entry, &stream_uri) {
        playback_stream.source_options.push(archive_option);
    }

    Some(LiveTvRuntimeChannelSnapshot {
        number,
        name,
        group,
        state: "ready".to_owned(),
        live_edge: true,
        catch_up: entry.catchup.is_some()
            || entry.catchup_days.is_some()
            || entry.catchup_source.is_some(),
        archive: entry.catchup.is_some()
            || entry.catchup_days.is_some()
            || entry.catchup_source.is_some(),
        playback_source: playback_source(
            "live_channel",
            &provider.provider_key,
            &content_key,
            &provider.display_name,
            "Watch live",
        ),
        playback_stream,
        current: LiveTvRuntimeProgramSnapshot {
            title: format!("{title} live"),
            summary: format!("Live channel from {}", provider.display_name),
            start: "Now".to_owned(),
            end: "Next".to_owned(),
            progress_percent: 50,
        },
        next: LiveTvRuntimeProgramSnapshot {
            title: format!("Next on {title}"),
            summary: format!("Follow-up block on {}", provider.display_name),
            start: "Next".to_owned(),
            end: "Later".to_owned(),
            progress_percent: 0,
        },
    })
}

fn m3u_transport_for_uri(uri: &str) -> &'static str {
    if uri.ends_with(".m3u8") {
        "hls"
    } else {
        "http"
    }
}

fn m3u_archive_source_option(
    entry: &M3uEntry,
    stream_uri: &str,
) -> Option<PlaybackVariantOptionSnapshot> {
    let mode = m3u_catchup_mode(entry)?;
    let catchup_source = entry.catchup_source.as_deref().unwrap_or("");
    let catchup_days = entry
        .catchup_days
        .as_deref()
        .and_then(|value| value.parse::<i32>().ok())
        .unwrap_or(1);
    let config = configure_catchup(
        mode,
        stream_uri,
        catchup_source,
        catchup_days,
        catchup_days,
        if stream_uri.contains('?') {
            "&utc={utc}&lutc={lutc}"
        } else {
            "?utc={utc}&lutc={lutc}"
        },
        false,
    )
    .ok()?;
    let archive_uri = process_channel_for_live(&config);
    if archive_uri.trim().is_empty() || archive_uri == stream_uri {
        return None;
    }
    Some(PlaybackVariantOptionSnapshot {
        id: "archive".to_owned(),
        label: "Archive".to_owned(),
        uri: archive_uri,
        transport: if config.is_ts_stream {
            "http".to_owned()
        } else {
            m3u_transport_for_uri(stream_uri).to_owned()
        },
        live: false,
        seekable: true,
        resume_position_seconds: 0,
    })
}

fn m3u_catchup_mode(entry: &M3uEntry) -> Option<CatchupMode> {
    let raw = entry
        .catchup
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());
    match raw.map(|value| value.to_ascii_lowercase()) {
        Some(value) if value == "default" => Some(CatchupMode::Default),
        Some(value) if value == "append" => Some(CatchupMode::Append),
        Some(value) if value == "shift" || value == "timeshift" => Some(CatchupMode::Shift),
        Some(value) if value == "flussonic" || value == "fs" => Some(CatchupMode::Flussonic),
        Some(value)
            if value == "xc"
                || value == "xtream"
                || value == "xtreamcodes"
                || value == "xtream_codes" =>
        {
            Some(CatchupMode::XtreamCodes)
        }
        Some(value) if value == "vod" => Some(CatchupMode::Vod),
        Some(_) => Some(CatchupMode::Default),
        None if entry
            .catchup_source
            .as_ref()
            .is_some_and(|value| !value.trim().is_empty()) =>
        {
            Some(CatchupMode::Default)
        }
        None => None,
    }
}

fn m3u_guide_snapshot(
    channels: &[LiveTvRuntimeChannelSnapshot],
    window_start: String,
    window_end: String,
    time_slots: Vec<String>,
) -> LiveTvRuntimeGuideSnapshot {
    LiveTvRuntimeGuideSnapshot {
        title: "Live TV Guide".to_owned(),
        window_start,
        window_end,
        time_slots,
        rows: channels
            .iter()
            .map(|channel| LiveTvRuntimeGuideRowSnapshot {
                channel_number: channel.number.clone(),
                channel_name: channel.name.clone(),
                slots: vec![
                    LiveTvRuntimeGuideSlotSnapshot {
                        start: channel.current.start.clone(),
                        end: channel.current.end.clone(),
                        title: channel.current.title.clone(),
                        state: "current".to_owned(),
                    },
                    LiveTvRuntimeGuideSlotSnapshot {
                        start: channel.next.start.clone(),
                        end: channel.next.end.clone(),
                        title: channel.next.title.clone(),
                        state: "next".to_owned(),
                    },
                ],
            })
            .collect(),
    }
}

fn m3u_group_order(channels: &[LiveTvRuntimeChannelSnapshot]) -> Vec<String> {
    let mut order = vec!["All".to_owned()];
    for channel in channels {
        if !order.contains(&channel.group) {
            order.push(channel.group.clone());
        }
    }
    order
}

fn m3u_group_snapshots(
    channels: &[LiveTvRuntimeChannelSnapshot],
) -> Vec<crate::LiveTvRuntimeGroupSnapshot> {
    let mut groups = vec![group_snapshot(
        "all",
        "All",
        "All configured M3U channels",
        channels.len() as u16,
        true,
    )];
    let mut seen = HashSet::new();
    for group in channels.iter().map(|channel| channel.group.clone()) {
        if seen.insert(group.clone()) {
            let count = channels
                .iter()
                .filter(|channel| channel.group == group)
                .count() as u16;
            groups.push(group_snapshot(
                &normalize_key(&group),
                &group,
                "Parsed M3U group",
                count,
                false,
            ));
        }
    }
    groups
}

fn stable_m3u_content_key(
    provider: &SourceProviderEntrySnapshot,
    entry: &M3uEntry,
    stream_uri: &str,
) -> String {
    let name = entry
        .name
        .as_deref()
        .or(entry.tvg_name.as_deref())
        .or(entry.tvg_id.as_deref())
        .unwrap_or("channel");
    let normalized = normalize_key(&format!("{}-{name}", provider.provider_key));
    let mut seen_keys = HashSet::new();
    generate_playlist_unique_id(
        Some(&normalized),
        if stream_uri.trim().is_empty() {
            None
        } else {
            Some(stream_uri)
        },
        Some(name),
        &mut seen_keys,
    )
}

#[cfg(not(target_arch = "wasm32"))]
fn stable_stalker_content_key(
    provider: &SourceProviderEntrySnapshot,
    title: &str,
    stream_uri: &str,
) -> String {
    let normalized = normalize_key(&format!("{}-{title}", provider.provider_key));
    let mut seen_keys = HashSet::new();
    generate_playlist_unique_id(
        Some(&normalized),
        if stream_uri.trim().is_empty() {
            None
        } else {
            Some(stream_uri)
        },
        Some(title),
        &mut seen_keys,
    )
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_live_channels(
    provider: &SourceProviderEntrySnapshot,
    channels: &[XtreamChannel],
) -> Vec<LiveTvRuntimeChannelSnapshot> {
    channels
        .iter()
        .take(24)
        .map(|channel| xtream_live_channel(provider, channel))
        .collect()
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_live_channel(
    provider: &SourceProviderEntrySnapshot,
    channel: &XtreamChannel,
) -> LiveTvRuntimeChannelSnapshot {
    let number = channel
        .num
        .map(|value| value.to_string())
        .unwrap_or_else(|| channel.stream_id.to_string());
    let stream_uri = channel
        .url
        .clone()
        .or_else(|| channel.direct_source.clone())
        .unwrap_or_default();
    let content_key = stable_xtream_content_key(provider, &channel.name, &stream_uri);
    let group = channel
        .category_id
        .clone()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "All".to_owned());
    let current_title = format!("{} live", channel.name);
    let next_title = format!("Next on {}", channel.name);

    LiveTvRuntimeChannelSnapshot {
        number,
        name: channel.name.clone(),
        group,
        state: "ready".to_owned(),
        live_edge: true,
        catch_up: channel.tv_archive.unwrap_or(0) > 0,
        archive: channel.tv_archive.unwrap_or(0) > 0,
        playback_source: playback_source(
            "live_channel",
            &provider.provider_key,
            &content_key,
            &provider.display_name,
            "Watch live",
        ),
        playback_stream: playback_stream(&stream_uri, "hls", true, true, 0),
        current: LiveTvRuntimeProgramSnapshot {
            title: current_title,
            summary: format!("Live channel from {}", provider.display_name),
            start: "Now".to_owned(),
            end: "Next".to_owned(),
            progress_percent: 50,
        },
        next: LiveTvRuntimeProgramSnapshot {
            title: next_title,
            summary: format!("Follow-up block on {}", provider.display_name),
            start: "Next".to_owned(),
            end: "Later".to_owned(),
            progress_percent: 0,
        },
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_guide_snapshot(channels: &[LiveTvRuntimeChannelSnapshot]) -> LiveTvRuntimeGuideSnapshot {
    let (window_start, window_end, time_slots) = guide_window_from_channels(channels);
    LiveTvRuntimeGuideSnapshot {
        title: "Live TV Guide".to_owned(),
        window_start,
        window_end,
        time_slots,
        rows: channels
            .iter()
            .map(|channel| LiveTvRuntimeGuideRowSnapshot {
                channel_number: channel.number.clone(),
                channel_name: channel.name.clone(),
                slots: vec![
                    LiveTvRuntimeGuideSlotSnapshot {
                        start: channel.current.start.clone(),
                        end: channel.current.end.clone(),
                        title: channel.current.title.clone(),
                        state: "current".to_owned(),
                    },
                    LiveTvRuntimeGuideSlotSnapshot {
                        start: channel.next.start.clone(),
                        end: channel.next.end.clone(),
                        title: channel.next.title.clone(),
                        state: "next".to_owned(),
                    },
                ],
            })
            .collect(),
    }
}

#[cfg(not(target_arch = "wasm32"))]
async fn fetch_xtream_short_epg(
    client: &XtreamClient,
    stream_id: i64,
) -> Result<Option<XtreamShortEpg>, String> {
    let epg = client
        .get_short_epg(stream_id, Some(4))
        .await
        .map_err(|error| error.to_string())?;
    if epg.epg_listings.is_empty() {
        Ok(None)
    } else {
        Ok(Some(epg))
    }
}

#[cfg(not(target_arch = "wasm32"))]
async fn fetch_stalker_epg(
    client: &StalkerClient,
    channel_id: &str,
) -> Result<Option<Vec<StalkerEpgEntry>>, String> {
    let epg = client
        .get_epg(channel_id, 4)
        .await
        .map_err(|error| error.to_string())?;
    if epg.is_empty() {
        Ok(None)
    } else {
        Ok(Some(epg))
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn apply_xtream_short_epg(
    provider: &SourceProviderEntrySnapshot,
    channel: &mut LiveTvRuntimeChannelSnapshot,
    epg: &XtreamShortEpg,
) {
    if let Some(current) = epg.epg_listings.first() {
        channel.current =
            xtream_program_from_listing(provider, &channel.name, current, "current", "Now", "Next");
    }
    if let Some(next) = epg.epg_listings.get(1) {
        channel.next =
            xtream_program_from_listing(provider, &channel.name, next, "next", "Next", "Later");
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_program_from_listing(
    provider: &SourceProviderEntrySnapshot,
    channel_name: &str,
    listing: &XtreamEpgListing,
    state: &str,
    default_start: &str,
    default_end: &str,
) -> LiveTvRuntimeProgramSnapshot {
    let title = listing
        .title
        .clone()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| format!("{channel_name} {state}"));
    let summary = listing
        .description
        .clone()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| format!("EPG from {}", provider.display_name));
    LiveTvRuntimeProgramSnapshot {
        title,
        summary,
        start: listing
            .start
            .clone()
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| default_start.to_owned()),
        end: listing
            .end
            .clone()
            .or_else(|| listing.stop.clone())
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| default_end.to_owned()),
        progress_percent: if state == "current" { 50 } else { 0 },
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn apply_stalker_epg(
    provider: &SourceProviderEntrySnapshot,
    channel: &mut LiveTvRuntimeChannelSnapshot,
    epg: &[StalkerEpgEntry],
) {
    if let Some(current) = epg.first() {
        channel.current = stalker_program_from_entry(provider, &channel.name, current, "current");
    }
    if let Some(next) = epg.get(1) {
        channel.next = stalker_program_from_entry(provider, &channel.name, next, "next");
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_program_from_entry(
    provider: &SourceProviderEntrySnapshot,
    channel_name: &str,
    entry: &StalkerEpgEntry,
    state: &str,
) -> LiveTvRuntimeProgramSnapshot {
    let start = entry
        .start_timestamp
        .map(|value| value.to_string())
        .unwrap_or_else(|| if state == "current" { "Now" } else { "Next" }.to_owned());
    let end = entry
        .end_timestamp
        .map(|value| value.to_string())
        .unwrap_or_else(|| if state == "current" { "Next" } else { "Later" }.to_owned());
    LiveTvRuntimeProgramSnapshot {
        title: if entry.name.trim().is_empty() {
            format!("{channel_name} {state}")
        } else {
            entry.name.clone()
        },
        summary: entry
            .description
            .clone()
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| format!("EPG from {}", provider.display_name)),
        start,
        end,
        progress_percent: if state == "current" { 50 } else { 0 },
    }
}

fn guide_window_from_channels(
    channels: &[LiveTvRuntimeChannelSnapshot],
) -> (String, String, Vec<String>) {
    let Some(first) = channels.first() else {
        return ("Now".to_owned(), "Later".to_owned(), vec![]);
    };
    let window_start = if first.current.start.trim().is_empty() {
        "Now".to_owned()
    } else {
        first.current.start.clone()
    };
    let window_end = if first.next.end.trim().is_empty() {
        "Later".to_owned()
    } else {
        first.next.end.clone()
    };
    let mut time_slots = Vec::new();
    for slot in [
        first.current.start.clone(),
        first.current.end.clone(),
        first.next.start.clone(),
        first.next.end.clone(),
    ] {
        if !slot.trim().is_empty() && !time_slots.contains(&slot) {
            time_slots.push(slot);
        }
    }
    (window_start, window_end, time_slots)
}

#[cfg(not(target_arch = "wasm32"))]
fn guide_hydration_enabled(provider: &SourceProviderEntrySnapshot) -> bool {
    provider
        .runtime_config
        .get("guide_mode")
        .map(|value| value == "epg")
        .unwrap_or(false)
}

#[cfg(not(target_arch = "wasm32"))]
fn stable_xtream_content_key(
    provider: &SourceProviderEntrySnapshot,
    title: &str,
    stream_uri: &str,
) -> String {
    let normalized = normalize_key(&format!("{}-{title}", provider.provider_key));
    let mut seen_keys = HashSet::new();
    generate_playlist_unique_id(
        Some(&normalized),
        if stream_uri.trim().is_empty() {
            None
        } else {
            Some(stream_uri)
        },
        Some(title),
        &mut seen_keys,
    )
}

#[allow(dead_code)]
fn build_live_channels(
    providers: &[&SourceProviderEntrySnapshot],
    seen_content_keys: &mut HashSet<String>,
) -> Vec<LiveTvRuntimeChannelSnapshot> {
    let mut channels = Vec::new();
    for (index, provider) in providers.iter().enumerate() {
        let number = fallback_live_channel_number(index);
        let group = fallback_live_group(provider);
        let name = fallback_live_channel_name(provider);
        let current_title = format!("{} Live", provider.display_name);
        let next_title = format!("{} Next", provider.display_name);
        let stream_uri = fallback_live_stream_uri(provider, index);
        let live_edge = provider.supports("live_tv");
        let catch_up = provider.supports("catch_up");

        let playback_source = playback_source(
            "live_channel",
            &provider.provider_key,
            &stable_content_key(
                &provider.provider_key,
                &name,
                Some(&stream_uri),
                seen_content_keys,
            ),
            &provider.display_name,
            "Watch live",
        );
        let playback_stream = playback_stream(&stream_uri, "hls", true, true, 0);

        channels.push(LiveTvRuntimeChannelSnapshot {
            number,
            name,
            group,
            state: "ready".to_owned(),
            live_edge,
            catch_up,
            archive: provider.supports("catch_up"),
            playback_source,
            playback_stream,
            current: LiveTvRuntimeProgramSnapshot {
                title: current_title.clone(),
                summary: format!("{} on {}", current_title, provider.display_name),
                start: "21:00".to_owned(),
                end: "22:00".to_owned(),
                progress_percent: 54,
            },
            next: LiveTvRuntimeProgramSnapshot {
                title: next_title.clone(),
                summary: format!("Follow-up block on {}", provider.display_name),
                start: "22:00".to_owned(),
                end: "22:30".to_owned(),
                progress_percent: 0,
            },
        });
    }
    channels
}

#[allow(dead_code)]
fn build_guide_snapshot(
    providers: &[&SourceProviderEntrySnapshot],
    selected_channel_number: &str,
) -> LiveTvRuntimeGuideSnapshot {
    let mut rows = Vec::new();
    for (index, provider) in providers.iter().enumerate() {
        let channel_number = fallback_live_channel_number(index);
        let channel_name = fallback_live_channel_name(provider);
        let current_title = format!("{} Live", provider.display_name);
        let next_title = format!("{} Next", provider.display_name);

        rows.push(LiveTvRuntimeGuideRowSnapshot {
            channel_number: channel_number.clone(),
            channel_name,
            slots: vec![
                LiveTvRuntimeGuideSlotSnapshot {
                    start: "21:00".to_owned(),
                    end: "22:00".to_owned(),
                    title: current_title,
                    state: if channel_number == selected_channel_number {
                        "current".to_owned()
                    } else {
                        "future".to_owned()
                    },
                },
                LiveTvRuntimeGuideSlotSnapshot {
                    start: "22:00".to_owned(),
                    end: "22:30".to_owned(),
                    title: next_title,
                    state: "next".to_owned(),
                },
            ],
        });
    }

    LiveTvRuntimeGuideSnapshot {
        title: "Live TV Guide".to_owned(),
        window_start: "21:00".to_owned(),
        window_end: "22:30".to_owned(),
        time_slots: vec![
            "Now".to_owned(),
            "21:30".to_owned(),
            "22:00".to_owned(),
            "22:30".to_owned(),
        ],
        rows,
    }
}

#[allow(dead_code)]
fn fallback_live_channel_number(index: usize) -> String {
    format!("{:03}", 101 + (index as u16 * 17))
}

#[allow(dead_code)]
fn fallback_live_group(provider: &SourceProviderEntrySnapshot) -> String {
    if provider.supports("movies") {
        "Movies".to_owned()
    } else if provider.supports("series") {
        "Series".to_owned()
    } else if provider.supports("catch_up") {
        "Archive".to_owned()
    } else {
        "Live".to_owned()
    }
}

#[allow(dead_code)]
fn fallback_live_channel_name(provider: &SourceProviderEntrySnapshot) -> String {
    normalized_provider_label(provider)
}

#[allow(dead_code)]
fn fallback_live_stream_uri(provider: &SourceProviderEntrySnapshot, index: usize) -> String {
    if let Some(base) = provider
        .runtime_config
        .get("stream_base_url")
        .or_else(|| provider.runtime_config.get("server_url"))
    {
        let normalized = base.trim_end_matches('/');
        return format!("{normalized}/live/{index}.m3u8");
    }

    format!(
        "https://{}.runtime/live/{}.m3u8",
        normalize_key(&provider.provider_key),
        index + 1
    )
}

fn build_live_selection(
    provider: &SourceProviderEntrySnapshot,
    selected_channel: &LiveTvRuntimeChannelSnapshot,
) -> LiveTvRuntimeSelectionSnapshot {
    LiveTvRuntimeSelectionSnapshot {
        channel_number: selected_channel.number.clone(),
        channel_name: selected_channel.name.clone(),
        status: "Live".to_owned(),
        live_edge: selected_channel.live_edge,
        catch_up: selected_channel.catch_up,
        archive: selected_channel.archive,
        now: selected_channel.current.clone(),
        next: selected_channel.next.clone(),
        primary_action: "Watch live".to_owned(),
        secondary_action: if provider.supports("catch_up") {
            "Start over".to_owned()
        } else {
            "Open guide".to_owned()
        },
        badges: vec![
            "Live".to_owned(),
            provider.provider_type.clone(),
            if provider.supports("catch_up") {
                "Catch-up".to_owned()
            } else {
                "Guide".to_owned()
            },
        ],
        detail_lines: vec![
            format!("Hydrated from {}.", provider.display_name),
            "Selected detail stays in the right lane while browse remains on the left.".to_owned(),
        ],
    }
}

fn build_media_runtime(
    source_registry: &SourceRegistrySnapshot,
    media_provider: Option<&SourceProviderEntrySnapshot>,
) -> MediaRuntimeSnapshot {
    let Some(provider) = media_provider else {
        return empty_media_runtime();
    };

    if provider.provider_type == "Xtream" {
        if let Some(runtime) = try_build_xtream_media_runtime(provider) {
            return runtime;
        }
    }
    if provider.provider_type == "Stalker" {
        if let Some(runtime) = try_build_stalker_media_runtime(provider) {
            return runtime;
        }
    }

    if demo_seeded_runtime_enabled(source_registry) {
        return demo_seeded_media_runtime(provider);
    }

    provider_error_media_runtime(
        provider,
        "Media runtime failed to hydrate from the configured provider.",
    )
}

#[cfg(not(target_arch = "wasm32"))]
fn try_build_xtream_media_runtime(
    provider: &SourceProviderEntrySnapshot,
) -> Option<MediaRuntimeSnapshot> {
    let client = xtream_client_from_provider(provider)?;
    let movies = fetch_xtream_movie_listings(&client);
    let series = fetch_xtream_series_listings(&client);
    if movies.is_empty() && series.is_empty() {
        return None;
    }

    let mut seen_content_keys = HashSet::new();
    let movie_collection = MediaRuntimeCollectionSnapshot {
        title: "Featured Films".to_owned(),
        summary: format!("Movie catalog hydrated from {}.", provider.display_name),
        items: xtream_movie_items(provider, &movies, &mut seen_content_keys),
    };
    let series_collection = MediaRuntimeCollectionSnapshot {
        title: "Featured Series".to_owned(),
        summary: format!("Series catalog hydrated from {}.", provider.display_name),
        items: xtream_series_items(provider, &series, &mut seen_content_keys),
    };
    let series_detail =
        xtream_series_detail(provider, &client, series.first(), &mut seen_content_keys)
            .unwrap_or_else(|| fallback_series_detail(provider, &mut seen_content_keys));
    let movie_hero = xtream_movie_hero(&movies);
    let series_hero = xtream_series_hero(&series);

    Some(MediaRuntimeSnapshot {
        title: "CrispyTivi Media Runtime".to_owned(),
        version: "1".to_owned(),
        active_panel: "Movies".to_owned(),
        active_scope: "Featured".to_owned(),
        movie_hero,
        series_hero,
        movie_collections: vec![movie_collection],
        series_collections: vec![series_collection],
        series_detail,
        notes: vec![
            "Hydrated from Xtream provider runtime config via the shared Xtream client."
                .to_owned(),
            "If the real provider fetch fails, Rust falls back to deterministic retained scaffolding."
                .to_owned(),
        ],
    })
}

#[cfg(not(target_arch = "wasm32"))]
fn fetch_xtream_movie_listings(client: &XtreamClient) -> Vec<XtreamMovieListing> {
    xtream_first_non_empty_category(client, XtreamMediaKind::Movies)
        .and_then(|category| {
            crate::block_on_source_runtime(client.get_vod_streams(Some(&category.category_id)))
                .ok()
                .filter(|items| !items.is_empty())
        })
        .or_else(|| {
            crate::block_on_source_runtime(client.get_vod_streams(None))
                .ok()
                .filter(|items| !items.is_empty())
        })
        .unwrap_or_default()
}

#[cfg(not(target_arch = "wasm32"))]
fn fetch_xtream_series_listings(client: &XtreamClient) -> Vec<XtreamShowListing> {
    xtream_first_non_empty_category(client, XtreamMediaKind::Series)
        .and_then(|category| {
            crate::block_on_source_runtime(client.get_series(Some(&category.category_id)))
                .ok()
                .filter(|items| !items.is_empty())
        })
        .or_else(|| {
            crate::block_on_source_runtime(client.get_series(None))
                .ok()
                .filter(|items| !items.is_empty())
        })
        .unwrap_or_default()
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_first_non_empty_category(
    client: &XtreamClient,
    kind: XtreamMediaKind,
) -> Option<XtreamCategory> {
    let categories = match kind {
        XtreamMediaKind::Movies => {
            crate::block_on_source_runtime(client.get_vod_categories()).ok()?
        }
        XtreamMediaKind::Series => {
            crate::block_on_source_runtime(client.get_series_categories()).ok()?
        }
    };
    categories
        .into_iter()
        .find(|category| !category.category_id.trim().is_empty())
}

#[cfg(not(target_arch = "wasm32"))]
enum XtreamMediaKind {
    Movies,
    Series,
}

#[cfg(target_arch = "wasm32")]
fn try_build_xtream_media_runtime(
    _provider: &SourceProviderEntrySnapshot,
) -> Option<MediaRuntimeSnapshot> {
    None
}

#[cfg(not(target_arch = "wasm32"))]
fn try_build_stalker_media_runtime(
    provider: &SourceProviderEntrySnapshot,
) -> Option<MediaRuntimeSnapshot> {
    crate::block_on_source_runtime(fetch_stalker_media_runtime(provider))
        .ok()
        .flatten()
}

#[cfg(target_arch = "wasm32")]
fn try_build_stalker_media_runtime(
    _provider: &SourceProviderEntrySnapshot,
) -> Option<MediaRuntimeSnapshot> {
    None
}

#[cfg(not(target_arch = "wasm32"))]
async fn fetch_stalker_media_runtime(
    provider: &SourceProviderEntrySnapshot,
) -> Result<Option<MediaRuntimeSnapshot>, String> {
    let mut client = stalker_client_from_provider(provider)
        .ok_or_else(|| "missing stalker runtime config".to_owned())?;
    client
        .authenticate()
        .await
        .map_err(|error| error.to_string())?;

    let movie_category = client
        .get_vod_categories()
        .await
        .map_err(|error| error.to_string())?
        .into_iter()
        .find(|category| !category.is_adult);
    let series_category = client
        .get_series_categories()
        .await
        .map_err(|error| error.to_string())?
        .into_iter()
        .find(|category| !category.is_adult);

    let movies = if let Some(category) = movie_category.as_ref() {
        client
            .get_all_vod(&category.id, None)
            .await
            .map_err(|error| error.to_string())?
    } else {
        vec![]
    };
    let series = if let Some(category) = series_category.as_ref() {
        client
            .get_all_series(&category.id, None)
            .await
            .map_err(|error| error.to_string())?
    } else {
        vec![]
    };

    if movies.is_empty() && series.is_empty() {
        return Ok(None);
    }

    let mut seen_content_keys = HashSet::new();
    let movie_collection = MediaRuntimeCollectionSnapshot {
        title: "Featured Films".to_owned(),
        summary: format!("Movie catalog hydrated from {}.", provider.display_name),
        items: stalker_movie_items(provider, &movies, &mut seen_content_keys),
    };
    let series_collection = MediaRuntimeCollectionSnapshot {
        title: "Featured Series".to_owned(),
        summary: format!("Series catalog hydrated from {}.", provider.display_name),
        items: stalker_series_items(provider, &series, &mut seen_content_keys),
    };
    let series_detail =
        stalker_series_detail(provider, &client, series.first(), &mut seen_content_keys)
            .await
            .unwrap_or_else(|| fallback_series_detail(provider, &mut seen_content_keys));
    let movie_hero = stalker_movie_hero(&movies);
    let series_hero = stalker_series_hero(&series);

    Ok(Some(MediaRuntimeSnapshot {
        title: "CrispyTivi Media Runtime".to_owned(),
        version: "1".to_owned(),
        active_panel: "Movies".to_owned(),
        active_scope: "Featured".to_owned(),
        movie_hero,
        series_hero,
        movie_collections: vec![movie_collection],
        series_collections: vec![series_collection],
        series_detail,
        notes: vec![
            "Hydrated from Stalker provider runtime config via the shared Stalker client."
                .to_owned(),
            "If the real provider fetch fails, Rust falls back to deterministic retained scaffolding."
                .to_owned(),
        ],
    }))
}

fn media_item(
    provider: &SourceProviderEntrySnapshot,
    seen_content_keys: &mut HashSet<String>,
    kind: &str,
    title: &str,
    caption: &str,
    rank: Option<u16>,
    base_seed: &str,
    stream_uri: &str,
    resume_position_seconds: u32,
    handoff_label: &str,
) -> MediaRuntimeItemSnapshot {
    let normalized_title = non_empty_string(Some(title.to_owned())).unwrap_or_else(|| match kind {
        "movie" => "Untitled movie".to_owned(),
        "series" => "Untitled series".to_owned(),
        _ => "Untitled item".to_owned(),
    });
    let normalized_caption =
        non_empty_string(Some(caption.to_owned())).unwrap_or_else(|| match kind {
            "movie" => "Movie".to_owned(),
            "series" => "Series".to_owned(),
            _ => "Media".to_owned(),
        });
    let content_key = stable_content_key(
        &format!("{base_seed}-{normalized_title}"),
        &normalized_title,
        Some(stream_uri),
        seen_content_keys,
    );
    MediaRuntimeItemSnapshot {
        title: normalized_title,
        caption: normalized_caption,
        rank,
        playback_source: playback_source(
            kind,
            &provider.provider_key,
            &content_key,
            &provider.display_name,
            handoff_label,
        ),
        playback_stream: playback_stream(stream_uri, "hls", false, true, resume_position_seconds),
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_movie_items(
    provider: &SourceProviderEntrySnapshot,
    movies: &[XtreamMovieListing],
    seen_content_keys: &mut HashSet<String>,
) -> Vec<MediaRuntimeItemSnapshot> {
    movies
        .iter()
        .take(12)
        .map(|movie| {
            let title = movie.title.as_deref().unwrap_or(&movie.name);
            let caption = movie
                .genre
                .clone()
                .or_else(|| movie.year.clone())
                .unwrap_or_else(|| "Movie".to_owned());
            let stream_uri = movie
                .url
                .clone()
                .or_else(|| movie.direct_source.clone())
                .unwrap_or_default();
            media_item(
                provider,
                seen_content_keys,
                "movie",
                title,
                &caption,
                movie.num.and_then(|value| u16::try_from(value).ok()),
                &format!("{}-movies", provider.provider_key),
                &stream_uri,
                0,
                "Play movie",
            )
        })
        .collect()
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_series_items(
    provider: &SourceProviderEntrySnapshot,
    series: &[XtreamShowListing],
    seen_content_keys: &mut HashSet<String>,
) -> Vec<MediaRuntimeItemSnapshot> {
    series
        .iter()
        .take(12)
        .map(|show| {
            let title = show.title.as_deref().unwrap_or(&show.name);
            let caption = show
                .genre
                .clone()
                .or_else(|| show.year.clone())
                .unwrap_or_else(|| "Series".to_owned());
            media_item(
                provider,
                seen_content_keys,
                "series",
                title,
                &caption,
                show.num.and_then(|value| u16::try_from(value).ok()),
                &format!("{}-series", provider.provider_key),
                &format!("series://{}/{}", provider.provider_key, show.series_id),
                0,
                "Browse series",
            )
        })
        .collect()
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_series_detail(
    provider: &SourceProviderEntrySnapshot,
    client: &XtreamClient,
    show_listing: Option<&XtreamShowListing>,
    seen_content_keys: &mut HashSet<String>,
) -> Option<MediaRuntimeSeriesDetailSnapshot> {
    let show_listing = show_listing?;
    let show =
        crate::block_on_source_runtime(client.get_series_info(show_listing.series_id)).ok()?;
    let show_title = show_listing.title.as_deref().unwrap_or(&show_listing.name);
    let summary = show
        .info
        .as_ref()
        .and_then(|info| info.plot.clone())
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| format!("{show_title} from {}", provider.display_name));
    let seasons = xtream_series_seasons(provider, show_title, &show, seen_content_keys);
    if seasons.is_empty() {
        return None;
    }

    Some(MediaRuntimeSeriesDetailSnapshot {
        summary_title: "Season and episode playback".to_owned(),
        summary_body: summary,
        handoff_label: "Play episode".to_owned(),
        seasons,
    })
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_series_seasons(
    provider: &SourceProviderEntrySnapshot,
    show_title: &str,
    show: &XtreamShow,
    seen_content_keys: &mut HashSet<String>,
) -> Vec<MediaRuntimeSeasonSnapshot> {
    show.seasons
        .iter()
        .take(4)
        .filter_map(|season| {
            xtream_series_season(provider, show_title, show, season, seen_content_keys)
        })
        .collect()
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_series_season(
    provider: &SourceProviderEntrySnapshot,
    show_title: &str,
    show: &XtreamShow,
    season: &XtreamSeason,
    seen_content_keys: &mut HashSet<String>,
) -> Option<MediaRuntimeSeasonSnapshot> {
    let season_number = season.season_number?;
    let season_key = season_number.to_string();
    let episodes = show.episodes.get(&season_key)?;
    let mapped_episodes: Vec<MediaRuntimeEpisodeSnapshot> = episodes
        .iter()
        .take(12)
        .filter_map(|episode| {
            xtream_episode(
                provider,
                show_title,
                season_number,
                episode,
                seen_content_keys,
            )
        })
        .collect();
    if mapped_episodes.is_empty() {
        return None;
    }

    Some(MediaRuntimeSeasonSnapshot {
        label: season
            .name
            .clone()
            .unwrap_or_else(|| format!("Season {season_number}")),
        summary: season
            .overview
            .clone()
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| format!("{show_title} season {season_number}")),
        episodes: mapped_episodes,
    })
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_episode(
    provider: &SourceProviderEntrySnapshot,
    show_title: &str,
    season_number: i64,
    episode: &XtreamEpisode,
    seen_content_keys: &mut HashSet<String>,
) -> Option<MediaRuntimeEpisodeSnapshot> {
    let stream_uri = episode
        .url
        .clone()
        .or_else(|| episode.direct_source.clone())?;
    let episode_number = episode_number(episode);
    let title = episode
        .title
        .clone()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| format!("{show_title} Episode {episode_number}"));
    let summary = episode
        .info
        .as_ref()
        .and_then(|info| info.plot.clone())
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| format!("{title} from {}", provider.display_name));
    let duration_label = episode
        .info
        .as_ref()
        .and_then(|info| info.duration.clone())
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "Episode".to_owned());
    let content_key = stable_content_key(
        &format!(
            "{}-{show_title}-s{season_number}-e{episode_number}",
            provider.provider_key
        ),
        &title,
        Some(&stream_uri),
        seen_content_keys,
    );

    Some(MediaRuntimeEpisodeSnapshot {
        code: format!("S{season_number}:E{episode_number}"),
        title,
        summary,
        duration_label,
        handoff_label: "Play episode".to_owned(),
        playback_source: playback_source(
            "episode",
            &provider.provider_key,
            &content_key,
            &provider.display_name,
            "Play episode",
        ),
        playback_stream: playback_stream(&stream_uri, "hls", false, true, 0),
    })
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_movie_items(
    provider: &SourceProviderEntrySnapshot,
    movies: &[StalkerVodItem],
    seen_content_keys: &mut HashSet<String>,
) -> Vec<MediaRuntimeItemSnapshot> {
    movies
        .iter()
        .take(12)
        .map(|movie| {
            let caption = movie
                .genre
                .clone()
                .or_else(|| movie.year.clone())
                .unwrap_or_else(|| "Movie".to_owned());
            let stream_uri = resolve_stream_url(&movie.cmd, &provider.runtime_config["portal_url"])
                .unwrap_or_default();
            media_item(
                provider,
                seen_content_keys,
                "movie",
                &movie.name,
                &caption,
                None,
                &format!("{}-movies", provider.provider_key),
                &stream_uri,
                0,
                "Play movie",
            )
        })
        .collect()
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_series_items(
    provider: &SourceProviderEntrySnapshot,
    series: &[StalkerSeriesItem],
    seen_content_keys: &mut HashSet<String>,
) -> Vec<MediaRuntimeItemSnapshot> {
    series
        .iter()
        .take(12)
        .map(|show| {
            let caption = show
                .genre
                .clone()
                .or_else(|| show.year.clone())
                .unwrap_or_else(|| "Series".to_owned());
            media_item(
                provider,
                seen_content_keys,
                "series",
                &show.name,
                &caption,
                None,
                &format!("{}-series", provider.provider_key),
                &format!("series://{}/{}", provider.provider_key, show.id),
                0,
                "Browse series",
            )
        })
        .collect()
}

#[cfg(not(target_arch = "wasm32"))]
async fn stalker_series_detail(
    provider: &SourceProviderEntrySnapshot,
    client: &StalkerClient,
    series: Option<&StalkerSeriesItem>,
    seen_content_keys: &mut HashSet<String>,
) -> Option<MediaRuntimeSeriesDetailSnapshot> {
    let series = series?.clone();
    let detail = client.get_series_info(series).await.ok()?;
    let seasons = stalker_series_seasons(provider, &detail, seen_content_keys);
    if seasons.is_empty() {
        return None;
    }

    Some(MediaRuntimeSeriesDetailSnapshot {
        summary_title: "Season and episode playback".to_owned(),
        summary_body: detail
            .series
            .description
            .clone()
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| format!("{} from {}", detail.series.name, provider.display_name)),
        handoff_label: "Play episode".to_owned(),
        seasons,
    })
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_series_seasons(
    provider: &SourceProviderEntrySnapshot,
    detail: &StalkerSeriesDetail,
    seen_content_keys: &mut HashSet<String>,
) -> Vec<MediaRuntimeSeasonSnapshot> {
    detail
        .seasons
        .iter()
        .take(4)
        .filter_map(|season| {
            let mapped_episodes: Vec<MediaRuntimeEpisodeSnapshot> = detail
                .episodes
                .get(&season.id)
                .into_iter()
                .flat_map(|episodes| episodes.iter())
                .take(12)
                .filter_map(|episode| {
                    let stream_uri =
                        resolve_stream_url(&episode.cmd, &provider.runtime_config["portal_url"])?;
                    Some(MediaRuntimeEpisodeSnapshot {
                        code: episode
                            .episode_number
                            .map(|number| format!("S?:E{number}"))
                            .unwrap_or_else(|| episode.id.clone()),
                        title: episode.name.clone(),
                        summary: episode
                            .description
                            .clone()
                            .filter(|value| !value.trim().is_empty())
                            .unwrap_or_else(|| format!("Episode from {}", detail.series.name)),
                        duration_label: episode
                            .duration
                            .clone()
                            .unwrap_or_else(|| "Episode".to_owned()),
                        handoff_label: "Play episode".to_owned(),
                        playback_source: playback_source(
                            "episode",
                            &provider.provider_key,
                            &stable_content_key(
                                &provider.provider_key,
                                &episode.id,
                                Some(&stream_uri),
                                seen_content_keys,
                            ),
                            &provider.display_name,
                            "Play episode",
                        ),
                        playback_stream: playback_stream(&stream_uri, "http", false, true, 0),
                    })
                })
                .collect();
            if mapped_episodes.is_empty() {
                return None;
            }

            Some(MediaRuntimeSeasonSnapshot {
                label: season.name.clone(),
                summary: season
                    .description
                    .clone()
                    .filter(|value| !value.trim().is_empty())
                    .unwrap_or_else(|| format!("{} season", detail.series.name)),
                episodes: mapped_episodes,
            })
        })
        .collect()
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_movie_hero(movies: &[StalkerVodItem]) -> MediaRuntimeHeroSnapshot {
    let fallback = MediaRuntimeHeroSnapshot {
        kicker: "Featured film".to_owned(),
        title: "Featured film".to_owned(),
        summary: "Movie lane hydrated from the active Stalker provider.".to_owned(),
        primary_action: "Play movie".to_owned(),
        secondary_action: "Add to watchlist".to_owned(),
    };
    let Some(movie) = movies.first() else {
        return fallback;
    };

    MediaRuntimeHeroSnapshot {
        kicker: "Featured film".to_owned(),
        title: non_empty_string(Some(movie.name.clone()))
            .unwrap_or_else(|| "Featured film".to_owned()),
        summary: non_empty_string(movie.description.clone())
            .or_else(|| non_empty_string(movie.genre.clone()))
            .unwrap_or_else(|| "Movie lane hydrated from the active Stalker provider.".to_owned()),
        primary_action: "Play movie".to_owned(),
        secondary_action: "Add to watchlist".to_owned(),
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn stalker_series_hero(series: &[StalkerSeriesItem]) -> MediaRuntimeHeroSnapshot {
    let fallback = MediaRuntimeHeroSnapshot {
        kicker: "Series spotlight".to_owned(),
        title: "Series spotlight".to_owned(),
        summary: "Series lane hydrated from the active Stalker provider.".to_owned(),
        primary_action: "Browse series".to_owned(),
        secondary_action: "Open details".to_owned(),
    };
    let Some(show) = series.first() else {
        return fallback;
    };

    MediaRuntimeHeroSnapshot {
        kicker: "Series spotlight".to_owned(),
        title: non_empty_string(Some(show.name.clone()))
            .unwrap_or_else(|| "Series spotlight".to_owned()),
        summary: non_empty_string(show.description.clone())
            .or_else(|| non_empty_string(show.genre.clone()))
            .unwrap_or_else(|| "Series lane hydrated from the active Stalker provider.".to_owned()),
        primary_action: "Browse series".to_owned(),
        secondary_action: "Open details".to_owned(),
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn episode_number(episode: &XtreamEpisode) -> i64 {
    episode
        .episode_num
        .as_ref()
        .and_then(json_i64)
        .or_else(|| episode.id.as_ref().and_then(json_i64))
        .unwrap_or(1)
}

#[cfg(not(target_arch = "wasm32"))]
fn json_i64(value: &serde_json::Value) -> Option<i64> {
    value
        .as_i64()
        .or_else(|| value.as_str().and_then(|item| item.parse().ok()))
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_movie_hero(movies: &[XtreamMovieListing]) -> MediaRuntimeHeroSnapshot {
    let fallback = MediaRuntimeHeroSnapshot {
        kicker: "Featured film".to_owned(),
        title: "Featured movie".to_owned(),
        summary: "Movie runtime is hydrated from the active provider.".to_owned(),
        primary_action: "Play movie".to_owned(),
        secondary_action: "Add to watchlist".to_owned(),
    };
    let Some(movie) = movies.first() else {
        return fallback;
    };
    MediaRuntimeHeroSnapshot {
        kicker: "Featured film".to_owned(),
        title: non_empty_string(movie.title.clone())
            .or_else(|| non_empty_string(Some(movie.name.clone())))
            .unwrap_or_else(|| "Featured movie".to_owned()),
        summary: non_empty_string(movie.plot.clone())
            .or_else(|| non_empty_string(movie.genre.clone()))
            .unwrap_or_else(|| "Movie runtime is hydrated from the active provider.".to_owned()),
        primary_action: "Play movie".to_owned(),
        secondary_action: "Add to watchlist".to_owned(),
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn xtream_series_hero(series: &[XtreamShowListing]) -> MediaRuntimeHeroSnapshot {
    let fallback = MediaRuntimeHeroSnapshot {
        kicker: "Series spotlight".to_owned(),
        title: "Featured series".to_owned(),
        summary: "Series runtime is hydrated from the active provider.".to_owned(),
        primary_action: "Browse episodes".to_owned(),
        secondary_action: "Add to watchlist".to_owned(),
    };
    let Some(show) = series.first() else {
        return fallback;
    };
    MediaRuntimeHeroSnapshot {
        kicker: "Series spotlight".to_owned(),
        title: non_empty_string(show.title.clone())
            .or_else(|| non_empty_string(Some(show.name.clone())))
            .unwrap_or_else(|| "Featured series".to_owned()),
        summary: non_empty_string(show.plot.clone())
            .or_else(|| non_empty_string(show.genre.clone()))
            .unwrap_or_else(|| "Series runtime is hydrated from the active provider.".to_owned()),
        primary_action: "Browse episodes".to_owned(),
        secondary_action: "Add to watchlist".to_owned(),
    }
}

fn non_empty_string(value: Option<String>) -> Option<String> {
    value.and_then(|text| {
        let trimmed = text.trim();
        if trimmed.is_empty() {
            None
        } else if trimmed.len() == text.len() {
            Some(text)
        } else {
            Some(trimmed.to_owned())
        }
    })
}

fn fallback_series_detail(
    provider: &SourceProviderEntrySnapshot,
    seen_content_keys: &mut HashSet<String>,
) -> MediaRuntimeSeriesDetailSnapshot {
    let stream_uri = format!("series://{}/fallback", provider.provider_key);
    MediaRuntimeSeriesDetailSnapshot {
        summary_title: "Season and episode playback".to_owned(),
        summary_body: format!(
            "{} keeps season choice above episode choice.",
            provider.display_name
        ),
        handoff_label: "Play episode".to_owned(),
        seasons: vec![MediaRuntimeSeasonSnapshot {
            label: "Season 1".to_owned(),
            summary: "Fallback retained season while real series metadata is unavailable."
                .to_owned(),
            episodes: vec![MediaRuntimeEpisodeSnapshot {
                code: "S1:E1".to_owned(),
                title: "Fallback Episode".to_owned(),
                summary: "Retained fallback episode while series info is unavailable.".to_owned(),
                duration_label: "Episode".to_owned(),
                handoff_label: "Play episode".to_owned(),
                playback_source: playback_source(
                    "episode",
                    &provider.provider_key,
                    &stable_content_key(
                        &format!("{}-fallback-series", provider.provider_key),
                        "Fallback Episode",
                        Some(&stream_uri),
                        seen_content_keys,
                    ),
                    &provider.display_name,
                    "Play episode",
                ),
                playback_stream: playback_stream(&stream_uri, "hls", false, true, 0),
            }],
        }],
    }
}

#[allow(dead_code)]
fn fallback_media_collection_title(provider: &SourceProviderEntrySnapshot, kind: &str) -> String {
    match kind {
        "movies" => format!("{} Movies", provider.display_name),
        "series" => format!("{} Series", provider.display_name),
        _ => format!("{} Library", provider.display_name),
    }
}

#[allow(dead_code)]
fn normalized_provider_label(provider: &SourceProviderEntrySnapshot) -> String {
    non_empty_string(Some(provider.display_name.clone()))
        .unwrap_or_else(|| "Configured provider".to_owned())
}

#[allow(dead_code)]
fn fallback_media_content_seed(provider: &SourceProviderEntrySnapshot, kind: &str) -> String {
    format!("{}-{}", provider.provider_key, normalize_key(kind))
}

#[allow(dead_code)]
fn fallback_media_title(
    provider: &SourceProviderEntrySnapshot,
    kind: &str,
    index: usize,
) -> String {
    match kind {
        "movie" => format!("{} Movie {index}", provider.display_name),
        "series" => format!("{} Series {index}", provider.display_name),
        _ => format!("{} Item {index}", provider.display_name),
    }
}

#[allow(dead_code)]
fn fallback_media_episode_title(provider: &SourceProviderEntrySnapshot, index: usize) -> String {
    format!("{} Episode {index}", provider.display_name)
}

#[allow(dead_code)]
fn fallback_media_caption(
    provider: &SourceProviderEntrySnapshot,
    kind: &str,
    index: usize,
) -> String {
    match kind {
        "movie" => format!("Fallback movie {index} from {}", provider.display_name),
        "series" => format!("Fallback series {index} from {}", provider.display_name),
        _ => format!("Fallback item {index} from {}", provider.display_name),
    }
}

#[allow(dead_code)]
fn fallback_media_episode_summary(provider: &SourceProviderEntrySnapshot, index: usize) -> String {
    format!(
        "Fallback episode {index} hydrated from {}.",
        provider.display_name
    )
}

#[allow(dead_code)]
fn fallback_media_hero_title(provider: &SourceProviderEntrySnapshot, kind: &str) -> String {
    match kind {
        "movie" => format!("{} Spotlight", provider.display_name),
        "series" => format!("{} Spotlight", provider.display_name),
        _ => format!("{} Spotlight", provider.display_name),
    }
}

#[allow(dead_code)]
fn fallback_media_stream_uri(
    provider: &SourceProviderEntrySnapshot,
    kind: &str,
    index: usize,
    extension: &str,
) -> String {
    if let Some(base) = provider
        .runtime_config
        .get("media_stream_base_url")
        .or_else(|| provider.runtime_config.get("stream_base_url"))
        .or_else(|| provider.runtime_config.get("server_url"))
    {
        let normalized = base.trim_end_matches('/');
        return format!("{normalized}/{kind}/{index}.{extension}");
    }

    let normalized_provider = normalize_key(&provider.provider_key);
    format!("https://{normalized_provider}.runtime/{kind}/{index}.{extension}")
}

fn build_search_runtime(
    source_registry: &SourceRegistrySnapshot,
    live_tv: &LiveTvRuntimeSnapshot,
    media: &MediaRuntimeSnapshot,
) -> SearchRuntimeSnapshot {
    let live_ready = source_registry
        .configured_providers
        .iter()
        .any(|provider| provider.supports("live_tv") && is_ready(provider));
    let movie_ready = source_registry
        .configured_providers
        .iter()
        .any(|provider| provider.supports("movies") && is_ready(provider));
    let series_ready = source_registry
        .configured_providers
        .iter()
        .any(|provider| provider.supports("series") && is_ready(provider));

    let mut groups = Vec::new();
    if live_ready {
        groups.push(SearchRuntimeGroupSnapshot {
            title: "Live TV".to_owned(),
            summary: "Live channels and guide-linked results.".to_owned(),
            selected: true,
            results: live_tv
                .channels
                .iter()
                .map(|channel| SearchRuntimeResultSnapshot {
                    title: channel.name.clone(),
                    caption: format!("Channel {}", channel.number),
                    source_label: "Live TV".to_owned(),
                    handoff_label: "Open channel".to_owned(),
                })
                .collect(),
        });
    }
    if movie_ready {
        groups.push(SearchRuntimeGroupSnapshot {
            title: "Movies".to_owned(),
            summary: "Film results and featured rails.".to_owned(),
            selected: false,
            results: media
                .movie_collections
                .iter()
                .flat_map(|collection| collection.items.iter())
                .map(|item| SearchRuntimeResultSnapshot {
                    title: item.title.clone(),
                    caption: item.caption.clone(),
                    source_label: "Movies".to_owned(),
                    handoff_label: "Open movie".to_owned(),
                })
                .collect(),
        });
    }
    if series_ready {
        groups.push(SearchRuntimeGroupSnapshot {
            title: "Series".to_owned(),
            summary: "Series results and episode-ready handoff.".to_owned(),
            selected: false,
            results: media
                .series_collections
                .iter()
                .flat_map(|collection| collection.items.iter())
                .map(|item| SearchRuntimeResultSnapshot {
                    title: item.title.clone(),
                    caption: item.caption.clone(),
                    source_label: "Series".to_owned(),
                    handoff_label: "Open series".to_owned(),
                })
                .collect(),
        });
    }

    if groups.is_empty() {
        return empty_search_runtime();
    }

    SearchRuntimeSnapshot {
        title: "CrispyTivi Search Runtime".to_owned(),
        version: "1".to_owned(),
        query: String::new(),
        active_group_title: groups[0].title.clone(),
        groups,
        notes: vec![
            "Rust-owned search runtime snapshot.".to_owned(),
            "Search groups are filtered from configured-provider capability truth.".to_owned(),
        ],
    }
}

#[allow(dead_code)]
fn fallback_search_runtime_from_registry(
    source_registry: &SourceRegistrySnapshot,
) -> SearchRuntimeSnapshot {
    let results: Vec<SearchRuntimeResultSnapshot> = source_registry
        .configured_providers
        .iter()
        .map(|provider| SearchRuntimeResultSnapshot {
            title: provider.display_name.clone(),
            caption: provider.endpoint_label.clone(),
            source_label: provider.provider_type.clone(),
            handoff_label: "Open settings".to_owned(),
        })
        .collect();
    if results.is_empty() {
        return empty_search_runtime();
    }

    SearchRuntimeSnapshot {
        title: "CrispyTivi Search Runtime".to_owned(),
        version: "1".to_owned(),
        query: String::new(),
        active_group_title: "Configured Providers".to_owned(),
        groups: vec![SearchRuntimeGroupSnapshot {
            title: "Configured Providers".to_owned(),
            summary: "Provider registry entries available for source management.".to_owned(),
            selected: true,
            results,
        }],
        notes: vec![
            "Rust-owned search runtime fallback is derived from configured providers.".to_owned(),
            "Search results stay on the Rust boundary even when live and media groups are empty."
                .to_owned(),
        ],
    }
}

fn build_personalization_runtime() -> PersonalizationRuntimeSnapshot {
    PersonalizationRuntimeSnapshot {
        title: "CrispyTivi Personalization Runtime".to_owned(),
        version: "1".to_owned(),
        startup_route: "Home".to_owned(),
        continue_watching: vec![],
        recently_viewed: vec![],
        favorite_media_keys: vec![],
        favorite_channel_numbers: vec![],
        notes: vec![
            "Real-mode personalization starts empty until persisted user state exists.".to_owned(),
        ],
    }
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

fn stable_content_key(
    seed: &str,
    name: &str,
    url_seed: Option<&str>,
    seen_keys: &mut HashSet<String>,
) -> String {
    let normalized = normalize_key(&format!("{seed}-{name}"));
    generate_playlist_unique_id(Some(&normalized), url_seed, Some(name), seen_keys)
}

fn normalize_key(input: &str) -> String {
    let mut key = String::with_capacity(input.len());
    let mut last_was_underscore = false;
    for ch in input.chars() {
        if ch.is_ascii_alphanumeric() {
            key.push(ch.to_ascii_lowercase());
            last_was_underscore = false;
        } else if !last_was_underscore && !key.is_empty() {
            key.push('_');
            last_was_underscore = true;
        }
    }
    while key.ends_with('_') {
        key.pop();
    }
    if key.is_empty() {
        "content".to_owned()
    } else {
        key
    }
}

fn is_ready(provider: &SourceProviderEntrySnapshot) -> bool {
    ready_health_status(&provider.health.status)
        && ready_auth_status(&provider.auth.status)
        && ready_import_status(&provider.import_details.status)
}

fn ready_health_status(status: &str) -> bool {
    matches!(status, "Ready" | "Complete" | "Healthy")
}

fn ready_auth_status(status: &str) -> bool {
    matches!(status, "Complete" | "Not required" | "Healthy")
}

fn ready_import_status(status: &str) -> bool {
    matches!(status, "Ready" | "Complete" | "Healthy")
}

fn first_ready_provider<'a>(
    source_registry: &'a SourceRegistrySnapshot,
    capabilities: &[&str],
) -> Option<&'a SourceProviderEntrySnapshot> {
    source_registry
        .configured_providers
        .iter()
        .find(|provider| {
            is_ready(provider)
                && capabilities
                    .iter()
                    .all(|capability| provider_supports(provider, capability))
        })
}

fn provider_supports(provider: &SourceProviderEntrySnapshot, capability: &str) -> bool {
    provider
        .capabilities
        .iter()
        .any(|item| item.id == capability && item.supported)
}

fn group_snapshot(
    id: &str,
    title: &str,
    summary: &str,
    channel_count: u16,
    selected: bool,
) -> crate::LiveTvRuntimeGroupSnapshot {
    crate::LiveTvRuntimeGroupSnapshot {
        id: id.to_owned(),
        title: title.to_owned(),
        summary: summary.to_owned(),
        channel_count,
        selected,
    }
}

fn empty_live_tv_runtime() -> LiveTvRuntimeSnapshot {
    LiveTvRuntimeSnapshot {
        title: "CrispyTivi Live TV Runtime".to_owned(),
        version: "1".to_owned(),
        provider: LiveTvRuntimeProviderSnapshot {
            provider_key: "none".to_owned(),
            provider_type: "None".to_owned(),
            family: "none".to_owned(),
            connection_mode: "none".to_owned(),
            source_name: "No provider configured".to_owned(),
            status: "Idle".to_owned(),
            summary: "Add a provider in Settings to populate Live TV.".to_owned(),
            last_sync: "Never".to_owned(),
            guide_health: "Unavailable".to_owned(),
        },
        browsing: LiveTvRuntimeBrowsingSnapshot {
            active_panel: "Channels".to_owned(),
            selected_group: "All".to_owned(),
            selected_channel: "No channel selected".to_owned(),
            group_order: vec![],
            groups: vec![],
        },
        channels: vec![],
        guide: LiveTvRuntimeGuideSnapshot {
            title: "Live TV Guide".to_owned(),
            window_start: "Now".to_owned(),
            window_end: "Later".to_owned(),
            time_slots: vec![],
            rows: vec![],
        },
        selection: LiveTvRuntimeSelectionSnapshot {
            channel_number: "none".to_owned(),
            channel_name: "No channel selected".to_owned(),
            status: "Idle".to_owned(),
            live_edge: false,
            catch_up: false,
            archive: false,
            now: LiveTvRuntimeProgramSnapshot {
                title: "No live program".to_owned(),
                summary: "Add a provider to hydrate live listings.".to_owned(),
                start: "Now".to_owned(),
                end: "Later".to_owned(),
                progress_percent: 0,
            },
            next: LiveTvRuntimeProgramSnapshot {
                title: "No upcoming program".to_owned(),
                summary: "Live runtime will populate after provider setup.".to_owned(),
                start: "Later".to_owned(),
                end: "Later".to_owned(),
                progress_percent: 0,
            },
            primary_action: "Add provider".to_owned(),
            secondary_action: "Open Settings".to_owned(),
            badges: vec!["Live".to_owned(), "Idle".to_owned()],
            detail_lines: vec!["No configured provider is currently ready for Live TV.".to_owned()],
        },
        notes: vec!["Rust-owned empty Live TV runtime for first-run state.".to_owned()],
    }
}

fn provider_error_live_tv_runtime(
    provider: &SourceProviderEntrySnapshot,
    summary: &str,
) -> LiveTvRuntimeSnapshot {
    LiveTvRuntimeSnapshot {
        title: "CrispyTivi Live TV Runtime".to_owned(),
        version: "1".to_owned(),
        provider: LiveTvRuntimeProviderSnapshot {
            provider_key: provider.provider_key.clone(),
            provider_type: provider.provider_type.clone(),
            family: provider.family.clone(),
            connection_mode: provider.connection_mode.clone(),
            source_name: provider.display_name.clone(),
            status: "Error".to_owned(),
            summary: summary.to_owned(),
            last_sync: provider.health.last_sync.clone(),
            guide_health: "Unavailable".to_owned(),
        },
        browsing: LiveTvRuntimeBrowsingSnapshot {
            active_panel: "Channels".to_owned(),
            selected_group: "All".to_owned(),
            selected_channel: "No channel selected".to_owned(),
            group_order: vec![],
            groups: vec![],
        },
        channels: vec![],
        guide: LiveTvRuntimeGuideSnapshot {
            title: "Live TV Guide".to_owned(),
            window_start: "Now".to_owned(),
            window_end: "Later".to_owned(),
            time_slots: vec![],
            rows: vec![],
        },
        selection: LiveTvRuntimeSelectionSnapshot {
            channel_number: "none".to_owned(),
            channel_name: "No channel selected".to_owned(),
            status: "Unavailable".to_owned(),
            live_edge: false,
            catch_up: false,
            archive: false,
            now: LiveTvRuntimeProgramSnapshot {
                title: "Live provider unavailable".to_owned(),
                summary: summary.to_owned(),
                start: "Now".to_owned(),
                end: "Later".to_owned(),
                progress_percent: 0,
            },
            next: LiveTvRuntimeProgramSnapshot {
                title: "Retry provider setup".to_owned(),
                summary: "Fix provider connectivity or credentials in Settings.".to_owned(),
                start: "Later".to_owned(),
                end: "Later".to_owned(),
                progress_percent: 0,
            },
            primary_action: "Edit provider".to_owned(),
            secondary_action: "Open Settings".to_owned(),
            badges: vec!["Live".to_owned(), "Error".to_owned()],
            detail_lines: vec![summary.to_owned()],
        },
        notes: vec![
            "Rust-owned provider error state for Live TV runtime.".to_owned(),
            "No scaffolded channels are emitted when configured-provider hydration fails."
                .to_owned(),
        ],
    }
}

fn demo_seeded_live_tv_runtime(provider: &SourceProviderEntrySnapshot) -> LiveTvRuntimeSnapshot {
    let mut seen_content_keys = HashSet::new();
    let providers = vec![provider];
    let channels = build_live_channels(&providers, &mut seen_content_keys);
    let selected_channel =
        channels
            .first()
            .cloned()
            .unwrap_or_else(|| LiveTvRuntimeChannelSnapshot {
                number: "101".to_owned(),
                name: fallback_live_channel_name(provider),
                group: fallback_live_group(provider),
                state: "ready".to_owned(),
                live_edge: provider.supports("live_tv"),
                catch_up: provider.supports("catch_up"),
                archive: provider.supports("catch_up"),
                playback_source: playback_source(
                    "live_channel",
                    &provider.provider_key,
                    &stable_content_key(
                        &provider.provider_key,
                        &provider.display_name,
                        Some("demo://live"),
                        &mut seen_content_keys,
                    ),
                    &provider.display_name,
                    "Watch live",
                ),
                playback_stream: playback_stream("demo://live", "hls", true, true, 0),
                current: LiveTvRuntimeProgramSnapshot {
                    title: format!("{} Live", provider.display_name),
                    summary: format!("Demo live program on {}", provider.display_name),
                    start: "21:00".to_owned(),
                    end: "22:00".to_owned(),
                    progress_percent: 54,
                },
                next: LiveTvRuntimeProgramSnapshot {
                    title: format!("{} Next", provider.display_name),
                    summary: format!("Demo next block on {}", provider.display_name),
                    start: "22:00".to_owned(),
                    end: "22:30".to_owned(),
                    progress_percent: 0,
                },
            });

    LiveTvRuntimeSnapshot {
        title: "CrispyTivi Live TV Runtime".to_owned(),
        version: "1".to_owned(),
        provider: LiveTvRuntimeProviderSnapshot {
            provider_key: provider.provider_key.clone(),
            provider_type: provider.provider_type.clone(),
            family: provider.family.clone(),
            connection_mode: provider.connection_mode.clone(),
            source_name: provider.display_name.clone(),
            status: provider.health.status.clone(),
            summary: provider.summary.clone(),
            last_sync: provider.health.last_sync.clone(),
            guide_health: if provider.supports("guide") {
                "Guide available".to_owned()
            } else {
                "Guide unavailable".to_owned()
            },
        },
        browsing: LiveTvRuntimeBrowsingSnapshot {
            active_panel: "Channels".to_owned(),
            selected_group: "All".to_owned(),
            selected_channel: format!("{} {}", selected_channel.number, selected_channel.name),
            group_order: vec!["All".to_owned()],
            groups: vec![group_snapshot(
                "all",
                "All",
                "Rust-owned demo live runtime.",
                channels.len() as u16,
                true,
            )],
        },
        channels,
        guide: build_guide_snapshot(&providers, &selected_channel.number),
        selection: build_live_selection(provider, &selected_channel),
        notes: vec![
            "Rust-owned demo seeded Live TV runtime.".to_owned(),
            "Explicit demo mode may use retained Rust fallback content.".to_owned(),
        ],
    }
}

fn empty_media_runtime() -> MediaRuntimeSnapshot {
    MediaRuntimeSnapshot {
        title: "CrispyTivi Media Runtime".to_owned(),
        version: "1".to_owned(),
        active_panel: "Movies".to_owned(),
        active_scope: "Featured".to_owned(),
        movie_hero: MediaRuntimeHeroSnapshot {
            kicker: "Movies".to_owned(),
            title: "Add a provider to unlock movies".to_owned(),
            summary: "Movie shelves stay empty until a configured provider exposes VOD.".to_owned(),
            primary_action: "Open Settings".to_owned(),
            secondary_action: "Add provider".to_owned(),
        },
        series_hero: MediaRuntimeHeroSnapshot {
            kicker: "Series".to_owned(),
            title: "Add a provider to unlock series".to_owned(),
            summary: "Series shelves stay empty until a configured provider exposes series."
                .to_owned(),
            primary_action: "Open Settings".to_owned(),
            secondary_action: "Add provider".to_owned(),
        },
        movie_collections: vec![],
        series_collections: vec![],
        series_detail: MediaRuntimeSeriesDetailSnapshot {
            summary_title: "Series details unavailable".to_owned(),
            summary_body: "Series detail will hydrate after provider setup.".to_owned(),
            handoff_label: "Browse series".to_owned(),
            seasons: vec![],
        },
        notes: vec!["Rust-owned empty Media runtime for first-run state.".to_owned()],
    }
}

fn provider_error_media_runtime(
    provider: &SourceProviderEntrySnapshot,
    summary: &str,
) -> MediaRuntimeSnapshot {
    MediaRuntimeSnapshot {
        title: "CrispyTivi Media Runtime".to_owned(),
        version: "1".to_owned(),
        active_panel: "Movies".to_owned(),
        active_scope: "Featured".to_owned(),
        movie_hero: MediaRuntimeHeroSnapshot {
            kicker: "Movies".to_owned(),
            title: format!("{} failed to load movies", provider.display_name),
            summary: summary.to_owned(),
            primary_action: "Edit provider".to_owned(),
            secondary_action: "Open Settings".to_owned(),
        },
        series_hero: MediaRuntimeHeroSnapshot {
            kicker: "Series".to_owned(),
            title: format!("{} failed to load series", provider.display_name),
            summary: summary.to_owned(),
            primary_action: "Edit provider".to_owned(),
            secondary_action: "Open Settings".to_owned(),
        },
        movie_collections: vec![],
        series_collections: vec![],
        series_detail: MediaRuntimeSeriesDetailSnapshot {
            summary_title: "Series details unavailable".to_owned(),
            summary_body: summary.to_owned(),
            handoff_label: "Browse series".to_owned(),
            seasons: vec![],
        },
        notes: vec![
            "Rust-owned provider error state for Media runtime.".to_owned(),
            summary.to_owned(),
            "No scaffolded movie or series shelves are emitted when provider hydration fails."
                .to_owned(),
        ],
    }
}

fn demo_seeded_media_runtime(provider: &SourceProviderEntrySnapshot) -> MediaRuntimeSnapshot {
    let mut seen_content_keys = HashSet::new();
    let movie_stream_uri = fallback_media_stream_uri(provider, "movies", 1, "m3u8");
    let series_stream_uri = fallback_media_stream_uri(provider, "series", 1, "m3u8");
    let movie_title = fallback_media_title(provider, "movie", 1);
    let series_title = fallback_media_title(provider, "series", 1);

    let movie_item = media_item(
        provider,
        &mut seen_content_keys,
        "movie",
        &movie_title,
        &fallback_media_caption(provider, "movie", 1),
        Some(1),
        &fallback_media_content_seed(provider, "movies"),
        &movie_stream_uri,
        0,
        "Play movie",
    );
    let series_item = media_item(
        provider,
        &mut seen_content_keys,
        "series",
        &series_title,
        &fallback_media_caption(provider, "series", 1),
        Some(1),
        &fallback_media_content_seed(provider, "series"),
        &series_stream_uri,
        0,
        "Browse series",
    );

    MediaRuntimeSnapshot {
        title: "CrispyTivi Media Runtime".to_owned(),
        version: "1".to_owned(),
        active_panel: "Movies".to_owned(),
        active_scope: "Featured".to_owned(),
        movie_hero: MediaRuntimeHeroSnapshot {
            kicker: "Featured film".to_owned(),
            title: fallback_media_hero_title(provider, "movie"),
            summary: format!(
                "Rust-owned demo movie runtime for {}.",
                provider.display_name
            ),
            primary_action: "Play movie".to_owned(),
            secondary_action: "Add to watchlist".to_owned(),
        },
        series_hero: MediaRuntimeHeroSnapshot {
            kicker: "Series spotlight".to_owned(),
            title: fallback_media_hero_title(provider, "series"),
            summary: format!(
                "Rust-owned demo series runtime for {}.",
                provider.display_name
            ),
            primary_action: "Browse series".to_owned(),
            secondary_action: "Open details".to_owned(),
        },
        movie_collections: vec![MediaRuntimeCollectionSnapshot {
            title: fallback_media_collection_title(provider, "movies"),
            summary: format!(
                "Rust-owned demo movie shelf from {}.",
                provider.display_name
            ),
            items: vec![movie_item],
        }],
        series_collections: vec![MediaRuntimeCollectionSnapshot {
            title: fallback_media_collection_title(provider, "series"),
            summary: format!(
                "Rust-owned demo series shelf from {}.",
                provider.display_name
            ),
            items: vec![series_item],
        }],
        series_detail: fallback_series_detail(provider, &mut seen_content_keys),
        notes: vec![
            "Rust-owned demo seeded Media runtime.".to_owned(),
            "Explicit demo mode may use retained Rust fallback shelves.".to_owned(),
        ],
    }
}

fn empty_search_runtime() -> SearchRuntimeSnapshot {
    SearchRuntimeSnapshot {
        title: "CrispyTivi Search Runtime".to_owned(),
        version: "1".to_owned(),
        query: String::new(),
        active_group_title: "All".to_owned(),
        groups: vec![],
        notes: vec!["Rust-owned empty Search runtime for first-run state.".to_owned()],
    }
}

#[cfg(test)]
mod runtime_tests {
    use super::*;
    use std::collections::HashMap;
    use std::fs;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::path::PathBuf;
    use std::thread;
    use std::time::{SystemTime, UNIX_EPOCH};
    use wiremock::{
        Mock, MockServer, ResponseTemplate,
        matchers::{method, path, query_param},
    };

    #[test]
    fn xtream_live_channel_mapping_keeps_real_url_and_archive_flags() {
        let provider = SourceProviderEntrySnapshot {
            provider_key: "xtream_demo".to_owned(),
            provider_type: "Xtream".to_owned(),
            display_name: "Xtream Demo".to_owned(),
            family: "portal".to_owned(),
            connection_mode: "portal_account".to_owned(),
            summary: "Runtime-backed xtream provider.".to_owned(),
            endpoint_label: "portal.example.test".to_owned(),
            capabilities: vec![],
            health: crate::source_runtime::SourceHealthSnapshot {
                status: "Healthy".to_owned(),
                summary: "Ready".to_owned(),
                last_checked: "now".to_owned(),
                last_sync: "now".to_owned(),
            },
            auth: crate::source_runtime::SourceAuthSnapshot {
                status: "Complete".to_owned(),
                progress: "100%".to_owned(),
                summary: "Ready".to_owned(),
                primary_action: "Review".to_owned(),
                secondary_action: "Back".to_owned(),
                field_labels: vec![],
                helper_lines: vec![],
            },
            import_details: crate::source_runtime::SourceImportDetailsSnapshot {
                status: "Ready".to_owned(),
                progress: "Ready".to_owned(),
                summary: "Ready".to_owned(),
                primary_action: "Run import".to_owned(),
                secondary_action: "Review".to_owned(),
            },
            onboarding_hint: "hint".to_owned(),
            runtime_config: std::collections::HashMap::new(),
        };
        let channel = XtreamChannel {
            num: Some(101),
            name: "Crispy One".to_owned(),
            stream_type: Some("live".to_owned()),
            stream_id: 101,
            stream_icon: None,
            thumbnail: None,
            epg_channel_id: Some("crispy.one".to_owned()),
            added: None,
            category_id: Some("news".to_owned()),
            category_ids: vec![],
            custom_sid: None,
            tv_archive: Some(1),
            direct_source: None,
            tv_archive_duration: Some(24),
            is_adult: false,
            url: Some("http://portal.example.test/live/demo/pass/101.ts".to_owned()),
        };

        let mapped = xtream_live_channel(&provider, &channel);

        assert_eq!(mapped.number, "101");
        assert_eq!(mapped.name, "Crispy One");
        assert_eq!(
            mapped.playback_stream.uri,
            "http://portal.example.test/live/demo/pass/101.ts"
        );
        assert!(mapped.catch_up);
        assert!(mapped.archive);
        assert_eq!(mapped.playback_source.source_key, "xtream_demo");
    }

    #[test]
    fn xtream_live_runtime_uses_short_epg_for_selected_channel() {
        let server_url = spawn_xtream_test_server(true);
        let registry = xtream_only_registry(&server_url);

        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());

        assert_eq!(runtime.provider.provider_type, "Xtream");
        assert_eq!(runtime.selection.now.title, "Morning News");
        assert_eq!(runtime.selection.next.title, "Market Hour");
        assert_eq!(runtime.guide.rows[0].slots[0].title, "Morning News");
        assert_eq!(runtime.guide.rows[0].slots[0].start, "08:00");
        assert_eq!(runtime.guide.rows[0].slots[1].title, "Market Hour");
        assert_eq!(runtime.guide.rows[0].slots[1].end, "10:00");
    }

    #[test]
    fn xtream_live_runtime_falls_back_when_short_epg_fails() {
        let server_url = spawn_xtream_test_server(false);
        let registry = xtream_only_registry(&server_url);

        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());

        assert_eq!(runtime.provider.provider_type, "Xtream");
        assert_eq!(runtime.selection.now.title, "Portal One live");
        assert_eq!(runtime.selection.next.title, "Next on Portal One");
        assert_eq!(runtime.guide.rows[0].slots[0].title, "Portal One live");
    }

    #[test]
    fn local_m3u_live_runtime_hydrates_from_playlist_file() {
        let playlist_path = write_test_playlist(
            "#EXTM3U\n\
             #EXTINF:-1 tvg-id=\"news-1\" tvg-chno=\"101\" group-title=\"News\",Morning News\n\
             http://example.com/news.m3u8\n\
             #EXTINF:-1 tvg-id=\"movie-1\" tvg-chno=\"102\" group-title=\"Movies\",Late Feature\n\
             http://example.com/feature.ts\n",
        );
        let registry = local_m3u_registry(&playlist_path);

        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());

        assert_eq!(runtime.provider.provider_type, "local M3U");
        assert_eq!(runtime.channels.len(), 2);
        assert_eq!(runtime.channels[0].number, "101");
        assert_eq!(runtime.channels[0].name, "Morning News");
        assert_eq!(runtime.channels[0].group, "News");
        assert_eq!(
            runtime.channels[0].playback_stream.uri,
            "http://example.com/news.m3u8"
        );
        assert_eq!(runtime.selection.now.title, "Morning News live");
        assert_eq!(runtime.guide.rows[0].slots[0].title, "Morning News live");
    }

    #[test]
    fn local_m3u_live_runtime_hydrates_guide_from_xmltv_file() {
        let playlist_path = write_test_playlist(
            "#EXTM3U\n\
             #EXTINF:-1 tvg-id=\"news-1\" tvg-chno=\"101\" group-title=\"News\",Morning News\n\
             http://example.com/news.m3u8\n",
        );
        let xmltv_path = write_test_xmltv(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
             <tv>\n\
               <channel id=\"news-1\"><display-name>Morning News</display-name></channel>\n\
               <programme start=\"20250115120000 +0000\" stop=\"20250115130000 +0000\" channel=\"news-1\">\n\
                 <title>Lunch Bulletin</title><desc>Top stories at noon.</desc>\n\
               </programme>\n\
               <programme start=\"20250115130000 +0000\" stop=\"20250115140000 +0000\" channel=\"news-1\">\n\
                 <title>Markets Live</title><desc>Business and finance coverage.</desc>\n\
               </programme>\n\
             </tv>\n",
        );
        let mut registry = local_m3u_registry(&playlist_path);
        registry.configured_providers[0]
            .runtime_config
            .insert("xmltv_file".to_owned(), xmltv_path);

        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());

        assert_eq!(runtime.provider.provider_type, "local M3U");
        assert_eq!(runtime.provider.guide_health, "Guide hydrated from XMLTV");
        assert_eq!(runtime.selection.now.title, "Lunch Bulletin");
        assert_eq!(runtime.selection.next.title, "Markets Live");
        assert_eq!(runtime.guide.rows[0].slots[0].title, "Lunch Bulletin");
        assert_eq!(runtime.guide.rows[0].slots[1].title, "Markets Live");
    }

    #[test]
    fn local_m3u_live_runtime_exposes_archive_source_option_from_catchup() {
        let playlist_path = write_test_playlist(
            "#EXTM3U catchup=\"default\"\n\
             #EXTINF:-1 tvg-id=\"news-1\" tvg-chno=\"101\" catchup=\"append\" catchup-source=\"?utc={utc}&lutc={lutc}\" catchup-days=\"3\",Morning News\n\
             http://example.com/news.m3u8\n",
        );
        let registry = local_m3u_registry(&playlist_path);

        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());
        let archive = runtime.channels[0]
            .playback_stream
            .source_options
            .iter()
            .find(|option| option.id == "archive")
            .expect("archive source option should exist");

        assert_eq!(archive.label, "Archive");
        assert_ne!(archive.uri, runtime.channels[0].playback_stream.uri);
        assert!(archive.seekable);
        assert!(!archive.live);
    }

    #[test]
    fn m3u_url_live_runtime_hydrates_from_playlist_url() {
        let playlist_path = write_test_playlist(
            "#EXTM3U\n\
             #EXTINF:-1 tvg-id=\"news-1\" tvg-chno=\"101\" group-title=\"News\",Morning News\n\
             http://example.com/news.m3u8\n\
             #EXTINF:-1 tvg-id=\"movie-1\" tvg-chno=\"102\" group-title=\"Movies\",Late Feature\n\
             http://example.com/feature.ts\n",
        );
        let registry = m3u_url_registry(&format!("file://{playlist_path}"));

        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());

        assert_eq!(runtime.provider.provider_type, "M3U URL");
        assert_eq!(runtime.channels.len(), 2);
        assert_eq!(runtime.channels[0].number, "101");
        assert_eq!(runtime.channels[0].name, "Morning News");
        assert_eq!(runtime.channels[0].group, "News");
        assert_eq!(
            runtime.channels[0].playback_stream.uri,
            "http://example.com/news.m3u8"
        );
        assert_eq!(runtime.selection.now.title, "Morning News live");
        assert_eq!(runtime.guide.rows[0].slots[0].title, "Morning News live");
    }

    #[test]
    fn m3u_url_live_runtime_hydrates_guide_from_xmltv_url() {
        let playlist_path = write_test_playlist(
            "#EXTM3U\n\
             #EXTINF:-1 tvg-id=\"news-1\" tvg-chno=\"101\" group-title=\"News\",Morning News\n\
             http://example.com/news.m3u8\n",
        );
        let xmltv_path = write_test_xmltv(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
             <tv>\n\
               <channel id=\"news-1\"><display-name>Morning News</display-name></channel>\n\
               <programme start=\"20250115120000 +0000\" stop=\"20250115130000 +0000\" channel=\"news-1\">\n\
                 <title>Lunch Bulletin</title><desc>Top stories at noon.</desc>\n\
               </programme>\n\
             </tv>\n",
        );
        let mut registry = m3u_url_registry(&format!("file://{playlist_path}"));
        registry.configured_providers[0]
            .runtime_config
            .insert("xmltv_url".to_owned(), format!("file://{xmltv_path}"));

        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());

        assert_eq!(runtime.provider.provider_type, "M3U URL");
        assert_eq!(runtime.provider.guide_health, "Guide hydrated from XMLTV");
        assert_eq!(runtime.selection.now.title, "Lunch Bulletin");
        assert_eq!(runtime.guide.rows[0].slots[0].title, "Lunch Bulletin");
    }

    #[test]
    fn local_m3u_live_runtime_returns_provider_error_when_playlist_file_is_missing() {
        let playlist_path = missing_test_playlist_path();
        let mut registry = local_m3u_registry(&playlist_path);
        registry.registry_notes.clear();

        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());

        assert_eq!(runtime.provider.provider_type, "local M3U");
        assert_eq!(runtime.provider.source_name, "Local Archive");
        assert_eq!(runtime.provider.status, "Error");
        assert!(runtime.channels.is_empty());
        assert_eq!(runtime.selection.channel_name, "No channel selected");
    }

    #[tokio::test]
    async fn stalker_live_runtime_uses_shared_client_when_credentials_are_present() {
        let server = MockServer::start().await;
        mount_stalker_auth(&server).await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "itv"))
            .and(query_param("action", "get_genres"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": [
                    {"id": "1", "title": "News", "censored": "0"}
                ]
            })))
            .mount(&server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "itv"))
            .and(query_param("action", "get_ordered_list"))
            .and(query_param("genre", "1"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": {
                    "total_items": "1",
                    "max_page_items": "10",
                    "data": [{
                        "id": "55",
                        "name": "Stalker News",
                        "number": "55",
                        "cmd": "ffrt http://stream.example.com/stalker-news.ts",
                        "tv_genre_id": "1",
                        "tv_archive": "1",
                        "tv_archive_duration": "3",
                        "censored": "0"
                    }]
                }
            })))
            .mount(&server)
            .await;

        let provider = stalker_provider(&server.uri());
        let runtime = fetch_stalker_live_tv_runtime(&provider)
            .await
            .expect("stalker runtime fetch should succeed")
            .expect("stalker runtime should be present");

        assert_eq!(runtime.provider.provider_type, "Stalker");
        assert_eq!(runtime.channels.len(), 1);
        assert_eq!(runtime.channels[0].name, "Stalker News");
        assert_eq!(
            runtime.channels[0].playback_stream.uri,
            "http://stream.example.com/stalker-news.ts"
        );
    }

    #[tokio::test]
    async fn stalker_media_runtime_uses_shared_client_when_credentials_are_present() {
        let server = MockServer::start().await;
        mount_stalker_auth(&server).await;
        mount_stalker_media(&server).await;

        let provider = stalker_provider(&server.uri());
        let runtime = fetch_stalker_media_runtime(&provider)
            .await
            .expect("stalker media runtime fetch should succeed")
            .expect("stalker media runtime should be present");

        assert_eq!(runtime.movie_collections.len(), 1);
        assert_eq!(runtime.movie_collections[0].items[0].title, "Stalker Movie");
        assert_eq!(
            runtime.movie_collections[0].items[0].playback_stream.uri,
            "http://stream.example.com/stalker-movie.mp4"
        );
        assert_eq!(runtime.series_collections.len(), 1);
        assert_eq!(
            runtime.series_collections[0].items[0].title,
            "Stalker Series"
        );
        assert_eq!(runtime.series_detail.seasons.len(), 1);
        assert_eq!(runtime.series_detail.seasons[0].episodes[0].title, "Pilot");
        assert_eq!(
            runtime.series_detail.seasons[0].episodes[0]
                .playback_stream
                .uri,
            "http://stream.example.com/stalker-series-s1e1.mp4"
        );
    }

    #[test]
    fn xtream_media_runtime_falls_back_to_category_fetch_when_unfiltered_lists_fail() {
        let registry = xtream_only_registry(&spawn_xtream_media_category_fallback_test_server());
        let runtime = build_media_runtime(&registry, registry.configured_providers.first());

        assert_eq!(
            runtime.movie_collections[0].items[0].title,
            "State of Fear (2026)"
        );
        assert_eq!(
            runtime.series_collections[0].items[0].title,
            "صحاب الأرض (2026)"
        );
        assert_eq!(
            runtime.series_detail.seasons[0].episodes[0].title,
            "Episode 1"
        );
    }

    #[test]
    fn media_runtime_returns_provider_error_for_unknown_provider_runtime() {
        let mut registry = crate::source_runtime::seeded_source_registry_snapshot();
        registry.registry_notes.clear();
        let mut provider = registry
            .configured_providers
            .first()
            .cloned()
            .expect("seeded registry should contain providers");
        provider.provider_type = "Custom".to_owned();
        provider.display_name = "Portal Demo".to_owned();
        provider.endpoint_label = "portal.example.test/library".to_owned();
        provider.runtime_config = HashMap::from([(
            "media_stream_base_url".to_owned(),
            "http://portal.example.test/library".to_owned(),
        )]);
        registry.configured_providers = vec![provider];

        let runtime = build_media_runtime(&registry, registry.configured_providers.first());

        assert!(runtime.movie_collections.is_empty());
        assert!(runtime.series_collections.is_empty());
        assert_eq!(
            runtime.movie_hero.title,
            "Portal Demo failed to load movies"
        );
        assert_eq!(
            runtime.series_hero.title,
            "Portal Demo failed to load series"
        );
        assert!(runtime.notes.iter().any(|item| item.contains("failed")));
    }

    #[test]
    fn stalker_live_runtime_returns_provider_error_when_fetch_fails() {
        let registry = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("test runtime should initialize")
            .block_on(async {
                let server = MockServer::start().await;
                mount_stalker_auth(&server).await;
                Mock::given(method("GET"))
                    .and(path("/c/"))
                    .and(query_param("type", "itv"))
                    .and(query_param("action", "get_genres"))
                    .respond_with(ResponseTemplate::new(500))
                    .mount(&server)
                    .await;

                let provider = stalker_provider(&server.uri());
                SourceRegistrySnapshot {
                    title: "Source registry".to_owned(),
                    version: "1".to_owned(),
                    provider_types: vec![provider.clone()],
                    configured_providers: vec![provider],
                    onboarding: super::super::source_registry::SourceOnboardingSnapshot {
                        selected_provider_kind: "Stalker".to_owned(),
                        active_wizard_step: "Source Type".to_owned(),
                        wizard_active: false,
                        wizard_mode: "idle".to_owned(),
                        selected_source_index: 0,
                        field_values: std::collections::HashMap::new(),
                        step_order: vec![],
                        steps: vec![],
                        provider_copy: vec![],
                    },
                    registry_notes: vec![],
                }
            });
        let runtime = build_live_tv_runtime(&registry, registry.configured_providers.first());

        assert_eq!(runtime.provider.provider_type, "Stalker");
        assert_eq!(runtime.provider.status, "Error");
        assert!(runtime.channels.is_empty());
        assert_eq!(runtime.selection.channel_name, "No channel selected");
    }

    #[test]
    fn stalker_media_runtime_returns_provider_error_when_fetch_fails() {
        let registry = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("test runtime should initialize")
            .block_on(async {
                let server = MockServer::start().await;
                mount_stalker_auth(&server).await;
                Mock::given(method("GET"))
                    .and(path("/c/"))
                    .and(query_param("type", "vod"))
                    .and(query_param("action", "get_categories"))
                    .respond_with(ResponseTemplate::new(500))
                    .mount(&server)
                    .await;

                let provider = stalker_provider(&server.uri());
                SourceRegistrySnapshot {
                    title: "Source registry".to_owned(),
                    version: "1".to_owned(),
                    provider_types: vec![provider.clone()],
                    configured_providers: vec![provider],
                    onboarding: super::super::source_registry::SourceOnboardingSnapshot {
                        selected_provider_kind: "Stalker".to_owned(),
                        active_wizard_step: "Source Type".to_owned(),
                        wizard_active: false,
                        wizard_mode: "idle".to_owned(),
                        selected_source_index: 0,
                        field_values: std::collections::HashMap::new(),
                        step_order: vec![],
                        steps: vec![],
                        provider_copy: vec![],
                    },
                    registry_notes: vec![],
                }
            });
        let runtime = build_media_runtime(&registry, registry.configured_providers.first());

        assert!(runtime.movie_collections.is_empty());
        assert!(runtime.series_collections.is_empty());
        assert_eq!(
            runtime.movie_hero.title,
            "Stalker Demo failed to load movies"
        );
        assert_eq!(
            runtime.series_hero.title,
            "Stalker Demo failed to load series"
        );
    }

    #[test]
    fn search_runtime_stays_empty_when_content_groups_are_empty() {
        let mut registry =
            crate::source_runtime::source_registry::seeded_source_registry_snapshot();
        for provider in &mut registry.configured_providers {
            provider.health.status = "Needs auth".to_owned();
            provider.auth.status = "Needs auth".to_owned();
            provider.import_details.status = "Blocked".to_owned();
        }
        let live_tv = empty_live_tv_runtime();
        let media = empty_media_runtime();

        let runtime = build_search_runtime(&registry, &live_tv, &media);

        assert_eq!(runtime.active_group_title, "All");
        assert!(runtime.groups.is_empty());
    }

    async fn mount_stalker_auth(server: &MockServer) {
        Mock::given(method("GET"))
            .and(path("/c/"))
            .respond_with(ResponseTemplate::new(200).set_body_string("OK"))
            .up_to_n_times(1)
            .mount(server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("action", "handshake"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": { "token": "tk" }
            })))
            .mount(server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "stb"))
            .and(query_param("action", "do_auth"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": true
            })))
            .mount(server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "stb"))
            .and(query_param("action", "get_profile"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": { "token": "tk", "timezone": "Europe/Paris", "locale": "en" }
            })))
            .mount(server)
            .await;
    }

    async fn mount_stalker_media(server: &MockServer) {
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "vod"))
            .and(query_param("action", "get_categories"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": [
                    {"id": "10", "title": "Movies", "censored": "0"}
                ]
            })))
            .mount(server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "series"))
            .and(query_param("action", "get_categories"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": [
                    {"id": "20", "title": "Series", "censored": "0"}
                ]
            })))
            .mount(server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "vod"))
            .and(query_param("action", "get_ordered_list"))
            .and(query_param("category", "10"))
            .and(query_param("p", "1"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": {
                    "total_items": "1",
                    "max_page_items": "10",
                    "data": [{
                        "id": "v1",
                        "name": "Stalker Movie",
                        "cmd": "ffrt http://stream.example.com/stalker-movie.mp4",
                        "is_series": "0",
                        "category_id": "10",
                        "genre": "Thriller",
                        "description": "Movie from Stalker"
                    }]
                }
            })))
            .mount(server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "vod"))
            .and(query_param("action", "get_ordered_list"))
            .and(query_param("category", "20"))
            .and(query_param("p", "1"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": {
                    "total_items": "1",
                    "max_page_items": "10",
                    "data": [{
                        "id": "s1",
                        "name": "Stalker Series",
                        "is_series": "1",
                        "category_id": "20",
                        "genre": "Sci-fi",
                        "description": "Series from Stalker"
                    }]
                }
            })))
            .mount(server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "vod"))
            .and(query_param("action", "get_ordered_list"))
            .and(query_param("movie_id", "s1"))
            .and(query_param("season_id", "0"))
            .and(query_param("episode_id", "0"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": {
                    "data": [{
                        "id": "season-1",
                        "name": "Season 1",
                        "video_id": "s1",
                        "is_season": "1",
                        "description": "First season"
                    }]
                }
            })))
            .mount(server)
            .await;
        Mock::given(method("GET"))
            .and(path("/c/"))
            .and(query_param("type", "vod"))
            .and(query_param("action", "get_ordered_list"))
            .and(query_param("movie_id", "s1"))
            .and(query_param("season_id", "season-1"))
            .and(query_param("episode_id", "0"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "js": {
                    "data": [{
                        "id": "episode-1",
                        "name": "Pilot",
                        "cmd": "ffrt http://stream.example.com/stalker-series-s1e1.mp4",
                        "series_number": "1",
                        "description": "Pilot episode",
                        "time": "45 min"
                    }]
                }
            })))
            .mount(server)
            .await;
    }

    fn stalker_provider(base_url: &str) -> SourceProviderEntrySnapshot {
        let mut runtime_config = std::collections::HashMap::new();
        runtime_config.insert("portal_url".to_owned(), base_url.to_owned());
        runtime_config.insert("mac_address".to_owned(), "00:1A:79:AB:CD:EF".to_owned());
        SourceProviderEntrySnapshot {
            provider_key: "stalker_demo".to_owned(),
            provider_type: "Stalker".to_owned(),
            display_name: "Stalker Demo".to_owned(),
            family: "portal".to_owned(),
            connection_mode: "portal_mac".to_owned(),
            summary: "Runtime-backed stalker provider.".to_owned(),
            endpoint_label: base_url.to_owned(),
            capabilities: vec![
                crate::source_runtime::SourceCapabilitySnapshot {
                    id: "live_tv".to_owned(),
                    title: "Live TV".to_owned(),
                    summary: "Live".to_owned(),
                    supported: true,
                },
                crate::source_runtime::SourceCapabilitySnapshot {
                    id: "guide".to_owned(),
                    title: "Guide".to_owned(),
                    summary: "Guide".to_owned(),
                    supported: true,
                },
            ],
            health: crate::source_runtime::SourceHealthSnapshot {
                status: "Healthy".to_owned(),
                summary: "Ready".to_owned(),
                last_checked: "now".to_owned(),
                last_sync: "now".to_owned(),
            },
            auth: crate::source_runtime::SourceAuthSnapshot {
                status: "Complete".to_owned(),
                progress: "100%".to_owned(),
                summary: "Ready".to_owned(),
                primary_action: "Review".to_owned(),
                secondary_action: "Back".to_owned(),
                field_labels: vec![],
                helper_lines: vec![],
            },
            import_details: crate::source_runtime::SourceImportDetailsSnapshot {
                status: "Ready".to_owned(),
                progress: "Ready".to_owned(),
                summary: "Ready".to_owned(),
                primary_action: "Run import".to_owned(),
                secondary_action: "Review".to_owned(),
            },
            onboarding_hint: "hint".to_owned(),
            runtime_config,
        }
    }

    fn local_m3u_registry(playlist_path: &str) -> crate::source_runtime::SourceRegistrySnapshot {
        let mut registry =
            crate::source_runtime::source_registry::seeded_source_registry_snapshot();
        registry.configured_providers = registry
            .configured_providers
            .into_iter()
            .filter_map(|mut provider| {
                if provider.provider_type == "local M3U" {
                    provider.runtime_config =
                        HashMap::from([("playlist_file".to_owned(), playlist_path.to_owned())]);
                    Some(provider)
                } else {
                    None
                }
            })
            .collect();
        registry
    }

    fn m3u_url_registry(playlist_url: &str) -> crate::source_runtime::SourceRegistrySnapshot {
        let mut registry =
            crate::source_runtime::source_registry::seeded_source_registry_snapshot();
        registry.configured_providers = registry
            .configured_providers
            .into_iter()
            .filter_map(|mut provider| {
                if provider.provider_type == "M3U URL" {
                    provider.runtime_config =
                        HashMap::from([("playlist_url".to_owned(), playlist_url.to_owned())]);
                    Some(provider)
                } else {
                    None
                }
            })
            .collect();
        registry
    }

    fn write_test_playlist(content: &str) -> String {
        let path = unique_test_path("crispy_m3u_test", "m3u");
        fs::write(&path, content).expect("playlist should write");
        path.to_string_lossy().into_owned()
    }

    fn write_test_xmltv(content: &str) -> String {
        let path = unique_test_path("crispy_xmltv_test", "xml");
        fs::write(&path, content).expect("xmltv should write");
        path.to_string_lossy().into_owned()
    }

    fn missing_test_playlist_path() -> String {
        unique_test_path("crispy_m3u_missing", "m3u")
            .to_string_lossy()
            .into_owned()
    }

    fn unique_test_path(prefix: &str, extension: &str) -> PathBuf {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time should be valid")
            .as_nanos();
        std::env::temp_dir().join(format!("{prefix}_{stamp}.{extension}"))
    }

    fn xtream_only_registry(server_url: &str) -> crate::source_runtime::SourceRegistrySnapshot {
        let mut registry =
            crate::source_runtime::source_registry::seeded_source_registry_snapshot();
        registry.configured_providers = registry
            .configured_providers
            .into_iter()
            .filter_map(|mut provider| {
                if provider.provider_type == "Xtream" {
                    provider.runtime_config = HashMap::from([
                        ("server_url".to_owned(), server_url.to_owned()),
                        ("username".to_owned(), "demo_user".to_owned()),
                        ("password".to_owned(), "demo_pass".to_owned()),
                        ("guide_mode".to_owned(), "epg".to_owned()),
                    ]);
                    Some(provider)
                } else {
                    None
                }
            })
            .collect();
        registry
    }

    fn spawn_xtream_test_server(short_epg_ok: bool) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").expect("test server should bind");
        let server_url = format!(
            "http://{}",
            listener.local_addr().expect("local addr should exist")
        );

        thread::spawn(move || {
            for _ in 0..6 {
                let (mut stream, _) = listener.accept().expect("server should accept");
                let mut request = vec![0_u8; 8192];
                let len = stream.read(&mut request).expect("request should read");
                let request = String::from_utf8_lossy(&request[..len]);
                let response_body = if request.contains("action=get_profile") {
                    r#"{
                        "user_info": {
                            "username": "demo_user",
                            "password": "demo_pass",
                            "message": "",
                            "auth": 1,
                            "status": "Active",
                            "allowed_output_formats": ["m3u8"]
                        },
                        "server_info": {
                            "url": "portal.example.test"
                        }
                    }"#
                } else if request.contains("action=get_live_streams") {
                    r#"[
                        {
                            "num": 7,
                            "name": "Portal One",
                            "stream_id": 101,
                            "category_id": "News",
                            "tv_archive": 1,
                            "direct_source": "",
                            "url": "http://portal.example.test/live/demo_user/demo_pass/101.ts"
                        },
                        {
                            "num": 8,
                            "name": "Portal Two",
                            "stream_id": 102,
                            "category_id": "Sports",
                            "tv_archive": 0,
                            "direct_source": "",
                            "url": "http://portal.example.test/live/demo_user/demo_pass/102.ts"
                        }
                    ]"#
                } else if request.contains("action=get_short_epg") {
                    if short_epg_ok {
                        r#"{
                            "epg_listings": [
                                {
                                    "title": "Morning News",
                                    "description": "Top stories",
                                    "start": "08:00",
                                    "end": "09:00",
                                    "channel_id": "crispy.one"
                                },
                                {
                                    "title": "Market Hour",
                                    "description": "Stocks and finance",
                                    "start": "09:00",
                                    "end": "10:00",
                                    "channel_id": "crispy.one"
                                }
                            ]
                        }"#
                    } else {
                        "epg error"
                    }
                } else {
                    panic!("unexpected request: {request}");
                };
                let status_line = if request.contains("action=get_short_epg") && !short_epg_ok {
                    "HTTP/1.1 500 Internal Server Error"
                } else {
                    "HTTP/1.1 200 OK"
                };
                let response = format!(
                    "{status_line}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                    response_body.len(),
                    response_body
                );
                stream
                    .write_all(response.as_bytes())
                    .expect("response should write");
            }
        });

        server_url
    }

    fn spawn_xtream_media_category_fallback_test_server() -> String {
        let listener = TcpListener::bind("127.0.0.1:0").expect("test server should bind");
        let server_url = format!(
            "http://{}",
            listener.local_addr().expect("local addr should exist")
        );

        thread::spawn(move || {
            for _ in 0..8 {
                let (mut stream, _) = listener.accept().expect("server should accept");
                let mut request = vec![0_u8; 8192];
                let len = stream.read(&mut request).expect("request should read");
                let request = String::from_utf8_lossy(&request[..len]);
                let (status_line, response_body) = if request.contains("action=get_profile") {
                    (
                        "HTTP/1.1 200 OK",
                        r#"{
                        "user_info": {
                            "username": "demo_user",
                            "password": "demo_pass",
                            "message": "",
                            "auth": 1,
                            "status": "Active",
                            "allowed_output_formats": ["m3u8"]
                        },
                        "server_info": {
                            "url": "portal.example.test"
                        }
                    }"#,
                    )
                } else if request.contains("action=get_vod_streams")
                    && request.contains("category_id=461")
                {
                    (
                        "HTTP/1.1 200 OK",
                        r#"[
                        {
                            "num": 1,
                            "name": "State of Fear (2026)",
                            "stream_id": 9001,
                            "container_extension": "mp4",
                            "genre": "Thriller"
                        }
                    ]"#,
                    )
                } else if request.contains("action=get_vod_streams") {
                    ("HTTP/1.1 500 Internal Server Error", "vod list failed")
                } else if request.contains("action=get_vod_categories") {
                    (
                        "HTTP/1.1 200 OK",
                        r#"[
                        {"category_id": "461", "category_name": "TOP MOVIES"}
                    ]"#,
                    )
                } else if request.contains("action=get_series")
                    && !request.contains("action=get_series_categories")
                    && request.contains("category_id=490")
                {
                    (
                        "HTTP/1.1 200 OK",
                        r#"[
                        {
                            "num": 1,
                            "name": "صحاب الأرض (2026)",
                            "series_id": 7001,
                            "genre": "Drama"
                        }
                    ]"#,
                    )
                } else if request.contains("action=get_series")
                    && !request.contains("action=get_series_categories")
                    && !request.contains("action=get_series_info")
                {
                    ("HTTP/1.1 500 Internal Server Error", "series list failed")
                } else if request.contains("action=get_series_categories") {
                    (
                        "HTTP/1.1 200 OK",
                        r#"[
                        {"category_id": "490", "category_name": "Ramadan 2026"}
                    ]"#,
                    )
                } else if request.contains("action=get_series_info")
                    && request.contains("series_id=7001")
                {
                    (
                        "HTTP/1.1 200 OK",
                        r#"{
                        "info": {
                            "name": "صحاب الأرض (2026)",
                            "plot": "Portal-backed real series detail."
                        },
                        "seasons": [
                            {
                                "season_number": 1,
                                "name": "Season 1",
                                "overview": "Entry season"
                            }
                        ],
                        "episodes": {
                            "1": [
                                {
                                    "id": 7101,
                                    "title": "Episode 1",
                                    "container_extension": "m3u8",
                                    "info": {
                                        "plot": "Episode detail",
                                        "duration": "44 min"
                                    }
                                }
                            ]
                        }
                    }"#,
                    )
                } else {
                    panic!("unexpected request: {request}");
                };
                let response = format!(
                    "{status_line}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                    response_body.len(),
                    response_body
                );
                stream
                    .write_all(response.as_bytes())
                    .expect("response should write");
            }
        });

        server_url
    }
}
