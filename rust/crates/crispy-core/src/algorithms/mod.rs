//! Algorithm modules for CrispyTivi core logic.
//!
//! Each module ports a specific algorithm from the Dart
//! codebase to Rust for performance-critical paths.

pub use normalize::EPG_FORMAT;

pub mod catchup;
pub mod categories;
pub mod cloud_sync;
pub mod config_merge;
pub mod crypto;
pub mod dedup;
pub mod dvr;
pub mod epg_matching;
pub mod group_icon;
pub mod json_utils;
pub mod normalize;
pub mod permission;
pub mod pin;
pub mod recommendations;
pub mod search;
pub mod search_grouping;
pub mod sorting;
pub mod source_filter;
pub mod timezone;
pub mod url_normalize;
pub mod vod_sorting;
pub mod watch_history;
pub mod watch_progress;
