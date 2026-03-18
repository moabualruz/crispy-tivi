//! Spatial focus system for D-Pad / keyboard navigation.
//!
//! # Overview
//! - [`types`]     — `FocusNode`, `FocusZone`, `Rect`, `Direction`
//! - [`algorithm`] — nearest-neighbour scoring (3:1 primary/secondary weight)
//! - [`manager`]   — `FocusManager`: zone registry, navigation, modal stack

pub mod algorithm;
pub mod manager;
pub mod types;

pub use manager::FocusManager;
pub use types::{Direction, FocusNode, FocusZone, Rect};
