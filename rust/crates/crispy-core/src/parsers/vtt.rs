//! WebVTT thumbnail sprite sheet parser.
//!
//! Ported from Dart `vtt_parser.dart`. Pure function,
//! no DB access.

use serde::{Deserialize, Serialize};

/// A parsed thumbnail sprite sheet with all cue
/// positions.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThumbnailSprite {
    /// URL of the sprite image.
    pub image_url: String,
    /// Number of thumbnail columns in the grid.
    pub columns: i32,
    /// Number of thumbnail rows in the grid.
    pub rows: i32,
    /// Width of each thumbnail in pixels.
    pub thumb_width: i32,
    /// Height of each thumbnail in pixels.
    pub thumb_height: i32,
    /// Individual cue positions and timings.
    pub cues: Vec<ThumbnailCue>,
}

/// A single thumbnail cue within a sprite sheet.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThumbnailCue {
    /// Start time in milliseconds.
    pub start_ms: i64,
    /// End time in milliseconds.
    pub end_ms: i64,
    /// X offset in the sprite image (pixels).
    pub x: i32,
    /// Y offset in the sprite image (pixels).
    pub y: i32,
}

/// Parse a WebVTT thumbnail sprite sheet.
///
/// Returns `None` if the content is not valid VTT or
/// no cues are found.
///
/// [base_url] is used to resolve relative sprite image
/// paths.
pub fn parse_vtt(content: &str, base_url: &str) -> Option<ThumbnailSprite> {
    let lines: Vec<&str> = content.split('\n').map(|l| l.trim()).collect();

    // Must start with WEBVTT.
    if lines.is_empty() || !lines[0].starts_with("WEBVTT") {
        return None;
    }

    let mut cues = Vec::new();
    let mut sprite_url: Option<String> = None;
    let mut thumb_width: i32 = 160;
    let mut thumb_height: i32 = 90;

    let mut i = 1; // Skip WEBVTT header.
    while i < lines.len() {
        let line = lines[i];

        // Skip empty lines and comments.
        if line.is_empty() || line.starts_with("NOTE") {
            i += 1;
            continue;
        }

        // Timestamp line.
        if line.contains("-->")
            && let Some((start_ms, end_ms)) = parse_timestamp_line(line)
        {
            // Next line is the sprite reference.
            if i + 1 < lines.len() {
                if let Some(sd) = parse_sprite_reference(lines[i + 1], base_url) {
                    if sprite_url.is_none() {
                        sprite_url = Some(sd.image_url.clone());
                    }
                    thumb_width = sd.width;
                    thumb_height = sd.height;

                    cues.push(ThumbnailCue {
                        start_ms,
                        end_ms,
                        x: sd.x,
                        y: sd.y,
                    });
                }
                i += 2;
                continue;
            }
        }

        i += 1;
    }

    if cues.is_empty() {
        return None;
    }
    let sprite_url = sprite_url?;

    // Calculate grid dimensions from max offsets.
    let columns = calculate_columns(&cues, thumb_width);
    let rows = calculate_rows(&cues, thumb_height);

    Some(ThumbnailSprite {
        image_url: sprite_url,
        columns,
        rows,
        thumb_width,
        thumb_height,
        cues,
    })
}

// ── Internal helpers ─────────────────────────────

/// Parse `HH:MM:SS.mmm --> HH:MM:SS.mmm` line.
fn parse_timestamp_line(line: &str) -> Option<(i64, i64)> {
    let parts: Vec<&str> = line.split("-->").collect();
    if parts.len() != 2 {
        return None;
    }
    let start = parse_timestamp(parts[0].trim())?;
    let end = parse_timestamp(parts[1].trim())?;
    Some((start, end))
}

/// Parse `HH:MM:SS.mmm` or `MM:SS.mmm` into
/// milliseconds.
fn parse_timestamp(ts: &str) -> Option<i64> {
    // Remove any settings after the timestamp.
    let clean = ts.split(' ').next()?;
    let parts: Vec<&str> = clean.split(':').collect();

    if parts.len() < 2 || parts.len() > 3 {
        return None;
    }

    let (hours, minutes, seconds_str) = if parts.len() == 3 {
        (
            parts[0].parse::<i64>().ok()?,
            parts[1].parse::<i64>().ok()?,
            parts[2],
        )
    } else {
        (0i64, parts[0].parse::<i64>().ok()?, parts[1])
    };

    let secs: f64 = seconds_str.parse().ok()?;
    let total_ms = hours * 3_600_000 + minutes * 60_000 + (secs * 1000.0).round() as i64;

    Some(total_ms)
}

struct SpriteData {
    image_url: String,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
}

/// Parse `sprite.jpg#xywh=X,Y,W,H`.
fn parse_sprite_reference(line: &str, base_url: &str) -> Option<SpriteData> {
    let hash_idx = line.find("#xywh=")?;
    let image_path = &line[..hash_idx];
    let xywh = &line[hash_idx + 6..];

    let coords: Vec<&str> = xywh.split(',').collect();
    if coords.len() != 4 {
        return None;
    }

    let x: i32 = coords[0].parse().ok()?;
    let y: i32 = coords[1].parse().ok()?;
    let w: i32 = coords[2].parse().ok()?;
    let h: i32 = coords[3].parse().ok()?;

    let image_url = resolve_url(image_path, base_url);

    Some(SpriteData {
        image_url,
        x,
        y,
        width: w,
        height: h,
    })
}

/// Resolve a relative URL against a base URL.
fn resolve_url(path: &str, base_url: &str) -> String {
    if path.starts_with("http://") || path.starts_with("https://") {
        return path.to_string();
    }

    // Remove trailing filename from base URL.
    let base_path = match base_url.rfind('/') {
        Some(idx) => &base_url[..=idx],
        None => "",
    };

    format!("{}{}", base_path, path)
}

fn calculate_columns(cues: &[ThumbnailCue], thumb_width: i32) -> i32 {
    if cues.is_empty() || thumb_width <= 0 {
        return 1;
    }
    let max_x = cues.iter().map(|c| c.x).max().unwrap();
    (max_x / thumb_width) + 1
}

fn calculate_rows(cues: &[ThumbnailCue], thumb_height: i32) -> i32 {
    if cues.is_empty() || thumb_height <= 0 {
        return 1;
    }
    let max_y = cues.iter().map(|c| c.y).max().unwrap();
    (max_y / thumb_height) + 1
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE_VTT: &str = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
sprite.jpg#xywh=0,0,160,90

00:00:05.000 --> 00:00:10.000
sprite.jpg#xywh=160,0,160,90

00:00:10.000 --> 00:00:15.000
sprite.jpg#xywh=320,0,160,90
";

    #[test]
    fn parse_basic_vtt() {
        let result = parse_vtt(SAMPLE_VTT, "http://cdn.example.com/thumbs/");
        assert!(result.is_some());

        let sprite = result.unwrap();
        assert_eq!(sprite.image_url, "http://cdn.example.com/thumbs/sprite.jpg",);
        assert_eq!(sprite.thumb_width, 160);
        assert_eq!(sprite.thumb_height, 90);
        assert_eq!(sprite.cues.len(), 3);

        // Grid: 3 columns (x=0, 160, 320), 1 row.
        assert_eq!(sprite.columns, 3);
        assert_eq!(sprite.rows, 1);

        // First cue: 0-5s at (0,0).
        assert_eq!(sprite.cues[0].start_ms, 0);
        assert_eq!(sprite.cues[0].end_ms, 5000);
        assert_eq!(sprite.cues[0].x, 0);
        assert_eq!(sprite.cues[0].y, 0);

        // Second cue: 5-10s at (160,0).
        assert_eq!(sprite.cues[1].start_ms, 5000);
        assert_eq!(sprite.cues[1].end_ms, 10_000);
        assert_eq!(sprite.cues[1].x, 160);
    }

    #[test]
    fn parse_multi_row_grid() {
        let content = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
sprite.jpg#xywh=0,0,160,90

00:00:05.000 --> 00:00:10.000
sprite.jpg#xywh=160,0,160,90

00:00:10.000 --> 00:00:15.000
sprite.jpg#xywh=0,90,160,90

00:00:15.000 --> 00:00:20.000
sprite.jpg#xywh=160,90,160,90
";
        let sprite = parse_vtt(content, "http://cdn.example.com/").unwrap();
        assert_eq!(sprite.columns, 2);
        assert_eq!(sprite.rows, 2);
        assert_eq!(sprite.cues.len(), 4);
    }

    #[test]
    fn parse_absolute_sprite_url() {
        let content = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
https://cdn.example.com/sprite.jpg#xywh=0,0,200,112
";
        let sprite = parse_vtt(content, "http://other.com/").unwrap();
        assert_eq!(sprite.image_url, "https://cdn.example.com/sprite.jpg",);
        assert_eq!(sprite.thumb_width, 200);
        assert_eq!(sprite.thumb_height, 112);
    }

    #[test]
    fn invalid_vtt_returns_none() {
        assert!(parse_vtt("NOT VTT", "http://x/").is_none());
        assert!(parse_vtt("", "http://x/").is_none());
    }

    #[test]
    fn no_cues_returns_none() {
        let content = "WEBVTT\n\nSome random text\n";
        assert!(parse_vtt(content, "http://x/").is_none(),);
    }

    #[test]
    fn timestamp_parsing() {
        assert_eq!(parse_timestamp("00:00:05.000"), Some(5000),);
        assert_eq!(parse_timestamp("01:30:00.500"), Some(5_400_500),);
        assert_eq!(parse_timestamp("05:30.000"), Some(330_000),);
    }

    #[test]
    fn parse_basic_vtt_cue_details() {
        let result = parse_vtt(SAMPLE_VTT, "http://cdn.example.com/thumbs/");
        let sprite = result.unwrap();

        // Third cue: 10-15s at (320,0).
        assert_eq!(sprite.cues[2].start_ms, 10_000);
        assert_eq!(sprite.cues[2].end_ms, 15_000);
        assert_eq!(sprite.cues[2].x, 320);
        assert_eq!(sprite.cues[2].y, 0);

        // All cues reference same sprite.
        assert_eq!(sprite.image_url, "http://cdn.example.com/thumbs/sprite.jpg",);
    }

    #[test]
    fn parse_vtt_with_positions() {
        let content = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
grid.jpg#xywh=0,0,200,120

00:00:05.000 --> 00:00:10.000
grid.jpg#xywh=200,0,200,120

00:00:10.000 --> 00:00:15.000
grid.jpg#xywh=0,120,200,120

00:00:15.000 --> 00:00:20.000
grid.jpg#xywh=200,120,200,120
";
        let sprite = parse_vtt(content, "http://cdn.example.com/").unwrap();

        assert_eq!(sprite.thumb_width, 200);
        assert_eq!(sprite.thumb_height, 120);
        assert_eq!(sprite.columns, 2);
        assert_eq!(sprite.rows, 2);
        assert_eq!(sprite.cues.len(), 4);

        // Verify each cue position.
        assert_eq!(sprite.cues[0].x, 0);
        assert_eq!(sprite.cues[0].y, 0);
        assert_eq!(sprite.cues[1].x, 200);
        assert_eq!(sprite.cues[1].y, 0);
        assert_eq!(sprite.cues[2].x, 0);
        assert_eq!(sprite.cues[2].y, 120);
        assert_eq!(sprite.cues[3].x, 200);
        assert_eq!(sprite.cues[3].y, 120);
    }

    #[test]
    fn parse_empty_vtt_returns_none() {
        assert!(parse_vtt("", "http://x/").is_none());
        assert!(parse_vtt("   ", "http://x/").is_none());
    }

    #[test]
    fn parse_no_sprite_refs_returns_none() {
        // Valid WEBVTT header but no sprite references.
        let content = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
This is a subtitle line

00:00:05.000 --> 00:00:10.000
Another subtitle without sprites
";
        assert!(parse_vtt(content, "http://x/").is_none());
    }

    #[test]
    fn parse_relative_urls_resolved_against_base() {
        let content = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
thumbs/sprite.jpg#xywh=0,0,160,90
";
        let sprite = parse_vtt(content, "http://cdn.example.com/video/manifest.vtt").unwrap();

        // Relative path resolved against base directory.
        assert_eq!(
            sprite.image_url,
            "http://cdn.example.com/video/thumbs/sprite.jpg",
        );
    }

    #[test]
    fn parse_malformed_timestamps_dont_crash() {
        // Invalid timestamp format.
        let content1 = "\
WEBVTT

badtime --> alsobad
sprite.jpg#xywh=0,0,160,90
";
        assert!(parse_vtt(content1, "http://x/").is_none());

        // Only one part of the arrow.
        let content2 = "\
WEBVTT

00:00:00.000
sprite.jpg#xywh=0,0,160,90
";
        assert!(parse_vtt(content2, "http://x/").is_none());

        // Extra colons in timestamp.
        let content3 = "\
WEBVTT

00:00:00:00.000 --> 00:00:05.000
sprite.jpg#xywh=0,0,160,90
";
        assert!(parse_vtt(content3, "http://x/").is_none());
    }

    #[test]
    fn text_only_subtitle_no_sprite_url() {
        // Cue lines without #xywh= are plain subtitles.
        // parse_sprite_reference returns None for them,
        // so no cues are collected → result is None.
        let content = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
Hello, this is a subtitle.

00:00:05.000 --> 00:00:10.000
Another subtitle line.
";
        assert!(parse_vtt(content, "http://x/").is_none());
    }

    #[test]
    fn timestamp_with_hours_over_99() {
        // parse_timestamp parses hours as i64, so values
        // above 99 are valid.
        assert_eq!(parse_timestamp("100:00:00.000"), Some(360_000_000),);
        assert_eq!(parse_timestamp("999:59:59.999"), Some(3_599_999_999),);

        // Full VTT with large hours.
        let content = "\
WEBVTT

100:00:00.000 --> 100:00:05.000
sprite.jpg#xywh=0,0,160,90
";
        let sprite = parse_vtt(content, "http://cdn/").unwrap();
        assert_eq!(sprite.cues[0].start_ms, 360_000_000);
        assert_eq!(sprite.cues[0].end_ms, 360_005_000);
    }

    #[test]
    fn missing_webvtt_header() {
        // First line is not "WEBVTT" — returns None.
        let content = "\
00:00:00.000 --> 00:00:05.000
sprite.jpg#xywh=0,0,160,90
";
        assert!(parse_vtt(content, "http://x/").is_none());

        // Header with different casing.
        let content2 = "\
webvtt

00:00:00.000 --> 00:00:05.000
sprite.jpg#xywh=0,0,160,90
";
        assert!(parse_vtt(content2, "http://x/").is_none());
    }

    #[test]
    fn coordinates_with_floating_point() {
        // #xywh= coords are parsed as i32. Floats fail
        // the parse, so the cue is skipped → None.
        let content = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
sprite.jpg#xywh=0.5,0.5,160.0,90.0
";
        assert!(parse_vtt(content, "http://x/").is_none());
    }

    #[test]
    fn very_large_sprite_sheet_index() {
        // High x/y offsets representing a large sprite
        // grid (e.g., 100 columns × 50 rows).
        let content = "\
WEBVTT

00:00:00.000 --> 00:00:05.000
big.jpg#xywh=15840,4410,160,90

00:00:05.000 --> 00:00:10.000
big.jpg#xywh=0,0,160,90
";
        let sprite = parse_vtt(content, "http://cdn/").unwrap();
        assert_eq!(sprite.cues.len(), 2);
        // Columns: (15840 / 160) + 1 = 100.
        assert_eq!(sprite.columns, 100);
        // Rows: (4410 / 90) + 1 = 50.
        assert_eq!(sprite.rows, 50);
    }

    #[test]
    fn empty_lines_between_cues() {
        // Multiple blank lines between cues should not
        // break parsing.
        let content = "\
WEBVTT



00:00:00.000 --> 00:00:05.000
sprite.jpg#xywh=0,0,160,90



00:00:05.000 --> 00:00:10.000
sprite.jpg#xywh=160,0,160,90


";
        let sprite = parse_vtt(content, "http://cdn/").unwrap();
        assert_eq!(sprite.cues.len(), 2);
        assert_eq!(sprite.cues[0].x, 0);
        assert_eq!(sprite.cues[1].x, 160);
    }

    #[test]
    fn windows_style_line_endings() {
        // \r\n lines. split('\n') leaves trailing \r but
        // .trim() on each line removes it.
        let content = "WEBVTT\r\n\r\n\
             00:00:00.000 --> 00:00:05.000\r\n\
             sprite.jpg#xywh=0,0,160,90\r\n\r\n\
             00:00:05.000 --> 00:00:10.000\r\n\
             sprite.jpg#xywh=160,0,160,90\r\n";
        let sprite = parse_vtt(content, "http://cdn/").unwrap();
        assert_eq!(sprite.cues.len(), 2);
        assert_eq!(sprite.image_url, "http://cdn/sprite.jpg",);
    }

    // ── BUG-15: Division by zero guard tests ─────

    #[test]
    fn zero_thumb_width_no_panic() {
        // Directly test calculate_columns with zero width.
        let cues = vec![ThumbnailCue {
            start_ms: 0,
            end_ms: 5000,
            x: 320,
            y: 0,
        }];
        // Should return 1 (default) instead of panicking.
        assert_eq!(calculate_columns(&cues, 0), 1);
    }

    #[test]
    fn zero_thumb_height_no_panic() {
        // Directly test calculate_rows with zero height.
        let cues = vec![ThumbnailCue {
            start_ms: 0,
            end_ms: 5000,
            x: 0,
            y: 180,
        }];
        // Should return 1 (default) instead of panicking.
        assert_eq!(calculate_rows(&cues, 0), 1);
    }

    #[test]
    fn negative_thumb_dimensions_no_panic() {
        let cues = vec![ThumbnailCue {
            start_ms: 0,
            end_ms: 5000,
            x: 100,
            y: 100,
        }];
        assert_eq!(calculate_columns(&cues, -1), 1);
        assert_eq!(calculate_rows(&cues, -1), 1);
    }
}
