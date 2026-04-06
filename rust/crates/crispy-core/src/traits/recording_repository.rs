use crate::errors::DomainError;
use crate::models::Recording;

/// Persistence contract for DVR recordings.
pub trait RecordingRepository {
    fn save_recording(&self, rec: &Recording) -> Result<(), DomainError>;
    fn load_recordings(&self) -> Result<Vec<Recording>, DomainError>;
    fn update_recording(&self, rec: &Recording) -> Result<(), DomainError>;
    fn delete_recording(&self, id: &str) -> Result<(), DomainError>;
}
