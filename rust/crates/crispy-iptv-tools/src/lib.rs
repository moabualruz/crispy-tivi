//! IPTV playlist utilities: filter, merge, dedup, normalize, sort.
//!
//! This crate provides tools for manipulating IPTV playlists built on
//! top of [`crispy_iptv_types`]. Inspired by `huxuan/iptvtools` (Python)
//! and absorbing generic algorithms from `crispy-core`.

pub mod dedup;
pub mod error;
pub mod filter;
pub mod manipulate;
pub mod merge;
pub mod normalize;
pub mod resolution;
pub mod sanitize;
pub mod sort;
pub mod template;
pub mod udpxy;
pub mod unify;

pub use dedup::{DeduplicateStrategy, deduplicate};
pub use error::ToolsError;
pub use filter::{EntryFilter, filter_entries};
pub use manipulate::{append_resolution_to_name, height_to_label, replace_group_by_source};
pub use merge::{merge_entries, merge_entries_raw};
pub use normalize::{extract_base_url, normalize_title, normalize_url};
pub use resolution::detect_resolution;
pub use sanitize::{sanitize_image_url, sanitize_stream_url};
pub use sort::{SortCriteria, SortDirection, SortKey, sort_entries, sort_entries_multi};
pub use template::apply_template;
pub use udpxy::{convert_to_udpxy, is_multicast};
pub use unify::{UnifyConfig, load_unify_config, unify_entries};
