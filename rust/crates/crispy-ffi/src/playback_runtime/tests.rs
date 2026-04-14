use crate::source_runtime::{
    runtime_bundle_snapshot_from_source_registry, seeded_source_registry_snapshot,
};

#[test]
fn playback_runtime_derives_source_quality_audio_and_subtitle_options() {
    let bundle = runtime_bundle_snapshot_from_source_registry(seeded_source_registry_snapshot());
    let playback = crate::playback_runtime::playback_snapshot_from_runtime(&bundle.runtime);

    assert!(!playback.source_options.is_empty());
    assert!(!playback.quality_options.is_empty());
}

#[test]
fn playback_runtime_resolves_session_snapshot_from_stream_selection() {
    let bundle = runtime_bundle_snapshot_from_source_registry(seeded_source_registry_snapshot());
    let stream = bundle.runtime.media.movie_collections[0].items[0]
        .playback_stream
        .clone();
    let json = serde_json::to_string(&stream).expect("stream should serialize");
    let snapshot = crate::playback_runtime::playback_session_runtime_json_from_stream_json(
        &json,
        Some(0),
        Some(1),
        Some(0),
        Some(1),
    )
    .and_then(|value| {
        serde_json::from_str::<crate::playback_runtime::PlaybackSessionRuntimeSnapshot>(&value)
            .map_err(|error| error.to_string())
    })
    .expect("session runtime should resolve");

    assert!(!snapshot.playback_uri.is_empty());
    assert_eq!(
        snapshot
            .selected_quality_option
            .as_ref()
            .map(|option| option.label.as_str()),
        Some("1080p")
    );
    assert!(!snapshot.chooser_groups.is_empty());
}

#[test]
fn playback_runtime_prefers_selected_live_channel_stream_from_runtime() {
    let bundle = runtime_bundle_snapshot_from_source_registry(seeded_source_registry_snapshot());
    let mut runtime = bundle.runtime.clone();
    let selected_channel = runtime
        .live_tv
        .channels
        .first()
        .expect("seeded runtime should include a live channel")
        .clone();
    runtime.live_tv.selection.channel_number = selected_channel.number.clone();
    runtime.live_tv.selection.channel_name = selected_channel.name.clone();

    let playback = crate::playback_runtime::playback_snapshot_from_runtime(&runtime);

    assert_eq!(playback.uri, selected_channel.playback_stream.uri);
    assert_eq!(
        playback.uri,
        runtime.live_tv.channels[0].playback_stream.uri
    );
    if let Some(movie_stream) = runtime
        .media
        .movie_collections
        .first()
        .and_then(|collection| collection.items.first())
        .map(|item| item.playback_stream.uri.clone())
    {
        assert_ne!(playback.uri, movie_stream);
    }
}

#[test]
fn playback_runtime_derives_catchup_playback_uri_from_live_stream_url() {
    let stream = crate::PlaybackStreamSnapshot {
        uri: "http://list.tv:8080/my@account.xc/my_password/1477".to_owned(),
        transport: "hls".to_owned(),
        live: true,
        seekable: true,
        resume_position_seconds: 0,
        source_options: Vec::new(),
        quality_options: Vec::new(),
        audio_options: Vec::new(),
        subtitle_options: Vec::new(),
    };

    let snapshot = serde_json::from_str::<crate::playback_runtime::PlaybackSessionRuntimeSnapshot>(
        &crate::playback_runtime::playback_session_runtime_json_from_stream_json(
            &serde_json::to_string(&stream).expect("stream should serialize"),
            None,
            None,
            None,
            None,
        )
        .expect("session runtime should serialize"),
    )
    .expect("session runtime should deserialize");

    assert_eq!(
        snapshot.catchup_playback_uri.as_deref(),
        Some(
            "http://list.tv:8080/timeshift/my@account.xc/my_password/{duration:60}/{Y}-{m}-{d}:{H}-{M}/1477.ts"
        )
    );
    assert_eq!(snapshot.playback_uri, stream.uri);
}
