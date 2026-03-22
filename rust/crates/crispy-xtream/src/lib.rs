//! Async Xtream Codes API client.
//!
//! A faithful Rust translation of the [`@iptv/xtream-api`] TypeScript library,
//! providing a typed, async client for Xtream Codes compatible IPTV servers.
//!
//! # Quick Start
//!
//! ```no_run
//! use crispy_xtream::{XtreamClient, XtreamCredentials};
//!
//! # async fn example() -> Result<(), crispy_xtream::XtreamError> {
//! let client = XtreamClient::new(XtreamCredentials::new(
//!     "http://example.com:8080",
//!     "username",
//!     "password",
//! ))?;
//!
//! let profile = client.authenticate().await?;
//! let channels = client.get_live_streams(None).await?;
//! let epg = client.get_short_epg(42, Some(10)).await?;
//! let xmltv_url = client.xmltv_url();
//! # Ok(())
//! # }
//! ```
//!
//! [`@iptv/xtream-api`]: https://github.com/ektotv/xtream-api

pub mod client;
pub mod error;
pub mod parse;
pub mod types;
pub mod url;

// Re-export the public API at crate root for ergonomic imports.
pub use client::{XtreamClient, XtreamClientConfig, XtreamCredentials};
pub use error::XtreamError;
pub use types::{
    StreamFormat, StreamType, XtreamCategory, XtreamChannel, XtreamEpgListing, XtreamEpisode,
    XtreamEpisodeInfo, XtreamFullEpg, XtreamFullEpgListing, XtreamMovie, XtreamMovieData,
    XtreamMovieInfo, XtreamMovieListing, XtreamProfile, XtreamSeason, XtreamServerInfo,
    XtreamShortEpg, XtreamShow, XtreamShowInfo, XtreamShowListing, XtreamUserProfile,
};

pub use crispy_iptv_types;
