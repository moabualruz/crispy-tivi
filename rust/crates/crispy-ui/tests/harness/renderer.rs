use image::{ImageBuffer, Rgba, RgbaImage};
use serde::Serialize;
use slint::Rgb8Pixel;
use slint::platform::software_renderer::{MinimalSoftwareWindow, RepaintBufferType};
use std::{
    cell::{Cell, RefCell},
    env,
    path::{Path, PathBuf},
    rc::Rc,
};

use super::logger::TestLogger;

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize)]
pub enum ScreenshotStatus {
    Pass,
    Fail,
    New,
    Skipped,
}

#[derive(Debug, Clone, Serialize)]
pub struct ScreenshotResult {
    pub id: String,
    pub label: String,
    pub journey_step: String,
    pub journey_expectation: String,
    pub status: ScreenshotStatus,
    pub diff_pct: f64,
    pub golden_path: Option<PathBuf>,
    pub test_path: PathBuf,
    pub diff_path: Option<PathBuf>,
}

pub struct CompareResult {
    pub diff_pct: f64,
    pub passed: bool,
    pub diff_image: RgbaImage,
    pub max_pixel_distance: f64,
    pub mean_pixel_distance: f64,
}

// ---------------------------------------------------------------------------
// ScreenshotHarness
// ---------------------------------------------------------------------------

pub struct ScreenshotHarness {
    journey_id: String,
    run_dir: PathBuf,
    golden_dir: PathBuf,
    width: u32,
    height: u32,
    diff_threshold: f64,
    pixel_tolerance: f64,
    counter: Cell<u32>,
    results: RefCell<Vec<ScreenshotResult>>,
    window: Rc<MinimalSoftwareWindow>,
    /// Type-erased UI component handle (e.g. `AppWindow`).
    /// Journeys downcast via `harness.ui::<AppWindow>()`.
    pub ui_handle: Option<Box<dyn std::any::Any>>,
    /// Pipeline mode: "stub" | "cached" | "e2e"
    pub pipeline_mode: String,
    /// Optional structured logger for screenshot events.
    logger: Option<Rc<TestLogger>>,
}

impl ScreenshotHarness {
    /// Create a harness backed by an externally-provided `MinimalSoftwareWindow`.
    ///
    /// Use this in the journey runner where `AppWindow::new()` has already
    /// claimed the platform window.
    pub fn new(
        journey_id: &str,
        run_dir: &Path,
        golden_dir: &Path,
        window: Rc<MinimalSoftwareWindow>,
    ) -> Self {
        let (width, height) = {
            let sz = window.size();
            (sz.width, sz.height)
        };
        Self::build(journey_id, run_dir, golden_dir, width, height, window)
    }

    /// Create a standalone harness that owns its own `MinimalSoftwareWindow`.
    ///
    /// Use this for harness unit tests that don't need `AppWindow`.
    /// Requires that no Slint platform has been installed yet (or that
    /// `i_slint_backend_testing` was already initialised for the test process).
    pub fn new_standalone(journey_id: &str, run_dir: &Path, golden_dir: &Path) -> Self {
        let resolution = env::var("CRISPY_TEST_RESOLUTION").unwrap_or_else(|_| "1280x720".into());
        let (width, height) = parse_resolution(&resolution);

        // NewBuffer: full frame is repainted on every draw_if_needed call,
        // which is what we need for screenshot capture (no partial updates).
        let window = MinimalSoftwareWindow::new(RepaintBufferType::NewBuffer);
        window.set_size(slint::PhysicalSize::new(width, height));

        Self::build(journey_id, run_dir, golden_dir, width, height, window)
    }

    fn build(
        journey_id: &str,
        run_dir: &Path,
        golden_dir: &Path,
        width: u32,
        height: u32,
        window: Rc<MinimalSoftwareWindow>,
    ) -> Self {
        let diff_threshold = env::var("CRISPY_DIFF_THRESHOLD")
            .ok()
            .and_then(|v| v.parse::<f64>().ok())
            .unwrap_or(0.05);

        let pixel_tolerance = env::var("CRISPY_PIXEL_TOLERANCE")
            .ok()
            .and_then(|v| v.parse::<f64>().ok())
            .unwrap_or(30.0);

        // --- output dirs ---
        let test_dir = run_dir.join("test").join(journey_id);
        std::fs::create_dir_all(&test_dir).expect("failed to create test output directory");

        Self {
            journey_id: journey_id.to_owned(),
            run_dir: run_dir.to_owned(),
            golden_dir: golden_dir.to_owned(),
            width,
            height,
            diff_threshold,
            pixel_tolerance,
            counter: Cell::new(0),
            results: RefCell::new(Vec::new()),
            window,
            ui_handle: None,
            pipeline_mode: "stub".to_owned(),
            logger: None,
        }
    }

    /// Attach a structured logger to capture screenshot events.
    pub fn set_logger(&mut self, logger: Rc<TestLogger>) {
        self.logger = Some(logger);
    }

    /// Access the type-erased UI handle as a concrete type.
    ///
    /// Returns `None` if no handle was set or the type doesn't match.
    /// Journeys call this as `harness.ui::<AppWindow>()`.
    pub fn ui<T: 'static>(&self) -> Option<&T> {
        self.ui_handle.as_ref()?.downcast_ref::<T>()
    }

    /// Returns the current pipeline mode: "stub", "cached", or "e2e".
    pub fn pipeline(&self) -> &str {
        &self.pipeline_mode
    }

    /// Returns true when the pipeline has real data (cached or e2e).
    /// In these modes `populate_ui()` has already seeded meaningful content —
    /// journeys must NOT overwrite it with inline stub data.
    pub fn has_real_data(&self) -> bool {
        matches!(self.pipeline_mode.as_str(), "cached" | "e2e")
    }

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    pub fn window(&self) -> &Rc<MinimalSoftwareWindow> {
        &self.window
    }

    pub fn results(&self) -> Vec<ScreenshotResult> {
        self.results.borrow().clone()
    }

    /// Capture the current window state as a PNG, save it, and return the image.
    pub fn capture(
        &self,
        label: &str,
        _journey_step: &str,
        _journey_expectation: &str,
    ) -> RgbaImage {
        let n = self.counter.get();
        self.counter.set(n + 1);

        let img = self.render_to_image();

        let filename = format!("{n:03}_{label}.png");
        let out_path = self
            .run_dir
            .join("test")
            .join(&self.journey_id)
            .join(&filename);

        if let Err(e) = img.save(&out_path) {
            eprintln!("[screenshot] failed to save {}: {e}", out_path.display());
        }

        img
    }

    /// Capture + compare against golden. Records a ScreenshotResult.
    pub fn assert_screenshot(&self, label: &str, journey_step: &str, journey_expectation: &str) {
        let n = self.counter.get();
        // capture() increments the counter internally
        let img = self.capture(label, journey_step, journey_expectation);
        // counter was n before capture; the saved file used n
        let counter_used = n;

        let filename = format!("{counter_used:03}_{label}.png");
        let test_path = self
            .run_dir
            .join("test")
            .join(&self.journey_id)
            .join(&filename);
        let golden_path = self.golden_dir.join(&self.journey_id).join(&filename);

        let update_snapshots = env::var("CRISPY_UPDATE_SNAPSHOTS")
            .map(|v| v == "1")
            .unwrap_or(false);

        let (status, diff_pct, diff_path) = if golden_path.exists() {
            // Load golden
            match image::open(&golden_path) {
                Err(e) => {
                    eprintln!(
                        "[screenshot] failed to load golden {}: {e}",
                        golden_path.display()
                    );
                    (ScreenshotStatus::Fail, 1.0, None)
                }
                Ok(golden_dyn) => {
                    let golden_rgba = golden_dyn.to_rgba8();
                    let cmp = Self::compare_images(&golden_rgba, &img, self.pixel_tolerance);

                    let diff_path = if !cmp.passed {
                        let dp = self
                            .run_dir
                            .join("diff")
                            .join(&self.journey_id)
                            .join(format!("{counter_used:03}_{label}_DIFF.png"));
                        std::fs::create_dir_all(dp.parent().unwrap()).ok();
                        if let Err(e) = cmp.diff_image.save(&dp) {
                            eprintln!("[screenshot] failed to save diff {}: {e}", dp.display());
                        }
                        Some(dp)
                    } else {
                        None
                    };

                    let status = if cmp.passed {
                        ScreenshotStatus::Pass
                    } else {
                        ScreenshotStatus::Fail
                    };

                    (status, cmp.diff_pct, diff_path)
                }
            }
        } else {
            (ScreenshotStatus::New, 0.0, None)
        };

        // Update snapshots if requested
        if update_snapshots {
            std::fs::create_dir_all(golden_path.parent().unwrap()).ok();
            if let Err(e) = img.save(&golden_path) {
                eprintln!(
                    "[screenshot] failed to update golden {}: {e}",
                    golden_path.display()
                );
            }
        }

        let id = format!("{}::{counter_used:03}::{label}", self.journey_id);

        // Log the screenshot event to structured logger when attached.
        if let Some(ref log) = self.logger {
            let status_str = match &status {
                ScreenshotStatus::Pass => "pass",
                ScreenshotStatus::Fail => "fail",
                ScreenshotStatus::New => "new",
                ScreenshotStatus::Skipped => "skipped",
            };
            let diff_str = format!("{diff_pct:.4}");
            log.event(
                "render",
                "screenshot",
                &[
                    ("journey", self.journey_id.as_str()),
                    ("label", label),
                    ("step", journey_step),
                    ("status", status_str),
                    ("diff_pct", diff_str.as_str()),
                ],
            );
        }

        self.results.borrow_mut().push(ScreenshotResult {
            id,
            label: label.to_owned(),
            journey_step: journey_step.to_owned(),
            journey_expectation: journey_expectation.to_owned(),
            status,
            diff_pct,
            golden_path: Some(golden_path),
            test_path,
            diff_path,
        });
    }

    /// Capture current state without a golden assertion (just records for reporting).
    pub fn capture_state(&self, label: &str, journey_step: &str) {
        self.assert_screenshot(label, journey_step, "");
    }

    /// Fuzzy per-pixel image comparison.
    pub fn compare_images(
        golden: &RgbaImage,
        test: &RgbaImage,
        pixel_tolerance: f64,
    ) -> CompareResult {
        let (w, h) = golden.dimensions();
        let total = (w * h) as f64;

        let mut diff_img: RgbaImage = ImageBuffer::new(w, h);
        let mut differing: u64 = 0;
        let mut sum_dist = 0.0_f64;
        let mut max_dist = 0.0_f64;

        // If dimensions mismatch, treat as 100% different
        if test.dimensions() != (w, h) {
            let full_diff: RgbaImage = ImageBuffer::from_pixel(w, h, Rgba([255, 0, 0, 128]));
            return CompareResult {
                diff_pct: 1.0,
                passed: false,
                diff_image: full_diff,
                max_pixel_distance: 441.67, // sqrt(4 * 255^2)
                mean_pixel_distance: 441.67,
            };
        }

        for (x, y, gp) in golden.enumerate_pixels() {
            let tp = test.get_pixel(x, y);
            let dr = (gp[0] as f64 - tp[0] as f64).powi(2);
            let dg = (gp[1] as f64 - tp[1] as f64).powi(2);
            let db = (gp[2] as f64 - tp[2] as f64).powi(2);
            let da = (gp[3] as f64 - tp[3] as f64).powi(2);
            let dist = (dr + dg + db + da).sqrt();

            sum_dist += dist;
            if dist > max_dist {
                max_dist = dist;
            }

            if dist > pixel_tolerance {
                differing += 1;
                diff_img.put_pixel(x, y, Rgba([255, 0, 0, 128]));
            } else {
                diff_img.put_pixel(x, y, Rgba([0, 0, 0, 0]));
            }
        }

        let diff_pct = differing as f64 / total;
        let mean_dist = if total > 0.0 { sum_dist / total } else { 0.0 };

        // Default threshold for passed check is per CompareResult caller
        // Here we use pixel_tolerance-derived threshold stored externally.
        // compare_images is a pure function — caller checks diff_pct against threshold.
        // We embed a default 5% threshold check here for convenience.
        let passed = diff_pct <= 0.05;

        CompareResult {
            diff_pct,
            passed,
            diff_image: diff_img,
            max_pixel_distance: max_dist,
            mean_pixel_distance: mean_dist,
        }
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    fn render_to_image(&self) -> RgbaImage {
        let size = (self.width * self.height) as usize;
        let mut pixel_buf: Vec<Rgb8Pixel> = vec![Rgb8Pixel { r: 0, g: 0, b: 0 }; size];

        // Request a redraw so draw_if_needed fires even without a pending update
        self.window.request_redraw();

        self.window.draw_if_needed(|renderer| {
            renderer.render(&mut pixel_buf, self.width as usize);
        });

        // Convert Rgb8Pixel → RgbaImage (alpha always 255)
        let mut rgba_img: RgbaImage = ImageBuffer::new(self.width, self.height);
        for (i, px) in pixel_buf.iter().enumerate() {
            let x = (i as u32) % self.width;
            let y = (i as u32) / self.width;
            rgba_img.put_pixel(x, y, Rgba([px.r, px.g, px.b, 255]));
        }
        rgba_img
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn parse_resolution(s: &str) -> (u32, u32) {
    let parts: Vec<&str> = s.splitn(2, 'x').collect();
    if parts.len() == 2 {
        let w = parts[0].parse::<u32>().unwrap_or(1280);
        let h = parts[1].parse::<u32>().unwrap_or(720);
        (w, h)
    } else {
        (1280, 720)
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
        // Use i-slint-backend-testing so no real display is needed.
        // new_standalone() creates its own MinimalSoftwareWindow without
        // requiring the screenshot platform to be installed.
        i_slint_backend_testing::init_no_event_loop();
        let run_dir = tmp.path().join("run");
        let golden_dir = tmp.path().join("golden");
        std::fs::create_dir_all(&run_dir).unwrap();
        std::fs::create_dir_all(&golden_dir).unwrap();
        ScreenshotHarness::new_standalone("test_journey", &run_dir, &golden_dir)
    }

    #[test]
    fn test_capture_produces_non_empty_image() {
        let tmp = TempDir::new().unwrap();
        let harness = make_harness(&tmp);
        let img = harness.capture("blank", "initial", "window is blank");
        // Default resolution 1280x720
        assert_eq!(img.width(), 1280);
        assert_eq!(img.height(), 720);
        assert!(!img.as_raw().is_empty());
    }

    #[test]
    fn test_compare_identical_images_passes() {
        let img: RgbaImage = ImageBuffer::from_pixel(16, 16, Rgba([100, 150, 200, 255]));
        let result = ScreenshotHarness::compare_images(&img, &img, 30.0);
        assert!(result.passed, "identical images should pass");
        assert_eq!(result.diff_pct, 0.0);
        assert_eq!(result.max_pixel_distance, 0.0);
    }

    #[test]
    fn test_compare_different_images_fails() {
        let golden: RgbaImage = ImageBuffer::from_pixel(16, 16, Rgba([0, 0, 0, 255]));
        let test_img: RgbaImage = ImageBuffer::from_pixel(16, 16, Rgba([255, 255, 255, 255]));
        let result = ScreenshotHarness::compare_images(&golden, &test_img, 30.0);
        assert!(!result.passed, "completely different images should fail");
        assert!(
            result.diff_pct > 0.9,
            "diff_pct should be near 1.0, got {}",
            result.diff_pct
        );
    }

    #[test]
    fn test_compare_slightly_different_passes_within_threshold() {
        // Create a mostly-white image
        let mut golden: RgbaImage = ImageBuffer::from_pixel(100, 100, Rgba([255, 255, 255, 255]));
        let mut test_img: RgbaImage = ImageBuffer::from_pixel(100, 100, Rgba([255, 255, 255, 255]));
        // Change 3 pixels out of 10000 — tiny diff_pct
        test_img.put_pixel(0, 0, Rgba([200, 200, 200, 255]));
        test_img.put_pixel(1, 0, Rgba([200, 200, 200, 255]));
        golden.put_pixel(0, 0, Rgba([255, 255, 255, 255]));
        golden.put_pixel(1, 0, Rgba([255, 255, 255, 255]));

        let result = ScreenshotHarness::compare_images(&golden, &test_img, 30.0);
        // 2 pixels differ out of 10000 = 0.02% — well within 5% threshold
        assert!(
            result.passed,
            "tiny diff should pass, diff_pct={}",
            result.diff_pct
        );
    }

    #[test]
    fn test_assert_screenshot_new_when_no_golden() {
        let tmp = TempDir::new().unwrap();
        let harness = make_harness(&tmp);
        harness.assert_screenshot("splash", "load", "shows splash screen");
        let results = harness.results();
        assert_eq!(results.len(), 1);
        assert!(
            matches!(results[0].status, ScreenshotStatus::New),
            "expected New when golden doesn't exist"
        );
        assert_eq!(results[0].label, "splash");
        assert_eq!(results[0].journey_step, "load");
    }
}
