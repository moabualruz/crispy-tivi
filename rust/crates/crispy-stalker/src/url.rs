//! Stream URL resolution from Stalker `cmd` fields.
//!
//! The `cmd` field in Stalker responses can contain:
//! - A full URL: `http://portal.com/live/stream.ts`
//! - A prefixed URL: `ffrt http://...` or `ffmpeg http://...`
//! - A relative path: `/live/stream.ts`

/// Resolve a Stalker `cmd` field into a usable stream URL.
///
/// This is a pure function — no HTTP needed for simple URL extraction.
///
/// # Arguments
/// * `cmd` — Raw command string from the portal response.
/// * `base_url` — Base URL of the portal, used for relative paths.
///
/// # Returns
/// The resolved absolute stream URL, or `None` if `cmd` is empty.
pub fn resolve_stream_url(cmd: &str, base_url: &str) -> Option<String> {
    let trimmed = cmd.trim();
    if trimmed.is_empty() {
        return None;
    }

    // Strip known prefixes: "ffrt ", "ffmpeg ", "auto "
    let url_part = strip_cmd_prefix(trimmed);

    if url_part.starts_with("http://") || url_part.starts_with("https://") {
        Some(url_part.to_string())
    } else if url_part.starts_with('/') {
        // Relative path — join with base URL
        let base = base_url.trim_end_matches('/');
        Some(format!("{base}{url_part}"))
    } else {
        // Assume it's a full URL without scheme — unlikely but handle gracefully
        Some(url_part.to_string())
    }
}

/// Strip known command prefixes from a `cmd` string.
///
/// Stalker portals sometimes prepend `ffrt`, `ffmpeg`, or `auto` before the
/// actual URL. This function removes the first word if it matches a known
/// prefix.
fn strip_cmd_prefix(cmd: &str) -> &str {
    const PREFIXES: &[&str] = &["ffrt", "ffmpeg", "auto"];

    for prefix in PREFIXES {
        if let Some(rest) = cmd.strip_prefix(prefix) {
            let rest = rest.trim_start();
            if !rest.is_empty() {
                return rest;
            }
        }
    }

    cmd
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolves_full_http_url() {
        let result = resolve_stream_url("http://portal.com/live/stream.ts", "http://portal.com");
        assert_eq!(result.as_deref(), Some("http://portal.com/live/stream.ts"));
    }

    #[test]
    fn resolves_full_https_url() {
        let result = resolve_stream_url(
            "https://secure.portal.com/live/ch1.m3u8",
            "http://portal.com",
        );
        assert_eq!(
            result.as_deref(),
            Some("https://secure.portal.com/live/ch1.m3u8")
        );
    }

    #[test]
    fn strips_ffrt_prefix() {
        let result =
            resolve_stream_url("ffrt http://portal.com/live/stream.ts", "http://portal.com");
        assert_eq!(result.as_deref(), Some("http://portal.com/live/stream.ts"));
    }

    #[test]
    fn strips_ffmpeg_prefix() {
        let result = resolve_stream_url(
            "ffmpeg http://portal.com/live/stream.ts",
            "http://portal.com",
        );
        assert_eq!(result.as_deref(), Some("http://portal.com/live/stream.ts"));
    }

    #[test]
    fn strips_auto_prefix() {
        let result =
            resolve_stream_url("auto http://portal.com/live/stream.ts", "http://portal.com");
        assert_eq!(result.as_deref(), Some("http://portal.com/live/stream.ts"));
    }

    #[test]
    fn resolves_relative_path() {
        let result = resolve_stream_url("/live/stream.ts", "http://portal.com");
        assert_eq!(result.as_deref(), Some("http://portal.com/live/stream.ts"));
    }

    #[test]
    fn resolves_relative_path_strips_trailing_slash() {
        let result = resolve_stream_url("/live/stream.ts", "http://portal.com/");
        assert_eq!(result.as_deref(), Some("http://portal.com/live/stream.ts"));
    }

    #[test]
    fn returns_none_for_empty_cmd() {
        assert!(resolve_stream_url("", "http://portal.com").is_none());
        assert!(resolve_stream_url("  ", "http://portal.com").is_none());
    }

    #[test]
    fn handles_unknown_format_gracefully() {
        let result = resolve_stream_url("some-opaque-token", "http://portal.com");
        assert_eq!(result.as_deref(), Some("some-opaque-token"));
    }

    #[test]
    fn strips_ffrt_prefix_with_relative_path() {
        let result = resolve_stream_url("ffrt /live/stream.ts", "http://portal.com");
        assert_eq!(result.as_deref(), Some("http://portal.com/live/stream.ts"));
    }
}
