//! Deep-link router for the `crispytivi://` URI scheme.
//!
//! # Supported URIs
//! | URI | DeepLink variant |
//! |-----|-----------------|
//! | `crispytivi://channel/{id}` | `Channel(id)` |
//! | `crispytivi://epg/{id}` | `EpgProgramme(id)` |
//! | `crispytivi://vod/{id}` | `VodDetail(id)` |
//! | `crispytivi://vod/{id}/play?pos={secs}` | `VodPlay(id, pos)` |
//! | `crispytivi://series/{series_id}/{season}/{episode}` | `SeriesEpisode(…)` |
//! | `crispytivi://recording/{id}` | `Recording(id)` |
//! | `crispytivi://search?q={query}` | `Search(query)` |
//! | `crispytivi://settings/{section}` | `Settings(section)` |
//! | `crispytivi://watchparty/{id}` | `WatchParty(id)` |
//! | `crispytivi://import?url={url}` | `PlaylistImport(url)` |

use crate::errors::CrispyError;

// ── DeepLink ──────────────────────────────────────────────────────────────────

/// All navigational destinations reachable via a `crispytivi://` URI.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DeepLink {
    /// Jump to a live channel by its internal ID.
    Channel(String),
    /// Open EPG detail for a programme.
    EpgProgramme(String),
    /// Open VOD detail page.
    VodDetail(String),
    /// Start VOD playback at an optional position (seconds).
    VodPlay(String, u64),
    /// Jump to a specific series episode.
    SeriesEpisode {
        series_id: String,
        season: u32,
        episode: u32,
    },
    /// Open DVR recording detail.
    Recording(String),
    /// Open search with a pre-filled query.
    Search(String),
    /// Open a specific settings section.
    Settings(String),
    /// Join a watch party by its ID.
    WatchParty(String),
    /// Trigger playlist import from a remote URL.
    PlaylistImport(String),
}

// ── Scheme constant ───────────────────────────────────────────────────────────

const SCHEME: &str = "crispytivi://";

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Split a URI path into non-empty segments.
fn path_segments(path: &str) -> Vec<&str> {
    path.split('/').filter(|s| !s.is_empty()).collect()
}

/// Extract a query parameter value from `?key=value&…`.
fn query_param<'a>(query: &'a str, key: &str) -> Option<&'a str> {
    for pair in query.split('&') {
        if let Some(rest) = pair.strip_prefix(key) {
            if let Some(val) = rest.strip_prefix('=') {
                return Some(val);
            }
        }
    }
    None
}

fn require_id(id: &str, context: &str) -> Result<String, CrispyError> {
    if id.is_empty() {
        return Err(CrispyError::Security {
            message: format!("{context} ID must not be empty"),
        });
    }
    Ok(id.to_string())
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Parse a `crispytivi://` URI into a `DeepLink`.
///
/// Returns `CrispyError::Security` for malformed or unknown URIs.
pub fn parse_deep_link(uri: &str) -> Result<DeepLink, CrispyError> {
    let rest = uri
        .strip_prefix(SCHEME)
        .ok_or_else(|| CrispyError::Security {
            message: format!("Unknown URI scheme: {uri}"),
        })?;

    // Split path from query string.
    let (path_part, query_part) = match rest.split_once('?') {
        Some((p, q)) => (p, q),
        None => (rest, ""),
    };

    let segs = path_segments(path_part);

    match segs.as_slice() {
        ["channel", id] => Ok(DeepLink::Channel(require_id(id, "channel")?)),

        ["epg", id] => Ok(DeepLink::EpgProgramme(require_id(id, "epg_programme")?)),

        ["vod", id] => Ok(DeepLink::VodDetail(require_id(id, "vod")?)),

        ["vod", id, "play"] => {
            let vid = require_id(id, "vod")?;
            let pos = query_param(query_part, "pos")
                .and_then(|v| v.parse::<u64>().ok())
                .unwrap_or(0);
            Ok(DeepLink::VodPlay(vid, pos))
        }

        ["series", series_id, season_str, episode_str] => {
            let sid = require_id(series_id, "series")?;
            let season = season_str
                .parse::<u32>()
                .map_err(|_| CrispyError::Security {
                    message: format!("Invalid season number: {season_str}"),
                })?;
            let episode = episode_str
                .parse::<u32>()
                .map_err(|_| CrispyError::Security {
                    message: format!("Invalid episode number: {episode_str}"),
                })?;
            Ok(DeepLink::SeriesEpisode {
                series_id: sid,
                season,
                episode,
            })
        }

        ["recording", id] => Ok(DeepLink::Recording(require_id(id, "recording")?)),

        ["search"] => {
            let query = query_param(query_part, "q")
                .map(|s| s.replace('+', " "))
                .unwrap_or_default();
            Ok(DeepLink::Search(query))
        }

        ["settings", section] => Ok(DeepLink::Settings(section.to_string())),
        ["settings"] => Ok(DeepLink::Settings(String::new())),

        ["watchparty", id] => Ok(DeepLink::WatchParty(require_id(id, "watchparty")?)),

        ["import"] => {
            let url = query_param(query_part, "url").unwrap_or("").to_string();
            if url.is_empty() {
                return Err(CrispyError::Security {
                    message: "PlaylistImport requires a `url` query parameter".to_string(),
                });
            }
            Ok(DeepLink::PlaylistImport(url))
        }

        _ => Err(CrispyError::Security {
            message: format!("Unknown deep-link path: {path_part}"),
        }),
    }
}

/// Serialise a `DeepLink` back to its canonical `crispytivi://` URI.
pub fn to_uri(link: &DeepLink) -> String {
    match link {
        DeepLink::Channel(id) => format!("{SCHEME}channel/{id}"),
        DeepLink::EpgProgramme(id) => format!("{SCHEME}epg/{id}"),
        DeepLink::VodDetail(id) => format!("{SCHEME}vod/{id}"),
        DeepLink::VodPlay(id, pos) => format!("{SCHEME}vod/{id}/play?pos={pos}"),
        DeepLink::SeriesEpisode {
            series_id,
            season,
            episode,
        } => {
            format!("{SCHEME}series/{series_id}/{season}/{episode}")
        }
        DeepLink::Recording(id) => format!("{SCHEME}recording/{id}"),
        DeepLink::Search(q) => {
            let encoded = q.replace(' ', "+");
            format!("{SCHEME}search?q={encoded}")
        }
        DeepLink::Settings(section) if section.is_empty() => {
            format!("{SCHEME}settings")
        }
        DeepLink::Settings(section) => format!("{SCHEME}settings/{section}"),
        DeepLink::WatchParty(id) => format!("{SCHEME}watchparty/{id}"),
        DeepLink::PlaylistImport(url) => format!("{SCHEME}import?url={url}"),
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn roundtrip(link: DeepLink) {
        let uri = to_uri(&link);
        let parsed =
            parse_deep_link(&uri).unwrap_or_else(|e| panic!("parse failed for {uri}: {e}"));
        assert_eq!(parsed, link, "roundtrip mismatch for URI: {uri}");
    }

    #[test]
    fn test_channel_roundtrip() {
        roundtrip(DeepLink::Channel("ch_abc".to_string()));
    }

    #[test]
    fn test_epg_roundtrip() {
        roundtrip(DeepLink::EpgProgramme("epg_123".to_string()));
    }

    #[test]
    fn test_vod_detail_roundtrip() {
        roundtrip(DeepLink::VodDetail("movie_42".to_string()));
    }

    #[test]
    fn test_vod_play_with_position_roundtrip() {
        roundtrip(DeepLink::VodPlay("movie_42".to_string(), 3600));
    }

    #[test]
    fn test_vod_play_without_position_defaults_to_zero() {
        let link = parse_deep_link("crispytivi://vod/movie_7/play").unwrap();
        assert_eq!(link, DeepLink::VodPlay("movie_7".to_string(), 0));
    }

    #[test]
    fn test_series_episode_roundtrip() {
        roundtrip(DeepLink::SeriesEpisode {
            series_id: "series_5".to_string(),
            season: 2,
            episode: 8,
        });
    }

    #[test]
    fn test_recording_roundtrip() {
        roundtrip(DeepLink::Recording("rec_99".to_string()));
    }

    #[test]
    fn test_search_roundtrip() {
        roundtrip(DeepLink::Search("breaking bad".to_string()));
    }

    #[test]
    fn test_search_empty_query() {
        let link = parse_deep_link("crispytivi://search").unwrap();
        assert_eq!(link, DeepLink::Search(String::new()));
    }

    #[test]
    fn test_settings_with_section_roundtrip() {
        roundtrip(DeepLink::Settings("playback".to_string()));
    }

    #[test]
    fn test_settings_no_section() {
        let link = parse_deep_link("crispytivi://settings").unwrap();
        assert_eq!(link, DeepLink::Settings(String::new()));
    }

    #[test]
    fn test_watchparty_roundtrip() {
        roundtrip(DeepLink::WatchParty("party_x".to_string()));
    }

    #[test]
    fn test_playlist_import_roundtrip() {
        roundtrip(DeepLink::PlaylistImport(
            "http://example.com/list.m3u".to_string(),
        ));
    }

    #[test]
    fn test_unknown_scheme_rejected() {
        let err = parse_deep_link("https://example.com").unwrap_err();
        assert!(err.to_string().contains("Unknown URI scheme"), "{err}");
    }

    #[test]
    fn test_unknown_path_rejected() {
        let err = parse_deep_link("crispytivi://unknown/path").unwrap_err();
        assert!(err.to_string().contains("Unknown deep-link path"), "{err}");
    }

    #[test]
    fn test_empty_channel_id_rejected() {
        // Trailing slash produces no ID segment; router rejects as unknown path.
        let err = parse_deep_link("crispytivi://channel/").unwrap_err();
        assert!(
            err.to_string().contains("Unknown deep-link path")
                || err.to_string().contains("ID must not be empty"),
            "{err}"
        );
    }

    #[test]
    fn test_invalid_season_number_rejected() {
        let err = parse_deep_link("crispytivi://series/s1/abc/1").unwrap_err();
        assert!(err.to_string().contains("Invalid season"), "{err}");
    }

    #[test]
    fn test_import_without_url_rejected() {
        let err = parse_deep_link("crispytivi://import").unwrap_err();
        assert!(err.to_string().contains("PlaylistImport"), "{err}");
    }
}
