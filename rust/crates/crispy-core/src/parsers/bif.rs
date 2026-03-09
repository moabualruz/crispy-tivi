//! BIF (Base Index Frames) trickplay thumbnail parser.
//!
//! BIF files are binary containers holding JPEG thumbnails
//! indexed by timestamp, used by Plex/Emby servers for
//! trickplay preview during seeking.
//!
//! Format:
//! - `0..7`: magic bytes (`0x89 "BIF" 0x0D 0x0A 0x1A 0x0A`)
//! - `8..11`: version (uint32 LE)
//! - `12..15`: image count (uint32 LE)
//! - `16..19`: timestamp multiplier (uint32 LE, ms per unit; 0 = 1000)
//! - `20..63`: reserved
//! - `64..`: index table — (imageCount + 1) entries of 8 bytes each:
//!   `[timestamp (uint32 LE), offset (uint32 LE)]`
//!   Last entry is a sentinel (timestamp = 0xFFFFFFFF).

use serde::{Deserialize, Serialize};

/// Magic header bytes for BIF format.
const BIF_MAGIC: [u8; 8] = [0x89, 0x42, 0x49, 0x46, 0x0D, 0x0A, 0x1A, 0x0A];

/// Minimum BIF file size (header + at least one index entry).
const MIN_BIF_SIZE: usize = 64;

/// Offset where the index table starts.
const INDEX_START: usize = 64;

/// Size of each index entry in bytes.
const INDEX_ENTRY_SIZE: usize = 8;

/// A parsed BIF index entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BifEntry {
    /// Thumbnail timestamp in milliseconds.
    pub timestamp_ms: u64,
    /// Byte offset of the JPEG data in the BIF file.
    pub offset: u32,
    /// Length of the JPEG data in bytes.
    pub length: u32,
}

/// Read a little-endian u32 from a byte slice.
fn read_u32_le(data: &[u8], pos: usize) -> u32 {
    u32::from_le_bytes([data[pos], data[pos + 1], data[pos + 2], data[pos + 3]])
}

/// Parse a BIF file's header and index table.
///
/// Returns a vector of [`BifEntry`] with timestamp, offset, and
/// length for each JPEG frame. Returns an empty vec on invalid
/// input (bad magic, truncated data, etc.).
pub fn parse_bif_index(data: &[u8]) -> Vec<BifEntry> {
    if data.len() < MIN_BIF_SIZE {
        return Vec::new();
    }

    // Validate magic header.
    if data[..8] != BIF_MAGIC {
        return Vec::new();
    }

    let image_count = read_u32_le(data, 12) as usize;
    let mut ts_multiplier = read_u32_le(data, 16) as u64;
    if ts_multiplier == 0 {
        ts_multiplier = 1000;
    }

    // Need (image_count + 1) index entries (last is sentinel).
    let index_table_size = (image_count + 1) * INDEX_ENTRY_SIZE;
    if data.len() < INDEX_START + index_table_size {
        return Vec::new();
    }

    let mut entries = Vec::with_capacity(image_count);

    for i in 0..image_count {
        let entry_offset = INDEX_START + i * INDEX_ENTRY_SIZE;
        let timestamp = read_u32_le(data, entry_offset) as u64;
        let img_offset = read_u32_le(data, entry_offset + 4);

        // Next entry's offset gives the end of this image.
        let next_entry_offset = INDEX_START + (i + 1) * INDEX_ENTRY_SIZE;
        let next_img_offset = read_u32_le(data, next_entry_offset + 4);

        if next_img_offset <= img_offset || next_img_offset as usize > data.len() {
            continue;
        }

        entries.push(BifEntry {
            timestamp_ms: timestamp * ts_multiplier,
            offset: img_offset,
            length: next_img_offset - img_offset,
        });
    }

    entries
}

/// Find the BIF entry nearest to (but not exceeding) the target
/// timestamp using binary search. Returns `None` if entries is
/// empty.
pub fn find_bif_entry(entries: &[BifEntry], timestamp_ms: u64) -> Option<&BifEntry> {
    if entries.is_empty() {
        return None;
    }

    let mut lo = 0usize;
    let mut hi = entries.len() - 1;

    while lo < hi {
        let mid = (lo + hi).div_ceil(2); // bias right
        if entries[mid].timestamp_ms <= timestamp_ms {
            lo = mid;
        } else {
            hi = mid - 1;
        }
    }

    Some(&entries[lo])
}

/// Extract thumbnail JPEG bytes from a BIF file using a
/// pre-parsed entry.
///
/// Returns `None` if the entry's range is out of bounds.
pub fn extract_bif_thumbnail(data: &[u8], entry: &BifEntry) -> Option<Vec<u8>> {
    let start = entry.offset as usize;
    let end = start + entry.length as usize;
    if end > data.len() {
        return None;
    }
    Some(data[start..end].to_vec())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a minimal valid BIF file with given JPEG payloads.
    fn make_bif(multiplier: u32, frames: &[(&[u8], u32)]) -> Vec<u8> {
        let image_count = frames.len() as u32;
        let index_entries = image_count + 1; // +1 for sentinel
        let index_size = index_entries as usize * INDEX_ENTRY_SIZE;
        let data_start = INDEX_START + index_size;

        // Calculate total size.
        let total_data: usize = frames.iter().map(|(d, _)| d.len()).sum();
        let total_size = data_start + total_data;

        let mut buf = vec![0u8; total_size];

        // Write magic.
        buf[..8].copy_from_slice(&BIF_MAGIC);
        // Version = 0.
        buf[8..12].copy_from_slice(&0u32.to_le_bytes());
        // Image count.
        buf[12..16].copy_from_slice(&image_count.to_le_bytes());
        // Timestamp multiplier.
        buf[16..20].copy_from_slice(&multiplier.to_le_bytes());

        // Write index entries + image data.
        let mut data_offset = data_start;
        for (i, (jpeg, ts)) in frames.iter().enumerate() {
            let entry_pos = INDEX_START + i * INDEX_ENTRY_SIZE;
            buf[entry_pos..entry_pos + 4].copy_from_slice(&ts.to_le_bytes());
            buf[entry_pos + 4..entry_pos + 8].copy_from_slice(&(data_offset as u32).to_le_bytes());

            buf[data_offset..data_offset + jpeg.len()].copy_from_slice(jpeg);
            data_offset += jpeg.len();
        }

        // Sentinel entry.
        let sentinel_pos = INDEX_START + frames.len() * INDEX_ENTRY_SIZE;
        buf[sentinel_pos..sentinel_pos + 4].copy_from_slice(&0xFFFFFFFFu32.to_le_bytes());
        buf[sentinel_pos + 4..sentinel_pos + 8]
            .copy_from_slice(&(data_offset as u32).to_le_bytes());

        buf
    }

    #[test]
    fn parse_valid_bif() {
        let bif = make_bif(
            1000,
            &[(b"JPEG1___", 0), (b"JPEG2___", 5), (b"JPEG3___", 10)],
        );

        let entries = parse_bif_index(&bif);
        assert_eq!(entries.len(), 3);
        assert_eq!(entries[0].timestamp_ms, 0);
        assert_eq!(entries[1].timestamp_ms, 5000);
        assert_eq!(entries[2].timestamp_ms, 10000);
        assert_eq!(entries[0].length, 8);
    }

    #[test]
    fn parse_zero_multiplier_defaults_to_1000() {
        let bif = make_bif(0, &[(b"IMG", 3)]);
        let entries = parse_bif_index(&bif);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].timestamp_ms, 3000);
    }

    #[test]
    fn parse_custom_multiplier() {
        let bif = make_bif(500, &[(b"A", 2), (b"B", 4)]);
        let entries = parse_bif_index(&bif);
        assert_eq!(entries[0].timestamp_ms, 1000); // 2 * 500
        assert_eq!(entries[1].timestamp_ms, 2000); // 4 * 500
    }

    #[test]
    fn parse_invalid_magic_returns_empty() {
        let mut bif = make_bif(1000, &[(b"X", 0)]);
        bif[0] = 0x00; // corrupt magic
        assert!(parse_bif_index(&bif).is_empty());
    }

    #[test]
    fn parse_truncated_header_returns_empty() {
        let data = vec![0u8; 32]; // too short
        assert!(parse_bif_index(&data).is_empty());
    }

    #[test]
    fn parse_truncated_index_returns_empty() {
        // Valid header but index table extends beyond data.
        let mut bif = vec![0u8; MIN_BIF_SIZE];
        bif[..8].copy_from_slice(&BIF_MAGIC);
        // Claim 1000 images — index would need way more space.
        bif[12..16].copy_from_slice(&1000u32.to_le_bytes());
        bif[16..20].copy_from_slice(&1000u32.to_le_bytes());
        assert!(parse_bif_index(&bif).is_empty());
    }

    #[test]
    fn parse_empty_bif_no_images() {
        let bif = make_bif(1000, &[]);
        let entries = parse_bif_index(&bif);
        assert!(entries.is_empty());
    }

    #[test]
    fn binary_search_finds_exact_match() {
        let bif = make_bif(1000, &[(b"A", 0), (b"B", 5), (b"C", 10)]);
        let entries = parse_bif_index(&bif);
        let found = find_bif_entry(&entries, 5000).unwrap();
        assert_eq!(found.timestamp_ms, 5000);
    }

    #[test]
    fn binary_search_finds_nearest_preceding() {
        let bif = make_bif(1000, &[(b"A", 0), (b"B", 5), (b"C", 10)]);
        let entries = parse_bif_index(&bif);
        let found = find_bif_entry(&entries, 7000).unwrap();
        assert_eq!(found.timestamp_ms, 5000);
    }

    #[test]
    fn binary_search_returns_first_for_early_timestamp() {
        let bif = make_bif(1000, &[(b"A", 5), (b"B", 10)]);
        let entries = parse_bif_index(&bif);
        let found = find_bif_entry(&entries, 0).unwrap();
        assert_eq!(found.timestamp_ms, 5000);
    }

    #[test]
    fn binary_search_returns_last_for_late_timestamp() {
        let bif = make_bif(1000, &[(b"A", 0), (b"B", 5)]);
        let entries = parse_bif_index(&bif);
        let found = find_bif_entry(&entries, 99999).unwrap();
        assert_eq!(found.timestamp_ms, 5000);
    }

    #[test]
    fn binary_search_empty_returns_none() {
        assert!(find_bif_entry(&[], 1000).is_none());
    }

    #[test]
    fn extract_thumbnail_returns_jpeg_bytes() {
        let bif = make_bif(1000, &[(b"JPEG1___", 0), (b"JPEG2___", 5)]);
        let entries = parse_bif_index(&bif);
        let bytes = extract_bif_thumbnail(&bif, &entries[1]).unwrap();
        assert_eq!(bytes, b"JPEG2___");
    }

    #[test]
    fn extract_thumbnail_out_of_bounds_returns_none() {
        let entry = BifEntry {
            timestamp_ms: 0,
            offset: 9999,
            length: 100,
        };
        let data = vec![0u8; 100];
        assert!(extract_bif_thumbnail(&data, &entry).is_none());
    }
}
