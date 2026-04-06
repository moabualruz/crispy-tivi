//! Integration tests for the crispy-core DB layer.
//!
//! These tests cover full write → read → verify round-trips using an
//! in-memory SQLite database.  They are intentionally scoped to the
//! gaps NOT already covered by the inline `#[cfg(test)]` modules in
//! the individual service files.
//!
//! Covered here:
//!  - Profile field mutation (name, PIN, is_child flag)
//!  - Multiple profiles coexisting and listing
//!  - Watch history per-profile isolation
//!  - Watch history ordering (most recent first)
//!  - Watch history upsert (no duplicate rows)
//!  - Channel favorites per-profile isolation
//!  - Source OR-REPLACE semantics (upsert, not duplicate)
//!  - Channel cascade delete triggered by source deletion
//!  - Channel group field roundtrip
//!  - Profile cascade delete removes watch history and favorites

use crispy_core::models::{Channel, Source, UserProfile, WatchHistory};
use crispy_core::services::{
    ChannelService, HistoryService, ProfileService, ServiceContext, SourceService,
};

// ── Helpers ───────────────────────────────────────────────────────────────────

fn make_svc() -> ServiceContext {
    let svc = ServiceContext::open_in_memory().expect("open in-memory DB");
    // Seed sources so FK constraints on channels are satisfied.
    for (id, name) in [
        ("s1", "Source 1"),
        ("s2", "Source 2"),
        ("s3", "Source 3"),
        ("src1", "Src 1"),
        ("src2", "Src 2"),
        ("srcA", "Src A"),
        ("srcB", "Src B"),
    ] {
        SourceService(svc.clone())
            .save_source(&source(id, name))
            .expect("seed source");
    }
    // Seed profiles so watch history + favorites FK constraints pass.
    for (id, name) in [
        ("p1", "Alice"),
        ("p2", "Bob"),
        ("profile_alice", "Alice"),
        ("profile_bob", "Bob"),
    ] {
        ProfileService(svc.clone())
            .save_profile(&profile(id, name))
            .expect("seed profile");
    }
    svc
}

fn source(id: &str, name: &str) -> Source {
    Source {
        id: id.to_string(),
        name: name.to_string(),
        source_type: crispy_core::value_objects::SourceType::M3u,
        url: format!("http://example.com/{id}.m3u"),
        username: None,
        password: None,
        access_token: None,
        device_id: None,
        user_id: None,
        mac_address: None,
        epg_url: None,
        user_agent: None,
        refresh_interval_minutes: 60,
        accept_self_signed: false,
        enabled: true,
        sort_order: 0,
        last_sync_time: None,
        last_sync_status: None,
        last_sync_error: None,
        created_at: None,
        updated_at: None,
        credentials_encrypted: false,
        deleted_at: None,
        epg_etag: None,
        epg_last_modified: None,
    }
}

fn profile(id: &str, name: &str) -> UserProfile {
    UserProfile {
        id: id.to_string(),
        name: name.to_string(),
        avatar_index: 0,
        pin: None,
        is_child: false,
        pin_version: 0,
        max_allowed_rating: 4,
        role: crispy_core::value_objects::ProfileRole::Viewer,
        dvr_permission: crispy_core::value_objects::DvrPermission::None,
        dvr_quota_mb: None,
    }
}

fn channel(id: &str, name: &str, source_id: &str) -> Channel {
    Channel {
        id: id.to_string(),
        native_id: id.to_string(),
        name: name.to_string(),
        stream_url: format!("http://example.com/{id}.ts"),
        source_id: Some(source_id.to_string()),
        ..Default::default()
    }
}

fn watch_entry(id: &str, name: &str, profile_id: &str, last_watched_str: &str) -> WatchHistory {
    WatchHistory {
        id: id.to_string(),
        media_type: crispy_core::value_objects::MediaType::Movie,
        name: name.to_string(),
        stream_url: format!("http://example.com/{id}"),
        poster_url: None,
        series_poster_url: None,
        position_ms: 1000,
        duration_ms: 5000,
        last_watched: chrono::NaiveDateTime::parse_from_str(last_watched_str, "%Y-%m-%d %H:%M:%S")
            .expect("parse datetime"),
        series_id: None,
        season_number: None,
        episode_number: None,
        device_id: None,
        device_name: None,
        profile_id: Some(profile_id.to_string()),
        source_id: None,
    }
}

// ── Profile tests ─────────────────────────────────────────────────────────────

/// Profile name and PIN can be mutated; new values survive a reload.
#[test]
fn test_save_profile_updates_name_and_pin_when_saved_twice() {
    let svc = make_svc();
    let psvc = ProfileService(svc.clone());
    let mut p = profile("p1", "Alice");
    psvc.save_profile(&p).unwrap();

    p.name = "Alicia".to_string();
    p.pin = Some("1234".to_string());
    psvc.save_profile(&p).unwrap();

    let loaded = psvc
        .load_profiles()
        .unwrap()
        .into_iter()
        .find(|pr| pr.id == "p1")
        .expect("profile must exist after save");

    assert_eq!(loaded.name, "Alicia");
    assert_eq!(loaded.pin.as_deref(), Some("1234"));
}

/// The `is_child` flag is persisted and read back correctly.
#[test]
fn test_save_profile_persists_is_child_flag_when_true() {
    let svc = make_svc();
    let psvc = ProfileService(svc.clone());
    let mut p = profile("p2", "KidProfile");
    p.is_child = true;
    psvc.save_profile(&p).unwrap();

    let loaded = psvc
        .load_profiles()
        .unwrap()
        .into_iter()
        .find(|pr| pr.id == "p2")
        .expect("profile must exist after save");

    assert!(loaded.is_child, "is_child must be true after save/load");
}

/// Multiple profiles can coexist; `load_profiles` returns all of them.
#[test]
fn test_load_profiles_returns_all_when_multiple_saved() {
    let svc = make_svc();
    let psvc = ProfileService(svc.clone());
    psvc.save_profile(&profile("p1", "Alice")).unwrap();
    psvc.save_profile(&profile("p2", "Bob")).unwrap();
    psvc.save_profile(&profile("p3", "Charlie")).unwrap();

    let all = psvc.load_profiles().unwrap();
    let ids: Vec<&str> = all.iter().map(|p| p.id.as_str()).collect();
    assert!(ids.contains(&"p1"));
    assert!(ids.contains(&"p2"));
    assert!(ids.contains(&"p3"));
}

/// Deleting one profile does not affect the others.
#[test]
fn test_delete_profile_removes_only_target_when_multiple_exist() {
    let svc = make_svc();
    let psvc = ProfileService(svc.clone());
    psvc.save_profile(&profile("p1", "Alice")).unwrap();
    psvc.save_profile(&profile("p2", "Bob")).unwrap();

    let before = psvc.load_profiles().unwrap().len();
    psvc.delete_profile("p1").unwrap();

    let remaining = psvc.load_profiles().unwrap();
    assert_eq!(remaining.len(), before - 1, "exactly one profile removed");
    assert!(remaining.iter().any(|p| p.id == "p2"), "p2 must survive");
    assert!(!remaining.iter().any(|p| p.id == "p1"), "p1 must be gone");
}

/// Cascade delete removes the profile's favorites.
#[test]
fn test_delete_profile_removes_favorites_when_profile_deleted() {
    let svc = make_svc();
    let psvc = ProfileService(svc.clone());
    let csvc = ChannelService(svc.clone());
    psvc.save_profile(&profile("p1", "Alice")).unwrap();

    let ch = channel("ch1", "CNN", "src1");
    csvc.save_channels(&[ch]).unwrap();
    csvc.add_favorite("p1", "ch1").unwrap();
    assert_eq!(csvc.get_favorites("p1").unwrap().len(), 1);

    psvc.delete_profile("p1").unwrap();

    let remaining = psvc.load_profiles().unwrap();
    assert!(
        !remaining.iter().any(|p| p.id == "p1"),
        "deleted profile must not appear in list"
    );
    assert!(
        csvc.get_favorites("p1").unwrap().is_empty(),
        "favorites must be removed when their profile is deleted"
    );
}

/// Cascade delete removes the profile's watch history.
#[test]
fn test_delete_profile_removes_watch_history_when_profile_deleted() {
    let svc = make_svc();
    let psvc = ProfileService(svc.clone());
    let hsvc = HistoryService(svc.clone());
    psvc.save_profile(&profile("p1", "Alice")).unwrap();

    let entry = watch_entry("w1", "Film", "p1", "2024-06-01 10:00:00");
    hsvc.save_watch_history(&entry).unwrap();
    assert_eq!(hsvc.load_watch_history().unwrap().len(), 1);

    psvc.delete_profile("p1").unwrap();

    assert!(
        hsvc.load_watch_history().unwrap().is_empty(),
        "watch history must be removed when its profile is deleted"
    );
}

// ── Watch history tests ───────────────────────────────────────────────────────

/// Results are in descending `last_watched` order (most recent first).
#[test]
fn test_load_watch_history_orders_most_recent_first_when_multiple_entries() {
    let svc = make_svc();
    let hsvc = HistoryService(svc.clone());

    // Insert in non-chronological order.
    hsvc.save_watch_history(&watch_entry("w1", "Oldest", "p1", "2024-01-01 10:00:00"))
        .unwrap();
    hsvc.save_watch_history(&watch_entry("w3", "Newest", "p1", "2024-03-01 10:00:00"))
        .unwrap();
    hsvc.save_watch_history(&watch_entry("w2", "Middle", "p1", "2024-02-01 10:00:00"))
        .unwrap();

    let history = hsvc.load_watch_history().unwrap();
    assert_eq!(history.len(), 3);
    assert_eq!(history[0].id, "w3", "most recent must be first");
    assert_eq!(history[1].id, "w2");
    assert_eq!(history[2].id, "w1", "oldest must be last");
}

/// `profile_id` is stored verbatim so entries can be filtered per profile.
#[test]
fn test_save_watch_history_preserves_profile_id_for_isolation_when_multiple_profiles() {
    let svc = make_svc();
    let hsvc = HistoryService(svc.clone());

    hsvc.save_watch_history(&watch_entry(
        "w1",
        "Movie A",
        "profile_alice",
        "2024-01-01 10:00:00",
    ))
    .unwrap();
    hsvc.save_watch_history(&watch_entry(
        "w2",
        "Movie B",
        "profile_bob",
        "2024-01-02 10:00:00",
    ))
    .unwrap();

    let all = hsvc.load_watch_history().unwrap();
    assert_eq!(all.len(), 2);

    let alice: Vec<_> = all
        .iter()
        .filter(|e| e.profile_id.as_deref() == Some("profile_alice"))
        .collect();
    let bob: Vec<_> = all
        .iter()
        .filter(|e| e.profile_id.as_deref() == Some("profile_bob"))
        .collect();

    assert_eq!(alice.len(), 1);
    assert_eq!(alice[0].id, "w1");
    assert_eq!(bob.len(), 1);
    assert_eq!(bob[0].id, "w2");
}

/// Saving the same entry twice (same id) updates `position_ms` — no duplicates.
#[test]
fn test_save_watch_history_overwrites_position_when_same_id_saved_twice() {
    let svc = make_svc();
    let hsvc = HistoryService(svc.clone());

    let mut e = watch_entry("w1", "Movie", "p1", "2024-01-01 10:00:00");
    e.position_ms = 1000;
    hsvc.save_watch_history(&e).unwrap();

    e.position_ms = 9500;
    hsvc.save_watch_history(&e).unwrap();

    let all = hsvc.load_watch_history().unwrap();
    assert_eq!(all.len(), 1, "upsert must not create duplicate rows");
    assert_eq!(
        all[0].position_ms, 9500,
        "position must reflect the latest save"
    );
}

// ── Favorites tests ───────────────────────────────────────────────────────────

/// Adding a channel to profile A does not make it appear in profile B's list.
#[test]
fn test_favorites_are_isolated_per_profile_when_two_profiles_share_channel() {
    let svc = make_svc();
    let psvc = ProfileService(svc.clone());
    let csvc = ChannelService(svc.clone());
    psvc.save_profile(&profile("pA", "Alice")).unwrap();
    psvc.save_profile(&profile("pB", "Bob")).unwrap();

    let ch = channel("ch1", "CNN", "src1");
    csvc.save_channels(&[ch]).unwrap();

    csvc.add_favorite("pA", "ch1").unwrap();

    let alice_favs = csvc.get_favorites("pA").unwrap();
    let bob_favs = csvc.get_favorites("pB").unwrap();

    assert_eq!(alice_favs, vec!["ch1"]);
    assert!(bob_favs.is_empty(), "Bob's favorites must be empty");
}

/// Removing a favorite from one profile does not affect the other profile.
#[test]
fn test_remove_favorite_only_removes_from_target_profile_when_both_have_same_channel() {
    let svc = make_svc();
    let psvc = ProfileService(svc.clone());
    let csvc = ChannelService(svc.clone());
    psvc.save_profile(&profile("pA", "Alice")).unwrap();
    psvc.save_profile(&profile("pB", "Bob")).unwrap();

    let ch = channel("ch1", "BBC", "src1");
    csvc.save_channels(&[ch]).unwrap();

    csvc.add_favorite("pA", "ch1").unwrap();
    csvc.add_favorite("pB", "ch1").unwrap();

    csvc.remove_favorite("pA", "ch1").unwrap();

    assert!(csvc.get_favorites("pA").unwrap().is_empty());
    assert_eq!(csvc.get_favorites("pB").unwrap(), vec!["ch1"]);
}

// ── Source tests ──────────────────────────────────────────────────────────────

/// Saving a source with the same ID twice replaces it rather than duplicating.
#[test]
fn test_save_source_upserts_when_same_id_saved_twice() {
    let svc = make_svc();
    let ssvc = SourceService(svc.clone());
    let before = ssvc.get_sources().unwrap().len();
    ssvc.save_source(&source("upsert_test", "Original")).unwrap();

    let mut s2 = source("upsert_test", "Renamed");
    s2.source_type = crispy_core::value_objects::SourceType::Xtream;
    ssvc.save_source(&s2).unwrap();

    let all = ssvc.get_sources().unwrap();
    assert_eq!(
        all.len(),
        before + 1,
        "must have exactly one new source after two saves with same id"
    );
    let loaded = ssvc.get_source("upsert_test").unwrap().unwrap();
    assert_eq!(loaded.name, "Renamed");
    assert_eq!(
        loaded.source_type,
        crispy_core::value_objects::SourceType::Xtream
    );
}

/// Deleting a source removes only its channels; channels from other sources survive.
#[test]
fn test_delete_source_removes_only_its_channels_when_multiple_sources_exist() {
    let svc = make_svc();
    let ssvc = SourceService(svc.clone());
    let csvc = ChannelService(svc.clone());
    ssvc.save_source(&source("src1", "Source A")).unwrap();
    ssvc.save_source(&source("src2", "Source B")).unwrap();

    csvc.save_channels(&[
        channel("ch1", "Ch-A1", "src1"),
        channel("ch2", "Ch-A2", "src1"),
        channel("ch3", "Ch-B1", "src2"),
    ])
    .unwrap();

    assert_eq!(csvc.load_channels().unwrap().len(), 3);

    ssvc.delete_source("src1").unwrap();

    let remaining = csvc.load_channels().unwrap();
    assert_eq!(remaining.len(), 1, "only ch3 from src2 must survive");
    assert_eq!(remaining[0].id, "ch3");
}

/// Deleting a nonexistent source is a no-op (no error returned).
#[test]
fn test_delete_source_is_noop_when_source_does_not_exist() {
    let svc = make_svc();
    SourceService(svc.clone())
        .delete_source("nonexistent-id")
        .unwrap();
}

// ── Channel tests ─────────────────────────────────────────────────────────────

/// The `channel_group` field survives a save/load round-trip.
#[test]
fn test_save_channels_persists_channel_group_when_group_is_set() {
    let svc = make_svc();
    let csvc = ChannelService(svc.clone());

    let mut ch = channel("ch1", "Al Jazeera", "src1");
    ch.channel_group = Some("News".to_string());
    csvc.save_channels(&[ch]).unwrap();

    let loaded = csvc.load_channels().unwrap();
    assert_eq!(loaded.len(), 1);
    assert_eq!(
        loaded[0].channel_group.as_deref(),
        Some("News"),
        "channel_group must survive the save/load round-trip"
    );
}

/// Channels from one source can be isolated by `get_channels_by_sources`.
#[test]
fn test_get_channels_by_sources_returns_only_matching_source_when_multiple_sources_exist() {
    let svc = make_svc();
    let csvc = ChannelService(svc.clone());

    csvc.save_channels(&[
        channel("ch1", "Ch1", "srcA"),
        channel("ch2", "Ch2", "srcA"),
        channel("ch3", "Ch3", "srcB"),
    ])
    .unwrap();

    let result = csvc
        .get_channels_by_sources(&["srcA".to_string()])
        .unwrap();

    assert_eq!(result.len(), 2);
    let ids: Vec<&str> = result.iter().map(|c| c.id.as_str()).collect();
    assert!(ids.contains(&"ch1"));
    assert!(ids.contains(&"ch2"));
    assert!(
        !ids.contains(&"ch3"),
        "ch3 belongs to srcB and must not appear"
    );
}

/// An empty `save_channels` call returns 0 and does not remove existing channels.
#[test]
fn test_save_channels_returns_zero_and_preserves_existing_when_empty_slice() {
    let svc = make_svc();
    let csvc = ChannelService(svc.clone());
    csvc.save_channels(&[channel("ch1", "Existing", "src1")])
        .unwrap();

    let count = csvc.save_channels(&[]).unwrap();
    assert_eq!(count, 0);
    assert_eq!(csvc.load_channels().unwrap().len(), 1);
}
