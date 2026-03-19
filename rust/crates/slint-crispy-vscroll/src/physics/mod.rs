//! Scroll physics engine — momentum, snap, rubber-band, spring.

#[cfg(feature = "momentum")]
pub mod momentum;
pub mod presets;
#[cfg(feature = "rubber-band")]
pub mod rubber_band;
#[cfg(any(
    feature = "snap-nearest",
    feature = "snap-start",
    feature = "snap-center"
))]
pub mod snap;
#[cfg(feature = "spring-physics")]
pub mod spring;
