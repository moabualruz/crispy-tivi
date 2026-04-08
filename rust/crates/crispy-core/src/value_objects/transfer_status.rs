//! TransferStatus — lifecycle state of a file transfer task.
use serde::{Deserialize, Deserializer, Serialize, Serializer};

/// Lifecycle state of a file transfer task.
///
/// Replaces `status: String` in [`crate::models::TransferTask`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, Default)]
pub enum TransferStatus {
    /// Queued, waiting to start.
    #[default]
    Pending,
    /// Currently transferring.
    InProgress,
    /// Transfer finished successfully.
    Completed,
    /// Transfer failed due to an error.
    Failed,
    /// Transfer was cancelled before completion.
    Cancelled,
}

impl TransferStatus {
    /// Returns the canonical lowercase string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::InProgress => "in_progress",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Cancelled => "cancelled",
        }
    }

    /// Whether this status represents a terminal state.
    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Completed | Self::Failed | Self::Cancelled)
    }
}

impl std::fmt::Display for TransferStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl Serialize for TransferStatus {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.as_str())
    }
}

impl TryFrom<&str> for TransferStatus {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        let normalized = s.trim().to_lowercase().replace(['-', ' '], "_");
        match normalized.as_str() {
            "pending" | "queued" => Ok(Self::Pending),
            "in_progress" | "inprogress" | "active" => Ok(Self::InProgress),
            "completed" | "done" => Ok(Self::Completed),
            "failed" | "error" => Ok(Self::Failed),
            "cancelled" | "canceled" => Ok(Self::Cancelled),
            other => Err(format!("unknown transfer status: {other}")),
        }
    }
}

impl TryFrom<String> for TransferStatus {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        Self::try_from(s.as_str())
    }
}

impl<'de> Deserialize<'de> for TransferStatus {
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
            TransferStatus::Pending,
            TransferStatus::InProgress,
            TransferStatus::Completed,
            TransferStatus::Failed,
            TransferStatus::Cancelled,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = TransferStatus::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(
            TransferStatus::try_from("queued").unwrap(),
            TransferStatus::Pending
        );
        assert_eq!(
            TransferStatus::try_from("active").unwrap(),
            TransferStatus::InProgress
        );
        assert_eq!(
            TransferStatus::try_from("done").unwrap(),
            TransferStatus::Completed
        );
        assert_eq!(
            TransferStatus::try_from("error").unwrap(),
            TransferStatus::Failed
        );
        assert_eq!(
            TransferStatus::try_from("canceled").unwrap(),
            TransferStatus::Cancelled
        );
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(TransferStatus::try_from("unknown").is_err());
    }

    #[test]
    fn terminal_states() {
        assert!(TransferStatus::Completed.is_terminal());
        assert!(TransferStatus::Failed.is_terminal());
        assert!(TransferStatus::Cancelled.is_terminal());
        assert!(!TransferStatus::Pending.is_terminal());
        assert!(!TransferStatus::InProgress.is_terminal());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(TransferStatus::Pending.to_string(), "pending");
    }

    #[test]
    fn serialize_uses_canonical_values() {
        assert_eq!(
            serde_json::to_string(&TransferStatus::InProgress).unwrap(),
            "\"in_progress\""
        );
        assert_eq!(
            serde_json::to_string(&TransferStatus::Cancelled).unwrap(),
            "\"cancelled\""
        );
    }

    #[test]
    fn alias_input_re_serializes_canonically() {
        let parsed: TransferStatus = serde_json::from_str("\"active\"").unwrap();

        assert_eq!(parsed, TransferStatus::InProgress);
        assert_eq!(serde_json::to_string(&parsed).unwrap(), "\"in_progress\"");
    }
}
