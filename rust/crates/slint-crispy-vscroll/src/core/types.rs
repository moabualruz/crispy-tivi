//! Core primitive types for slint-crispy-vscroll.

use std::ops::{Add, Div, Mul, Neg, Sub};

// ---------------------------------------------------------------------------
// Vec2
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}

impl Vec2 {
    pub const ZERO: Self = Self { x: 0.0, y: 0.0 };

    pub fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }

    pub fn magnitude(&self) -> f32 {
        (self.x * self.x + self.y * self.y).sqrt()
    }

    pub fn dot(&self, other: &Self) -> f32 {
        self.x * other.x + self.y * other.y
    }

    pub fn clamp(&self, min: Self, max: Self) -> Self {
        Self {
            x: self.x.clamp(min.x, max.x),
            y: self.y.clamp(min.y, max.y),
        }
    }

    pub fn is_finite(&self) -> bool {
        self.x.is_finite() && self.y.is_finite()
    }
}

impl Add for Vec2 {
    type Output = Self;
    fn add(self, rhs: Self) -> Self {
        Self::new(self.x + rhs.x, self.y + rhs.y)
    }
}

impl Sub for Vec2 {
    type Output = Self;
    fn sub(self, rhs: Self) -> Self {
        Self::new(self.x - rhs.x, self.y - rhs.y)
    }
}

impl Mul<f32> for Vec2 {
    type Output = Self;
    fn mul(self, rhs: f32) -> Self {
        Self::new(self.x * rhs, self.y * rhs)
    }
}

impl Div<f32> for Vec2 {
    type Output = Self;
    fn div(self, rhs: f32) -> Self {
        Self::new(self.x / rhs, self.y / rhs)
    }
}

impl Neg for Vec2 {
    type Output = Self;
    fn neg(self) -> Self {
        Self::new(-self.x, -self.y)
    }
}

// ---------------------------------------------------------------------------
// Vec3
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

// ---------------------------------------------------------------------------
// Direction / Axis / NavDirection
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Direction {
    Vertical,
    Horizontal,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Axis {
    Vertical,
    Horizontal,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NavDirection {
    Up,
    Down,
    Left,
    Right,
}

impl NavDirection {
    pub fn axis(&self) -> Axis {
        match self {
            Self::Up | Self::Down => Axis::Vertical,
            Self::Left | Self::Right => Axis::Horizontal,
        }
    }

    pub fn is_forward(&self) -> bool {
        matches!(self, Self::Down | Self::Right)
    }
}

// ---------------------------------------------------------------------------
// Edge
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Edge {
    None,
    Start,
    End,
    Both,
}

// ---------------------------------------------------------------------------
// SnapMode
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SnapMode {
    None,
    Nearest,
    StartAligned,
    CenterAligned,
}

// ---------------------------------------------------------------------------
// ScrollPhase
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ScrollPhase {
    Started,
    Moved,
    Ended,
    Cancelled,
    Momentum,
    Settling,
}

// ---------------------------------------------------------------------------
// ScrollSource
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ScrollSource {
    Touch,
    Mouse,
    Trackpad,
    DPad,
    GamepadStick,
    GamepadTrigger,
    Programmatic,
    Keyboard,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vec2_magnitude() {
        let v = Vec2::new(3.0, 4.0);
        assert!((v.magnitude() - 5.0).abs() < 0.001);
    }

    #[test]
    fn test_vec2_clamp() {
        let v = Vec2::new(-5.0, 15.0);
        let clamped = v.clamp(Vec2::ZERO, Vec2::new(10.0, 10.0));
        assert_eq!(clamped.x, 0.0);
        assert_eq!(clamped.y, 10.0);
    }

    #[test]
    fn test_vec2_arithmetic() {
        let a = Vec2::new(1.0, 2.0);
        let b = Vec2::new(3.0, 4.0);
        let sum = a + b;
        assert_eq!(sum.x, 4.0);
        assert_eq!(sum.y, 6.0);
        let diff = b - a;
        assert_eq!(diff.x, 2.0);
        assert_eq!(diff.y, 2.0);
        let scaled = a * 3.0;
        assert_eq!(scaled.x, 3.0);
        assert_eq!(scaled.y, 6.0);
    }

    #[test]
    fn test_vec2_dot() {
        let a = Vec2::new(1.0, 0.0);
        let b = Vec2::new(0.0, 1.0);
        assert_eq!(a.dot(&b), 0.0); // perpendicular
    }

    #[test]
    fn test_vec2_is_finite() {
        assert!(Vec2::new(1.0, 2.0).is_finite());
        assert!(!Vec2::new(f32::NAN, 0.0).is_finite());
        assert!(!Vec2::new(0.0, f32::INFINITY).is_finite());
    }

    #[test]
    fn test_nav_direction_axis() {
        assert_eq!(NavDirection::Up.axis(), Axis::Vertical);
        assert_eq!(NavDirection::Down.axis(), Axis::Vertical);
        assert_eq!(NavDirection::Left.axis(), Axis::Horizontal);
        assert_eq!(NavDirection::Right.axis(), Axis::Horizontal);
    }

    #[test]
    fn test_nav_direction_is_forward() {
        assert!(!NavDirection::Up.is_forward());
        assert!(NavDirection::Down.is_forward());
        assert!(!NavDirection::Left.is_forward());
        assert!(NavDirection::Right.is_forward());
    }

    #[test]
    fn test_vec2_div_and_neg() {
        let v = Vec2::new(6.0, 4.0);
        let halved = v / 2.0;
        assert_eq!(halved.x, 3.0);
        assert_eq!(halved.y, 2.0);
        let neg = -v;
        assert_eq!(neg.x, -6.0);
        assert_eq!(neg.y, -4.0);
    }

    #[test]
    fn test_vec2_zero_constant() {
        assert_eq!(Vec2::ZERO, Vec2::new(0.0, 0.0));
    }

    #[test]
    fn test_edge_variants_distinct() {
        assert_ne!(Edge::None, Edge::Start);
        assert_ne!(Edge::End, Edge::Both);
    }

    #[test]
    fn test_snap_mode_variants() {
        assert_ne!(SnapMode::None, SnapMode::Nearest);
        assert_ne!(SnapMode::StartAligned, SnapMode::CenterAligned);
    }

    #[test]
    fn test_scroll_phase_variants() {
        let phases = [
            ScrollPhase::Started,
            ScrollPhase::Moved,
            ScrollPhase::Ended,
            ScrollPhase::Cancelled,
            ScrollPhase::Momentum,
            ScrollPhase::Settling,
        ];
        // All 6 variants are distinct
        for (i, a) in phases.iter().enumerate() {
            for (j, b) in phases.iter().enumerate() {
                if i == j {
                    assert_eq!(a, b);
                } else {
                    assert_ne!(a, b);
                }
            }
        }
    }

    #[test]
    fn test_scroll_source_variants() {
        assert_ne!(ScrollSource::Touch, ScrollSource::Mouse);
        assert_ne!(ScrollSource::DPad, ScrollSource::Keyboard);
        assert_ne!(ScrollSource::GamepadStick, ScrollSource::GamepadTrigger);
        assert_ne!(ScrollSource::Programmatic, ScrollSource::Trackpad);
    }
}
