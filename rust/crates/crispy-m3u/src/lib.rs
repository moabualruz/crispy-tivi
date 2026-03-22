//! High-performance M3U/M3U8 playlist parser and writer.
//!
//! A faithful Rust translation of the TypeScript library `@iptv/playlist`.
//! Parses `#EXTM3U` playlists into structured data and writes them back.
//!
//! # Example
//!
//! ```
//! use crispy_m3u::{parse, write};
//!
//! let content = "#EXTM3U\n#EXTINF:-1 tvg-id=\"ch1\" group-title=\"News\",CNN\nhttp://example.com/cnn\n";
//! let playlist = parse(content).unwrap();
//! assert_eq!(playlist.entries.len(), 1);
//! assert_eq!(playlist.entries[0].name.as_deref(), Some("CNN"));
//!
//! let output = write(&playlist);
//! assert!(output.starts_with("#EXTM3U"));
//! ```

pub mod error;
pub mod id;
pub mod parser;
pub mod types;
pub mod writer;

pub use error::M3uError;
pub use id::generate_stable_id;
pub use parser::parse;
pub use types::{M3uEntry, M3uHeader, M3uPlaylist};
pub use writer::write;
