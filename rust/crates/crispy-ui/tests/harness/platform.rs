//! Custom Slint platform for screenshot testing.
//!
//! Installs a `MinimalSoftwareWindow`-backed platform so that `AppWindow::new()`
//! renders through our pixel buffer instead of a real display.
//!
//! `init_screenshot_platform` uses a `Once` guard — safe to call multiple times.
//! The shared window is stored in a thread-local and retrieved via
//! `get_shared_window()`.

use slint::platform::{
    Platform, WindowAdapter,
    software_renderer::{MinimalSoftwareWindow, RepaintBufferType},
};
use std::{cell::RefCell, rc::Rc, sync::Once, time::Duration};

static PLATFORM_INIT: Once = Once::new();

thread_local! {
    static SHARED_WINDOW: RefCell<Option<Rc<MinimalSoftwareWindow>>> = RefCell::new(None);
}

/// Install the screenshot platform.
///
/// Must be called before the first `AppWindow::new()`. Safe to call multiple
/// times — subsequent calls are no-ops (the `Once` guard prevents
/// re-initialisation).
///
/// Width/height are only applied on the first call; later calls with
/// different sizes are silently ignored.
pub fn init_screenshot_platform(width: u32, height: u32) {
    PLATFORM_INIT.call_once(|| {
        let window = MinimalSoftwareWindow::new(RepaintBufferType::NewBuffer);
        window.set_size(slint::PhysicalSize::new(width, height));

        SHARED_WINDOW.with(|cell| {
            *cell.borrow_mut() = Some(window.clone());
        });

        struct ScreenshotPlatform(Rc<MinimalSoftwareWindow>);

        impl Platform for ScreenshotPlatform {
            fn create_window_adapter(&self) -> Result<Rc<dyn WindowAdapter>, slint::PlatformError> {
                Ok(self.0.clone())
            }

            fn duration_since_start(&self) -> Duration {
                Duration::from_millis(0)
            }
        }

        slint::platform::set_platform(Box::new(ScreenshotPlatform(window)))
            .expect("failed to set screenshot platform");
    });
}

/// Return the shared `MinimalSoftwareWindow`.
///
/// Panics if `init_screenshot_platform` has not been called yet.
pub fn get_shared_window() -> Rc<MinimalSoftwareWindow> {
    SHARED_WINDOW.with(|cell| {
        cell.borrow()
            .as_ref()
            .expect("screenshot platform not initialised — call init_screenshot_platform() first")
            .clone()
    })
}
