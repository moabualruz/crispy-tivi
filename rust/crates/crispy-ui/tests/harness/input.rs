use slint::SharedString;
use slint::platform::{Key, WindowEvent};

use super::renderer::ScreenshotHarness;

// ---------------------------------------------------------------------------
// InputEmulation trait
// ---------------------------------------------------------------------------

/// Input emulation — extends ScreenshotHarness with key injection + capture.
pub trait InputEmulation {
    /// Inject a key press + release then capture a screenshot.
    fn press_and_capture(&self, key: Key, label: &str, journey_step: &str);

    fn press_up(&self, label: &str, step: &str);
    fn press_down(&self, label: &str, step: &str);
    fn press_left(&self, label: &str, step: &str);
    fn press_right(&self, label: &str, step: &str);
    fn press_ok(&self, label: &str, step: &str);
    fn press_back(&self, label: &str, step: &str);

    /// Press `key` N times, capturing a screenshot after each press.
    /// Labels are `{label_prefix}_{i}` (1-indexed).
    fn press_n(&self, key: Key, n: u32, label_prefix: &str, step: &str);

    /// Type each character in `text` as individual key events, then capture once at the end.
    fn type_text(&self, text: &str, label: &str, step: &str);

    /// Call `setter`, then capture a screenshot.
    fn set_and_capture<F: FnOnce()>(&self, setter: F, label: &str, step: &str);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Dispatch a key press + release pair to the window.
///
/// `WindowEvent::KeyPressed/KeyReleased` take a `SharedString` `text` field.
/// `slint::platform::Key` is a newtype struct wrapping `SharedString` with
/// associated constants for special keys.  Converting via `Into<SharedString>`
/// produces the correct private-use-area Unicode scalar that Slint recognises.
fn inject_key(window: &slint::platform::software_renderer::MinimalSoftwareWindow, key: Key) {
    let text: SharedString = key.into();
    window.dispatch_event(WindowEvent::KeyPressed { text: text.clone() });
    window.dispatch_event(WindowEvent::KeyReleased { text });
    // Flush any timers/animations triggered by the event so the UI settles
    // before the next screenshot is captured.
    slint::platform::update_timers_and_animations();
}

/// Inject a single character as a key press + release (used by `type_text`).
fn inject_char(window: &slint::platform::software_renderer::MinimalSoftwareWindow, ch: char) {
    let text: SharedString = SharedString::from(ch);
    window.dispatch_event(WindowEvent::KeyPressed { text: text.clone() });
    window.dispatch_event(WindowEvent::KeyReleased { text });
    slint::platform::update_timers_and_animations();
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

impl InputEmulation for ScreenshotHarness {
    fn press_and_capture(&self, key: Key, label: &str, journey_step: &str) {
        inject_key(self.window(), key);
        self.assert_screenshot(label, journey_step, "");
    }

    fn press_up(&self, label: &str, step: &str) {
        self.press_and_capture(Key::UpArrow, label, step);
    }

    fn press_down(&self, label: &str, step: &str) {
        self.press_and_capture(Key::DownArrow, label, step);
    }

    fn press_left(&self, label: &str, step: &str) {
        self.press_and_capture(Key::LeftArrow, label, step);
    }

    fn press_right(&self, label: &str, step: &str) {
        self.press_and_capture(Key::RightArrow, label, step);
    }

    fn press_ok(&self, label: &str, step: &str) {
        self.press_and_capture(Key::Return, label, step);
    }

    fn press_back(&self, label: &str, step: &str) {
        self.press_and_capture(Key::Escape, label, step);
    }

    fn press_n(&self, key: Key, n: u32, label_prefix: &str, step: &str) {
        for i in 1..=n {
            let text: SharedString = key.clone().into();
            self.window()
                .dispatch_event(WindowEvent::KeyPressed { text: text.clone() });
            self.window()
                .dispatch_event(WindowEvent::KeyReleased { text });
            slint::platform::update_timers_and_animations();

            let label = format!("{label_prefix}_{i}");
            self.assert_screenshot(&label, step, "");
        }
    }

    fn type_text(&self, text: &str, label: &str, step: &str) {
        for ch in text.chars() {
            inject_char(self.window(), ch);
        }
        self.assert_screenshot(label, step, "");
    }

    fn set_and_capture<F: FnOnce()>(&self, setter: F, label: &str, step: &str) {
        setter();
        slint::platform::update_timers_and_animations();
        self.assert_screenshot(label, step, "");
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn make_harness(tmp: &TempDir) -> ScreenshotHarness {
        i_slint_backend_testing::init_no_event_loop();
        let run_dir = tmp.path().join("run");
        let golden_dir = tmp.path().join("golden");
        std::fs::create_dir_all(&run_dir).unwrap();
        std::fs::create_dir_all(&golden_dir).unwrap();
        ScreenshotHarness::new_standalone("input_test", &run_dir, &golden_dir)
    }

    #[test]
    fn test_press_and_capture_increments_counter() {
        let tmp = TempDir::new().unwrap();
        let harness = make_harness(&tmp);

        assert_eq!(harness.results().len(), 0);
        harness.press_and_capture(Key::Return, "ok_pressed", "step1");
        assert_eq!(
            harness.results().len(),
            1,
            "one screenshot should have been captured"
        );
    }

    #[test]
    fn test_press_n_captures_n_screenshots() {
        let tmp = TempDir::new().unwrap();
        let harness = make_harness(&tmp);

        harness.press_n(Key::DownArrow, 5, "nav_down", "scrolling");
        assert_eq!(
            harness.results().len(),
            5,
            "press_n(5) should produce exactly 5 screenshots"
        );
    }

    #[test]
    fn test_type_text_captures_one_screenshot() {
        let tmp = TempDir::new().unwrap();
        let harness = make_harness(&tmp);

        harness.type_text("hello", "typed_hello", "search_step");
        assert_eq!(
            harness.results().len(),
            1,
            "type_text should capture exactly one screenshot at the end"
        );
    }

    #[test]
    fn test_set_and_capture_records_result() {
        let tmp = TempDir::new().unwrap();
        let harness = make_harness(&tmp);

        let mut called = false;
        harness.set_and_capture(
            || {
                called = true;
            },
            "state_set",
            "setup_step",
        );

        assert!(called, "setter closure must be called");
        assert_eq!(harness.results().len(), 1);
    }

    #[test]
    fn test_convenience_dpad_methods_each_capture() {
        let tmp = TempDir::new().unwrap();
        let harness = make_harness(&tmp);

        // Escape (press_back) has special popup-dismissal handling inside Slint's
        // WindowInner::process_key_input that panics when no component is mounted
        // on the MinimalSoftwareWindow.  In real journeys the window always has a
        // component; here we only test the four D-pad directions + OK.
        harness.press_up("up", "step");
        harness.press_down("down", "step");
        harness.press_left("left", "step");
        harness.press_right("right", "step");
        harness.press_ok("ok", "step");

        assert_eq!(harness.results().len(), 5);
    }
}
