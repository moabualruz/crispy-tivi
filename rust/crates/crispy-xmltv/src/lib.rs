//! Streaming XMLTV/EPG parser and writer.
//!
//! Faithfully translates the `@iptv/xmltv` TypeScript library into Rust,
//! using `quick_xml` event-based parsing for efficient handling of 100 MB+
//! EPG files without buffering the entire DOM.
//!
//! # Usage
//!
//! ```rust
//! use crispy_xmltv::{parse, write};
//!
//! let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
//! <tv>
//!   <channel id="ch1">
//!     <display-name>Channel One</display-name>
//!   </channel>
//!   <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
//!     <title>Test Show</title>
//!   </programme>
//! </tv>"#;
//!
//! let doc = parse(xml).unwrap();
//! assert_eq!(doc.channels.len(), 1);
//! assert_eq!(doc.programmes.len(), 1);
//!
//! let output = write(&doc);
//! assert!(output.contains("<channel id=\"ch1\">"));
//! ```

pub mod compression;
pub mod episode;
pub mod error;
pub mod parser;
pub mod timestamp;
pub mod types;
pub mod writer;

pub use compression::decompress_auto;
pub use episode::{EpisodeInfo, parse_episode_number};
pub use error::XmltvError;
pub use parser::{parse, parse_compressed, parse_reader};
pub use types::XmltvDocument;
pub use writer::write;
