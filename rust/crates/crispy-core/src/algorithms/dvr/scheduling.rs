//! DVR scheduling: recurring expansion, conflict detection, start-time lookup.

use chrono::{Duration, NaiveDateTime};

use crate::models::Recording;

use super::{RecordingInstance, combine_date_time};

/// Expand recurring recordings into concrete instances
/// for the next 7 days.
///
/// For each recurring recording whose `recur_days`
/// bitmask includes a given day, a
/// [`RecordingInstance`] is produced with the
/// recording's time-of-day applied to that date.
///
/// Instances that have already ended (before `now`) or
/// that already exist as non-recurring recordings are
/// skipped.
pub fn expand_recurring_recordings(
    recordings: &[Recording],
    now: NaiveDateTime,
) -> Vec<RecordingInstance> {
    use chrono::Datelike;

    let today = now.date();
    let mut instances = Vec::new();

    for rec in recordings {
        if !rec.is_recurring || rec.recur_days == 0 {
            continue;
        }

        for day_offset in 0..7 {
            let target_date = today + Duration::days(day_offset);

            // Chrono: num_days_from_monday() gives
            // Mon=0..Sun=6. Bitmask: Mon=bit0..Sun=bit6.
            let day_bit = 1 << target_date.weekday().num_days_from_monday();

            if (rec.recur_days & day_bit) == 0 {
                continue;
            }

            let instance_start = combine_date_time(target_date, rec.start_time);
            let mut instance_end = combine_date_time(target_date, rec.end_time);

            // Handle overnight recordings (e.g. 23:00–01:00):
            // if end time-of-day is before start time-of-day,
            // the recording spans midnight into the next day.
            if instance_end <= instance_start {
                instance_end += Duration::days(1);
            }

            // Skip past instances.
            if instance_end < now {
                continue;
            }

            // Skip if a non-recurring recording already
            // matches this instance.
            let already_exists = recordings.iter().any(|r| {
                !r.is_recurring
                    && r.channel_name == rec.channel_name
                    && r.program_name == rec.program_name
                    && r.start_time == instance_start
            });

            if already_exists {
                continue;
            }

            instances.push(RecordingInstance {
                channel_name: rec.channel_name.clone(),
                program_name: rec.program_name.clone(),
                start_time: instance_start,
                end_time: instance_end,
                channel_id: rec.channel_id.clone(),
                channel_logo_url: rec.channel_logo_url.clone(),
                stream_url: rec.stream_url.clone(),
                owner_profile_id: rec.owner_profile_id.clone(),
                is_shared: rec.is_shared,
            });
        }
    }

    instances
}

/// Check if a candidate recording conflicts with any
/// existing recording on the same channel with
/// overlapping time.
///
/// `exclude_id` allows ignoring a specific recording
/// (e.g. the one being edited).
pub fn detect_recording_conflict(
    recordings: &[Recording],
    exclude_id: Option<&str>,
    channel_name: &str,
    start: NaiveDateTime,
    end: NaiveDateTime,
) -> bool {
    recordings.iter().any(|r| {
        let dominated = match exclude_id {
            Some(eid) => r.id == eid,
            None => false,
        };
        !dominated && r.channel_name == channel_name && r.start_time < end && r.end_time > start
    })
}

/// Find IDs of scheduled recordings whose time window
/// contains `now` (i.e. they should be started).
pub fn find_recordings_to_start(recordings: &[Recording], now: NaiveDateTime) -> Vec<String> {
    recordings
        .iter()
        .filter(|r| {
            r.status == crate::value_objects::RecordingStatus::Scheduled
                && r.start_time <= now
                && r.end_time > now
        })
        .map(|r| r.id.clone())
        .collect()
}

/// Returns IDs of recordings that should start now (JSON bridge variant).
///
/// A recording should start when:
/// - `status == "scheduled"`
/// - `startTime <= now_ms`
/// - `endTime > now_ms`
///
/// Input: JSON array of recording objects with at least:
///   `{ "id": "...", "status": "...", "startTime": epochMs, "endTime": epochMs }`
///
/// Returns: JSON array of recording ID strings that should start.
pub fn get_recordings_to_start(recordings_json: &str, now_ms: i64) -> String {
    let Ok(arr) = serde_json::from_str::<serde_json::Value>(recordings_json) else {
        return "[]".to_string();
    };
    let Some(items) = arr.as_array() else {
        return "[]".to_string();
    };

    let ids: Vec<&str> = items
        .iter()
        .filter(|r| {
            let status = r.get("status").and_then(|v| v.as_str()).unwrap_or("");
            let start = r
                .get("startTime")
                .and_then(|v| v.as_i64())
                .unwrap_or(i64::MAX);
            let end = r.get("endTime").and_then(|v| v.as_i64()).unwrap_or(0);
            status == "scheduled" && start <= now_ms && end > now_ms
        })
        .filter_map(|r| r.get("id").and_then(|v| v.as_str()))
        .collect();

    serde_json::to_string(&ids).unwrap_or_else(|_| "[]".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::algorithms::normalize::EPG_FORMAT;

    fn dt(s: &str) -> NaiveDateTime {
        NaiveDateTime::parse_from_str(s, EPG_FORMAT).unwrap()
    }

    #[allow(clippy::too_many_arguments)]
    fn make_recording(
        id: &str,
        channel: &str,
        program: &str,
        start: &str,
        end: &str,
        status: &str,
        is_recurring: bool,
        recur_days: i32,
    ) -> Recording {
        Recording {
            id: id.to_string(),
            channel_id: None,
            channel_name: channel.to_string(),
            channel_logo_url: None,
            program_name: program.to_string(),
            stream_url: None,
            start_time: dt(start),
            end_time: dt(end),
            status: status.try_into().unwrap_or_default(),
            file_path: None,
            file_size_bytes: None,
            is_recurring,
            recur_days,
            owner_profile_id: None,
            is_shared: true,
            remote_backend_id: None,
            remote_path: None,
        }
    }

    // ── expand_recurring_recordings ────────────────────

    #[test]
    fn expand_recurring_mon_wed_fri() {
        // Mon=bit0, Wed=bit2, Fri=bit4 → 0b10101 = 21
        let rec = make_recording(
            "r1",
            "BBC One",
            "News",
            // Time-of-day: 20:00–21:00
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            true,
            21, // Mon + Wed + Fri
        );

        // "now" is Monday 2026-02-16 at 10:00.
        let now = dt("2026-02-16 10:00:00");
        let instances = expand_recurring_recordings(&[rec], now);

        // 7-day window: Mon 16 – Sun 22 Feb 2026.
        // Mon 16 Feb: bit0 ✓  (20:00 > 10:00 → future)
        // Tue 17 Feb: bit1 ✗
        // Wed 18 Feb: bit2 ✓
        // Thu 19 Feb: bit3 ✗
        // Fri 20 Feb: bit4 ✓
        // Sat 21 Feb: bit5 ✗
        // Sun 22 Feb: bit6 ✗
        assert_eq!(instances.len(), 3);
        assert_eq!(instances[0].start_time, dt("2026-02-16 20:00:00"),);
        assert_eq!(instances[1].start_time, dt("2026-02-18 20:00:00"),);
        assert_eq!(instances[2].start_time, dt("2026-02-20 20:00:00"),);
    }

    #[test]
    fn expand_skips_past_instances() {
        // Every day (all bits: 0b1111111 = 127).
        let rec = make_recording(
            "r1",
            "CH",
            "Show",
            "2026-02-16 08:00:00",
            "2026-02-16 09:00:00",
            "scheduled",
            true,
            127,
        );

        // "now" is Mon 16 Feb at 09:30 — today's
        // instance ended at 09:00, should be skipped.
        let now = dt("2026-02-16 09:30:00");
        let instances = expand_recurring_recordings(&[rec], now);

        // Mon skipped (ended), Tue–Sun = 6 instances.
        assert_eq!(instances.len(), 6);
        assert_eq!(instances[0].start_time, dt("2026-02-17 08:00:00"),);
    }

    #[test]
    fn expand_skips_existing_instances() {
        // Recurring: Mon + Tue (bits 0+1 = 3).
        let recurring = make_recording(
            "r1",
            "CH",
            "Show",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            true,
            3,
        );
        // Existing non-recurring instance for Monday.
        let existing = make_recording(
            "e1",
            "CH",
            "Show",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false,
            0,
        );

        let now = dt("2026-02-16 10:00:00");
        let instances = expand_recurring_recordings(&[recurring, existing], now);

        // Monday already exists → only Tuesday generated.
        assert_eq!(instances.len(), 1);
        assert_eq!(instances[0].start_time, dt("2026-02-17 20:00:00"),);
    }

    #[test]
    fn expand_skips_non_recurring() {
        let rec = make_recording(
            "r1",
            "CH",
            "Show",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false, // not recurring
            0,
        );

        let now = dt("2026-02-16 10:00:00");
        let instances = expand_recurring_recordings(&[rec], now);
        assert!(instances.is_empty());
    }

    // ── detect_recording_conflict ──────────────────────

    #[test]
    fn conflict_overlapping_same_channel() {
        let existing = make_recording(
            "r1",
            "BBC One",
            "News",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false,
            0,
        );

        let has_conflict = detect_recording_conflict(
            &[existing],
            None,
            "BBC One",
            dt("2026-02-16 20:30:00"),
            dt("2026-02-16 21:30:00"),
        );
        assert!(has_conflict);
    }

    #[test]
    fn no_conflict_non_overlapping() {
        let existing = make_recording(
            "r1",
            "BBC One",
            "News",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false,
            0,
        );

        let has_conflict = detect_recording_conflict(
            &[existing],
            None,
            "BBC One",
            dt("2026-02-16 21:00:00"),
            dt("2026-02-16 22:00:00"),
        );
        assert!(!has_conflict);
    }

    #[test]
    fn no_conflict_different_channel() {
        let existing = make_recording(
            "r1",
            "BBC One",
            "News",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false,
            0,
        );

        let has_conflict = detect_recording_conflict(
            &[existing],
            None,
            "CNN",
            dt("2026-02-16 20:00:00"),
            dt("2026-02-16 21:00:00"),
        );
        assert!(!has_conflict);
    }

    #[test]
    fn conflict_excludes_self() {
        let existing = make_recording(
            "r1",
            "BBC One",
            "News",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false,
            0,
        );

        // Same time, same channel, but excluded by ID.
        let has_conflict = detect_recording_conflict(
            &[existing],
            Some("r1"),
            "BBC One",
            dt("2026-02-16 20:00:00"),
            dt("2026-02-16 21:00:00"),
        );
        assert!(!has_conflict);
    }

    // ── find_recordings_to_start ───────────────────────

    #[test]
    fn finds_scheduled_within_window() {
        let recs = vec![
            make_recording(
                "r1",
                "CH",
                "Show A",
                "2026-02-16 20:00:00",
                "2026-02-16 21:00:00",
                "scheduled",
                false,
                0,
            ),
            make_recording(
                "r2",
                "CH",
                "Show B",
                "2026-02-16 22:00:00",
                "2026-02-16 23:00:00",
                "scheduled",
                false,
                0,
            ),
            make_recording(
                "r3",
                "CH",
                "Show C",
                "2026-02-16 20:00:00",
                "2026-02-16 21:00:00",
                "recording",
                false,
                0,
            ),
        ];

        let now = dt("2026-02-16 20:30:00");
        let ids = find_recordings_to_start(&recs, now);

        // r1: scheduled + in window → yes
        // r2: scheduled but future → no
        // r3: recording (not scheduled) → no
        assert_eq!(ids, vec!["r1".to_string()]);
    }

    #[test]
    fn finds_nothing_when_all_past() {
        let recs = vec![make_recording(
            "r1",
            "CH",
            "Show",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false,
            0,
        )];

        let now = dt("2026-02-16 22:00:00");
        let ids = find_recordings_to_start(&recs, now);
        assert!(ids.is_empty());
    }

    // ── Recurring: every-day bitmask ────────────────

    #[test]
    fn expand_every_day_bitmask() {
        // All 7 bits set: 0b1111111 = 127.
        let rec = make_recording(
            "r1",
            "CH",
            "Daily",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            true,
            127,
        );

        // Now is Mon 16 Feb at 10:00 — all 7 days'
        // 20:00 instances are in the future.
        let now = dt("2026-02-16 10:00:00");
        let instances = expand_recurring_recordings(&[rec], now);
        assert_eq!(instances.len(), 7);

        // Verify each day has an instance.
        for (i, inst) in instances.iter().enumerate() {
            use chrono::Datelike;
            let expected_day = 16 + i as u32;
            assert_eq!(inst.start_time.date().day(), expected_day,);
        }
    }

    // ── Recurring: weekday-only bitmask ─────────────

    #[test]
    fn expand_weekday_only_bitmask() {
        // Mon–Fri: bits 0–4 = 0b0011111 = 31.
        let rec = make_recording(
            "r1",
            "CH",
            "Weekday",
            "2026-02-16 18:00:00",
            "2026-02-16 19:00:00",
            "scheduled",
            true,
            31,
        );

        // Mon 16 Feb at 10:00.
        let now = dt("2026-02-16 10:00:00");
        let instances = expand_recurring_recordings(&[rec], now);

        // Mon 16, Tue 17, Wed 18, Thu 19, Fri 20 = 5.
        // Sat 21, Sun 22 are excluded.
        assert_eq!(instances.len(), 5);
        // Verify Saturday/Sunday are absent.
        for inst in &instances {
            use chrono::Datelike;
            let wd = inst.start_time.date().weekday().num_days_from_monday();
            assert!(wd < 5, "Weekday only — got {wd}");
        }
    }

    // ── Recurring: single-day bitmask ───────────────

    #[test]
    fn expand_single_day_sunday_only() {
        // Sunday = bit 6 = 64.
        let rec = make_recording(
            "r1",
            "CH",
            "Sunday Show",
            "2026-02-16 12:00:00",
            "2026-02-16 13:00:00",
            "scheduled",
            true,
            64,
        );

        // Mon 16 Feb at 10:00, 7-day window → Sun 22.
        let now = dt("2026-02-16 10:00:00");
        let instances = expand_recurring_recordings(&[rec], now);

        assert_eq!(instances.len(), 1);
        // Sun 22 Feb 2026.
        assert_eq!(instances[0].start_time, dt("2026-02-22 12:00:00"),);
    }

    // ── Conflict: adjacent non-overlapping ──────────

    #[test]
    fn no_conflict_adjacent_time_slots() {
        // Existing: 20:00–21:00.
        let existing = make_recording(
            "r1",
            "BBC One",
            "News",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false,
            0,
        );

        // Candidate starts exactly when existing ends.
        let has_conflict = detect_recording_conflict(
            &[existing],
            None,
            "BBC One",
            dt("2026-02-16 21:00:00"),
            dt("2026-02-16 22:00:00"),
        );
        assert!(!has_conflict, "Adjacent slots should not conflict",);
    }

    // ── Conflict: exact same time slot ──────────────

    #[test]
    fn conflict_exact_same_time_slot() {
        let existing = make_recording(
            "r1",
            "BBC One",
            "News",
            "2026-02-16 20:00:00",
            "2026-02-16 21:00:00",
            "scheduled",
            false,
            0,
        );

        // Candidate has identical start and end.
        let has_conflict = detect_recording_conflict(
            &[existing],
            None,
            "BBC One",
            dt("2026-02-16 20:00:00"),
            dt("2026-02-16 21:00:00"),
        );
        assert!(has_conflict, "Identical time slots must conflict",);
    }

    // ── Conflict: nested recording ──────────────────

    #[test]
    fn conflict_nested_recording_inside_another() {
        // Existing: 19:00–22:00.
        let existing = make_recording(
            "r1",
            "BBC One",
            "Movie",
            "2026-02-16 19:00:00",
            "2026-02-16 22:00:00",
            "scheduled",
            false,
            0,
        );

        // Candidate: 20:00–21:00, fully inside.
        let has_conflict = detect_recording_conflict(
            &[existing],
            None,
            "BBC One",
            dt("2026-02-16 20:00:00"),
            dt("2026-02-16 21:00:00"),
        );
        assert!(has_conflict, "Nested recording must conflict",);
    }

    // ── Find recordings: none ready ─────────────────

    #[test]
    fn find_recordings_none_ready() {
        let recs = vec![
            // Future — not yet started.
            make_recording(
                "r1",
                "CH",
                "Future",
                "2026-02-16 22:00:00",
                "2026-02-16 23:00:00",
                "scheduled",
                false,
                0,
            ),
            // Past — already ended.
            make_recording(
                "r2",
                "CH",
                "Past",
                "2026-02-16 18:00:00",
                "2026-02-16 19:00:00",
                "scheduled",
                false,
                0,
            ),
            // Current but already recording.
            make_recording(
                "r3",
                "CH",
                "Active",
                "2026-02-16 20:00:00",
                "2026-02-16 21:00:00",
                "recording",
                false,
                0,
            ),
        ];

        let now = dt("2026-02-16 20:30:00");
        let ids = find_recordings_to_start(&recs, now);
        assert!(ids.is_empty(), "No scheduled recordings in current window",);
    }

    // ── get_recordings_to_start (JSON variant) ──────

    #[test]
    fn get_recordings_to_start_empty_returns_empty_array() {
        let result = get_recordings_to_start("[]", 1_000_000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert!(ids.is_empty());
    }

    #[test]
    fn get_recordings_to_start_one_in_window_returns_id() {
        let json = r#"[{
            "id": "r1",
            "status": "scheduled",
            "startTime": 900000,
            "endTime": 1100000
        }]"#;
        let result = get_recordings_to_start(json, 1_000_000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert_eq!(ids, vec!["r1"]);
    }

    #[test]
    fn get_recordings_to_start_not_yet_started_returns_empty() {
        // startTime > now_ms → not started yet.
        let json = r#"[{
            "id": "r1",
            "status": "scheduled",
            "startTime": 2000000,
            "endTime": 3000000
        }]"#;
        let result = get_recordings_to_start(json, 1_000_000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert!(ids.is_empty());
    }

    #[test]
    fn get_recordings_to_start_already_ended_returns_empty() {
        // endTime <= now_ms → already ended.
        let json = r#"[{
            "id": "r1",
            "status": "scheduled",
            "startTime": 500000,
            "endTime": 800000
        }]"#;
        let result = get_recordings_to_start(json, 1_000_000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert!(ids.is_empty());
    }

    #[test]
    fn get_recordings_to_start_only_scheduled_returned() {
        // Mix of statuses — only "scheduled" qualifies.
        let json = r#"[
            {"id": "r1", "status": "scheduled",  "startTime": 900000,  "endTime": 1100000},
            {"id": "r2", "status": "recording",  "startTime": 900000,  "endTime": 1100000},
            {"id": "r3", "status": "completed",  "startTime": 900000,  "endTime": 1100000}
        ]"#;
        let result = get_recordings_to_start(json, 1_000_000);
        let ids: Vec<String> = serde_json::from_str(&result).unwrap();
        assert_eq!(ids, vec!["r1"]);
    }

    #[test]
    fn get_recordings_to_start_multiple_in_window_all_returned() {
        // Multiple scheduled recordings in the current window.
        let json = r#"[
            {"id": "r1", "status": "scheduled", "startTime": 800000, "endTime": 1200000},
            {"id": "r2", "status": "scheduled", "startTime": 850000, "endTime": 1300000},
            {"id": "r3", "status": "scheduled", "startTime": 1100000, "endTime": 1500000}
        ]"#;
        let result = get_recordings_to_start(json, 1_000_000);
        let mut ids: Vec<String> = serde_json::from_str(&result).unwrap();
        ids.sort();
        assert_eq!(ids, vec!["r1", "r2"]);
    }

    // ── Find recordings: multiple simultaneous ──────

    #[test]
    fn find_recordings_multiple_simultaneous() {
        let recs = vec![
            make_recording(
                "r1",
                "BBC One",
                "News",
                "2026-02-16 20:00:00",
                "2026-02-16 21:00:00",
                "scheduled",
                false,
                0,
            ),
            make_recording(
                "r2",
                "CNN",
                "Breaking",
                "2026-02-16 20:00:00",
                "2026-02-16 21:00:00",
                "scheduled",
                false,
                0,
            ),
            make_recording(
                "r3",
                "ITV",
                "Drama",
                "2026-02-16 20:00:00",
                "2026-02-16 21:00:00",
                "scheduled",
                false,
                0,
            ),
        ];

        let now = dt("2026-02-16 20:30:00");
        let ids = find_recordings_to_start(&recs, now);
        assert_eq!(ids.len(), 3);
        assert!(ids.contains(&"r1".to_string()));
        assert!(ids.contains(&"r2".to_string()));
        assert!(ids.contains(&"r3".to_string()));
    }
}
