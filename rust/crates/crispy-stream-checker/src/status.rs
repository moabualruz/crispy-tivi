//! Stream status categorization from HTTP status codes.
//!
//! Translated from IPTVChecker-Python `check_channel_status()` HTTP status
//! classification logic.

use crate::types::StreamCategory;

/// HTTP status codes that indicate the stream should be retried.
///
/// From IPTVChecker-Python: `retryable_http_statuses = {408, 425, 429, 500, 502, 503, 504}`
const RETRYABLE_STATUSES: &[u16] = &[408, 425, 429, 500, 502, 503, 504];

/// HTTP status codes that indicate a primary geoblock.
///
/// From IPTVChecker-Python: `geoblock_statuses = {403, 451, 426}`
const GEOBLOCK_STATUSES: &[u16] = &[403, 426, 451];

/// HTTP status codes that indicate a secondary geoblock.
///
/// From IPTVChecker-Python: `secondary_geoblock_statuses = {401, 423, 451}`
const SECONDARY_GEOBLOCK_STATUSES: &[u16] = &[401, 423, 451];

/// Categorize a stream from its HTTP status code.
///
/// Translation of the status categorization logic from IPTVChecker-Python's
/// `check_channel_status()` → `verify()` inner function:
///
/// - 200-299: Check data threshold → `Alive`
/// - 403, 426, 451: `Geoblocked` (primary)
/// - 401, 423: `Geoblocked` (secondary)
/// - 408, 425, 429, 500, 502-504: `Retry`
/// - All others: `Dead`
pub fn categorize_status(status_code: u16) -> StreamCategory {
    if (200..300).contains(&status_code) {
        // 2xx — alive pending data threshold check
        return StreamCategory::Alive;
    }

    if GEOBLOCK_STATUSES.contains(&status_code) {
        return StreamCategory::Geoblocked;
    }

    if RETRYABLE_STATUSES.contains(&status_code) {
        return StreamCategory::Retry;
    }

    // Secondary geoblock check (401, 423) — checked after retryable
    // because 451 is in both sets but handled above as primary geoblock.
    if SECONDARY_GEOBLOCK_STATUSES.contains(&status_code) {
        return StreamCategory::Geoblocked;
    }

    StreamCategory::Dead
}

/// Check whether the received byte count meets the minimum data threshold.
///
/// From IPTVChecker-Python:
/// - Direct streams (depth 0): 500 KB (`min_data_threshold = 1024 * 500`)
/// - Nested segments: 128 KB (`playlist_segment_threshold = 1024 * 128`)
pub fn meets_data_threshold(bytes_received: u64, min_bytes: u64) -> bool {
    bytes_received >= min_bytes
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn categorize_200_as_alive() {
        assert_eq!(categorize_status(200), StreamCategory::Alive);
    }

    #[test]
    fn categorize_204_as_alive() {
        assert_eq!(categorize_status(204), StreamCategory::Alive);
    }

    #[test]
    fn categorize_403_as_geoblocked() {
        assert_eq!(categorize_status(403), StreamCategory::Geoblocked);
    }

    #[test]
    fn categorize_451_as_geoblocked() {
        assert_eq!(categorize_status(451), StreamCategory::Geoblocked);
    }

    #[test]
    fn categorize_426_as_geoblocked() {
        assert_eq!(categorize_status(426), StreamCategory::Geoblocked);
    }

    #[test]
    fn categorize_401_as_geoblocked_secondary() {
        assert_eq!(categorize_status(401), StreamCategory::Geoblocked);
    }

    #[test]
    fn categorize_423_as_geoblocked_secondary() {
        assert_eq!(categorize_status(423), StreamCategory::Geoblocked);
    }

    #[test]
    fn categorize_429_as_retry() {
        assert_eq!(categorize_status(429), StreamCategory::Retry);
    }

    #[test]
    fn categorize_500_as_retry() {
        assert_eq!(categorize_status(500), StreamCategory::Retry);
    }

    #[test]
    fn categorize_502_as_retry() {
        assert_eq!(categorize_status(502), StreamCategory::Retry);
    }

    #[test]
    fn categorize_503_as_retry() {
        assert_eq!(categorize_status(503), StreamCategory::Retry);
    }

    #[test]
    fn categorize_504_as_retry() {
        assert_eq!(categorize_status(504), StreamCategory::Retry);
    }

    #[test]
    fn categorize_404_as_dead() {
        assert_eq!(categorize_status(404), StreamCategory::Dead);
    }

    #[test]
    fn categorize_410_as_dead() {
        assert_eq!(categorize_status(410), StreamCategory::Dead);
    }

    #[test]
    fn data_threshold_met() {
        assert!(meets_data_threshold(512_000, 512_000));
        assert!(meets_data_threshold(600_000, 512_000));
    }

    #[test]
    fn data_threshold_not_met() {
        assert!(!meets_data_threshold(100_000, 512_000));
        assert!(!meets_data_threshold(0, 131_072));
    }
}
