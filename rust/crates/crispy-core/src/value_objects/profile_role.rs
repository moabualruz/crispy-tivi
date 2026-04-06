//! ProfileRole — role level of a user profile.
use rusqlite::types::{FromSql, FromSqlResult, ToSql, ToSqlOutput, ValueRef};
use serde::{Deserialize, Serialize};

/// Role level of a user profile.
///
/// Replaces `role: i32` in [`crate::models::UserProfile`].
/// Stored as an integer (0/1/2) in the database.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum ProfileRole {
    /// Administrator — full access to all features.
    Admin,
    /// Standard viewer — can watch but not manage.
    #[default]
    Viewer,
    /// Restricted — child/guest profile with content limits.
    Restricted,
}

impl ProfileRole {
    /// Returns the canonical lowercase string used in FFI and display.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Admin => "admin",
            Self::Viewer => "viewer",
            Self::Restricted => "restricted",
        }
    }

    /// Returns the integer discriminant used for DB storage.
    pub fn as_i32(&self) -> i32 {
        match self {
            Self::Admin => 0,
            Self::Viewer => 1,
            Self::Restricted => 2,
        }
    }
}

impl std::fmt::Display for ProfileRole {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl From<i32> for ProfileRole {
    fn from(n: i32) -> Self {
        match n {
            0 => Self::Admin,
            1 => Self::Viewer,
            2 => Self::Restricted,
            _ => Self::Viewer,
        }
    }
}

impl TryFrom<&str> for ProfileRole {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "admin" => Ok(Self::Admin),
            "viewer" => Ok(Self::Viewer),
            "restricted" => Ok(Self::Restricted),
            other => Err(format!("unknown profile role: {other}")),
        }
    }
}

impl TryFrom<String> for ProfileRole {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::try_from(s.as_str())
    }
}

impl FromSql for ProfileRole {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        let n = i32::column_result(value)?;
        Ok(Self::from(n))
    }
}

impl ToSql for ProfileRole {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(ToSqlOutput::from(self.as_i32()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_i32() {
        let variants = [
            ProfileRole::Admin,
            ProfileRole::Viewer,
            ProfileRole::Restricted,
        ];
        for v in &variants {
            let n = v.as_i32();
            let parsed = ProfileRole::from(n);
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn roundtrip_as_str() {
        let variants = [
            ProfileRole::Admin,
            ProfileRole::Viewer,
            ProfileRole::Restricted,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = ProfileRole::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn unknown_i32_falls_back_to_viewer() {
        assert_eq!(ProfileRole::from(99), ProfileRole::Viewer);
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(ProfileRole::try_from("superuser").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(ProfileRole::Admin.to_string(), "admin");
    }
}
