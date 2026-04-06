//! CategoryType — discriminates the media category domain.
use serde::{Deserialize, Serialize};

/// Discriminates the domain of a [`crate::models::Category`].
///
/// Replaces `category_type: String` in [`crate::models::Category`]
/// and [`crate::models::FavoriteCategory`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum CategoryType {
    /// Live TV channels.
    #[default]
    Live,
    /// Video on demand (movies).
    Vod,
    /// Series/TV shows.
    Series,
    /// Radio streams.
    Radio,
}

impl CategoryType {
    /// Returns the canonical lowercase string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Live => "live",
            Self::Vod => "vod",
            Self::Series => "series",
            Self::Radio => "radio",
        }
    }
}

impl std::fmt::Display for CategoryType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl TryFrom<&str> for CategoryType {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "live" | "channel" | "channels" => Ok(Self::Live),
            "vod" | "movie" | "movies" => Ok(Self::Vod),
            "series" => Ok(Self::Series),
            "radio" => Ok(Self::Radio),
            other => Err(format!("unknown category type: {other}")),
        }
    }
}

impl TryFrom<String> for CategoryType {
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
            CategoryType::Live,
            CategoryType::Vod,
            CategoryType::Series,
            CategoryType::Radio,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = CategoryType::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(
            CategoryType::try_from("channel").unwrap(),
            CategoryType::Live
        );
        assert_eq!(CategoryType::try_from("movies").unwrap(), CategoryType::Vod);
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(CategoryType::try_from("unknown").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(CategoryType::Vod.to_string(), "vod");
    }
}
