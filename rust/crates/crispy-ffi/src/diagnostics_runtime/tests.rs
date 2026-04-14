#[test]
fn diagnostics_runtime_snapshot_serializes_real_runtime_state() {
    let snapshot = crate::diagnostics_runtime::diagnostics_runtime_snapshot();

    assert_eq!(snapshot.version, "1");
    assert!(!snapshot.reports.is_empty());
    assert!(!snapshot.validation_summary.is_empty());
}

#[test]
fn active_diagnostics_runtime_tracks_host_tooling_on_real_path() {
    let snapshot = crate::diagnostics_runtime::active_diagnostics_runtime_snapshot();
    let host_tooling = crate::diagnostics_runtime::diagnostics_host_tooling_snapshot();

    assert_eq!(snapshot.ffprobe_available, host_tooling.ffprobe_available);
    assert_eq!(snapshot.ffmpeg_available, host_tooling.ffmpeg_available);
    assert_eq!(snapshot.reports.len(), 0);
}

#[test]
fn diagnostics_reports_are_derived_from_rust_runtime_bundle() {
    let mut live_tv = crate::live_tv_runtime_snapshot();
    live_tv.channels[0].playback_stream.uri = "https://example.test/live/custom.m3u8".to_owned();
    let reports = {
        #[cfg(not(target_arch = "wasm32"))]
        {
            super::diagnostics_reports_from_live_tv_snapshot(&live_tv)
        }
        #[cfg(target_arch = "wasm32")]
        {
            super::runtime_diagnostics_report("ignored", "ignored")
        }
    };

    assert_eq!(reports[0].url_hash, "https://example.test/live/custom.m3u8");
}
