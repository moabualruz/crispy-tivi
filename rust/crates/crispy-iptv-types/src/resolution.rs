//! Stream resolution classification.

use serde::{Deserialize, Serialize};

/// Video resolution tier.
#[derive(
    Debug, Clone, Copy, Default, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize,
)]
pub enum Resolution {
    /// Unknown or undetectable resolution.
    #[default]
    Unknown,
    /// Standard definition (≤576p).
    SD,
    /// High definition (720p).
    HD,
    /// Full high definition (1080p).
    FHD,
    /// Ultra high definition (2160p / 4K).
    UHD,
}

impl std::fmt::Display for Resolution {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unknown => write!(f, "Unknown"),
            Self::SD => write!(f, "SD"),
            Self::HD => write!(f, "HD"),
            Self::FHD => write!(f, "FHD"),
            Self::UHD => write!(f, "UHD"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ordering_is_ascending() {
        assert!(Resolution::SD < Resolution::HD);
        assert!(Resolution::HD < Resolution::FHD);
        assert!(Resolution::FHD < Resolution::UHD);
    }

    #[test]
    fn default_is_unknown() {
        assert_eq!(Resolution::default(), Resolution::Unknown);
    }

    #[test]
    fn display_formats() {
        assert_eq!(Resolution::UHD.to_string(), "UHD");
        assert_eq!(Resolution::SD.to_string(), "SD");
    }
}
