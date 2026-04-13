use std::collections::HashMap;

use crate::api::commit_source_setup_json;
use crate::source_runtime::{
    RuntimeBundleSnapshot, runtime_bundle_json, runtime_bundle_snapshot,
    source_registry_json, source_registry_snapshot,
};
use crate::SearchRuntimeSnapshot;

#[test]
fn source_registry_includes_configured_providers() {
    let snapshot = source_registry_snapshot();

    assert!(!snapshot.configured_providers.is_empty());
    assert_eq!(snapshot.onboarding.selected_provider_kind, "M3U URL");
    assert!(
        snapshot
            .configured_providers
            .iter()
            .any(|provider| provider.display_name == "Home Fiber IPTV")
    );
    assert!(
        snapshot
            .configured_providers
            .iter()
            .any(|provider| provider.display_name == "Weekend Cinema")
    );
}

#[test]
fn source_registry_round_trips_through_json() {
    let json = source_registry_json();
    let parsed: crate::source_runtime::SourceRegistrySnapshot =
        serde_json::from_str(&json).expect("source registry should parse");

    assert_eq!(parsed, source_registry_snapshot());
    assert_eq!(parsed.provider_types.len(), 4);
    assert_eq!(parsed.configured_providers.len(), 4);
}

#[test]
fn runtime_bundle_hydrates_real_runtime_outputs() {
    let bundle = runtime_bundle_snapshot();

    assert!(!bundle.runtime.live_tv.channels.is_empty());
    assert!(!bundle.runtime.media.movie_collections.is_empty());
    assert!(!bundle.runtime.search.groups.is_empty());
    assert_eq!(bundle.runtime.personalization.startup_route, "Home");
    assert_eq!(
        bundle.runtime.live_tv.provider.source_name,
        "Home Fiber IPTV"
    );
    assert_eq!(bundle.runtime.media.movie_hero.title, "The Last Harbor");
    assert_eq!(bundle.runtime.search.active_group_title, "Live TV");
}

#[test]
fn bundle_round_trips_to_json() {
    let json = runtime_bundle_json();
    let parsed: RuntimeBundleSnapshot =
        serde_json::from_str(&json).expect("runtime bundle should parse");

    assert_eq!(parsed, runtime_bundle_snapshot());
}

#[test]
fn search_runtime_schema_remains_parseable() {
    let bundle = runtime_bundle_snapshot();
    let parsed: SearchRuntimeSnapshot =
        serde_json::to_value(&bundle.runtime.search)
            .and_then(serde_json::from_value)
            .expect("search runtime should serialize and parse");

    assert_eq!(parsed, bundle.runtime.search);
}

#[test]
fn commit_source_setup_updates_configured_providers_in_rust() {
    let json = crate::source_runtime::source_registry_json();
    let updated = commit_source_setup_json(
        json,
        "add".to_owned(),
        "Xtream".to_owned(),
        0,
        HashMap::from([
            ("display_name".to_owned(), "Portal Demo".to_owned()),
            ("server_url".to_owned(), "http://portal.example.test".to_owned()),
            ("username".to_owned(), "demo_user".to_owned()),
            ("password".to_owned(), "demo_pass".to_owned()),
        ]),
    )
    .expect("commit should succeed");

    let bundle: crate::source_runtime::RuntimeBundleSnapshot =
        serde_json::from_str(&updated).expect("bundle should parse");

    assert!(bundle
        .source_registry
        .configured_providers
        .iter()
        .any(|provider| provider.display_name == "Portal Demo"));
}
