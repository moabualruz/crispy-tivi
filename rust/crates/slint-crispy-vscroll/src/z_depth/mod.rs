//! Z-depth transform system — parallax, card-deck, cover-flow, presets.

#[cfg(feature = "z-card-deck")]
pub mod card_deck;
#[cfg(feature = "z-cover-flow")]
pub mod cover_flow;
#[cfg(feature = "z-custom")]
pub mod custom;
#[cfg(feature = "z-parallax")]
pub mod parallax;
pub mod presets;
