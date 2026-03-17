//! CrispyTivi video player — libmpv backend for all platforms.
//!
//! Uses pre-built libmpv binaries auto-downloaded by build.rs:
//! - Windows: shinchiro/mpv-winbuild-cmake
//! - macOS/iOS: media-kit/libmpv-darwin-build
//! - Android: jarnedemeulemeester/libmpv-android
//! - Linux: system libmpv (user must install via package manager)

mod backend;
pub mod mpv_backend;
pub mod video_underlay;

pub use backend::{PlayerBackend, PlayerError, PlayerState};

/// Check if libmpv is available on this system.
/// On Linux, libmpv must be installed via the system package manager.
/// Returns Ok(()) if available, Err with install instructions if not.
pub fn check_libmpv_available() -> Result<(), String> {
    match mpv_backend::MpvBackend::new() {
        Ok(_) => Ok(()),
        Err(e) => {
            let msg = format!("{e}");
            #[cfg(target_os = "linux")]
            {
                return Err(format!(
                    "libmpv is required but not found on this system.\n\n\
                     Error: {msg}\n\n\
                     Please install it using your package manager:\n\
                     \n\
                     Ubuntu/Debian:  sudo apt install libmpv2\n\
                     Fedora:         sudo dnf install mpv-libs\n\
                     Arch Linux:     sudo pacman -S mpv\n\
                     openSUSE:       sudo zypper install libmpv2\n\
                     \n\
                     Then restart CrispyTivi."
                ));
            }
            #[cfg(not(target_os = "linux"))]
            Err(format!("Failed to initialize libmpv: {msg}"))
        }
    }
}
