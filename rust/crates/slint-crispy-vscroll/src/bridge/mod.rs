//! Slint ↔ Rust bridge — VecModel management, property sync.

pub mod slot_model;
pub mod validation;

pub use slot_model::{to_slint_slot, to_slint_slots, SlotDescriptorSlint};
pub use validation::{validate_on_first_tick, validate_pool_size, ValidationContext};
