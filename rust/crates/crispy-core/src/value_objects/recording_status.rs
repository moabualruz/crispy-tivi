//! RecordingStatus — lifecycle state of a recording.
use serde::{Deserialize, Serialize};

/// Lifecycle state of a scheduled or active recording.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum RecordingStatus {
    /// Recording has been scheduled but not yet started.
    #[default]
    Scheduled,
    /// Recording is currently in progress.
    Recording,
    /// Recording finished successfully.
    Completed,
    /// Recording failed due to an error.
    Failed,
    /// Recording was cancelled before it started or while in progress.
    Cancelled,
}

impl RecordingStatus {
    /// Returns the canonical lowercase string used in storage and FFI.
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Scheduled => "scheduled",
            Self::Recording => "recording",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Cancelled => "cancelled",
        }
    }

    /// Whether this status represents a terminal state (no further transitions expected).
    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Completed | Self::Failed | Self::Cancelled)
    }
}

impl std::fmt::Display for RecordingStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl TryFrom<&str> for RecordingStatus {
    type Error = String;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "scheduled" => Ok(Self::Scheduled),
            "recording" | "active" => Ok(Self::Recording),
            "completed" | "done" => Ok(Self::Completed),
            "failed" | "error" => Ok(Self::Failed),
            "cancelled" | "canceled" => Ok(Self::Cancelled),
            other => Err(format!("unknown recording status: {other}")),
        }
    }
}

impl TryFrom<String> for RecordingStatus {
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
            RecordingStatus::Scheduled,
            RecordingStatus::Recording,
            RecordingStatus::Completed,
            RecordingStatus::Failed,
            RecordingStatus::Cancelled,
        ];
        for v in &variants {
            let s = v.as_str();
            let parsed = RecordingStatus::try_from(s).expect("roundtrip failed");
            assert_eq!(&parsed, v);
        }
    }

    #[test]
    fn try_from_aliases() {
        assert_eq!(
            RecordingStatus::try_from("active").unwrap(),
            RecordingStatus::Recording
        );
        assert_eq!(
            RecordingStatus::try_from("canceled").unwrap(),
            RecordingStatus::Cancelled
        );
        assert_eq!(
            RecordingStatus::try_from("error").unwrap(),
            RecordingStatus::Failed
        );
    }

    #[test]
    fn try_from_unknown_errors() {
        assert!(RecordingStatus::try_from("unknown").is_err());
    }

    #[test]
    fn terminal_states() {
        assert!(RecordingStatus::Completed.is_terminal());
        assert!(RecordingStatus::Failed.is_terminal());
        assert!(RecordingStatus::Cancelled.is_terminal());
        assert!(!RecordingStatus::Scheduled.is_terminal());
        assert!(!RecordingStatus::Recording.is_terminal());
    }

    #[test]
    fn display_matches_as_str() {
        assert_eq!(RecordingStatus::Scheduled.to_string(), "scheduled");
    }
}
