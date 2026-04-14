use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::thread;

use crate::SearchRuntimeSnapshot;
use crate::api::{commit_source_setup_json, update_source_setup_json};
use crate::source_runtime::{
    RuntimeBundleSnapshot, runtime_bundle_json, runtime_bundle_snapshot,
    runtime_bundle_snapshot_from_source_registry, source_registry_json, source_registry_snapshot,
};

#[test]
fn source_registry_starts_empty_in_real_mode() {
    let snapshot = source_registry_snapshot();

    assert!(snapshot.configured_providers.is_empty());
    assert_eq!(snapshot.onboarding.selected_provider_kind, "M3U URL");
    assert_eq!(snapshot.provider_types.len(), 4);
}

#[test]
fn source_registry_round_trips_through_json() {
    let json = source_registry_json();
    let parsed: crate::source_runtime::SourceRegistrySnapshot =
        serde_json::from_str(&json).expect("source registry should parse");

    assert_eq!(parsed, source_registry_snapshot());
    assert_eq!(parsed.provider_types.len(), 4);
    assert!(parsed.configured_providers.is_empty());
}

#[test]
fn runtime_bundle_defaults_to_empty_real_runtime_outputs() {
    let bundle = runtime_bundle_snapshot();

    assert!(bundle.runtime.live_tv.channels.is_empty());
    assert!(bundle.runtime.media.movie_collections.is_empty());
    assert!(bundle.runtime.search.groups.is_empty());
    assert_eq!(bundle.runtime.personalization.startup_route, "Home");
    assert_eq!(
        bundle.runtime.live_tv.provider.source_name,
        "No provider configured"
    );
    assert_eq!(
        bundle.runtime.media.movie_hero.title,
        "Add a provider to unlock movies"
    );
    assert_eq!(bundle.runtime.search.active_group_title, "All");
}

#[test]
fn seeded_runtime_bundle_remains_available_for_explicit_demo_mode() {
    let bundle = runtime_bundle_snapshot_from_source_registry(
        crate::source_runtime::source_registry::seeded_source_registry_snapshot(),
    );

    assert!(!bundle.runtime.live_tv.channels.is_empty());
    assert!(!bundle.runtime.media.movie_collections.is_empty());
    assert!(!bundle.runtime.search.groups.is_empty());
    assert_eq!(
        bundle.runtime.live_tv.provider.source_name,
        "Home Fiber IPTV"
    );
    assert_eq!(
        bundle.runtime.media.movie_hero.title,
        "Weekend Cinema Spotlight"
    );
    assert_eq!(bundle.runtime.search.active_group_title, "Live TV");
}

#[test]
fn seed_demo_action_restores_seeded_registry_from_rust() {
    let seeded_json = update_source_setup_json(
        source_registry_json(),
        "seed_demo".to_owned(),
        None,
        None,
        None,
        None,
        None,
    )
    .expect("seed demo should succeed");

    let parsed: crate::source_runtime::SourceRegistrySnapshot =
        serde_json::from_str(&seeded_json).expect("seeded registry should parse");

    assert!(!parsed.configured_providers.is_empty());
    assert_eq!(parsed.onboarding.wizard_mode, "idle");
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
    let parsed: SearchRuntimeSnapshot = serde_json::to_value(&bundle.runtime.search)
        .and_then(serde_json::from_value)
        .expect("search runtime should serialize and parse");

    assert_eq!(parsed, bundle.runtime.search);
}

#[test]
fn commit_source_setup_updates_configured_providers_in_rust() {
    let json = crate::source_runtime::source_registry_json();
    let prepared = update_source_setup_json(
        json,
        "start_add".to_owned(),
        Some("Xtream".to_owned()),
        Some(0),
        None,
        None,
        None,
    )
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("display_name".to_owned()),
            Some("Portal Demo".to_owned()),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("server_url".to_owned()),
            Some("http://portal.example.test".to_owned()),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("username".to_owned()),
            Some("demo_user".to_owned()),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("password".to_owned()),
            Some("demo_pass".to_owned()),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "advance_wizard".to_owned(),
            None,
            None,
            None,
            None,
            None,
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "advance_wizard".to_owned(),
            None,
            None,
            None,
            None,
            None,
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "advance_wizard".to_owned(),
            None,
            None,
            None,
            None,
            None,
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "advance_wizard".to_owned(),
            None,
            None,
            None,
            None,
            None,
        )
    })
    .expect("wizard progression should succeed");

    let updated = commit_source_setup_json(prepared).expect("commit should succeed");

    let bundle: crate::source_runtime::RuntimeBundleSnapshot =
        serde_json::from_str(&updated).expect("bundle should parse");

    assert!(
        bundle
            .source_registry
            .configured_providers
            .iter()
            .any(|provider| provider.display_name == "Portal Demo")
    );
    let provider = bundle
        .source_registry
        .configured_providers
        .iter()
        .find(|provider| provider.display_name == "Portal Demo")
        .expect("committed provider should exist");
    assert_eq!(
        provider.runtime_config.get("server_url"),
        Some(&"http://portal.example.test".to_owned())
    );
    assert_eq!(
        provider.runtime_config.get("username"),
        Some(&"demo_user".to_owned())
    );
    assert_eq!(
        provider.runtime_config.get("password"),
        Some(&"demo_pass".to_owned())
    );
}

#[test]
fn commit_source_setup_shapes_provider_status_and_onboarding_in_rust() {
    let json = crate::source_runtime::source_registry_json();
    let prepared = update_source_setup_json(
        json,
        "start_add".to_owned(),
        Some("Xtream".to_owned()),
        Some(0),
        None,
        None,
        None,
    )
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("display_name".to_owned()),
            Some("Portal Demo".to_owned()),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("server_url".to_owned()),
            Some("http://portal.example.test".to_owned()),
        )
    })
    .expect("provider shaping setup should succeed");

    let updated = commit_source_setup_json(prepared).expect("commit should succeed");
    let bundle: crate::source_runtime::RuntimeBundleSnapshot =
        serde_json::from_str(&updated).expect("bundle should parse");
    let provider = bundle
        .source_registry
        .configured_providers
        .iter()
        .find(|provider| provider.display_name == "Portal Demo")
        .expect("committed provider should exist");

    assert_eq!(provider.health.status, "Healthy");
    assert_eq!(provider.auth.status, "Needs auth");
    assert_eq!(provider.import_details.status, "Blocked");
    assert_eq!(
        provider.runtime_config.get("server_url"),
        Some(&"http://portal.example.test".to_owned())
    );
    assert_eq!(
        provider.runtime_config.get("display_name"),
        Some(&"Portal Demo".to_owned())
    );
    assert_eq!(bundle.source_registry.onboarding.wizard_active, false);
    assert_eq!(bundle.source_registry.onboarding.wizard_mode, "idle");
    assert_eq!(
        bundle.source_registry.onboarding.active_wizard_step,
        "Source Type"
    );
    assert_eq!(
        bundle.source_registry.onboarding.selected_provider_kind,
        "Xtream"
    );
    assert_eq!(bundle.source_registry.onboarding.selected_source_index, 0);
    assert!(bundle.source_registry.onboarding.field_values.is_empty());
}

#[test]
fn direct_playlist_commit_reports_non_account_statuses_in_rust() {
    let json = crate::source_runtime::source_registry_json();
    let prepared = update_source_setup_json(
        json,
        "start_add".to_owned(),
        Some("M3U URL".to_owned()),
        Some(0),
        None,
        None,
        None,
    )
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("display_name".to_owned()),
            Some("Playlist Demo".to_owned()),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("playlist_url".to_owned()),
            Some("HTTP://PLAYLIST.EXAMPLE.TEST/demo.m3u?b=2&a=1".to_owned()),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("xmltv_url".to_owned()),
            Some("HTTP://PLAYLIST.EXAMPLE.TEST/demo.xmltv?z=2&y=1".to_owned()),
        )
    })
    .expect("playlist setup should succeed");

    let updated = commit_source_setup_json(prepared).expect("commit should succeed");
    let bundle: crate::source_runtime::RuntimeBundleSnapshot =
        serde_json::from_str(&updated).expect("bundle should parse");
    let provider = bundle
        .source_registry
        .configured_providers
        .iter()
        .find(|provider| provider.display_name == "Playlist Demo")
        .expect("committed provider should exist");

    assert_eq!(provider.health.status, "Healthy");
    assert_eq!(provider.auth.status, "Not required");
    assert_eq!(provider.auth.progress, "100%");
    assert_eq!(provider.import_details.status, "Ready");
    assert_eq!(provider.import_details.primary_action, "Start import");
    assert_eq!(
        provider.runtime_config.get("playlist_url"),
        Some(&"http://playlist.example.test/demo.m3u?a=1&b=2".to_owned())
    );
    assert_eq!(
        provider.runtime_config.get("xmltv_url"),
        Some(&"http://playlist.example.test/demo.xmltv?y=1&z=2".to_owned())
    );
}

#[test]
fn direct_playlist_commit_hydrates_live_runtime_from_playlist_url_in_rust() {
    let json = crate::source_runtime::source_registry_json();
    let prepared = update_source_setup_json(
        json,
        "start_add".to_owned(),
        Some("M3U URL".to_owned()),
        Some(0),
        None,
        None,
        None,
    )
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("display_name".to_owned()),
            Some("Playlist Demo".to_owned()),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("playlist_url".to_owned()),
            Some(
                "#EXTM3U\n\
                 #EXTINF:-1 tvg-id=\"news-1\" tvg-chno=\"101\" group-title=\"News\",Morning News\n\
                 http://example.com/news.m3u8\n"
                    .to_owned(),
            ),
        )
    })
    .and_then(|json| {
        update_source_setup_json(
            json,
            "update_field".to_owned(),
            None,
            None,
            None,
            Some("xmltv_url".to_owned()),
            Some("http://playlist.example.test/demo.xmltv".to_owned()),
        )
    })
    .expect("playlist setup should succeed");

    let updated = commit_source_setup_json(prepared).expect("commit should succeed");
    let bundle: crate::source_runtime::RuntimeBundleSnapshot =
        serde_json::from_str(&updated).expect("bundle should parse");
    let committed_provider = bundle
        .source_registry
        .configured_providers
        .iter()
        .find(|provider| provider.display_name == "Playlist Demo")
        .expect("committed provider should exist");
    assert_eq!(
        committed_provider.runtime_config.get("playlist_url"),
        Some(
            &"#EXTM3U\n\
              #EXTINF:-1 tvg-id=\"news-1\" tvg-chno=\"101\" group-title=\"News\",Morning News\n\
              http://example.com/news.m3u8"
                .to_owned()
        )
    );

    let mut hydrated_registry = bundle.source_registry.clone();
    hydrated_registry.configured_providers = hydrated_registry
        .configured_providers
        .into_iter()
        .filter(|provider| provider.display_name == "Playlist Demo")
        .collect();
    let hydrated = runtime_bundle_snapshot_from_source_registry(hydrated_registry);

    assert_eq!(hydrated.runtime.live_tv.provider.provider_type, "M3U URL");
    assert_eq!(
        hydrated.runtime.live_tv.provider.source_name,
        "Playlist Demo"
    );
    assert_eq!(hydrated.runtime.live_tv.channels.len(), 1);
    assert_eq!(hydrated.runtime.live_tv.channels[0].number, "101");
    assert_eq!(hydrated.runtime.live_tv.channels[0].name, "Morning News");
    assert_eq!(
        hydrated.runtime.live_tv.selection.now.title,
        "Morning News live"
    );
}

#[test]
fn xtream_live_runtime_uses_shared_client_when_credentials_are_present() {
    let server_url = spawn_xtream_test_server();
    let source_registry = xtream_only_registry(&server_url);

    let bundle = runtime_bundle_snapshot_from_source_registry(source_registry);

    assert_eq!(
        bundle.runtime.live_tv.provider.source_name,
        "Weekend Cinema"
    );
    assert_eq!(bundle.runtime.live_tv.channels.len(), 2);
    assert_eq!(bundle.runtime.live_tv.channels[0].number, "7");
    assert_eq!(bundle.runtime.live_tv.channels[0].name, "Portal One");
    assert!(
        bundle.runtime.live_tv.channels[0]
            .playback_stream
            .uri
            .contains("/live/demo_user/demo_pass/101.")
    );
    assert_eq!(bundle.runtime.media.movie_collections.len(), 1);
    assert_eq!(bundle.runtime.media.movie_collections[0].items.len(), 2);
    assert_eq!(
        bundle.runtime.media.movie_collections[0].items[0].title,
        "Portal Movie"
    );
    assert!(
        bundle.runtime.media.movie_collections[0].items[0]
            .playback_stream
            .uri
            .contains("/movie/demo_user/demo_pass/9001.mp4")
    );
    assert_eq!(bundle.runtime.media.series_collections.len(), 1);
    assert_eq!(bundle.runtime.media.series_collections[0].items.len(), 1);
    assert_eq!(
        bundle.runtime.media.series_collections[0].items[0].title,
        "Portal Series"
    );
    assert_eq!(bundle.runtime.media.series_detail.seasons.len(), 1);
    assert_eq!(
        bundle.runtime.media.series_detail.seasons[0].episodes[0].title,
        "Episode 1"
    );
    assert!(
        bundle.runtime.media.series_detail.seasons[0].episodes[0]
            .playback_stream
            .uri
            .contains("/series/demo_user/demo_pass/7001.mp4")
    );
}

#[test]
fn xtream_live_runtime_returns_provider_error_when_real_fetch_fails() {
    let source_registry = xtream_only_registry("http://127.0.0.1:9");

    let bundle = runtime_bundle_snapshot_from_source_registry(source_registry);

    assert_eq!(
        bundle.runtime.live_tv.provider.source_name,
        "Weekend Cinema"
    );
    assert_eq!(bundle.runtime.live_tv.provider.status, "Error");
    assert!(bundle.runtime.live_tv.channels.is_empty());
    assert!(bundle.runtime.media.movie_collections.is_empty());
    assert!(bundle.runtime.media.series_collections.is_empty());
    assert!(
        bundle
            .runtime
            .live_tv
            .selection
            .detail_lines
            .iter()
            .any(|line| line.contains("failed to hydrate"))
    );
}

fn xtream_only_registry(server_url: &str) -> crate::source_runtime::SourceRegistrySnapshot {
    let mut registry = crate::source_runtime::source_registry::seeded_source_registry_snapshot();
    registry.registry_notes.clear();
    registry.configured_providers = registry
        .configured_providers
        .into_iter()
        .filter_map(|mut provider| {
            if provider.provider_type == "Xtream" {
                provider.runtime_config = HashMap::from([
                    ("server_url".to_owned(), server_url.to_owned()),
                    ("username".to_owned(), "demo_user".to_owned()),
                    ("password".to_owned(), "demo_pass".to_owned()),
                ]);
                Some(provider)
            } else {
                None
            }
        })
        .collect();
    registry
}

fn spawn_xtream_test_server() -> String {
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
                        "direct_source": ""
                    },
                    {
                        "num": 8,
                        "name": "Portal Two",
                        "stream_id": 102,
                        "category_id": "Sports",
                        "tv_archive": 0,
                        "direct_source": ""
                    }
                ]"#
            } else if request.contains("action=get_vod_categories") {
                r#"[
                    {"category_id": "461", "category_name": "TOP MOVIES", "parent_id": 0}
                ]"#
            } else if request.contains("action=get_vod_streams") {
                r#"[
                    {
                        "num": 1,
                        "name": "Portal Movie",
                        "stream_id": 9001,
                        "genre": "Thriller",
                        "container_extension": "mp4"
                    },
                    {
                        "num": 2,
                        "name": "Portal Movie Two",
                        "stream_id": 9002,
                        "genre": "Drama",
                        "container_extension": "mp4"
                    }
                ]"#
            } else if request.contains("action=get_series_info") {
                r#"{
                    "info": {
                        "name": "Portal Series",
                        "plot": "Series plot"
                    },
                    "seasons": [
                        {
                            "name": "Season 1",
                            "season_number": 1,
                            "overview": "Season one"
                        }
                    ],
                    "episodes": {
                        "1": [
                            {
                                "id": "7001",
                                "episode_num": "1",
                                "title": "Episode 1",
                                "container_extension": "mp4",
                                "info": {
                                    "plot": "Episode plot",
                                    "duration": "45 min"
                                }
                            }
                        ]
                    }
                }"#
            } else if request.contains("action=get_series_categories") {
                r#"[
                    {"category_id": "245", "category_name": "Series", "parent_id": 0}
                ]"#
            } else if request.contains("action=get_series") {
                r#"[
                    {
                        "num": 1,
                        "name": "Portal Series",
                        "series_id": 7001,
                        "genre": "Sci-fi"
                    }
                ]"#
            } else {
                panic!("unexpected request: {request}");
            };
            let response = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
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
