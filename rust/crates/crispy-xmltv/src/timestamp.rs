//! XMLTV timestamp parsing and formatting.
//!
//! XMLTV timestamps follow the format `"YYYYMMDDHHmmss ±HHMM"` with
//! variable-length date portions (4, 6, 8, or 14 digits) and optional
//! timezone offsets.

use chrono::{NaiveDate, NaiveDateTime, NaiveTime, TimeDelta};

/// Parse an XMLTV timestamp string into a UTC Unix timestamp (seconds).
///
/// Accepts formats:
/// - `"20250115120000 +0000"` — full with timezone
/// - `"20250115120000"` — full without timezone (assumed UTC)
/// - `"20250115"` — date only (midnight UTC)
/// - `"202501"` — year+month (first day, midnight UTC)
/// - `"2025"` — year only (January 1st, midnight UTC)
///
/// Returns `None` if the string cannot be parsed.
pub fn parse_xmltv_timestamp(s: &str) -> Option<i64> {
    let trimmed = s.trim();
    if trimmed.is_empty() {
        return None;
    }

    // Split into numeric portion and optional timezone offset.
    let (numeric, tz_offset) = split_timestamp_parts(trimmed);

    let dt = parse_datetime(numeric)?;

    // Apply timezone offset to get UTC.
    let utc = dt - tz_offset;

    Some(utc.and_utc().timestamp())
}

/// Format a UTC Unix timestamp (seconds) into XMLTV format.
///
/// Output: `"YYYYMMDDHHmmss +0000"` (always UTC).
pub fn format_xmltv_timestamp(ts: i64) -> String {
    let dt = chrono::DateTime::from_timestamp(ts, 0)
        .unwrap_or(chrono::DateTime::UNIX_EPOCH)
        .naive_utc();

    format!(
        "{:04}{:02}{:02}{:02}{:02}{:02} +0000",
        dt.date().year(),
        dt.date().month(),
        dt.date().day(),
        dt.time().hour(),
        dt.time().minute(),
        dt.time().second(),
    )
}

/// Split timestamp into (numeric_part, timezone_delta).
fn split_timestamp_parts(s: &str) -> (&str, TimeDelta) {
    // Find where the numeric part ends.
    let numeric_end = s.find(|c: char| !c.is_ascii_digit()).unwrap_or(s.len());

    let numeric = &s[..numeric_end];
    let remainder = s[numeric_end..].trim();

    let delta = if remainder.is_empty() {
        TimeDelta::zero()
    } else {
        parse_tz_offset(remainder)
    };

    (numeric, delta)
}

/// Parse timezone offset like "+0530", "-0800", or "Z".
fn parse_tz_offset(s: &str) -> TimeDelta {
    let s = s.trim();
    if s.eq_ignore_ascii_case("z") {
        return TimeDelta::zero();
    }

    if s.len() < 5 {
        return TimeDelta::zero();
    }

    let sign: i64 = if s.starts_with('-') { -1 } else { 1 };

    let hours: i64 = s[1..3].parse().unwrap_or(0);
    let minutes: i64 = s[3..5].parse().unwrap_or(0);

    TimeDelta::minutes(sign * (hours * 60 + minutes))
}

/// Parse the numeric portion of an XMLTV timestamp into a `NaiveDateTime`.
fn parse_datetime(s: &str) -> Option<NaiveDateTime> {
    let len = s.len();

    let year: i32 = s.get(..4)?.parse().ok()?;
    let month: u32 = if len >= 6 { s[4..6].parse().ok()? } else { 1 };
    let day: u32 = if len >= 8 { s[6..8].parse().ok()? } else { 1 };
    let hour: u32 = if len >= 10 { s[8..10].parse().ok()? } else { 0 };
    let minute: u32 = if len >= 12 {
        s[10..12].parse().ok()?
    } else {
        0
    };
    let second: u32 = if len >= 14 {
        s[12..14].parse().ok()?
    } else {
        0
    };

    let date = NaiveDate::from_ymd_opt(year, month, day)?;
    let time = NaiveTime::from_hms_opt(hour, minute, second)?;
    Some(NaiveDateTime::new(date, time))
}

use chrono::Datelike as _;
use chrono::Timelike as _;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_full_utc_timestamp() {
        let ts = parse_xmltv_timestamp("20250115120000 +0000").unwrap();
        // 2025-01-15 12:00:00 UTC
        assert_eq!(ts, 1_736_942_400);
    }

    #[test]
    fn parse_timestamp_with_positive_offset() {
        // +0530 means local time is 5:30 ahead of UTC.
        // 12:00:00 +0530 = 06:30:00 UTC
        let ts = parse_xmltv_timestamp("20250115120000 +0530").unwrap();
        let expected = parse_xmltv_timestamp("20250115063000 +0000").unwrap();
        assert_eq!(ts, expected);
    }

    #[test]
    fn parse_timestamp_with_negative_offset() {
        // -0800 means local time is 8 hours behind UTC.
        // 12:00:00 -0800 = 20:00:00 UTC
        let ts = parse_xmltv_timestamp("20250115120000 -0800").unwrap();
        let expected = parse_xmltv_timestamp("20250115200000 +0000").unwrap();
        assert_eq!(ts, expected);
    }

    #[test]
    fn parse_no_timezone() {
        // Without timezone, assume UTC.
        let ts = parse_xmltv_timestamp("20250115120000").unwrap();
        assert_eq!(ts, 1_736_942_400);
    }

    #[test]
    fn parse_date_only() {
        // "20250115" → 2025-01-15 00:00:00 UTC
        let ts = parse_xmltv_timestamp("20250115").unwrap();
        let expected = parse_xmltv_timestamp("20250115000000 +0000").unwrap();
        assert_eq!(ts, expected);
    }

    #[test]
    fn parse_year_month_only() {
        // "202501" → 2025-01-01 00:00:00 UTC
        let ts = parse_xmltv_timestamp("202501").unwrap();
        let expected = parse_xmltv_timestamp("20250101000000 +0000").unwrap();
        assert_eq!(ts, expected);
    }

    #[test]
    fn parse_year_only() {
        // "2025" → 2025-01-01 00:00:00 UTC
        let ts = parse_xmltv_timestamp("2025").unwrap();
        let expected = parse_xmltv_timestamp("20250101000000 +0000").unwrap();
        assert_eq!(ts, expected);
    }

    #[test]
    fn parse_empty_returns_none() {
        assert!(parse_xmltv_timestamp("").is_none());
        assert!(parse_xmltv_timestamp("  ").is_none());
    }

    #[test]
    fn parse_invalid_returns_none() {
        assert!(parse_xmltv_timestamp("not-a-timestamp").is_none());
        assert!(parse_xmltv_timestamp("20251315120000 +0000").is_none()); // month 13
    }

    #[test]
    fn format_roundtrip() {
        let original = "20250115120000 +0000";
        let ts = parse_xmltv_timestamp(original).unwrap();
        let formatted = format_xmltv_timestamp(ts);
        assert_eq!(formatted, original);
    }

    #[test]
    fn format_epoch() {
        let formatted = format_xmltv_timestamp(0);
        assert_eq!(formatted, "19700101000000 +0000");
    }
}
