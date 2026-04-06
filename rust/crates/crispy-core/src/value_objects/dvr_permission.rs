//! DvrPermission — DVR access level of a user profile.
use serde::{Deserialize, Serialize};

/// DVR access level granted to a user profile.
///
/// Replaces `dvr_permission: i32` in [`crate::models::UserProfile`].
/// Stored as an integer (0/1/2) in the database.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum DvrPermission {
    /// No DVR access — cannot schedule or view recordings.
    None,
    /// View-only — can watch existing recordings but not schedule new ones.
    ViewOnly,
    /// Full access — can schedule, manage, and delete recordings.
    #[default]
    Full,
}

impl DvrPermission {
    /// Returns the canonical lowercase string used in FFI and display.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::None => "none",
            Self::ViewOnly => "view_only",
            Self::Full => "full",
        }
    }

    /// Returns the integer discriminant used for DB storage.
    pub fn as_i32(&self) -> i32 {
        match self {
            Self::None => 0,
            Self::ViewOnly => 1,
            Self::Full => 2,
        }
    }
}

impl std::fmt::Display for DvrPermission {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl From<i32> for DvrPermission {
    fn from(n: i32) -> Self {
        match n {
            0 => Self::None,
            1 => Self::ViewOnly,
            2 => Self::Full,
            _ => Self::Full,
        }
    }
}

impl TryFrom<&str> for DvrPermission {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "none" => Ok(Self::None),
            "view_only" | "viewonly" | "view-only" => Ok(Self::ViewOnly),
            "full" => Ok(Self::Full),
            other => Err(format!("unknown DVR permission: {other}")),
        }
    }
}

impl TryFrom<String> for DvrPermission {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::try_from(s.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_i32() {
        let variants = [
            DvrPermission::None,
            DvrPermission::ViewOnly,
            DvrPermission::Full,
        ];
        for v in &variants {
            let n = v.as_i32();
            let parsed = DvrPermission::from(n);
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn roundtrip_as_str() {
        let variants = [
            DvrPermission::None,
            DvrPermission::ViewOnly,
            DvrPermission::Full,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = DvrPermission::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(
            DvrPermission::try_from("viewonly").unwrap(),
            DvrPermission::ViewOnly
        );
        assert_eq!(
            DvrPermission::try_from("view-only").unwrap(),
            DvrPermission::ViewOnly
        );
    }

    #[test]
    fn unknown_i32_falls_back_to_full() {
        assert_eq!(DvrPermission::from(99), DvrPermission::Full);
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(DvrPermission::try_from("partial").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(DvrPermission::Full.to_string(), "full");
    }
}
