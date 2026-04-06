use crate::errors::DomainError;
use crate::models::TransferTask;

/// Persistence contract for DVR transfer tasks.
pub trait TransferRepository {
    fn save_transfer_task(&self, task: &TransferTask) -> Result<(), DomainError>;
    fn load_transfer_tasks(&self) -> Result<Vec<TransferTask>, DomainError>;
    fn update_transfer_task(&self, task: &TransferTask) -> Result<(), DomainError>;
    fn delete_transfer_task(&self, id: &str) -> Result<(), DomainError>;
}
