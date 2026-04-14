use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn source_registry_json() -> String {
    crate::source_runtime::source_registry_json()
}

#[frb(sync)]
pub fn update_source_setup_json(
    source_registry_json: String,
    action: String,
    selected_provider_type: Option<String>,
    selected_source_index: Option<i32>,
    target_step: Option<String>,
    field_key: Option<String>,
    field_value: Option<String>,
) -> Result<String, String> {
    crate::source_runtime::update_source_setup_json(
        &source_registry_json,
        &action,
        selected_provider_type.as_deref(),
        selected_source_index,
        target_step.as_deref(),
        field_key.as_deref(),
        field_value.as_deref(),
    )
}

#[frb(sync)]
pub fn hydrate_runtime_bundle_json(source_registry_json: Option<String>) -> Result<String, String> {
    crate::source_runtime::runtime_bundle_json_from_source_registry_json(
        source_registry_json.as_deref(),
    )
}

#[frb(sync)]
pub fn playback_runtime_json(source_registry_json: Option<String>) -> Result<String, String> {
    crate::playback_runtime::playback_runtime_json_from_source_registry_json(
        source_registry_json.as_deref(),
    )
}

#[frb(sync)]
pub fn playback_session_runtime_json_from_stream_json(
    playback_stream_json: String,
    source_index: Option<i32>,
    quality_index: Option<i32>,
    audio_index: Option<i32>,
    subtitle_index: Option<i32>,
) -> Result<String, String> {
    crate::playback_runtime::playback_session_runtime_json_from_stream_json(
        &playback_stream_json,
        source_index,
        quality_index,
        audio_index,
        subtitle_index,
    )
}

#[frb(sync)]
pub fn commit_source_setup_json(source_registry_json: String) -> Result<String, String> {
    crate::source_runtime::commit_source_setup_json(&source_registry_json)
}

#[frb(sync)]
pub fn diagnostics_runtime_json() -> String {
    crate::diagnostics_runtime::active_diagnostics_runtime_json()
}
