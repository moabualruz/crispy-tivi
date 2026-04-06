//! MatchMethod — describes how an EPG mapping was produced.
use serde::{Deserialize, Serialize};

/// Describes the matching strategy that produced an [`crate::models::EpgMapping`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum MatchMethod {
    /// Exact match on the TVG-ID attribute.
    #[default]
    TvgIdExact,
    /// Fuzzy / approximate string match.
    Fuzzy,
    /// Manual override set by the user.
    Manual,
}

impl MatchMethod {
    /// Returns the canonical snake_case string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::TvgIdExact => "tvg_id_exact",
            Self::Fuzzy => "fuzzy",
            Self::Manual => "manual",
        }
    }
}

impl std::fmt::Display for MatchMethod {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl TryFrom<&str> for MatchMethod {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "tvg_id_exact" | "tvgidexact" | "exact" => Ok(Self::TvgIdExact),
            "fuzzy" => Ok(Self::Fuzzy),
            "manual" => Ok(Self::Manual),
            other => Err(format!("unknown match method: {other}")),
        }
    }
}

impl TryFrom<String> for MatchMethod {
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
            MatchMethod::TvgIdExact,
            MatchMethod::Fuzzy,
            MatchMethod::Manual,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = MatchMethod::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(
            MatchMethod::try_from("exact").unwrap(),
            MatchMethod::TvgIdExact
        );
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(MatchMethod::try_from("unknown").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(MatchMethod::TvgIdExact.to_string(), "tvg_id_exact");
        assert_eq!(MatchMethod::Fuzzy.to_string(), "fuzzy");
    }
}
