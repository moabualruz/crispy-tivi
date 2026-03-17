//! libmpv video backend.
//!
//! Uses the `libmpv` crate for hardware-accelerated video playback.
//! ABSOLUTE RULE: Hardware decode is mandatory (`hwdec=auto`).

use std::sync::{Arc, Mutex};

use crate::backend::{PlayerBackend, PlayerError, PlayerState};

/// libmpv-based video player backend.
pub struct MpvBackend {
    mpv: libmpv::Mpv,
    state: Arc<Mutex<PlayerState>>,
}

impl MpvBackend {
    /// Create a new mpv backend instance with hardware decoding enabled.
    /// Return the raw mpv handle so it can be shared with the render context.
    ///
    /// # Safety
    /// The returned pointer is valid for the lifetime of this `MpvBackend`.
    /// The caller must not call `mpv_destroy` or `mpv_terminate_destroy` on it —
    /// the `libmpv::Mpv` destructor owns the handle.
    pub fn raw_handle(&self) -> *mut libmpv_sys::mpv_handle {
        self.mpv.ctx.as_ptr()
    }

    pub fn new() -> Result<Self, PlayerError> {
        let mpv = libmpv::Mpv::new().map_err(|e| PlayerError::Playback(e.to_string()))?;

        mpv.set_property("hwdec", "auto-safe")
            .map_err(|e| PlayerError::Playback(format!("Failed to set hwdec: {e}")))?;
        mpv.set_property("vo", "gpu-next")
            .map_err(|e| PlayerError::Playback(format!("Failed to set vo: {e}")))?;
        mpv.set_property("gpu-hwdec-interop", "all")
            .map_err(|e| PlayerError::Playback(format!("Failed to set gpu-hwdec-interop: {e}")))?;
        mpv.set_property("profile", "gpu-hq")
            .map_err(|e| PlayerError::Playback(format!("Failed to set profile: {e}")))?;
        mpv.set_property("video-sync", "display-resample")
            .map_err(|e| PlayerError::Playback(format!("Failed to set video-sync: {e}")))?;
        mpv.set_property("interpolation", "yes")
            .map_err(|e| PlayerError::Playback(format!("Failed to set interpolation: {e}")))?;
        mpv.set_property("tscale", "oversample")
            .map_err(|e| PlayerError::Playback(format!("Failed to set tscale: {e}")))?;
        mpv.set_property("deinterlace", "yes")
            .map_err(|e| PlayerError::Playback(format!("Failed to set deinterlace: {e}")))?;
        mpv.set_property("keep-open", "yes")
            .map_err(|e| PlayerError::Playback(format!("Failed to set keep-open: {e}")))?;
        mpv.set_property("cache", "yes")
            .map_err(|e| PlayerError::Playback(format!("Failed to set cache: {e}")))?;
        mpv.set_property("demuxer-max-bytes", "150MiB")
            .map_err(|e| PlayerError::Playback(format!("Failed to set demuxer-max-bytes: {e}")))?;

        tracing::info!("MpvBackend initialized with gpu-hq profile and auto-safe hwdec");

        Ok(Self {
            mpv,
            state: Arc::new(Mutex::new(PlayerState::Idle)),
        })
    }
}

impl PlayerBackend for MpvBackend {
    fn play(&self, url: &str) -> Result<(), PlayerError> {
        tracing::info!(url = %url, "MpvBackend: play");
        *self.state.lock().unwrap() = PlayerState::Buffering;

        self.mpv
            .command("loadfile", &[url, "replace"])
            .map_err(|e| PlayerError::Playback(format!("loadfile failed: {e}")))?;

        *self.state.lock().unwrap() = PlayerState::Playing;
        Ok(())
    }

    fn pause(&self) -> Result<(), PlayerError> {
        let current = *self.state.lock().unwrap();
        match current {
            PlayerState::Playing => {
                self.mpv
                    .set_property("pause", true)
                    .map_err(|e| PlayerError::Playback(format!("pause failed: {e}")))?;
                *self.state.lock().unwrap() = PlayerState::Paused;
            }
            PlayerState::Paused => {
                self.mpv
                    .set_property("pause", false)
                    .map_err(|e| PlayerError::Playback(format!("unpause failed: {e}")))?;
                *self.state.lock().unwrap() = PlayerState::Playing;
            }
            _ => {}
        }
        Ok(())
    }

    fn seek(&self, position_secs: f64) -> Result<(), PlayerError> {
        self.mpv
            .command("seek", &[&position_secs.to_string(), "absolute"])
            .map_err(|e| PlayerError::Playback(format!("seek failed: {e}")))?;
        Ok(())
    }

    fn set_volume(&self, volume: f32) -> Result<(), PlayerError> {
        let vol = (volume * 100.0).clamp(0.0, 100.0) as i64;
        self.mpv
            .set_property("volume", vol)
            .map_err(|e| PlayerError::Playback(format!("set volume failed: {e}")))?;
        Ok(())
    }

    fn stop(&self) -> Result<(), PlayerError> {
        self.mpv
            .command("stop", &[])
            .map_err(|e| PlayerError::Playback(format!("stop failed: {e}")))?;
        *self.state.lock().unwrap() = PlayerState::Stopped;
        Ok(())
    }

    fn state(&self) -> PlayerState {
        *self.state.lock().unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests require libmpv-2.dll in PATH or alongside the test binary.
    // They will be skipped in CI without the native library.

    #[test]
    fn test_mpv_backend_state_default() {
        // Only test if libmpv is available
        match MpvBackend::new() {
            Ok(backend) => assert_eq!(backend.state(), PlayerState::Idle),
            Err(_) => {
                eprintln!("libmpv not available — skipping test");
            }
        }
    }
}
