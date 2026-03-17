//! libmpv video backend using raw libmpv-sys FFI.
//!
//! Bypasses the `libmpv` crate's version check (which rejects newer mpv DLLs).
//! The mpv 2.x C API is backward-compatible with 1.x calls.
//! ABSOLUTE RULE: Hardware decode is mandatory (`hwdec=auto-safe`).

use std::ffi::{CStr, CString};
use std::ptr;
use std::sync::{Arc, Mutex};

use crate::backend::{PlayerBackend, PlayerError, PlayerState};

/// libmpv-based video player backend using raw FFI.
pub struct MpvBackend {
    handle: *mut libmpv_sys::mpv_handle,
    state: Arc<Mutex<PlayerState>>,
}

// Safety: mpv_handle is thread-safe per mpv documentation (commands can be sent from any thread)
unsafe impl Send for MpvBackend {}
unsafe impl Sync for MpvBackend {}

impl MpvBackend {
    /// Get the raw mpv handle for sharing with the render context.
    pub fn raw_handle(&self) -> *mut libmpv_sys::mpv_handle {
        self.handle
    }

    /// Create a new mpv backend with GPU-first quality settings.
    pub fn new() -> Result<Self, PlayerError> {
        let handle = unsafe { libmpv_sys::mpv_create() };
        if handle.is_null() {
            return Err(PlayerError::NotInitialized);
        }

        // Set quality properties BEFORE mpv_initialize
        // vo=libmpv is MANDATORY when using mpv_render_context_create().
        // vo=gpu-next creates its own window — causes the "detached player" bug.
        // All GPU quality settings (hwdec, interpolation, etc.) still work with vo=libmpv
        // because the render context provides the OpenGL surface.
        let props = [
            ("hwdec", "auto-safe"),
            ("vo", "libmpv"),
            ("gpu-hwdec-interop", "all"),
            ("profile", "gpu-hq"),
            ("video-sync", "display-resample"),
            ("interpolation", "yes"),
            ("tscale", "oversample"),
            ("deinterlace", "yes"),
            ("keep-open", "yes"),
            ("cache", "yes"),
            ("demuxer-max-bytes", "150MiB"),
        ];

        for (key, value) in &props {
            let k = CString::new(*key).unwrap();
            let v = CString::new(*value).unwrap();
            let ret = unsafe { libmpv_sys::mpv_set_option_string(handle, k.as_ptr(), v.as_ptr()) };
            if ret < 0 {
                tracing::warn!(key = %key, value = %value, code = ret, "mpv option failed (non-fatal)");
            }
        }

        let ret = unsafe { libmpv_sys::mpv_initialize(handle) };
        if ret < 0 {
            unsafe { libmpv_sys::mpv_destroy(handle) };
            return Err(PlayerError::Playback(format!(
                "mpv_initialize failed with code {ret}"
            )));
        }

        tracing::info!("MpvBackend initialized (raw FFI, gpu-hq, hwdec=auto-safe)");

        Ok(Self {
            handle,
            state: Arc::new(Mutex::new(PlayerState::Idle)),
        })
    }

    /// Send a command to mpv (e.g., "loadfile", "stop").
    fn command(&self, args: &[&str]) -> Result<(), PlayerError> {
        let c_args: Vec<CString> = args.iter().map(|a| CString::new(*a).unwrap()).collect();
        let mut ptrs: Vec<*const i8> = c_args.iter().map(|a| a.as_ptr()).collect();
        ptrs.push(ptr::null());

        let ret = unsafe { libmpv_sys::mpv_command(self.handle, ptrs.as_ptr() as *mut *const i8) };
        if ret < 0 {
            let err_str = unsafe {
                CStr::from_ptr(libmpv_sys::mpv_error_string(ret))
                    .to_string_lossy()
                    .to_string()
            };
            return Err(PlayerError::Playback(format!(
                "mpv command {:?} failed: {err_str}",
                args
            )));
        }
        Ok(())
    }

    /// Set a string property on mpv.
    fn set_property_string(&self, key: &str, value: &str) -> Result<(), PlayerError> {
        let k = CString::new(key).unwrap();
        let v = CString::new(value).unwrap();
        let ret =
            unsafe { libmpv_sys::mpv_set_property_string(self.handle, k.as_ptr(), v.as_ptr()) };
        if ret < 0 {
            let err_str = unsafe {
                CStr::from_ptr(libmpv_sys::mpv_error_string(ret))
                    .to_string_lossy()
                    .to_string()
            };
            return Err(PlayerError::Playback(format!(
                "set_property {key}={value} failed: {err_str}"
            )));
        }
        Ok(())
    }
}

impl PlayerBackend for MpvBackend {
    fn play(&self, url: &str) -> Result<(), PlayerError> {
        tracing::info!(url = %url, "MpvBackend: play");
        *self.state.lock().unwrap() = PlayerState::Buffering;
        self.command(&["loadfile", url, "replace"])?;
        *self.state.lock().unwrap() = PlayerState::Playing;
        Ok(())
    }

    fn pause(&self) -> Result<(), PlayerError> {
        let current = *self.state.lock().unwrap();
        match current {
            PlayerState::Playing => {
                self.set_property_string("pause", "yes")?;
                *self.state.lock().unwrap() = PlayerState::Paused;
            }
            PlayerState::Paused => {
                self.set_property_string("pause", "no")?;
                *self.state.lock().unwrap() = PlayerState::Playing;
            }
            _ => {}
        }
        Ok(())
    }

    fn seek(&self, position_secs: f64) -> Result<(), PlayerError> {
        self.command(&["seek", &position_secs.to_string(), "absolute"])?;
        Ok(())
    }

    fn set_volume(&self, volume: f32) -> Result<(), PlayerError> {
        let vol = (volume * 100.0).clamp(0.0, 100.0);
        self.set_property_string("volume", &vol.to_string())?;
        Ok(())
    }

    fn stop(&self) -> Result<(), PlayerError> {
        self.command(&["stop"])?;
        *self.state.lock().unwrap() = PlayerState::Stopped;
        Ok(())
    }

    fn state(&self) -> PlayerState {
        *self.state.lock().unwrap()
    }
}

impl Drop for MpvBackend {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            unsafe {
                libmpv_sys::mpv_terminate_destroy(self.handle);
            }
            tracing::info!("MpvBackend destroyed");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mpv_backend_init() {
        match MpvBackend::new() {
            Ok(backend) => assert_eq!(backend.state(), PlayerState::Idle),
            Err(e) => {
                eprintln!("libmpv not available — skipping test: {e}");
            }
        }
    }
}
