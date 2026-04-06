//! TransferDirection — direction of a file transfer task.
use serde::{Deserialize, Serialize};

/// Direction of a file transfer between local and remote storage.
///
/// Replaces `direction: String` in [`crate::models::TransferTask`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum TransferDirection {
    /// Sending a local file to a remote backend.
    #[default]
    Upload,
    /// Fetching a remote file to local storage.
    Download,
}

impl TransferDirection {
    /// Returns the canonical lowercase string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Upload => "upload",
            Self::Download => "download",
        }
    }
}

impl std::fmt::Display for TransferDirection {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl TryFrom<&str> for TransferDirection {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "upload" => Ok(Self::Upload),
            "download" => Ok(Self::Download),
            other => Err(format!("unknown transfer direction: {other}")),
        }
    }
}

impl TryFrom<String> for TransferDirection {
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
        let variants = [TransferDirection::Upload, TransferDirection::Download];
        for v in &variants {
            let s = v.as_str();
            let parsed = TransferDirection::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(TransferDirection::try_from("sync").is_err());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(TransferDirection::Upload.to_string(), "upload");
    }
}
