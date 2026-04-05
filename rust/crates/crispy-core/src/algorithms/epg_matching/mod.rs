//! EPG-to-channel matching using 6 strategies with
//! script-mismatch filtering.
//!
//! Ports the matching logic from Dart
//! `playlist_sync_service.dart` (lines 630-803).

mod matching;
mod merge;
mod scoring;
mod types;

// Re-export all public items to maintain the same public API.
pub use matching::match_epg_to_channels;
pub use merge::{filter_upcoming_programs, merge_epg_window};
pub use scoring::match_epg_with_confidence;
pub use types::{EpgMatchCandidate, EpgMatchResult, EpgMatchStats, MatchStrategy};

/// Shared test helpers used by submodule tests.
#[cfg(test)]
pub(crate) mod tests {
    use crate::algorithms::normalize::EPG_FORMAT;
    use crate::models::{Channel, EpgEntry};
    use chrono::NaiveDateTime;

    pub fn make_channel(
        id: &str,
        name: &str,
        tvg_id: Option<&str>,
        tvg_name: Option<&str>,
    ) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: format!("http://example.com/{id}"),
            number: None,
            channel_group: None,
            logo_url: None,
            tvg_id: tvg_id.map(String::from),
            tvg_name: tvg_name.map(String::from),
            is_favorite: false,
            user_agent: None,
            has_catchup: false,
            catchup_days: 0,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
            is_247: false,
            tvg_shift: None,
            tvg_language: None,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: None,
            is_adult: false,
            custom_sid: None,
            direct_source: None,
            ..Default::default()
        }
    }

    pub fn make_epg(channel_id: &str, title: &str) -> EpgEntry {
        let start = NaiveDateTime::parse_from_str("2024-02-16 15:00:00", EPG_FORMAT).unwrap();
        let end = NaiveDateTime::parse_from_str("2024-02-16 16:00:00", EPG_FORMAT).unwrap();
        EpgEntry {
            epg_channel_id: channel_id.to_string(),
            title: title.to_string(),
            start_time: start,
            end_time: end,
            ..EpgEntry::default()
        }
    }
}
