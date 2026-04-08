//! LayoutType — multi-view layout configuration.
use serde::{Deserialize, Deserializer, Serialize, Serializer};

/// Discriminates the grid layout used in a multi-view saved layout.
///
/// Replaces `layout: String` in [`crate::models::SavedLayout`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, Default)]
pub enum LayoutType {
    /// 2×2 grid (four streams).
    #[default]
    Grid2x2,
    /// 3×3 grid (nine streams).
    Grid3x3,
    /// Picture-in-picture overlay.
    PictureInPicture,
    /// Two streams side by side.
    SideBySide,
    /// User-defined custom layout.
    Custom,
}

impl LayoutType {
    /// Returns the canonical string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Grid2x2 => "grid_2x2",
            Self::Grid3x3 => "grid_3x3",
            Self::PictureInPicture => "pip",
            Self::SideBySide => "side_by_side",
            Self::Custom => "custom",
        }
    }
}

impl std::fmt::Display for LayoutType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl Serialize for LayoutType {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.as_str())
    }
}

impl TryFrom<&str> for LayoutType {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        let normalized = s.trim().to_lowercase().replace(['-', ' '], "_");
        match normalized.as_str() {
            "grid_2x2" | "grid2x2" | "quad" | "2x2" | "grid" => Ok(Self::Grid2x2),
            "grid_3x3" | "grid3x3" | "3x3" => Ok(Self::Grid3x3),
            "pip" | "picture_in_picture" | "pictureinpicture" => Ok(Self::PictureInPicture),
            "side_by_side" | "sidebyside" => Ok(Self::SideBySide),
            "custom" => Ok(Self::Custom),
            other => Err(format!("unknown layout type: {other}")),
        }
    }
}

impl TryFrom<String> for LayoutType {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::try_from(s.as_str())
    }
}

impl<'de> Deserialize<'de> for LayoutType {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let raw = String::deserialize(deserializer)?;
        Self::try_from(raw).map_err(serde::de::Error::custom)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_as_str() {
        let variants = [
            LayoutType::Grid2x2,
            LayoutType::Grid3x3,
            LayoutType::PictureInPicture,
            LayoutType::SideBySide,
            LayoutType::Custom,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = LayoutType::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(LayoutType::try_from("quad").unwrap(), LayoutType::Grid2x2);
        assert_eq!(LayoutType::try_from("2x2").unwrap(), LayoutType::Grid2x2);
        assert_eq!(LayoutType::try_from("grid").unwrap(), LayoutType::Grid2x2);
        assert_eq!(
            LayoutType::try_from("pip").unwrap(),
            LayoutType::PictureInPicture
        );
        assert_eq!(
            LayoutType::try_from("side-by-side").unwrap(),
            LayoutType::SideBySide
        );
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(LayoutType::try_from("fullscreen").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(LayoutType::Grid2x2.to_string(), "grid_2x2");
    }

    #[test]
    fn serialize_uses_canonical_values() {
        assert_eq!(
            serde_json::to_string(&LayoutType::Grid2x2).unwrap(),
            "\"grid_2x2\""
        );
        assert_eq!(
            serde_json::to_string(&LayoutType::PictureInPicture).unwrap(),
            "\"pip\""
        );
    }

    #[test]
    fn alias_input_re_serializes_canonically() {
        let parsed: LayoutType = serde_json::from_str("\"quad\"").unwrap();

        assert_eq!(parsed, LayoutType::Grid2x2);
        assert_eq!(serde_json::to_string(&parsed).unwrap(), "\"grid_2x2\"");
    }
}
