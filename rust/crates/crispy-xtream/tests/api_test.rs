//! Integration tests for `XtreamClient` using wiremock.
//!
//! Each test spins up a mock server that simulates Xtream Codes API responses.

use wiremock::matchers::{method, path, query_param};
use wiremock::{Mock, MockServer, ResponseTemplate};

use crispy_xtream::{StreamType, XtreamClient, XtreamClientConfig, XtreamCredentials};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async fn setup() -> (MockServer, XtreamClient) {
    let server = MockServer::start().await;
    let creds = XtreamCredentials::new(server.uri(), "testuser", "testpass");
    let client = XtreamClient::with_config(creds, XtreamClientConfig::default()).unwrap();
    (server, client)
}

fn profile_json() -> &'static str {
    r#"{
        "user_info": {
            "username": "testuser",
            "password": "testpass",
            "message": "Welcome",
            "auth": 1,
            "status": "Active",
            "exp_date": "1735689600",
            "is_trial": "0",
            "active_cons": 0,
            "created_at": "1704067200",
            "max_connections": "1",
            "allowed_output_formats": ["ts", "m3u8"]
        },
        "server_info": {
            "xui": true,
            "version": "1.5.12",
            "revision": null,
            "url": "example.com",
            "port": "80",
            "https_port": "443",
            "server_protocol": "http",
            "rtmp_port": "8880",
            "timezone": "UTC",
            "timestamp_now": 1704067200,
            "time_now": "2024-01-01 00:00:00"
        }
    }"#
}

/// Mount the profile mock (needed by methods that auto-authenticate).
async fn mount_profile(server: &MockServer) {
    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_profile"))
        .respond_with(ResponseTemplate::new(200).set_body_raw(profile_json(), "application/json"))
        .mount(server)
        .await;
}

// ---------------------------------------------------------------------------
// 1. Authenticate
// ---------------------------------------------------------------------------

#[tokio::test]
async fn authenticate_parses_profile() {
    let (server, client) = setup().await;
    mount_profile(&server).await;

    let profile = client.authenticate().await.unwrap();
    assert_eq!(profile.user_info.username, "testuser");
    assert_eq!(profile.user_info.auth, 1);
    assert_eq!(profile.user_info.status, "Active");
    assert_eq!(profile.user_info.allowed_output_formats, vec!["ts", "m3u8"]);
    assert_eq!(profile.server_info.timezone.as_deref(), Some("UTC"));
}

// ---------------------------------------------------------------------------
// 2. Get live categories
// ---------------------------------------------------------------------------

#[tokio::test]
async fn get_live_categories() {
    let (server, client) = setup().await;

    let body = r#"[
        {"category_id": "1", "category_name": "Sports", "parent_id": 0},
        {"category_id": "2", "category_name": "News", "parent_id": 0}
    ]"#;

    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_live_categories"))
        .respond_with(ResponseTemplate::new(200).set_body_raw(body, "application/json"))
        .mount(&server)
        .await;

    let cats = client.get_live_categories().await.unwrap();
    assert_eq!(cats.len(), 2);
    assert_eq!(cats[0].category_id, "1");
    assert_eq!(cats[0].category_name, "Sports");
    assert_eq!(cats[1].category_name, "News");
}

// ---------------------------------------------------------------------------
// 3. Get live streams
// ---------------------------------------------------------------------------

#[tokio::test]
async fn get_live_streams_with_urls() {
    let (server, client) = setup().await;
    mount_profile(&server).await;

    let body = r#"[
        {
            "num": 1,
            "name": "BBC One",
            "stream_type": "live",
            "stream_id": 42,
            "stream_icon": "http://img.example.com/bbc1.png",
            "thumbnail": "",
            "epg_channel_id": "bbc1.uk",
            "added": "1704067200",
            "category_id": "1",
            "category_ids": [1],
            "custom_sid": "",
            "tv_archive": 1,
            "direct_source": "",
            "tv_archive_duration": 7
        }
    ]"#;

    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_live_streams"))
        .respond_with(ResponseTemplate::new(200).set_body_raw(body, "application/json"))
        .mount(&server)
        .await;

    let channels = client.get_live_streams(None).await.unwrap();
    assert_eq!(channels.len(), 1);
    assert_eq!(channels[0].name, "BBC One");
    assert_eq!(channels[0].stream_id, 42);

    // Verify generated stream URL.
    let url = channels[0].url.as_ref().unwrap();
    assert!(
        url.ends_with("/live/testuser/testpass/42.ts"),
        "url was: {url}"
    );
}

// ---------------------------------------------------------------------------
// 4. Get VOD streams
// ---------------------------------------------------------------------------

#[tokio::test]
async fn get_vod_streams_with_urls() {
    let (server, client) = setup().await;
    mount_profile(&server).await;

    let body = r#"[
        {
            "num": 1,
            "name": "Test Movie",
            "stream_id": 99,
            "stream_icon": "",
            "rating": 7.5,
            "rating_5based": 3.75,
            "container_extension": "mp4",
            "category_id": "5",
            "category_ids": [5],
            "added": "1704067200"
        }
    ]"#;

    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_vod_streams"))
        .respond_with(ResponseTemplate::new(200).set_body_raw(body, "application/json"))
        .mount(&server)
        .await;

    let movies = client.get_vod_streams(None).await.unwrap();
    assert_eq!(movies.len(), 1);
    assert_eq!(movies[0].name, "Test Movie");
    assert_eq!(movies[0].stream_id, 99);

    let url = movies[0].url.as_ref().unwrap();
    assert!(
        url.ends_with("/movie/testuser/testpass/99.mp4"),
        "url was: {url}"
    );
}

// ---------------------------------------------------------------------------
// 5. Get series + series_info
// ---------------------------------------------------------------------------

#[tokio::test]
async fn get_series_info_with_episodes() {
    let (server, client) = setup().await;

    let body = r#"{
        "seasons": [
            {
                "id": 1,
                "name": "Season 1",
                "episode_count": 2,
                "season_number": 1
            }
        ],
        "info": {
            "name": "Test Show",
            "title": "Test Show",
            "cover": "http://img.example.com/show.png",
            "category_id": "10",
            "category_ids": [10]
        },
        "episodes": {
            "1": [
                {
                    "id": "501",
                    "episode_num": "1",
                    "title": "Pilot",
                    "container_extension": "mkv",
                    "season": 1,
                    "added": "1704067200",
                    "info": {
                        "duration_secs": 2700,
                        "duration": "00:45:00",
                        "rating": 8.0
                    }
                },
                {
                    "id": "502",
                    "episode_num": "2",
                    "title": "Second",
                    "container_extension": "mkv",
                    "season": 1
                }
            ]
        }
    }"#;

    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_series_info"))
        .and(query_param("series_id", "100"))
        .respond_with(ResponseTemplate::new(200).set_body_raw(body, "application/json"))
        .mount(&server)
        .await;

    let show = client.get_series_info(100).await.unwrap();
    assert_eq!(
        show.info.as_ref().unwrap().name.as_deref(),
        Some("Test Show")
    );
    assert_eq!(show.info.as_ref().unwrap().series_id, Some(100));
    assert_eq!(show.seasons.len(), 1);

    let eps = show.episodes.get("1").unwrap();
    assert_eq!(eps.len(), 2);
    assert_eq!(eps[0].title.as_deref(), Some("Pilot"));

    // Episode URLs attached.
    let ep_url = eps[0].url.as_ref().unwrap();
    assert!(
        ep_url.ends_with("/series/testuser/testpass/501.mkv"),
        "url was: {ep_url}"
    );
}

// ---------------------------------------------------------------------------
// 6. Get short EPG with base64 decoding
// ---------------------------------------------------------------------------

#[tokio::test]
async fn get_short_epg_decodes_base64() {
    let (server, client) = setup().await;

    // "News" = TmV3cw==, "Daily news" = RGFpbHkgbmV3cw==
    let body = r#"{
        "epg_listings": [
            {
                "id": "123",
                "epg_id": "bbc1.uk",
                "title": "TmV3cw==",
                "lang": "en",
                "start": "2024-01-01 10:00:00",
                "end": "2024-01-01 11:00:00",
                "description": "RGFpbHkgbmV3cw==",
                "channel_id": "bbc1.uk",
                "start_timestamp": "1704106800",
                "stop_timestamp": "1704110400",
                "stop": "2024-01-01 11:00:00"
            }
        ]
    }"#;

    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_short_epg"))
        .and(query_param("stream_id", "42"))
        .and(query_param("limit", "10"))
        .respond_with(ResponseTemplate::new(200).set_body_raw(body, "application/json"))
        .mount(&server)
        .await;

    let epg = client.get_short_epg(42, Some(10)).await.unwrap();
    assert_eq!(epg.epg_listings.len(), 1);
    assert_eq!(epg.epg_listings[0].title.as_deref(), Some("News"));
    assert_eq!(
        epg.epg_listings[0].description.as_deref(),
        Some("Daily news")
    );
}

// ---------------------------------------------------------------------------
// 7. Build stream URL format
// ---------------------------------------------------------------------------

#[tokio::test]
async fn build_stream_url_format() {
    let (_, client) = setup().await;
    let url = client.stream_url(StreamType::Channel, 42, "ts");
    assert!(url.contains("/live/testuser/testpass/42.ts"));
}

// ---------------------------------------------------------------------------
// 8. Build XMLTV URL format
// ---------------------------------------------------------------------------

#[tokio::test]
async fn build_xmltv_url_format() {
    let (_, client) = setup().await;
    let url = client.xmltv_url();
    assert!(url.contains("/xmltv.php?username=testuser&password=testpass"));
}

// ---------------------------------------------------------------------------
// 9. Build catchup/timeshift URL format
// ---------------------------------------------------------------------------

#[tokio::test]
async fn build_catchup_url_format() {
    let (_, client) = setup().await;
    let url = client.timeshift_url(42, 120, "2024-01-01:10-00");
    assert!(url.contains("/timeshift/testuser/testpass/120/2024-01-01:10-00/42.ts"));
}

// ---------------------------------------------------------------------------
// 10. Auth failure (401/403)
// ---------------------------------------------------------------------------

#[tokio::test]
async fn auth_failure_returns_error() {
    let (server, client) = setup().await;

    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_profile"))
        .respond_with(ResponseTemplate::new(403).set_body_string("Forbidden"))
        .mount(&server)
        .await;

    let result = client.authenticate().await;
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(
        matches!(err, crispy_xtream::XtreamError::Auth(_)),
        "got: {err:?}"
    );
}

// ---------------------------------------------------------------------------
// 11. Rate limiting (429)
// ---------------------------------------------------------------------------

#[tokio::test]
async fn rate_limited_returns_error() {
    let (server, client) = setup().await;

    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_live_categories"))
        .respond_with(
            ResponseTemplate::new(429)
                .insert_header("Retry-After", "30")
                .set_body_string("Too Many Requests"),
        )
        .mount(&server)
        .await;

    let result = client.get_live_categories().await;
    assert!(result.is_err());

    match result.unwrap_err() {
        crispy_xtream::XtreamError::RateLimited { retry_after_secs } => {
            assert_eq!(retry_after_secs, 30);
        }
        other => panic!("expected RateLimited, got: {other:?}"),
    }
}

// ---------------------------------------------------------------------------
// 12. Malformed JSON → graceful error
// ---------------------------------------------------------------------------

#[tokio::test]
async fn malformed_json_returns_error() {
    let (server, client) = setup().await;

    Mock::given(method("GET"))
        .and(path("/player_api.php"))
        .and(query_param("action", "get_live_categories"))
        .respond_with(
            ResponseTemplate::new(200).set_body_raw("not json at all", "application/json"),
        )
        .mount(&server)
        .await;

    let result = client.get_live_categories().await;
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        crispy_xtream::XtreamError::UnexpectedResponse(_)
    ),);
}
