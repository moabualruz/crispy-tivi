use serde::{Deserialize, Serialize};

use crate::source_runtime::HydratedRuntimeSnapshot;
use crate::{PlaybackStreamSnapshot, PlaybackTrackOptionSnapshot, PlaybackVariantOptionSnapshot};

#[cfg(not(target_arch = "wasm32"))]
use crispy_catchup::provider::{generate_flussonic_source, generate_xtream_codes_source};

#[cfg(test)]
mod tests;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlaybackChooserOptionSnapshot {
    pub id: String,
    pub label: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlaybackChooserGroupSnapshot {
    pub kind: String,
    pub title: String,
    pub options: Vec<PlaybackChooserOptionSnapshot>,
    pub selected_index: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlaybackSessionRuntimeSnapshot {
    pub playback_uri: String,
    pub catchup_playback_uri: Option<String>,
    pub chooser_groups: Vec<PlaybackChooserGroupSnapshot>,
    pub selected_source_option: Option<PlaybackVariantOptionSnapshot>,
    pub selected_quality_option: Option<PlaybackVariantOptionSnapshot>,
    pub selected_audio_option: Option<PlaybackTrackOptionSnapshot>,
    pub selected_subtitle_option: Option<PlaybackTrackOptionSnapshot>,
}

pub fn playback_snapshot_from_runtime(runtime: &HydratedRuntimeSnapshot) -> PlaybackStreamSnapshot {
    if let Some(selected_live_stream) = selected_live_playback_stream(runtime) {
        return selected_live_stream;
    }

    runtime
        .media
        .movie_collections
        .iter()
        .flat_map(|collection| collection.items.iter())
        .map(|item| item.playback_stream.clone())
        .next()
        .or_else(|| {
            runtime
                .media
                .series_collections
                .iter()
                .flat_map(|collection| collection.items.iter())
                .map(|item| item.playback_stream.clone())
                .next()
        })
        .or_else(|| {
            runtime
                .live_tv
                .channels
                .iter()
                .map(|channel| channel.playback_stream.clone())
                .next()
        })
        .unwrap_or_else(empty_playback_stream)
}

fn selected_live_playback_stream(
    runtime: &HydratedRuntimeSnapshot,
) -> Option<PlaybackStreamSnapshot> {
    let selected_channel_number = runtime.live_tv.selection.channel_number.trim();
    if selected_channel_number.is_empty() {
        return None;
    }

    runtime
        .live_tv
        .channels
        .iter()
        .find(|channel| channel.number == selected_channel_number)
        .map(|channel| channel.playback_stream.clone())
}

pub fn playback_runtime_json_from_runtime(runtime: &HydratedRuntimeSnapshot) -> String {
    serde_json::to_string_pretty(&playback_snapshot_from_runtime(runtime))
        .expect("playback runtime serialization should succeed")
}

pub fn playback_runtime_json_from_source_registry_json(
    source_registry_json: Option<&str>,
) -> Result<String, String> {
    let source_registry = match source_registry_json {
        Some(json) if !json.trim().is_empty() => serde_json::from_str(json).map_err(|error| {
            format!("playback runtime source registry JSON parse failed: {error}")
        })?,
        _ => crate::source_runtime::source_registry_snapshot(),
    };
    let bundle =
        crate::source_runtime::runtime_bundle_snapshot_from_source_registry(source_registry);
    Ok(playback_runtime_json_from_runtime(&bundle.runtime))
}

pub fn playback_session_runtime_json_from_stream_json(
    playback_stream_json: &str,
    source_index: Option<i32>,
    quality_index: Option<i32>,
    audio_index: Option<i32>,
    subtitle_index: Option<i32>,
) -> Result<String, String> {
    let stream: PlaybackStreamSnapshot = serde_json::from_str(playback_stream_json)
        .map_err(|error| format!("playback runtime stream JSON parse failed: {error}"))?;
    let snapshot = playback_session_runtime_from_stream(
        &stream,
        source_index,
        quality_index,
        audio_index,
        subtitle_index,
    );
    serde_json::to_string_pretty(&snapshot)
        .map_err(|error| format!("playback runtime session serialization failed: {error}"))
}

fn playback_session_runtime_from_stream(
    stream: &PlaybackStreamSnapshot,
    source_index: Option<i32>,
    quality_index: Option<i32>,
    audio_index: Option<i32>,
    subtitle_index: Option<i32>,
) -> PlaybackSessionRuntimeSnapshot {
    let selected_source_index = clamp_index(source_index, stream.source_options.len());
    let selected_quality_index = clamp_index(quality_index, stream.quality_options.len());
    let selected_audio_index = clamp_index(audio_index, stream.audio_options.len());
    let selected_subtitle_index = clamp_index(subtitle_index, stream.subtitle_options.len());

    let selected_source_option =
        select_variant_option(&stream.source_options, selected_source_index);
    let selected_quality_option =
        select_variant_option(&stream.quality_options, selected_quality_index);
    let selected_audio_option = select_track_option(&stream.audio_options, selected_audio_index);
    let selected_subtitle_option =
        select_track_option(&stream.subtitle_options, selected_subtitle_index);
    let catchup_playback_uri = derive_catchup_playback_uri(stream);

    PlaybackSessionRuntimeSnapshot {
        playback_uri: selected_quality_option
            .as_ref()
            .and_then(|option| (!option.uri.is_empty()).then_some(option.uri.clone()))
            .or_else(|| {
                selected_source_option
                    .as_ref()
                    .and_then(|option| (!option.uri.is_empty()).then_some(option.uri.clone()))
            })
            .unwrap_or_else(|| stream.uri.clone()),
        chooser_groups: vec![
            playback_group_from_variants(
                "source",
                "Source",
                &stream.source_options,
                selected_source_index,
                "Primary source",
            ),
            playback_group_from_variants(
                "quality",
                "Quality",
                &stream.quality_options,
                selected_quality_index,
                "Auto",
            ),
            playback_group_from_tracks(
                "audio",
                "Audio",
                &stream.audio_options,
                selected_audio_index,
            ),
            playback_group_from_tracks(
                "subtitles",
                "Subtitles",
                &stream.subtitle_options,
                selected_subtitle_index,
            ),
        ],
        selected_source_option,
        selected_quality_option,
        selected_audio_option,
        selected_subtitle_option,
        catchup_playback_uri,
    }
}

fn playback_group_from_variants(
    kind: &str,
    title: &str,
    options: &[PlaybackVariantOptionSnapshot],
    selected_index: usize,
    fallback_label: &str,
) -> PlaybackChooserGroupSnapshot {
    let mapped = if options.is_empty() {
        vec![PlaybackChooserOptionSnapshot {
            id: "default".to_owned(),
            label: fallback_label.to_owned(),
        }]
    } else {
        options
            .iter()
            .map(|option| PlaybackChooserOptionSnapshot {
                id: option.id.clone(),
                label: option.label.clone(),
            })
            .collect()
    };
    PlaybackChooserGroupSnapshot {
        kind: kind.to_owned(),
        title: title.to_owned(),
        options: mapped,
        selected_index: selected_index.min(options.len().saturating_sub(1)),
    }
}

fn playback_group_from_tracks(
    kind: &str,
    title: &str,
    options: &[PlaybackTrackOptionSnapshot],
    selected_index: usize,
) -> PlaybackChooserGroupSnapshot {
    let mapped = if options.is_empty() {
        vec![PlaybackChooserOptionSnapshot {
            id: "off".to_owned(),
            label: "Off".to_owned(),
        }]
    } else {
        options
            .iter()
            .map(|option| PlaybackChooserOptionSnapshot {
                id: option.id.clone(),
                label: option.label.clone(),
            })
            .collect()
    };
    PlaybackChooserGroupSnapshot {
        kind: kind.to_owned(),
        title: title.to_owned(),
        options: mapped,
        selected_index: selected_index.min(options.len().saturating_sub(1)),
    }
}

fn select_variant_option(
    options: &[PlaybackVariantOptionSnapshot],
    selected_index: usize,
) -> Option<PlaybackVariantOptionSnapshot> {
    options.get(selected_index).cloned()
}

fn select_track_option(
    options: &[PlaybackTrackOptionSnapshot],
    selected_index: usize,
) -> Option<PlaybackTrackOptionSnapshot> {
    options.get(selected_index).cloned()
}

fn clamp_index(index: Option<i32>, len: usize) -> usize {
    if len == 0 {
        return 0;
    }
    let candidate = index.unwrap_or(0).max(0) as usize;
    candidate.min(len - 1)
}

fn empty_playback_stream() -> PlaybackStreamSnapshot {
    PlaybackStreamSnapshot {
        uri: String::new(),
        transport: "hls".to_owned(),
        live: false,
        seekable: false,
        resume_position_seconds: 0,
        source_options: Vec::<PlaybackVariantOptionSnapshot>::new(),
        quality_options: Vec::<PlaybackVariantOptionSnapshot>::new(),
        audio_options: Vec::<PlaybackTrackOptionSnapshot>::new(),
        subtitle_options: Vec::<PlaybackTrackOptionSnapshot>::new(),
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn derive_catchup_playback_uri(stream: &PlaybackStreamSnapshot) -> Option<String> {
    let uri = stream.uri.trim();
    if uri.is_empty() || (!stream.live && !stream.seekable && stream.resume_position_seconds == 0) {
        return None;
    }

    if let Ok((source, _)) = generate_xtream_codes_source(uri) {
        return Some(source);
    }

    let is_ts_hint = stream.transport.eq_ignore_ascii_case("ts");
    if let Ok((source, _)) = generate_flussonic_source(uri, is_ts_hint) {
        return Some(source);
    }

    None
}

#[cfg(target_arch = "wasm32")]
fn derive_catchup_playback_uri(_stream: &PlaybackStreamSnapshot) -> Option<String> {
    None
}
