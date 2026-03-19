//! OS reduced-motion preference detection.
//! Currently returns false. Platform-specific detection to be added later.

/// Query whether the OS prefers reduced motion.
///
/// Returns `true` if the user has enabled reduced-motion in their OS accessibility settings.
/// Currently a stub — always returns `false`. Platform-specific detection will be added:
/// - Windows: `SPI_GETCLIENTAREAANIMATION`
/// - macOS: `NSWorkspace.accessibilityDisplayShouldReduceMotion`
/// - Linux: `org.gnome.desktop.interface.enable-animations`
/// - WASM: `prefers-reduced-motion` media query
pub fn is_reduced_motion_preferred() -> bool {
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_reduced_motion_default_is_false() {
        assert!(!is_reduced_motion_preferred());
    }

    #[test]
    fn test_reduced_motion_returns_bool() {
        let result: bool = is_reduced_motion_preferred();
        assert!(!result);
    }
}
