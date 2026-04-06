//! HLS variant playlist parsing and best-quality selection.
//!
//! Translated from IPTVChecker-Python `extract_next_url`:
//! - Parses `#EXT-X-STREAM-INF` tags with RESOLUTION, BANDWIDTH,
//!   AVERAGE-BANDWIDTH attributes.
//! - Scores variants by (has_resolution, pixel_count, avg_bandwidth, bandwidth).
//! - Resolves relative URLs against the playlist base URL.
//! - Recurses into nested playlists up to a configurable depth limit.

use std::collections::HashSet;

use regex::Regex;
use tracing::debug;

use crate::error::ProbeError;
use crate::types::HlsVariant;

/// Parse an HLS master playlist and return all variant entries.
///
/// Translated from IPTVChecker-Python `extract_next_url` inner logic:
/// parses `#EXT-X-STREAM-INF` lines and their subsequent URL lines.
pub fn parse_hls_variants(content: &str, base_url: &str) -> Vec<HlsVariant> {
    let mut variants = Vec::new();
    let mut pending_attrs: Option<Attributes> = None;

    for raw_line in content.lines() {
        let line = raw_line.trim();
        if line.is_empty() {
            continue;
        }

        if line.starts_with('#') {
            if line.to_ascii_uppercase().starts_with("#EXT-X-STREAM-INF") {
                pending_attrs = Some(parse_tag_attributes(line));
            }
            continue;
        }

        // Non-comment, non-empty line = URL
        let resolved_url = resolve_url(base_url, line);

        if let Some(attrs) = pending_attrs.take() {
            let bandwidth = parse_u64_attr(&attrs, "BANDWIDTH");
            let average_bandwidth = {
                let v = parse_u64_attr(&attrs, "AVERAGE-BANDWIDTH");
                if v > 0 { Some(v) } else { None }
            };
            let (width, height) = parse_resolution_attr(&attrs);

            variants.push(HlsVariant {
                url: resolved_url,
                bandwidth,
                average_bandwidth,
                width,
                height,
                codecs: attrs.get("CODECS").cloned(),
            });
        }
        // Non-variant URLs (media segments in a media playlist) are ignored.
    }

    variants
}

/// Select the best variant URL from an HLS playlist body.
///
/// If no `#EXT-X-STREAM-INF` tags are found, returns the first URL
/// (treating it as a media playlist). This matches IPTVChecker-Python:
/// ```python
/// if not saw_stream_inf:
///     return resolved_url
/// ```
pub fn select_best_variant_from_content(content: &str, base_url: &str) -> Option<String> {
    let mut saw_stream_inf = false;
    let mut first_url: Option<String> = None;

    let variants = parse_hls_variants(content, base_url);
    if !variants.is_empty() {
        saw_stream_inf = true;
    }

    if !saw_stream_inf {
        // Look for first non-comment URL (media playlist)
        for raw_line in content.lines() {
            let line = raw_line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            first_url = Some(resolve_url(base_url, line));
            break;
        }
    }

    if saw_stream_inf {
        // Translated from Python: pick variant with highest quality_score
        variants
            .into_iter()
            .max_by_key(super::types::HlsVariant::quality_score)
            .map(|v| v.url)
    } else {
        first_url
    }
}

/// Recursively resolve an HLS playlist to the best final media URL.
///
/// Follows nested master playlists up to `max_depth` levels.
/// Translated from IPTVChecker-Python `verify` + `extract_next_url`
/// recursion with `visited` set for loop detection.
pub async fn select_best_variant(playlist_url: &str, max_depth: u32) -> Result<String, ProbeError> {
    let client = simple_http_client();
    let mut visited = HashSet::new();
    select_best_variant_recursive(&client, playlist_url, max_depth, &mut visited).await
}

fn select_best_variant_recursive<'a>(
    client: &'a reqwest::Client,
    url: &'a str,
    remaining_depth: u32,
    visited: &'a mut HashSet<String>,
) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<String, ProbeError>> + Send + 'a>> {
    Box::pin(async move {
        if remaining_depth == 0 {
            return Err(ProbeError::HlsMaxDepth(0));
        }

        // Loop detection (translated from Python: `if normalized_url in visited`)
        let normalized = url.split('#').next().unwrap_or(url).to_string();
        if !visited.insert(normalized.clone()) {
            return Err(ProbeError::HlsLoop(url.to_string()));
        }

        debug!(url, remaining_depth, "fetching HLS playlist");

        let resp = client
            .get(url)
            .send()
            .await
            .map_err(|e| ProbeError::ProcessFailed {
                code: None,
                stderr: format!("HTTP request failed: {e}"),
            })?;

        let body = resp.text().await.map_err(|e| ProbeError::ProcessFailed {
            code: None,
            stderr: format!("failed to read response body: {e}"),
        })?;

        match select_best_variant_from_content(&body, url) {
            Some(next_url) => {
                // Check if the selected URL is itself a playlist (contains .m3u8)
                if looks_like_playlist(&next_url) && remaining_depth > 1 {
                    select_best_variant_recursive(client, &next_url, remaining_depth - 1, visited)
                        .await
                } else {
                    Ok(next_url)
                }
            }
            None => Ok(url.to_string()),
        }
    })
}

/// Simple heuristic to check if a URL looks like an HLS playlist.
fn looks_like_playlist(url: &str) -> bool {
    let path = url.split('?').next().unwrap_or(url);
    path.ends_with(".m3u8") || path.ends_with(".m3u")
}

/// Minimal HTTP client for HLS playlist fetching.
fn simple_http_client() -> reqwest::Client {
    reqwest::Client::builder()
        .user_agent("VLC/3.0.14")
        .timeout(std::time::Duration::from_secs(15))
        .build()
        .unwrap_or_default()
}

// --- HLS tag attribute parsing ---
// Translated from IPTVChecker-Python `parse_tag_attributes`

type Attributes = std::collections::HashMap<String, String>;

/// Parse `#EXT-X-STREAM-INF:KEY=VALUE,...` attributes.
///
/// Faithful translation of IPTVChecker-Python `parse_tag_attributes`:
/// handles quoted values with backslash escaping, unquoted values,
/// and uppercases all keys.
fn parse_tag_attributes(tag_line: &str) -> Attributes {
    let mut attrs = Attributes::new();

    let payload = match tag_line.find(':') {
        Some(pos) => &tag_line[pos + 1..],
        None => return attrs,
    };

    let bytes = payload.as_bytes();
    let len = bytes.len();
    let mut i = 0;

    while i < len {
        // Skip whitespace and commas
        while i < len && matches!(bytes[i], b' ' | b'\t' | b',') {
            i += 1;
        }
        if i >= len {
            break;
        }

        // Read key
        let key_start = i;
        while i < len && bytes[i] != b'=' && bytes[i] != b',' {
            i += 1;
        }
        let key = payload[key_start..i].trim().to_ascii_uppercase();
        if key.is_empty() {
            i += 1;
            continue;
        }

        if i >= len || bytes[i] != b'=' {
            // No value — skip to next comma
            while i < len && bytes[i] != b',' {
                i += 1;
            }
            continue;
        }
        i += 1; // skip '='

        // Read value
        let value = if i < len && bytes[i] == b'"' {
            // Quoted value with backslash escape support
            i += 1;
            let mut chars = Vec::new();
            while i < len {
                if bytes[i] == b'\\' && i + 1 < len {
                    chars.push(bytes[i + 1]);
                    i += 2;
                    continue;
                }
                if bytes[i] == b'"' {
                    i += 1;
                    break;
                }
                chars.push(bytes[i]);
                i += 1;
            }
            String::from_utf8_lossy(&chars).to_string()
        } else {
            // Unquoted value — read until comma
            let val_start = i;
            while i < len && bytes[i] != b',' {
                i += 1;
            }
            payload[val_start..i].trim().to_string()
        };

        attrs.insert(key, value);

        if i < len && bytes[i] == b',' {
            i += 1;
        }
    }

    attrs
}

/// Parse RESOLUTION attribute ("WIDTHxHEIGHT") into (Option<u32>, Option<u32>).
///
/// Translated from Python `parse_resolution_pixels`.
fn parse_resolution_attr(attrs: &Attributes) -> (Option<u32>, Option<u32>) {
    let Some(res_str) = attrs.get("RESOLUTION") else {
        return (None, None);
    };

    let re = Regex::new(r"(?i)^\s*(\d+)\s*x\s*(\d+)\s*$").expect("valid regex");
    match re.captures(res_str) {
        Some(caps) => {
            let w: u32 = caps[1].parse().unwrap_or(0);
            let h: u32 = caps[2].parse().unwrap_or(0);
            if w > 0 && h > 0 {
                (Some(w), Some(h))
            } else {
                (None, None)
            }
        }
        None => (None, None),
    }
}

/// Parse a u64 attribute value.
fn parse_u64_attr(attrs: &Attributes, key: &str) -> u64 {
    attrs
        .get(key)
        .and_then(|v| v.trim().parse::<u64>().ok())
        .unwrap_or(0)
}

/// Resolve a potentially relative URL against a base URL.
fn resolve_url(base: &str, relative: &str) -> String {
    // If the relative URL is already absolute, return it directly.
    if relative.starts_with("http://") || relative.starts_with("https://") {
        return relative.to_string();
    }

    // Find the base path (everything up to last '/')
    if let Some(last_slash) = base.rfind('/') {
        format!("{}/{}", &base[..last_slash], relative)
    } else {
        relative.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const MASTER_PLAYLIST: &str = r#"#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
low/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720,AVERAGE-BANDWIDTH=2200000
mid/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,AVERAGE-BANDWIDTH=4500000
high/playlist.m3u8
"#;

    const NO_RESOLUTION_PLAYLIST: &str = r#"#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1500000
audio_only.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000
video.m3u8
"#;

    const MEDIA_PLAYLIST: &str = r#"#EXTM3U
#EXT-X-TARGETDURATION:10
#EXTINF:10,
segment001.ts
#EXTINF:10,
segment002.ts
"#;

    #[test]
    fn parses_master_playlist_variants() {
        let variants = parse_hls_variants(MASTER_PLAYLIST, "http://example.com/master.m3u8");
        assert_eq!(variants.len(), 3);

        assert_eq!(variants[0].bandwidth, 800_000);
        assert_eq!(variants[0].width, Some(640));
        assert_eq!(variants[0].height, Some(360));
        assert!(variants[0].url.ends_with("low/playlist.m3u8"));

        assert_eq!(variants[2].bandwidth, 5_000_000);
        assert_eq!(variants[2].average_bandwidth, Some(4_500_000));
        assert_eq!(variants[2].width, Some(1920));
        assert_eq!(variants[2].height, Some(1080));
    }

    #[test]
    fn selects_highest_quality_variant() {
        let best =
            select_best_variant_from_content(MASTER_PLAYLIST, "http://example.com/master.m3u8")
                .unwrap();
        assert!(best.contains("high/playlist.m3u8"));
    }

    #[test]
    fn resolution_beats_bandwidth_in_scoring() {
        // Variant with resolution but lower bandwidth should score higher
        // than variant without resolution but higher bandwidth.
        let best =
            select_best_variant_from_content(NO_RESOLUTION_PLAYLIST, "http://example.com/m.m3u8")
                .unwrap();
        // Without resolution, highest bandwidth wins
        assert!(best.contains("video.m3u8"));
    }

    #[test]
    fn media_playlist_returns_first_segment() {
        let best = select_best_variant_from_content(
            MEDIA_PLAYLIST,
            "http://example.com/stream/index.m3u8",
        )
        .unwrap();
        assert!(best.ends_with("stream/segment001.ts"));
    }

    #[test]
    fn resolves_relative_urls() {
        assert_eq!(
            resolve_url("http://host.com/path/master.m3u8", "sub/index.m3u8"),
            "http://host.com/path/sub/index.m3u8"
        );
    }

    #[test]
    fn preserves_absolute_urls() {
        let abs = "https://cdn.example.com/stream.m3u8";
        assert_eq!(resolve_url("http://other.com/playlist.m3u8", abs), abs);
    }

    #[test]
    fn parses_tag_attributes_with_quotes() {
        let attrs = parse_tag_attributes(
            r#"#EXT-X-STREAM-INF:BANDWIDTH=1500000,CODECS="avc1.42e01e,mp4a.40.2",RESOLUTION=1280x720"#,
        );
        assert_eq!(attrs.get("BANDWIDTH").unwrap(), "1500000");
        assert_eq!(attrs.get("CODECS").unwrap(), "avc1.42e01e,mp4a.40.2");
        assert_eq!(attrs.get("RESOLUTION").unwrap(), "1280x720");
    }

    #[test]
    fn hls_recursion_depth_limit() {
        // Verify that max_depth=0 returns an error immediately.
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        let result = rt.block_on(select_best_variant("http://example.com/test.m3u8", 0));
        assert!(matches!(result, Err(ProbeError::HlsMaxDepth(_))));
    }

    #[test]
    fn empty_playlist_returns_none() {
        assert!(select_best_variant_from_content("", "http://example.com/m.m3u8").is_none());
    }
}
