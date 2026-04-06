use crate::database::DbError;
use crate::models::{Recording, StorageBackend, TransferTask};

/// Persistence contract for DVR recordings, storage backends, and transfer tasks.
pub trait DvrRepository {
    fn save_recording(&self, rec: &Recording) -> Result<(), DbError>;
    fn load_recordings(&self) -> Result<Vec<Recording>, DbError>;
    fn update_recording(&self, rec: &Recording) -> Result<(), DbError>;
    fn delete_recording(&self, id: &str) -> Result<(), DbError>;
    fn save_storage_backend(&self, backend: &StorageBackend) -> Result<(), DbError>;
    fn load_storage_backends(&self) -> Result<Vec<StorageBackend>, DbError>;
    fn delete_storage_backend(&self, id: &str) -> Result<(), DbError>;
    fn save_transfer_task(&self, task: &TransferTask) -> Result<(), DbError>;
    fn load_transfer_tasks(&self) -> Result<Vec<TransferTask>, DbError>;
    fn update_transfer_task(&self, task: &TransferTask) -> Result<(), DbError>;
    fn delete_transfer_task(&self, id: &str) -> Result<(), DbError>;
}
