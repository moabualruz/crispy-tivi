//! Watch history filtering algorithms.
//!
//! Ports `getContinueWatching` and `getFromOtherDevices`
//! from Dart `watch_history_service.dart`.
//! Also ports streak/stats/merge/filter helpers from
//! profiles and favorites domain utils.

mod badge;
mod continue_watching;
mod merge;
mod series;
mod streak;

pub use badge::{THIRTY_DAYS_MS, vod_badge_kind};
pub use continue_watching::{
    derive_watch_history_id, filter_by_cw_status, filter_continue_watching, filter_cross_device,
};
pub use merge::merge_dedup_sort_history;
pub use series::{
    count_in_progress_episodes, episode_count_by_season, resolve_next_episodes,
    series_ids_with_new_episodes,
};
pub use streak::{ProfileStats, compute_profile_stats, compute_watch_streak};
