//! Async Stalker/MAG portal API client.
//!
//! This crate implements the Stalker middleware portal protocol, a legacy
//! query-string-based API used by MAG set-top-box portals. It handles
//! portal discovery, MAC-based authentication, paginated data fetching,
//! and stream URL resolution.
//!
//! # Usage
//!
//! ```no_run
//! use crispy_stalker::{StalkerClient, StalkerCredentials};
//!
//! # async fn example() -> Result<(), Box<dyn std::error::Error>> {
//! let creds = StalkerCredentials {
//!     base_url: "http://portal.example.com".into(),
//!     mac_address: "00:1A:79:AB:CD:EF".into(),
//!     timezone: None,
//! };
//!
//! let mut client = StalkerClient::new(creds, false)?;
//! client.authenticate().await?;
//!
//! let genres = client.get_genres().await?;
//! for genre in &genres {
//!     let channels = client.get_all_channels(&genre.id, None).await?;
//!     println!("{}: {} channels", genre.title, channels.len());
//! }
//! # Ok(())
//! # }
//! ```

pub mod backoff;
pub mod client;
pub mod device;
pub mod discovery;
pub mod error;
pub mod session;
pub mod types;
pub mod url;

pub use backoff::BackoffConfig;
pub use client::StalkerClient;
pub use error::StalkerError;
pub use session::StalkerSession;
pub use types::{
    PaginatedResult, StalkerAccountInfo, StalkerCategory, StalkerChannel, StalkerCredentials,
    StalkerEpgEntry, StalkerEpisode, StalkerProfile, StalkerSeason, StalkerSeriesDetail,
    StalkerSeriesItem, StalkerVodItem,
};
pub use url::resolve_stream_url;
