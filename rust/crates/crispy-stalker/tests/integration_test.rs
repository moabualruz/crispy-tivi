//! Integration tests for `StalkerClient` using wiremock.

use wiremock::matchers::{method, path, query_param};
use wiremock::{Mock, MockServer, ResponseTemplate};

use crispy_stalker::{StalkerClient, StalkerCredentials};

const TEST_MAC: &str = "00:1A:79:AB:CD:EF";

/// Build a client pointed at the given mock server.
fn test_client(server: &MockServer) -> StalkerClient {
    let creds = StalkerCredentials {
        base_url: server.uri(),
        mac_address: TEST_MAC.into(),
        timezone: None,
    };
    let http = reqwest::Client::builder()
        .build()
        .expect("failed to build http client");
    StalkerClient::with_http_client(creds, http)
}

/// Mount the standard auth flow: discovery at `/c/`, handshake, do_auth, get_profile.
async fn mount_full_auth(server: &MockServer, token: &str) {
    // Discovery: plain GET to /c/ returns 200
    Mock::given(method("GET"))
        .and(path("/c/"))
        .respond_with(ResponseTemplate::new(200).set_body_string("OK"))
        .up_to_n_times(1)
        .mount(server)
        .await;

    // Handshake
    Mock::given(method("GET"))
        .and(path("/c/"))
        .and(query_param("type", "stb"))
        .and(query_param("action", "handshake"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": { "token": token }
        })))
        .mount(server)
        .await;

    // do_auth
    Mock::given(method("GET"))
        .and(path("/c/"))
        .and(query_param("type", "stb"))
        .and(query_param("action", "do_auth"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({"js": true})))
        .mount(server)
        .await;

    // get_profile (called during authentication to fully activate session)
    Mock::given(method("GET"))
        .and(path("/c/"))
        .and(query_param("type", "stb"))
        .and(query_param("action", "get_profile"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": { "token": token, "timezone": "Europe/Paris", "locale": "en" }
        })))
        .mount(server)
        .await;
}

/// Mount all auth mocks and authenticate the client.
async fn authenticate_client(server: &MockServer) -> StalkerClient {
    mount_full_auth(server, "test_token_123").await;
    let mut client = test_client(server);
    client.authenticate().await.expect("authentication failed");
    client
}

#[tokio::test]
async fn portal_discovery_finds_stalker_portal_path() {
    let server = MockServer::start().await;

    // /stalker_portal/c/ responds 200
    Mock::given(method("GET"))
        .and(path("/stalker_portal/c/"))
        .respond_with(ResponseTemplate::new(200).set_body_string("OK"))
        .up_to_n_times(1)
        .mount(&server)
        .await;

    // /c/ responds 404 so discovery skips it
    // (stalker_portal is first in the list, so it should be tried first)

    // Handshake at /stalker_portal/c/
    Mock::given(method("GET"))
        .and(path("/stalker_portal/c/"))
        .and(query_param("action", "handshake"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": { "token": "tk" }
        })))
        .mount(&server)
        .await;

    // do_auth at /stalker_portal/c/
    Mock::given(method("GET"))
        .and(path("/stalker_portal/c/"))
        .and(query_param("action", "do_auth"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({"js": true})))
        .mount(&server)
        .await;

    // get_profile at /stalker_portal/c/
    Mock::given(method("GET"))
        .and(path("/stalker_portal/c/"))
        .and(query_param("action", "get_profile"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": { "token": "tk", "timezone": "Europe/Paris" }
        })))
        .mount(&server)
        .await;

    let mut client = test_client(&server);
    client.authenticate().await.unwrap();
    assert!(client.portal_url().unwrap().contains("/stalker_portal/c/"));
}

#[tokio::test]
async fn handshake_extracts_token_and_authenticates() {
    let server = MockServer::start().await;
    mount_full_auth(&server, "my_token_abc").await;

    let mut client = test_client(&server);
    client.authenticate().await.unwrap();
    assert!(client.is_authenticated());
}

#[tokio::test]
async fn get_genres_parses_categories() {
    let server = MockServer::start().await;
    let client = authenticate_client(&server).await;

    Mock::given(method("GET"))
        .and(query_param("type", "itv"))
        .and(query_param("action", "get_genres"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": [
                {"id": "1", "title": "News", "censored": "0"},
                {"id": "2", "title": "Sports", "censored": "0"},
                {"id": "99", "title": "Adult", "censored": "1"}
            ]
        })))
        .mount(&server)
        .await;

    let genres = client.get_genres().await.unwrap();
    assert_eq!(genres.len(), 3);
    assert_eq!(genres[0].title, "News");
    assert_eq!(genres[2].title, "Adult");
    assert!(genres[2].is_adult);
}

#[tokio::test]
async fn get_channels_single_page() {
    let server = MockServer::start().await;
    let client = authenticate_client(&server).await;

    Mock::given(method("GET"))
        .and(query_param("type", "itv"))
        .and(query_param("action", "get_ordered_list"))
        .and(query_param("genre", "5"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "total_items": "2",
                "max_page_items": "10",
                "data": [
                    {
                        "id": "1", "name": "Channel One", "number": "1",
                        "cmd": "ffrt http://stream.example.com/ch1",
                        "tv_genre_id": "5",
                        "logo": "http://example.com/ch1.png",
                        "xmltv_id": "ch1.example",
                        "tv_archive": "1", "tv_archive_duration": "3",
                        "censored": "0"
                    },
                    {
                        "id": "2", "name": "Channel Two", "number": "2",
                        "cmd": "http://stream.example.com/ch2",
                        "tv_genre_id": "5", "logo": "",
                        "tv_archive": "0", "tv_archive_duration": "0",
                        "censored": "0"
                    }
                ]
            }
        })))
        .mount(&server)
        .await;

    let result = client.get_channels_page("5", 1).await.unwrap();
    assert_eq!(result.total_items, 2);
    assert_eq!(result.items.len(), 2);

    let ch1 = &result.items[0];
    assert_eq!(ch1.name, "Channel One");
    assert_eq!(ch1.number, Some(1));
    assert!(ch1.has_archive);
    assert_eq!(ch1.archive_days, 3);
    assert_eq!(ch1.epg_channel_id.as_deref(), Some("ch1.example"));

    let ch2 = &result.items[1];
    assert!(ch2.logo.is_none()); // empty string filtered to None
}

#[tokio::test]
async fn get_all_channels_multi_page() {
    let server = MockServer::start().await;
    let client = authenticate_client(&server).await;

    Mock::given(method("GET"))
        .and(query_param("type", "itv"))
        .and(query_param("action", "get_ordered_list"))
        .and(query_param("genre", "1"))
        .and(query_param("p", "1"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "total_items": "3", "max_page_items": "2",
                "data": [
                    {"id": "1", "name": "Ch 1", "cmd": ""},
                    {"id": "2", "name": "Ch 2", "cmd": ""}
                ]
            }
        })))
        .mount(&server)
        .await;

    Mock::given(method("GET"))
        .and(query_param("type", "itv"))
        .and(query_param("action", "get_ordered_list"))
        .and(query_param("genre", "1"))
        .and(query_param("p", "2"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "total_items": "3", "max_page_items": "2",
                "data": [
                    {"id": "3", "name": "Ch 3", "cmd": ""}
                ]
            }
        })))
        .mount(&server)
        .await;

    let channels = client.get_all_channels("1", None).await.unwrap();
    assert_eq!(channels.len(), 3);
    assert_eq!(channels[0].name, "Ch 1");
    assert_eq!(channels[2].name, "Ch 3");
}

#[tokio::test]
async fn resolve_stream_url_all_formats() {
    // Full URL
    assert_eq!(
        crispy_stalker::resolve_stream_url("http://example.com/live/ch1.ts", "http://portal.com"),
        Some("http://example.com/live/ch1.ts".into())
    );

    // ffrt prefix
    assert_eq!(
        crispy_stalker::resolve_stream_url(
            "ffrt http://example.com/live/ch1.ts",
            "http://portal.com"
        ),
        Some("http://example.com/live/ch1.ts".into())
    );

    // Relative path
    assert_eq!(
        crispy_stalker::resolve_stream_url("/live/ch1.ts", "http://portal.com"),
        Some("http://portal.com/live/ch1.ts".into())
    );
}

#[tokio::test]
async fn mac_to_device_id_conversion() {
    use crispy_stalker::StalkerSession;
    assert_eq!(
        StalkerSession::mac_to_device_id("00:1A:79:AB:CD:EF"),
        "001A79ABCDEF"
    );
    assert_eq!(
        StalkerSession::mac_to_device_id("aa:bb:cc:dd:ee:ff"),
        "AABBCCDDEEFF"
    );
}

#[tokio::test]
async fn keepalive_sends_watchdog_request() {
    let server = MockServer::start().await;
    let client = authenticate_client(&server).await;

    Mock::given(method("GET"))
        .and(query_param("type", "watchdog"))
        .and(query_param("action", "get_events"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({"js": 1})))
        .mount(&server)
        .await;

    client.keepalive().await.unwrap();
}

#[tokio::test]
async fn expired_session_returns_session_expired_error() {
    let server = MockServer::start().await;
    let client = authenticate_client(&server).await;

    Mock::given(method("GET"))
        .and(query_param("type", "itv"))
        .and(query_param("action", "get_genres"))
        .respond_with(ResponseTemplate::new(401))
        .mount(&server)
        .await;

    let result = client.get_genres().await;
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        crispy_stalker::StalkerError::SessionExpired
    ),);
}

#[tokio::test]
async fn auth_failure_returns_auth_error() {
    let server = MockServer::start().await;

    // Discovery
    Mock::given(method("GET"))
        .and(path("/c/"))
        .respond_with(ResponseTemplate::new(200).set_body_string("OK"))
        .up_to_n_times(1)
        .mount(&server)
        .await;

    // Handshake succeeds
    Mock::given(method("GET"))
        .and(path("/c/"))
        .and(query_param("action", "handshake"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": { "token": "token123" }
        })))
        .mount(&server)
        .await;

    // do_auth returns false
    Mock::given(method("GET"))
        .and(path("/c/"))
        .and(query_param("action", "do_auth"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({"js": false})))
        .mount(&server)
        .await;

    let mut client = test_client(&server);
    let result = client.authenticate().await;
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        crispy_stalker::StalkerError::Auth(_)
    ));
}

#[tokio::test]
async fn not_authenticated_returns_error() {
    let server = MockServer::start().await;
    let client = test_client(&server);

    let result = client.get_genres().await;
    assert!(matches!(
        result.unwrap_err(),
        crispy_stalker::StalkerError::NotAuthenticated
    ));
}

#[tokio::test]
async fn get_account_info_parses_fields() {
    let server = MockServer::start().await;
    let client = authenticate_client(&server).await;

    Mock::given(method("GET"))
        .and(query_param("type", "account_info"))
        .and(query_param("action", "get_main_info"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "login": "user42",
                "mac": "00:1A:79:AB:CD:EF",
                "status": "1",
                "expire_billing_date": "2026-12-31",
                "subscribed_till": "2026-06-15",
                "phone": "+1234567890"
            }
        })))
        .mount(&server)
        .await;

    let info = client.get_account_info().await.unwrap();
    assert_eq!(info.login.as_deref(), Some("user42"));
    assert_eq!(info.mac.as_deref(), Some("00:1A:79:AB:CD:EF"));
    assert_eq!(info.status.as_deref(), Some("1"));
    assert_eq!(info.expiration.as_deref(), Some("2026-12-31"));
    assert_eq!(info.subscribed_till.as_deref(), Some("2026-06-15"));
}

#[tokio::test]
async fn progress_callback_receives_correct_counts() {
    let server = MockServer::start().await;
    let client = authenticate_client(&server).await;

    // Page 1: 3 total items, 2 per page = 2 pages
    Mock::given(method("GET"))
        .and(query_param("type", "itv"))
        .and(query_param("action", "get_ordered_list"))
        .and(query_param("genre", "pg"))
        .and(query_param("p", "1"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "total_items": "3", "max_page_items": "2",
                "data": [
                    {"id": "1", "name": "Ch 1", "cmd": ""},
                    {"id": "2", "name": "Ch 2", "cmd": ""}
                ]
            }
        })))
        .mount(&server)
        .await;

    Mock::given(method("GET"))
        .and(query_param("type", "itv"))
        .and(query_param("action", "get_ordered_list"))
        .and(query_param("genre", "pg"))
        .and(query_param("p", "2"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "total_items": "3", "max_page_items": "2",
                "data": [
                    {"id": "3", "name": "Ch 3", "cmd": ""}
                ]
            }
        })))
        .mount(&server)
        .await;

    let progress = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
    let progress_clone = progress.clone();
    let callback = move |completed: u32, total: u32| {
        progress_clone.lock().unwrap().push((completed, total));
    };

    let channels = client
        .get_all_channels("pg", Some(&callback))
        .await
        .unwrap();
    assert_eq!(channels.len(), 3);

    let calls = progress.lock().unwrap();
    assert_eq!(calls.len(), 2); // page 1 + page 2
    assert_eq!(calls[0], (1, 2));
    assert_eq!(calls[1], (2, 2));
}

#[tokio::test]
async fn get_series_info_returns_seasons_and_episodes() {
    let server = MockServer::start().await;
    let client = authenticate_client(&server).await;

    // get_seasons for movie_id=10
    Mock::given(method("GET"))
        .and(query_param("type", "vod"))
        .and(query_param("action", "get_ordered_list"))
        .and(query_param("movie_id", "10"))
        .and(query_param("season_id", "0"))
        .and(query_param("episode_id", "0"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "data": [
                    {"id": "s1", "name": "Season 1", "video_id": "10", "is_season": "1"},
                    {"id": "s2", "name": "Season 2", "video_id": "10", "is_season": "1"}
                ]
            }
        })))
        .mount(&server)
        .await;

    // get_episodes for season s1
    Mock::given(method("GET"))
        .and(query_param("type", "vod"))
        .and(query_param("action", "get_ordered_list"))
        .and(query_param("movie_id", "10"))
        .and(query_param("season_id", "s1"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "data": [
                    {"id": "e1", "name": "Pilot", "cmd": "http://s/s1e1", "series_number": "1"}
                ]
            }
        })))
        .mount(&server)
        .await;

    // get_episodes for season s2
    Mock::given(method("GET"))
        .and(query_param("type", "vod"))
        .and(query_param("action", "get_ordered_list"))
        .and(query_param("movie_id", "10"))
        .and(query_param("season_id", "s2"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "js": {
                "data": [
                    {"id": "e2", "name": "Premiere", "cmd": "http://s/s2e1", "series_number": "1"},
                    {"id": "e3", "name": "Ep 2", "cmd": "http://s/s2e2", "series_number": "2"}
                ]
            }
        })))
        .mount(&server)
        .await;

    let series = crispy_stalker::StalkerSeriesItem {
        id: "10".into(),
        name: "Test Series".into(),
        ..Default::default()
    };

    let detail = client.get_series_info(series).await.unwrap();
    assert_eq!(detail.series.name, "Test Series");
    assert_eq!(detail.seasons.len(), 2);
    assert_eq!(detail.seasons[0].name, "Season 1");
    assert_eq!(detail.seasons[1].name, "Season 2");
    assert_eq!(detail.episodes["s1"].len(), 1);
    assert_eq!(detail.episodes["s1"][0].name, "Pilot");
    assert_eq!(detail.episodes["s2"].len(), 2);
    assert_eq!(detail.episodes["s2"][0].name, "Premiere");
}
