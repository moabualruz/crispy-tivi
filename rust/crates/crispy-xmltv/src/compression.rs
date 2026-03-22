//! Auto-detect and decompress gzip / XZ compressed XMLTV data.
//!
//! Faithfully translated from pvr.iptvsimple:
//! - `Epg::FillBufferFromXMLTVData()` — magic-byte detection
//! - `FileUtils::GzipInflate()` — zlib decompression
//! - `FileUtils::XzDecompress()` — LZMA/XZ decompression

use std::io::Read;

use crate::error::XmltvError;

/// Gzip magic bytes: `\x1F\x8B`.
const GZIP_MAGIC: [u8; 2] = [0x1F, 0x8B];

/// XZ magic bytes: `\xFD 7 z X Z \x00`.
const XZ_MAGIC: [u8; 6] = [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00];

/// Check whether `data` starts with the gzip magic bytes (`\x1F\x8B`).
pub fn is_gzip(data: &[u8]) -> bool {
    data.len() >= 2 && data[..2] == GZIP_MAGIC
}

/// Check whether `data` starts with the XZ magic bytes (`\xFD7zXZ\x00`).
pub fn is_xz(data: &[u8]) -> bool {
    data.len() >= 6 && data[..6] == XZ_MAGIC
}

/// Auto-detect compression format and decompress.
///
/// - Bytes starting with `\x1F\x8B` are treated as gzip.
/// - Bytes starting with `\xFD7zXZ\x00` are treated as XZ/LZMA.
/// - Everything else is returned as-is (uncompressed passthrough).
///
/// Translated from `Epg::FillBufferFromXMLTVData` in pvr.iptvsimple.
pub fn decompress_auto(data: &[u8]) -> Result<Vec<u8>, XmltvError> {
    if is_gzip(data) {
        decompress_gzip(data)
    } else if is_xz(data) {
        decompress_xz(data)
    } else {
        Ok(data.to_vec())
    }
}

/// Decompress gzip data.
///
/// Translated from `FileUtils::GzipInflate` in pvr.iptvsimple.
/// Uses `flate2` with `GzDecoder` which handles the gzip header
/// and dynamic buffer expansion internally.
pub fn decompress_gzip(data: &[u8]) -> Result<Vec<u8>, XmltvError> {
    if data.is_empty() {
        return Ok(Vec::new());
    }

    let mut decoder = flate2::read::GzDecoder::new(data);
    let mut decompressed = Vec::with_capacity(data.len() * 2);
    decoder
        .read_to_end(&mut decompressed)
        .map_err(|e| XmltvError::Decompression(format!("gzip decompression failed: {e}")))?;

    Ok(decompressed)
}

/// Decompress XZ/LZMA data.
///
/// Translated from `FileUtils::XzDecompress` in pvr.iptvsimple.
/// Uses `xz2` with `XzDecoder` which handles stream decoding
/// and chunked output internally.
pub fn decompress_xz(data: &[u8]) -> Result<Vec<u8>, XmltvError> {
    if data.is_empty() {
        return Ok(Vec::new());
    }

    let mut decoder = xz2::read::XzDecoder::new(data);
    let mut decompressed = Vec::with_capacity(data.len() * 4);
    decoder
        .read_to_end(&mut decompressed)
        .map_err(|e| XmltvError::Decompression(format!("XZ decompression failed: {e}")))?;

    Ok(decompressed)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Helper: compress `data` with gzip for round-trip tests.
    fn gzip_compress(data: &[u8]) -> Vec<u8> {
        use flate2::write::GzEncoder;
        use std::io::Write;

        let mut encoder = GzEncoder::new(Vec::new(), flate2::Compression::fast());
        encoder.write_all(data).unwrap();
        encoder.finish().unwrap()
    }

    /// Helper: compress `data` with XZ for round-trip tests.
    fn xz_compress(data: &[u8]) -> Vec<u8> {
        use std::io::Write;
        use xz2::write::XzEncoder;

        let mut encoder = XzEncoder::new(Vec::new(), 1);
        encoder.write_all(data).unwrap();
        encoder.finish().unwrap()
    }

    #[test]
    fn is_gzip_detects_magic_bytes() {
        let compressed = gzip_compress(b"hello");
        assert!(is_gzip(&compressed));
    }

    #[test]
    fn is_gzip_rejects_plain_text() {
        assert!(!is_gzip(b"plain text"));
    }

    #[test]
    fn is_gzip_rejects_short_input() {
        assert!(!is_gzip(&[0x1F]));
        assert!(!is_gzip(&[]));
    }

    #[test]
    fn is_xz_detects_magic_bytes() {
        let compressed = xz_compress(b"hello");
        assert!(is_xz(&compressed));
    }

    #[test]
    fn is_xz_rejects_plain_text() {
        assert!(!is_xz(b"plain text"));
    }

    #[test]
    fn is_xz_rejects_short_input() {
        assert!(!is_xz(&[0xFD, 0x37, 0x7A]));
        assert!(!is_xz(&[]));
    }

    #[test]
    fn decompress_gzip_roundtrip() {
        let original = b"<?xml version=\"1.0\"?><tv><channel id=\"ch1\"><display-name>Test</display-name></channel></tv>";
        let compressed = gzip_compress(original);
        let decompressed = decompress_gzip(&compressed).unwrap();
        assert_eq!(decompressed, original);
    }

    #[test]
    fn decompress_xz_roundtrip() {
        let original = b"<?xml version=\"1.0\"?><tv><channel id=\"ch1\"><display-name>Test</display-name></channel></tv>";
        let compressed = xz_compress(original);
        let decompressed = decompress_xz(&compressed).unwrap();
        assert_eq!(decompressed, original);
    }

    #[test]
    fn decompress_auto_detects_gzip() {
        let original = b"hello gzip world";
        let compressed = gzip_compress(original);
        let result = decompress_auto(&compressed).unwrap();
        assert_eq!(result, original);
    }

    #[test]
    fn decompress_auto_detects_xz() {
        let original = b"hello xz world";
        let compressed = xz_compress(original);
        let result = decompress_auto(&compressed).unwrap();
        assert_eq!(result, original);
    }

    #[test]
    fn decompress_auto_passthrough_uncompressed() {
        let plain = b"<?xml version=\"1.0\"?><tv></tv>";
        let result = decompress_auto(plain).unwrap();
        assert_eq!(result, plain);
    }

    #[test]
    fn decompress_gzip_empty_input() {
        let result = decompress_gzip(&[]).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn decompress_xz_empty_input() {
        let result = decompress_xz(&[]).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn decompress_gzip_invalid_data_returns_error() {
        // Valid magic bytes but garbage payload.
        let bad = [0x1F, 0x8B, 0x08, 0x00, 0xFF, 0xFF];
        let result = decompress_gzip(&bad);
        assert!(result.is_err());
    }

    #[test]
    fn end_to_end_compressed_gzip_parse() {
        let xmltv = r#"<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="ch1">
    <display-name>Test Channel</display-name>
  </channel>
  <programme start="20250115120000 +0000" stop="20250115130000 +0000" channel="ch1">
    <title>Test Show</title>
  </programme>
</tv>"#;
        let compressed = gzip_compress(xmltv.as_bytes());
        let doc = crate::parse_compressed(&compressed).unwrap();
        assert_eq!(doc.channels.len(), 1);
        assert_eq!(doc.channels[0].id, "ch1");
        assert_eq!(doc.programmes.len(), 1);
        assert_eq!(doc.programmes[0].title[0].value, "Test Show");
    }
}
