//! BackendType — storage backend protocol discriminator.
use serde::{Deserialize, Deserializer, Serialize};

/// Discriminates the storage protocol used by a [`crate::models::StorageBackend`].
///
/// Replaces `backend_type: String` in [`crate::models::StorageBackend`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum BackendType {
    /// Local filesystem storage.
    #[default]
    Local,
    /// SMB/CIFS network share.
    NetworkSmb,
    /// NFS network share.
    NetworkNfs,
    /// Cloud object storage (S3-compatible, Google Drive, etc.).
    Cloud,
}

impl BackendType {
    /// Returns the canonical string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Local => "local",
            Self::NetworkSmb => "network_smb",
            Self::NetworkNfs => "network_nfs",
            Self::Cloud => "cloud",
        }
    }
}

impl std::fmt::Display for BackendType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl TryFrom<&str> for BackendType {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        let normalized = s.trim().to_lowercase().replace(['-', ' '], "_");
        match normalized.as_str() {
            "local" => Ok(Self::Local),
            "network_smb" | "smb" => Ok(Self::NetworkSmb),
            "network_nfs" | "nfs" => Ok(Self::NetworkNfs),
            "cloud" | "s3" | "webdav" | "googledrive" | "google_drive" | "ftp" => Ok(Self::Cloud),
            other => Err(format!("unknown backend type: {other}")),
        }
    }
}

impl TryFrom<String> for BackendType {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::try_from(s.as_str())
    }
}

impl<'de> Deserialize<'de> for BackendType {
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
            BackendType::Local,
            BackendType::NetworkSmb,
            BackendType::NetworkNfs,
            BackendType::Cloud,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = BackendType::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(
            BackendType::try_from("smb").unwrap(),
            BackendType::NetworkSmb
        );
        assert_eq!(
            BackendType::try_from("nfs").unwrap(),
            BackendType::NetworkNfs
        );
        assert_eq!(BackendType::try_from("s3").unwrap(), BackendType::Cloud);
        assert_eq!(BackendType::try_from("webdav").unwrap(), BackendType::Cloud);
        assert_eq!(BackendType::try_from("ftp").unwrap(), BackendType::Cloud);
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(BackendType::try_from("sftp").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(BackendType::Local.to_string(), "local");
    }
}
