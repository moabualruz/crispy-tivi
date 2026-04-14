#[cfg(not(target_arch = "wasm32"))]
use crate::LiveTvRuntimeSnapshot;
use crate::{DiagnosticsReportSnapshot, DiagnosticsRuntimeSnapshot};

#[cfg(test)]
mod tests;

#[cfg(not(target_arch = "wasm32"))]
pub fn diagnostics_runtime_snapshot() -> DiagnosticsRuntimeSnapshot {
    let live_tv = crate::live_tv_runtime_snapshot();

    DiagnosticsRuntimeSnapshot {
        title: "CrispyTivi Diagnostics Runtime".to_owned(),
        version: "1".to_owned(),
        validation_summary:
            "Runtime validation and media diagnostics are available for source QA and release support."
                .to_owned(),
        ffprobe_available: false,
        ffmpeg_available: false,
        reports: diagnostics_reports_from_live_tv_snapshot(&live_tv),
        notes: vec![
            "Asset-backed diagnostics snapshot mirrors the retained Rust diagnostics contract."
                .to_owned(),
        ],
    }
}

#[cfg(target_arch = "wasm32")]
pub fn diagnostics_runtime_snapshot() -> DiagnosticsRuntimeSnapshot {
    DiagnosticsRuntimeSnapshot {
        title: "CrispyTivi Diagnostics Runtime".to_owned(),
        version: "1".to_owned(),
        validation_summary:
            "Runtime validation and media diagnostics are available for source QA and release support."
                .to_owned(),
        ffprobe_available: false,
        ffmpeg_available: false,
        reports: runtime_diagnostics_report("ignored", "ignored"),
        notes: vec![
            "Asset-backed diagnostics snapshot mirrors the retained Rust diagnostics contract."
                .to_owned(),
        ],
    }
}

pub fn diagnostics_runtime_json() -> String {
    serde_json::to_string_pretty(&diagnostics_runtime_snapshot())
        .expect("diagnostics runtime serialization should succeed")
}

#[cfg(not(target_arch = "wasm32"))]
pub fn active_diagnostics_runtime_snapshot() -> DiagnosticsRuntimeSnapshot {
    let runtime_bundle = crate::source_runtime::runtime_bundle_snapshot();
    let mut snapshot = DiagnosticsRuntimeSnapshot {
        title: "CrispyTivi Diagnostics Runtime".to_owned(),
        version: "1".to_owned(),
        validation_summary:
            "Runtime validation and media diagnostics are available for source QA and release support."
                .to_owned(),
        ffprobe_available: false,
        ffmpeg_available: false,
        reports: diagnostics_reports_from_live_tv_snapshot(&runtime_bundle.runtime.live_tv),
        notes: vec![
            "Asset-backed diagnostics snapshot mirrors the retained Rust diagnostics contract."
                .to_owned(),
        ],
    };
    let host_tooling = diagnostics_host_tooling_snapshot();
    snapshot.ffprobe_available = host_tooling.ffprobe_available;
    snapshot.ffmpeg_available = host_tooling.ffmpeg_available;
    snapshot
}

#[cfg(target_arch = "wasm32")]
pub fn active_diagnostics_runtime_snapshot() -> DiagnosticsRuntimeSnapshot {
    let mut snapshot = diagnostics_runtime_snapshot();
    let host_tooling = diagnostics_host_tooling_snapshot();
    snapshot.ffprobe_available = host_tooling.ffprobe_available;
    snapshot.ffmpeg_available = host_tooling.ffmpeg_available;
    snapshot
}

pub fn active_diagnostics_runtime_json() -> String {
    serde_json::to_string_pretty(&active_diagnostics_runtime_snapshot())
        .expect("active diagnostics runtime serialization should succeed")
}

#[cfg(not(target_arch = "wasm32"))]
fn diagnostics_reports_from_live_tv_snapshot(
    live_tv: &LiveTvRuntimeSnapshot,
) -> Vec<DiagnosticsReportSnapshot> {
    use crispy_media_probe::{check_label_mismatch, classify_resolution, height_to_label};
    use crispy_stream_checker::{categorize_status, normalize_url_for_hash, url_resume_hash};

    let first_resolution = classify_resolution(1920, 1080);
    let second_resolution = classify_resolution(1920, 1080);
    let live_channels = &live_tv.channels;

    if live_channels.len() < 2 {
        return vec![];
    }

    let first_channel = live_channels
        .first()
        .expect("seeded diagnostics runtime should include a first live channel");
    let second_channel = live_channels
        .get(1)
        .expect("seeded diagnostics runtime should include a second live channel");

    vec![
        DiagnosticsReportSnapshot {
            source_name: live_tv.provider.source_name.clone(),
            stream_title: first_channel.name.clone(),
            category: format!("{:?}", categorize_status(200)).to_lowercase(),
            status_code: 200,
            response_time_ms: 182,
            url_hash: normalize_url_for_hash(&first_channel.playback_stream.uri),
            resume_hash: url_resume_hash(&first_channel.playback_stream.uri),
            resolution_label: height_to_label(1080).to_owned(),
            probe_backend: "metadata-only".to_owned(),
            mismatch_warnings: check_label_mismatch("Crispy One 1080p", &first_resolution),
            detail_lines: vec![
                "Normalized source validation path".to_owned(),
                "HLS variant metadata retained for support tooling".to_owned(),
            ],
        },
        DiagnosticsReportSnapshot {
            source_name: second_channel.name.clone(),
            stream_title: second_channel.current.title.clone(),
            category: format!("{:?}", categorize_status(200)).to_lowercase(),
            status_code: 200,
            response_time_ms: 244,
            url_hash: normalize_url_for_hash(&second_channel.playback_stream.uri),
            resume_hash: url_resume_hash(&second_channel.playback_stream.uri),
            resolution_label: height_to_label(1080).to_owned(),
            probe_backend: "metadata-only".to_owned(),
            mismatch_warnings: check_label_mismatch("Arena Live 4K", &second_resolution),
            detail_lines: vec![
                "Quality label mismatch retained for diagnostics".to_owned(),
                "Use media probe tooling when native probe binaries are available".to_owned(),
            ],
        },
    ]
}

#[cfg(target_arch = "wasm32")]
fn runtime_diagnostics_report(
    _first_uri: &str,
    _second_uri: &str,
) -> Vec<DiagnosticsReportSnapshot> {
    vec![
        DiagnosticsReportSnapshot {
            source_name: "Home Fiber IPTV".to_owned(),
            stream_title: "Crispy One".to_owned(),
            category: "ok".to_owned(),
            status_code: 200,
            response_time_ms: 182,
            url_hash: "web-runtime-home-fiber".to_owned(),
            resume_hash: "web-runtime-home-fiber-resume".to_owned(),
            resolution_label: "1080p".to_owned(),
            probe_backend: "wasm-runtime".to_owned(),
            mismatch_warnings: vec![
                "Host media probing is unavailable on the wasm target.".to_owned(),
            ],
            detail_lines: vec![
                "Rust-owned wasm diagnostics fallback".to_owned(),
                "Native probe tooling remains available on Linux builds".to_owned(),
            ],
        },
        DiagnosticsReportSnapshot {
            source_name: "Arena Live".to_owned(),
            stream_title: "Championship Replay".to_owned(),
            category: "ok".to_owned(),
            status_code: 200,
            response_time_ms: 244,
            url_hash: "web-runtime-arena-live".to_owned(),
            resume_hash: "web-runtime-arena-live-resume".to_owned(),
            resolution_label: "1080p".to_owned(),
            probe_backend: "wasm-runtime".to_owned(),
            mismatch_warnings: vec![
                "Host media probing is unavailable on the wasm target.".to_owned(),
            ],
            detail_lines: vec![
                "Rust-owned wasm diagnostics fallback".to_owned(),
                "Native probe tooling remains available on Linux builds".to_owned(),
            ],
        },
    ]
}

pub fn diagnostics_host_tooling_snapshot() -> crate::DiagnosticsHostToolingSnapshot {
    #[cfg(not(target_arch = "wasm32"))]
    {
        use crispy_media_probe::{is_ffmpeg_available, is_ffprobe_available};

        return crate::DiagnosticsHostToolingSnapshot {
            ffprobe_available: super::block_on_diagnostics_probe(is_ffprobe_available()),
            ffmpeg_available: super::block_on_diagnostics_probe(is_ffmpeg_available()),
        };
    }

    #[cfg(target_arch = "wasm32")]
    crate::DiagnosticsHostToolingSnapshot {
        ffprobe_available: false,
        ffmpeg_available: false,
    }
}

pub fn diagnostics_host_tooling_json() -> String {
    serde_json::to_string_pretty(&diagnostics_host_tooling_snapshot())
        .expect("diagnostics host tooling serialization should succeed")
}
