//! EPG time formatting utilities.
//!
//! Ported from Dart `TimezoneUtils` (143 lines, 8 methods).
//! Formats timestamps for EPG display with timezone offset.

use chrono::{DateTime, Datelike, Offset, Timelike, Utc};
use chrono_tz::Tz;

/// Day-of-week abbreviations (Mon=0 .. Sun=6).
const DAYS: [&str; 7] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/// Month abbreviations (Jan=1 .. Dec=12, index 0 unused).
const MONTHS: [&str; 13] = [
    "", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

/// Format a Unix timestamp (milliseconds) as "HH:MM" in
/// the given timezone offset (hours from UTC).
///
/// Fractional offsets (e.g. 5.5 for IST) are supported.
pub fn format_epg_time(timestamp_ms: i64, offset_hours: f64) -> String {
    let dt = apply_offset(timestamp_ms, offset_hours);
    format!("{:02}:{:02}", dt.hour(), dt.minute())
}

/// Format a Unix timestamp (milliseconds) as
/// "Day DD Mon HH:MM" in the given timezone offset.
///
/// Example: "Mon 15 Jan 14:30"
pub fn format_epg_datetime(timestamp_ms: i64, offset_hours: f64) -> String {
    let dt = apply_offset(timestamp_ms, offset_hours);

    let day_name = DAYS[dt.weekday().num_days_from_monday() as usize];
    let month_name = MONTHS[dt.month() as usize];

    format!(
        "{} {:02} {} {:02}:{:02}",
        day_name,
        dt.day(),
        month_name,
        dt.hour(),
        dt.minute(),
    )
}

/// Format duration in minutes as "Xh Ym" or just "Ym".
///
/// - 0 → "0m"
/// - 45 → "45m"
/// - 60 → "1h 0m"
/// - 150 → "2h 30m"
pub fn format_duration_minutes(minutes: i32) -> String {
    if minutes < 60 {
        format!("{}m", minutes)
    } else {
        let h = minutes / 60;
        let m = minutes % 60;
        format!("{}h {}m", h, m)
    }
}

/// Calculate duration between two timestamps in minutes.
///
/// Returns `(end_ms - start_ms) / 60_000` as integer
/// (truncated towards zero).
pub fn duration_between_ms(start_ms: i64, end_ms: i64) -> i32 {
    ((end_ms - start_ms) / 60_000) as i32
}

/// Formats a playback position as "HH:MM:SS" or "MM:SS".
///
/// Hours are shown only when `duration_ms` (the total media length)
/// is >= 1 hour (3 600 000 ms). The position values are derived
/// from `position_ms`, clamped to zero if negative.
/// All fields are zero-padded to 2 digits.
///
/// This mirrors the Dart `formatPlaybackDuration(Duration)` behaviour:
/// the total-media length drives the hours flag; the current position
/// drives the displayed H/M/S values.
pub fn format_playback_duration(position_ms: i64, duration_ms: i64) -> String {
    let total_secs = (position_ms.max(0) / 1_000) as u64;
    let hours = total_secs / 3_600;
    let minutes = (total_secs % 3_600) / 60;
    let seconds = total_secs % 60;

    let show_hours = duration_ms >= 3_600_000;
    if show_hours {
        format!("{hours:02}:{minutes:02}:{seconds:02}")
    } else {
        format!("{minutes:02}:{seconds:02}")
    }
}

// ── DST-aware timezone functions ─────────────────

/// Returns the UTC offset in minutes for the given IANA timezone name
/// at the given epoch millisecond. DST-aware via chrono-tz.
///
/// Returns 0 for unknown timezone names, "system" (handled Dart-side),
/// "UTC", invalid input, or epoch values that can't be represented.
pub fn get_timezone_offset_minutes(tz_name: &str, epoch_ms: i64) -> i32 {
    if tz_name.is_empty() || tz_name == "system" || tz_name == "UTC" {
        return 0;
    }
    let tz: Tz = match tz_name.parse() {
        Ok(t) => t,
        Err(_) => return 0,
    };
    let secs = epoch_ms.div_euclid(1_000);
    let nanos = (epoch_ms.rem_euclid(1_000) * 1_000_000) as u32;
    let utc_dt = match DateTime::from_timestamp(secs, nanos) {
        Some(dt) => dt,
        None => return 0,
    };
    let local_dt = utc_dt.with_timezone(&tz);
    let offset_secs = local_dt.offset().fix().local_minus_utc();
    offset_secs / 60
}

/// Applies the DST-aware timezone offset to a UTC epoch_ms,
/// returning adjusted epoch_ms for display purposes.
///
/// Returns `epoch_ms` unchanged for "system", "UTC", unknown,
/// or unrepresentable inputs.
pub fn apply_timezone_offset(epoch_ms: i64, tz_name: &str) -> i64 {
    let offset_minutes = get_timezone_offset_minutes(tz_name, epoch_ms);
    epoch_ms + (offset_minutes as i64) * 60_000
}

/// Formats epoch_ms as "HH:MM:SS" in the given IANA timezone. DST-aware.
///
/// Falls back to UTC formatting for "system", "UTC", unknown timezones,
/// or unrepresentable epoch values.
pub fn format_time_with_seconds(epoch_ms: i64, tz_name: &str) -> String {
    if tz_name.is_empty() || tz_name == "system" || tz_name == "UTC" {
        let secs = epoch_ms.div_euclid(1_000);
        let nanos = (epoch_ms.rem_euclid(1_000) * 1_000_000) as u32;
        let dt = DateTime::from_timestamp(secs, nanos).unwrap_or_default();
        return format!("{:02}:{:02}:{:02}", dt.hour(), dt.minute(), dt.second());
    }
    let tz: Tz = match tz_name.parse() {
        Ok(t) => t,
        Err(_) => {
            let secs = epoch_ms.div_euclid(1_000);
            let nanos = (epoch_ms.rem_euclid(1_000) * 1_000_000) as u32;
            let dt = DateTime::from_timestamp(secs, nanos).unwrap_or_default();
            return format!("{:02}:{:02}:{:02}", dt.hour(), dt.minute(), dt.second());
        }
    };
    let secs = epoch_ms.div_euclid(1_000);
    let nanos = (epoch_ms.rem_euclid(1_000) * 1_000_000) as u32;
    let utc_dt = match DateTime::from_timestamp(secs, nanos) {
        Some(dt) => dt,
        None => return "00:00:00".to_string(),
    };
    let local_dt = utc_dt.with_timezone(&tz);
    format!(
        "{:02}:{:02}:{:02}",
        local_dt.hour(),
        local_dt.minute(),
        local_dt.second(),
    )
}

// ── Internal helpers ─────────────────────────────

/// Convert timestamp_ms + offset_hours into a
/// chrono DateTime<Utc> (shifted by offset for display).
///
/// Handles negative epoch milliseconds gracefully by
/// using `rem_euclid` for the sub-second component,
/// ensuring the nanoseconds value is always non-negative.
fn apply_offset(timestamp_ms: i64, offset_hours: f64) -> DateTime<Utc> {
    let offset_ms = (offset_hours * 3_600_000.0) as i64;
    let adjusted_ms = timestamp_ms + offset_ms;
    let secs = adjusted_ms.div_euclid(1_000);
    let nanos = (adjusted_ms.rem_euclid(1_000) * 1_000_000) as u32;
    DateTime::from_timestamp(secs, nanos).unwrap_or_default()
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // 2025-01-15 12:00:00 UTC in milliseconds.
    const NOON_UTC_MS: i64 = 1_736_942_400_000;

    #[test]
    fn format_time_utc() {
        let result = format_epg_time(NOON_UTC_MS, 0.0);
        assert_eq!(result, "12:00");
    }

    #[test]
    fn format_time_positive_offset() {
        // UTC+3 → 15:00
        let result = format_epg_time(NOON_UTC_MS, 3.0);
        assert_eq!(result, "15:00");
    }

    #[test]
    fn format_time_negative_offset() {
        // UTC-5 → 07:00
        let result = format_epg_time(NOON_UTC_MS, -5.0);
        assert_eq!(result, "07:00");
    }

    #[test]
    fn format_time_fractional_offset() {
        // UTC+5.5 (IST) → 17:30
        let result = format_epg_time(NOON_UTC_MS, 5.5);
        assert_eq!(result, "17:30");
    }

    #[test]
    fn format_datetime_utc() {
        // 2025-01-15 is a Wednesday.
        let result = format_epg_datetime(NOON_UTC_MS, 0.0);
        assert_eq!(result, "Wed 15 Jan 12:00");
    }

    #[test]
    fn format_datetime_crosses_day_boundary() {
        // UTC+14 → 2025-01-16 02:00 (Thursday).
        let result = format_epg_datetime(NOON_UTC_MS, 14.0);
        assert_eq!(result, "Thu 16 Jan 02:00");
    }

    #[test]
    fn duration_zero_minutes() {
        assert_eq!(format_duration_minutes(0), "0m");
    }

    #[test]
    fn duration_under_hour() {
        assert_eq!(format_duration_minutes(59), "59m");
    }

    #[test]
    fn duration_exactly_one_hour() {
        assert_eq!(format_duration_minutes(60), "1h 0m");
    }

    #[test]
    fn duration_mixed() {
        assert_eq!(format_duration_minutes(150), "2h 30m",);
    }

    #[test]
    fn duration_between_basic() {
        let start = 1_000_000;
        let end = 1_000_000 + 90 * 60_000; // 90 min later
        assert_eq!(duration_between_ms(start, end), 90);
    }

    // ── format_playback_duration ──────────────────────

    #[test]
    fn test_format_playback_duration_short() {
        // 1m 5s position, media < 1h → MM:SS
        assert_eq!(format_playback_duration(65_000, 300_000), "01:05");
    }

    #[test]
    fn test_format_playback_duration_with_hours() {
        // 1h 1m 5s position, 2h media → HH:MM:SS
        assert_eq!(format_playback_duration(3_665_000, 7_200_000), "01:01:05");
    }

    #[test]
    fn test_format_playback_duration_zero() {
        // 0s position, media < 1h → MM:SS
        assert_eq!(format_playback_duration(0, 300_000), "00:00");
    }

    #[test]
    fn test_format_playback_duration_zero_long_media() {
        // 0s position, 2h media → HH:MM:SS
        assert_eq!(format_playback_duration(0, 7_200_000), "00:00:00");
    }

    #[test]
    fn test_format_playback_duration_negative() {
        // negative position clamps to 0, media < 1h → MM:SS
        assert_eq!(format_playback_duration(-1_000, 300_000), "00:00");
    }

    #[test]
    fn test_format_playback_duration_exactly_one_hour_media() {
        // media exactly 1h → show hours
        assert_eq!(format_playback_duration(0, 3_600_000), "00:00:00");
    }

    #[test]
    fn test_format_playback_duration_just_under_one_hour_media() {
        // media just under 1h → no hours
        assert_eq!(format_playback_duration(0, 3_599_999), "00:00");
    }

    // ── DST-aware timezone functions ───────────────────

    // 2025-01-15 12:00:00 UTC (same as NOON_UTC_MS above).
    // 2025-07-15 12:00:00 UTC in milliseconds.
    const JULY_NOON_UTC_MS: i64 = 1_752_580_800_000;

    #[test]
    fn offset_utc_returns_zero() {
        assert_eq!(get_timezone_offset_minutes("UTC", NOON_UTC_MS), 0);
    }

    #[test]
    fn offset_system_returns_zero() {
        // "system" is always handled Dart-side; Rust returns 0.
        assert_eq!(get_timezone_offset_minutes("system", NOON_UTC_MS), 0);
    }

    #[test]
    fn offset_unknown_returns_zero() {
        assert_eq!(get_timezone_offset_minutes("Not/ATimezone", NOON_UTC_MS), 0,);
    }

    #[test]
    fn offset_tokyo_always_plus_540() {
        // Asia/Tokyo is +9h with no DST → 540 minutes always.
        assert_eq!(get_timezone_offset_minutes("Asia/Tokyo", NOON_UTC_MS), 540,);
        assert_eq!(
            get_timezone_offset_minutes("Asia/Tokyo", JULY_NOON_UTC_MS),
            540,
        );
    }

    #[test]
    fn offset_new_york_winter_is_minus_300() {
        // America/New_York in January → EST = UTC-5 = -300 minutes.
        assert_eq!(
            get_timezone_offset_minutes("America/New_York", NOON_UTC_MS),
            -300,
        );
    }

    #[test]
    fn offset_new_york_summer_is_minus_240() {
        // America/New_York in July → EDT = UTC-4 = -240 minutes.
        assert_eq!(
            get_timezone_offset_minutes("America/New_York", JULY_NOON_UTC_MS),
            -240,
        );
    }

    #[test]
    fn offset_kolkata_is_plus_330() {
        // Asia/Kolkata is +5:30 → 330 minutes (no DST).
        assert_eq!(
            get_timezone_offset_minutes("Asia/Kolkata", NOON_UTC_MS),
            330,
        );
    }

    #[test]
    fn apply_offset_tokyo_adjusts_epoch() {
        // +9h = 540 min × 60_000 ms = 32_400_000 ms added.
        let result = apply_timezone_offset(NOON_UTC_MS, "Asia/Tokyo");
        assert_eq!(result, NOON_UTC_MS + 540 * 60_000);
    }

    #[test]
    fn apply_offset_system_unchanged() {
        assert_eq!(apply_timezone_offset(NOON_UTC_MS, "system"), NOON_UTC_MS);
    }

    #[test]
    fn apply_offset_utc_unchanged() {
        assert_eq!(apply_timezone_offset(NOON_UTC_MS, "UTC"), NOON_UTC_MS);
    }

    #[test]
    fn format_time_seconds_utc_noon() {
        // 2025-01-15 12:00:00 UTC → "12:00:00"
        assert_eq!(format_time_with_seconds(NOON_UTC_MS, "UTC"), "12:00:00",);
    }

    #[test]
    fn format_time_seconds_tokyo() {
        // UTC 12:00 + 9h = 21:00 → "21:00:00"
        assert_eq!(
            format_time_with_seconds(NOON_UTC_MS, "Asia/Tokyo"),
            "21:00:00",
        );
    }

    #[test]
    fn format_time_seconds_new_york_winter() {
        // UTC 12:00 - 5h = 07:00 → "07:00:00"
        assert_eq!(
            format_time_with_seconds(NOON_UTC_MS, "America/New_York"),
            "07:00:00",
        );
    }

    #[test]
    fn format_time_seconds_unknown_falls_back_to_utc() {
        // Unknown tz → UTC fallback → "12:00:00"
        assert_eq!(
            format_time_with_seconds(NOON_UTC_MS, "Not/ATimezone"),
            "12:00:00",
        );
    }
}
