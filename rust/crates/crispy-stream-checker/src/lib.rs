//! Concurrent IPTV stream validation library.
//!
//! Validates M3U/IPTV stream URLs by performing HTTP HEAD (with GET fallback)
//! requests with bounded concurrency. Inspired by
//! [`iptv-checker-module`](https://github.com/detroitenglish/iptv-checker-module)
//! and [`IPTVChecker-Python`](https://github.com/kristofferR/IPTVChecker-Python).
//!
//! # Example
//!
//! ```no_run
//! # async fn example() {
//! use crispy_stream_checker::{check_stream, check_bulk, CheckOptions};
//!
//! let opts = CheckOptions::default();
//!
//! // Single stream
//! let result = check_stream("http://example.com/stream.m3u8", &opts).await;
//! println!("available: {}", result.info.available);
//!
//! // Bulk check with progress
//! let urls = vec!["http://a.com/1".into(), "http://b.com/2".into()];
//! let report = check_bulk(&urls, &opts).await;
//! println!("{}/{} available", report.available, report.total);
//! # }
//! ```

pub mod backoff;
pub mod checker;
pub mod checkpoint;
pub mod csv;
pub mod dedup;
pub mod error;
pub mod normalize;
pub mod proxy;
pub mod status;
pub mod types;

pub use backoff::BackoffStrategy;
pub use checker::{check_bulk, check_bulk_with_progress, check_stream, check_stream_named};
pub use checkpoint::CheckpointWriter;
pub use csv::sanitize_csv_field;
pub use dedup::UrlDeduplicator;
pub use error::{CheckerError, summarize_error, summarize_error_str};
pub use normalize::{normalize_url_for_hash, url_resume_hash};
pub use proxy::parse_proxy_list;
pub use status::{categorize_status, meets_data_threshold};
pub use types::{BulkCheckReport, CheckOptions, CheckResult, StreamCategory, StreamInfo};
