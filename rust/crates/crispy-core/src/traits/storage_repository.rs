use crate::errors::DomainError;
use crate::models::StorageBackend;

/// Persistence contract for DVR storage backends.
pub trait StorageRepository {
    fn save_storage_backend(&self, backend: &StorageBackend) -> Result<(), DomainError>;
    fn load_storage_backends(&self) -> Result<Vec<StorageBackend>, DomainError>;
    fn delete_storage_backend(&self, id: &str) -> Result<(), DomainError>;
}
