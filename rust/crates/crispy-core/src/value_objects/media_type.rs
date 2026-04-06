//! MediaType — discriminates the kind of media item.
use serde::{Deserialize, Serialize};

/// Discriminates the kind of a media item.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum MediaType {
    /// Live TV channel.
    #[default]
    Channel,
    /// Standalone movie.
    Movie,
    /// Single episode belonging to a series.
    Episode,
    /// Multi-episode series.
    Series,
}

impl MediaType {
    /// Returns the canonical lowercase string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Channel => "channel",
            Self::Movie => "movie",
            Self::Episode => "episode",
            Self::Series => "series",
        }
    }
}

impl std::fmt::Display for MediaType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl TryFrom<&str> for MediaType {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "channel" | "live" => Ok(Self::Channel),
            "movie" | "vod" => Ok(Self::Movie),
            "episode" => Ok(Self::Episode),
            "series" => Ok(Self::Series),
            other => Err(format!("unknown media type: {other}")),
        }
    }
}

impl TryFrom<String> for MediaType {
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
            MediaType::Channel,
            MediaType::Movie,
            MediaType::Episode,
            MediaType::Series,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = MediaType::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(MediaType::try_from("live").unwrap(), MediaType::Channel);
        assert_eq!(MediaType::try_from("vod").unwrap(), MediaType::Movie);
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(MediaType::try_from("unknown").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(MediaType::Movie.to_string(), "movie");
    }
}
