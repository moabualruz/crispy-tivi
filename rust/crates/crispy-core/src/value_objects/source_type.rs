//! SourceType — discriminates IPTV/media source protocols.
use serde::{Deserialize, Serialize};

/// Discriminates the protocol/format of an IPTV or media source.
///
/// Replaces `source_type: String` in [`crate::models::Source`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum SourceType {
    /// M3U/M3U+ playlist file or URL.
    #[default]
    M3u,
    /// Xtream Codes API (username/password auth).
    Xtream,
    /// Stalker portal (MAC address auth).
    Stalker,
    /// Plex Media Server.
    Plex,
    /// Emby Media Server.
    Emby,
    /// Jellyfin Media Server.
    Jellyfin,
}

impl SourceType {
    /// Returns the canonical lowercase string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::M3u => "m3u",
            Self::Xtream => "xtream",
            Self::Stalker => "stalker",
            Self::Plex => "plex",
            Self::Emby => "emby",
            Self::Jellyfin => "jellyfin",
        }
    }

    /// Whether this source type uses username/password credentials.
    pub fn uses_credentials(&self) -> bool {
        matches!(self, Self::Xtream | Self::Stalker)
    }

    /// Whether this source type uses a token-based auth.
    pub fn uses_token(&self) -> bool {
        matches!(self, Self::Plex | Self::Emby | Self::Jellyfin)
    }
}

impl std::fmt::Display for SourceType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl TryFrom<&str> for SourceType {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "m3u" | "m3u+" | "m3uplus" => Ok(Self::M3u),
            "xtream" | "xtream_codes" => Ok(Self::Xtream),
            "stalker" => Ok(Self::Stalker),
            "plex" => Ok(Self::Plex),
            "emby" => Ok(Self::Emby),
            "jellyfin" => Ok(Self::Jellyfin),
            other => Err(format!("unknown source type: {other}")),
        }
    }
}

impl TryFrom<String> for SourceType {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::try_from(s.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_as_str() {
        let variants = [
            SourceType::M3u,
            SourceType::Xtream,
            SourceType::Stalker,
            SourceType::Plex,
            SourceType::Emby,
            SourceType::Jellyfin,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = SourceType::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(SourceType::try_from("m3u+").unwrap(), SourceType::M3u);
        assert_eq!(
            SourceType::try_from("xtream_codes").unwrap(),
            SourceType::Xtream
        );
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(SourceType::try_from("unknown").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(SourceType::Xtream.to_string(), "xtream");
    }
}
