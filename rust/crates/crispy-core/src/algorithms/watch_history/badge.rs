//! VOD badge kind determination.

use chrono::{DateTime, Datelike, Utc};

/// The number of milliseconds in 30 days.
pub const THIRTY_DAYS_MS: i64 = 30 * 24 * 60 * 60 * 1_000;

/// Determines the badge label to show on a VOD card.
///
/// Decision priority:
/// 1. If `year` is present and `year >= (now's year − 1)` → `"new_release"`.
/// 2. If `added_at_ms` is present and within the last 30 days → `"new_to_library"`.
/// 3. Otherwise → `"new_to_library"` (fallback for recently-added lists).
///
/// * `year`        — release year of the VOD item.
/// * `added_at_ms` — epoch-ms timestamp when the item was added to the library.
/// * `now_ms`      — current time as epoch-ms (injectable for tests).
///
/// Returns the badge kind string directly (not JSON-wrapped).
pub fn vod_badge_kind(year: Option<i32>, added_at_ms: Option<i64>, now_ms: i64) -> String {
    let now: DateTime<Utc> = DateTime::from_timestamp_millis(now_ms).unwrap_or_default();
    let current_year = now.year();

    if let Some(y) = year
        && y >= current_year - 1
    {
        return "new_release".to_string();
    }

    if let Some(added) = added_at_ms
        && now_ms - added <= THIRTY_DAYS_MS
    {
        return "new_to_library".to_string();
    }

    "new_to_library".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn date_ms(year: i32, month: u32, day: u32) -> i64 {
        chrono::Utc
            .with_ymd_and_hms(year, month, day, 0, 0, 0)
            .unwrap()
            .timestamp_millis()
    }

    #[test]
    fn vod_badge_new_release_by_year_current_year() {
        // year == now's year → "new_release"
        let now = date_ms(2024, 6, 15);
        assert_eq!(vod_badge_kind(Some(2024), None, now), "new_release");
    }

    #[test]
    fn vod_badge_new_release_by_year_last_year() {
        // year == now's year - 1 → "new_release"
        let now = date_ms(2024, 6, 15);
        assert_eq!(vod_badge_kind(Some(2023), None, now), "new_release");
    }

    #[test]
    fn vod_badge_new_to_library_by_date_within_30_days() {
        let now = date_ms(2024, 6, 15);
        let added = now - 10 * 24 * 60 * 60 * 1_000; // 10 days ago
        assert_eq!(vod_badge_kind(None, Some(added), now), "new_to_library");
    }

    #[test]
    fn vod_badge_fallback_when_old_year_and_no_date() {
        let now = date_ms(2024, 6, 15);
        // year 2020 is not >= 2023 (2024-1)
        assert_eq!(vod_badge_kind(Some(2020), None, now), "new_to_library");
    }

    #[test]
    fn vod_badge_year_takes_priority_over_date() {
        // year == current year AND recent date — year rule wins first
        let now = date_ms(2024, 6, 15);
        let added = now - 5 * 24 * 60 * 60 * 1_000; // 5 days ago
        assert_eq!(vod_badge_kind(Some(2024), Some(added), now), "new_release");
    }
}
