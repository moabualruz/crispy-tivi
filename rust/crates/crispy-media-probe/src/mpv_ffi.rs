//! Raw FFI bindings for libmpv, loaded at runtime via `libloading`.
//!
//! This module defines the minimal subset of the mpv client API needed for
//! stream probing and screenshot capture. The library is loaded at runtime
//! (not linked at compile time) so that:
//!
//! - Builds succeed without libmpv installed
//! - The bundled libmpv from media_kit can be used via `CRISPY_LIBMPV_PATH`
//! - System libmpv is tried as a fallback

use std::ffi::{CStr, CString, c_char, c_int, c_void};
use std::path::Path;
use std::sync::OnceLock;

use libloading::{Library, Symbol};
use tracing::{debug, warn};

use crate::error::ProbeError;

/// mpv error codes (subset).
const MPV_ERROR_SUCCESS: c_int = 0;

/// mpv format codes for property access.
#[repr(C)]
#[allow(dead_code)]
pub(crate) enum MpvFormat {
    None = 0,
    String = 1,
    OsdString = 2,
    Flag = 3,
    Int64 = 4,
    Double = 5,
    // Node = 6, — not needed for probing
}

/// mpv event IDs (subset).
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(dead_code)]
pub(crate) enum MpvEventId {
    None = 0,
    Shutdown = 1,
    LogMessage = 6,
    GetPropertyReply = 8,
    SetPropertyReply = 9,
    CommandReply = 10,
    StartFile = 16,
    EndFile = 17,
    FileLoaded = 18,
    Idle = 19, // deprecated but still fires
    PropertyChange = 22,
}

/// Minimal mpv_event structure.
#[repr(C)]
pub(crate) struct MpvEvent {
    pub event_id: c_int,
    pub error: c_int,
    pub reply_userdata: u64,
    pub data: *mut c_void,
}

/// Function table loaded from libmpv at runtime.
pub(crate) struct MpvFunctions {
    _lib: Library,

    pub create: unsafe extern "C" fn() -> *mut c_void,
    pub initialize: unsafe extern "C" fn(ctx: *mut c_void) -> c_int,
    pub destroy: unsafe extern "C" fn(ctx: *mut c_void),
    pub set_option_string:
        unsafe extern "C" fn(ctx: *mut c_void, name: *const c_char, data: *const c_char) -> c_int,
    pub command: unsafe extern "C" fn(ctx: *mut c_void, args: *mut *const c_char) -> c_int,
    pub get_property_string:
        unsafe extern "C" fn(ctx: *mut c_void, name: *const c_char) -> *mut c_char,
    pub get_property: unsafe extern "C" fn(
        ctx: *mut c_void,
        name: *const c_char,
        format: c_int,
        data: *mut c_void,
    ) -> c_int,
    pub free: unsafe extern "C" fn(data: *mut c_void),
    pub wait_event: unsafe extern "C" fn(ctx: *mut c_void, timeout: f64) -> *mut MpvEvent,
    pub error_string: unsafe extern "C" fn(error: c_int) -> *const c_char,
}

// SAFETY: MpvFunctions is only a table of function pointers plus the library
// handle. The mpv client API is documented as thread-safe — each handle is
// independent. We hold the Library to keep it loaded.
unsafe impl Send for MpvFunctions {}
unsafe impl Sync for MpvFunctions {}

/// Cached library load result so we only attempt dlopen once.
static MPV_LIB: OnceLock<Result<MpvFunctions, String>> = OnceLock::new();

/// Get the libmpv library path from environment or use system default.
fn get_libmpv_path() -> Option<String> {
    std::env::var("CRISPY_LIBMPV_PATH").ok()
}

/// Platform-specific default library names to try.
fn default_lib_names() -> &'static [&'static str] {
    #[cfg(target_os = "windows")]
    {
        &["libmpv-2.dll", "mpv-2.dll", "mpv.dll"]
    }
    #[cfg(target_os = "macos")]
    {
        &["libmpv.dylib", "libmpv.2.dylib"]
    }
    #[cfg(target_os = "linux")]
    {
        &["libmpv.so", "libmpv.so.2", "libmpv.so.1"]
    }
    #[cfg(target_os = "android")]
    {
        &["libmpv.so"]
    }
    #[cfg(not(any(
        target_os = "windows",
        target_os = "macos",
        target_os = "linux",
        target_os = "android"
    )))]
    {
        &["libmpv.so", "libmpv.dylib"]
    }
}

/// Load libmpv from a specific path.
///
/// # Safety
/// Loads a dynamic library and resolves function pointers.
unsafe fn load_lib_from_path(path: &str) -> Result<MpvFunctions, String> {
    // SAFETY: We trust the library at the given path implements the mpv
    // client API. Caller is responsible for providing a valid library path.
    let lib = unsafe { Library::new(path) }.map_err(|e| format!("failed to load {path}: {e}"))?;
    load_symbols(lib)
}

/// Load libmpv from system defaults.
///
/// # Safety
/// Loads a dynamic library and resolves function pointers.
unsafe fn load_lib_default() -> Result<MpvFunctions, String> {
    let names = default_lib_names();
    let mut last_err = String::from("no library names to try");

    for name in names {
        // SAFETY: We trust the system-installed libmpv implements the mpv
        // client API. Each candidate name is tried in order.
        match unsafe { Library::new(*name) } {
            Ok(lib) => {
                debug!(lib_name = *name, "loaded libmpv");
                return load_symbols(lib);
            }
            Err(e) => {
                last_err = format!("{name}: {e}");
                debug!(lib_name = *name, error = %e, "libmpv candidate not found");
            }
        }
    }

    Err(format!(
        "libmpv not found on system — last error: {last_err}"
    ))
}

/// Resolve all required symbols from the loaded library.
fn load_symbols(lib: Library) -> Result<MpvFunctions, String> {
    // SAFETY: All symbols below are part of the stable mpv client API
    // (client.h). The function signatures match the C declarations.
    unsafe {
        macro_rules! sym {
            ($lib:expr, $name:expr) => {
                **$lib
                    .get::<Symbol<_>>(concat!("mpv_", $name, "\0").as_bytes())
                    .map_err(|e| format!("symbol mpv_{} not found: {}", $name, e))?
            };
        }

        Ok(MpvFunctions {
            create: sym!(lib, "create"),
            initialize: sym!(lib, "initialize"),
            destroy: sym!(lib, "destroy"),
            set_option_string: sym!(lib, "set_option_string"),
            command: sym!(lib, "command"),
            get_property_string: sym!(lib, "get_property_string"),
            get_property: sym!(lib, "get_property"),
            free: sym!(lib, "free"),
            wait_event: sym!(lib, "wait_event"),
            error_string: sym!(lib, "error_string"),
            _lib: lib,
        })
    }
}

/// Get a reference to the loaded libmpv function table.
///
/// Tries `CRISPY_LIBMPV_PATH` first, then system defaults. The result is
/// cached for the process lifetime.
pub(crate) fn get_mpv_functions() -> Result<&'static MpvFunctions, ProbeError> {
    let result = MPV_LIB.get_or_init(|| {
        if let Some(path) = get_libmpv_path() {
            debug!(path = %path, "loading libmpv from CRISPY_LIBMPV_PATH");
            if !Path::new(&path).exists() {
                warn!(path = %path, "CRISPY_LIBMPV_PATH does not exist, trying system default");
                // SAFETY: loading system default libmpv via dlopen.
                return unsafe { load_lib_default() };
            }
            // SAFETY: loading libmpv from user-specified path via dlopen.
            return unsafe { load_lib_from_path(&path) };
        }

        debug!("loading libmpv from system default");
        // SAFETY: loading system default libmpv via dlopen.
        unsafe { load_lib_default() }
    });

    result
        .as_ref()
        .map_err(|e| ProbeError::MpvUnavailable(e.clone()))
}

/// RAII wrapper for an mpv handle.
///
/// Creates an mpv context configured for headless probing (no video/audio
/// output). Destroys the handle on drop.
pub(crate) struct MpvHandle {
    ctx: *mut c_void,
    funcs: &'static MpvFunctions,
}

// SAFETY: mpv client API is documented as thread-safe. Each mpv_handle is
// independent and can be used from any thread.
unsafe impl Send for MpvHandle {}

impl MpvHandle {
    /// Create a new headless mpv context for probing.
    ///
    /// Sets `--no-video`, `--no-audio`, `--no-terminal`, `--demuxer-max-bytes`
    /// and `--demuxer-readahead-secs` for efficient probing without rendering.
    pub fn new_for_probing() -> Result<Self, ProbeError> {
        let funcs = get_mpv_functions()?;

        // SAFETY: mpv_create returns a new handle or NULL.
        let ctx = unsafe { (funcs.create)() };
        if ctx.is_null() {
            return Err(ProbeError::MpvInitFailed(
                "mpv_create returned null".to_string(),
            ));
        }

        let handle = Self { ctx, funcs };

        // Configure for headless probing.
        handle.set_option("vid", "no")?;
        handle.set_option("aid", "no")?;
        handle.set_option("terminal", "no")?;
        handle.set_option("msg-level", "all=error")?;
        handle.set_option("demuxer-max-bytes", "1MiB")?;
        handle.set_option("demuxer-readahead-secs", "2")?;

        // SAFETY: ctx is valid (non-null, just created).
        let err = unsafe { (funcs.initialize)(ctx) };
        if err != MPV_ERROR_SUCCESS {
            let msg = handle.error_to_string(err);
            // Note: drop will call destroy.
            return Err(ProbeError::MpvInitFailed(msg));
        }

        Ok(handle)
    }

    /// Create a new mpv context configured for screenshot capture.
    ///
    /// Enables video decoding (needed for frame capture) but uses a null
    /// video output so no window is opened.
    pub fn new_for_screenshot() -> Result<Self, ProbeError> {
        let funcs = get_mpv_functions()?;

        // SAFETY: mpv_create returns a new handle or NULL.
        let ctx = unsafe { (funcs.create)() };
        if ctx.is_null() {
            return Err(ProbeError::MpvInitFailed(
                "mpv_create returned null".to_string(),
            ));
        }

        let handle = Self { ctx, funcs };

        // Video decoding ON but no display output.
        handle.set_option("vo", "null")?;
        handle.set_option("ao", "null")?;
        handle.set_option("terminal", "no")?;
        handle.set_option("msg-level", "all=error")?;
        handle.set_option("pause", "yes")?;

        // SAFETY: ctx is valid (non-null, just created).
        let err = unsafe { (funcs.initialize)(ctx) };
        if err != MPV_ERROR_SUCCESS {
            let msg = handle.error_to_string(err);
            return Err(ProbeError::MpvInitFailed(msg));
        }

        Ok(handle)
    }

    /// Set an mpv option (before or after initialize).
    fn set_option(&self, name: &str, value: &str) -> Result<(), ProbeError> {
        let c_name = CString::new(name)
            .map_err(|_| ProbeError::MpvInitFailed("invalid option name".into()))?;
        let c_value = CString::new(value)
            .map_err(|_| ProbeError::MpvInitFailed("invalid option value".into()))?;

        // SAFETY: ctx is valid, strings are null-terminated.
        let err =
            unsafe { (self.funcs.set_option_string)(self.ctx, c_name.as_ptr(), c_value.as_ptr()) };

        if err != MPV_ERROR_SUCCESS {
            let msg = self.error_to_string(err);
            warn!(option = name, value, error = %msg, "mpv set_option failed");
            return Err(ProbeError::MpvCommandFailed {
                command: format!("set_option({name}, {value})"),
                detail: msg,
            });
        }
        Ok(())
    }

    /// Run an mpv command (e.g. `loadfile`, `screenshot-to-file`).
    pub fn command(&self, args: &[&str]) -> Result<(), ProbeError> {
        let c_args: Vec<CString> = args
            .iter()
            .map(|a| CString::new(*a).expect("mpv command arg contains null byte"))
            .collect();

        // Build null-terminated pointer array.
        let mut ptrs: Vec<*const c_char> = c_args.iter().map(|s| s.as_ptr()).collect();
        ptrs.push(std::ptr::null());

        // SAFETY: ctx is valid, ptrs is a properly terminated array.
        let err = unsafe { (self.funcs.command)(self.ctx, ptrs.as_mut_ptr()) };

        if err != MPV_ERROR_SUCCESS {
            let msg = self.error_to_string(err);
            let cmd_str = args.join(" ");
            return Err(ProbeError::MpvCommandFailed {
                command: cmd_str,
                detail: msg,
            });
        }
        Ok(())
    }

    /// Get a string property from mpv.
    ///
    /// Returns `None` if the property is not available.
    pub fn get_property_string(&self, name: &str) -> Option<String> {
        let c_name = CString::new(name).ok()?;

        // SAFETY: ctx is valid, c_name is null-terminated.
        let ptr = unsafe { (self.funcs.get_property_string)(self.ctx, c_name.as_ptr()) };
        if ptr.is_null() {
            return None;
        }

        // SAFETY: mpv returns a valid UTF-8 C string. We copy it and free.
        let value = unsafe { CStr::from_ptr(ptr) }
            .to_string_lossy()
            .into_owned();
        // SAFETY: ptr was allocated by mpv, must be freed with mpv_free.
        unsafe { (self.funcs.free)(ptr.cast()) };

        Some(value)
    }

    /// Get a double property from mpv.
    pub fn get_property_double(&self, name: &str) -> Option<f64> {
        let c_name = CString::new(name).ok()?;
        let mut value: f64 = 0.0;

        // SAFETY: ctx is valid, value is properly aligned, format matches type.
        let err = unsafe {
            (self.funcs.get_property)(
                self.ctx,
                c_name.as_ptr(),
                MpvFormat::Double as c_int,
                (&raw mut value).cast(),
            )
        };

        if err == MPV_ERROR_SUCCESS {
            Some(value)
        } else {
            None
        }
    }

    /// Get an i64 property from mpv.
    pub fn get_property_i64(&self, name: &str) -> Option<i64> {
        let c_name = CString::new(name).ok()?;
        let mut value: i64 = 0;

        // SAFETY: ctx is valid, value is properly aligned, format matches type.
        let err = unsafe {
            (self.funcs.get_property)(
                self.ctx,
                c_name.as_ptr(),
                MpvFormat::Int64 as c_int,
                (&raw mut value).cast(),
            )
        };

        if err == MPV_ERROR_SUCCESS {
            Some(value)
        } else {
            None
        }
    }

    /// Wait for an mpv event with timeout.
    ///
    /// Returns the event ID and error code.
    pub fn wait_event(&self, timeout: f64) -> (MpvEventId, c_int) {
        // SAFETY: ctx is valid, timeout is a simple f64.
        let ev = unsafe { (self.funcs.wait_event)(self.ctx, timeout) };
        if ev.is_null() {
            return (MpvEventId::None, 0);
        }

        // SAFETY: mpv always returns a valid event pointer from wait_event.
        let event_id = unsafe { (*ev).event_id };
        let error = unsafe { (*ev).error };

        // Map raw event ID to our enum. Unknown IDs become None.
        let id = match event_id {
            0 => MpvEventId::None,
            1 => MpvEventId::Shutdown,
            6 => MpvEventId::LogMessage,
            8 => MpvEventId::GetPropertyReply,
            9 => MpvEventId::SetPropertyReply,
            10 => MpvEventId::CommandReply,
            16 => MpvEventId::StartFile,
            17 => MpvEventId::EndFile,
            18 => MpvEventId::FileLoaded,
            19 => MpvEventId::Idle,
            22 => MpvEventId::PropertyChange,
            _ => MpvEventId::None,
        };

        (id, error)
    }

    /// Convert an mpv error code to a human-readable string.
    fn error_to_string(&self, code: c_int) -> String {
        // SAFETY: mpv_error_string always returns a valid static string.
        let ptr = unsafe { (self.funcs.error_string)(code) };
        if ptr.is_null() {
            return format!("unknown mpv error ({code})");
        }
        // SAFETY: ptr is a static string from libmpv.
        unsafe { CStr::from_ptr(ptr) }
            .to_string_lossy()
            .into_owned()
    }
}

impl Drop for MpvHandle {
    fn drop(&mut self) {
        if !self.ctx.is_null() {
            // SAFETY: ctx is valid and will not be used after this.
            unsafe { (self.funcs.destroy)(self.ctx) };
            self.ctx = std::ptr::null_mut();
        }
    }
}

/// Check whether libmpv is available on this system.
///
/// Returns `true` if the library can be loaded and the required symbols
/// are found.
pub fn is_mpv_available() -> bool {
    get_mpv_functions().is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_lib_names_not_empty() {
        assert!(!default_lib_names().is_empty());
    }

    #[test]
    fn get_libmpv_path_reads_env() {
        // Without the env var set, returns None.
        // We don't set it here to avoid interfering with other tests.
        // Just verify the function doesn't panic.
        let _path = get_libmpv_path();
    }

    #[test]
    fn is_mpv_available_does_not_panic() {
        // Result depends on whether libmpv is installed.
        let _available = is_mpv_available();
    }
}
