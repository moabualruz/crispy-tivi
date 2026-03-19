// Bring all Slint-generated types (AppWindow, AppState, OnboardingState, …)
// into scope for this test binary. This is required because `crispy-ui` is a
// binary crate; the generated types are not exported from a library.
slint::include_modules!();

mod harness;
mod journeys;

use harness::{journey_runner::JourneyRunner, platform, report};
use slint::ComponentHandle;

#[test]
fn screenshot_journeys() {
    // Install the software-renderer platform BEFORE any AppWindow is created.
    // Reads CRISPY_TEST_RESOLUTION (default 1280x720).
    let resolution =
        std::env::var("CRISPY_TEST_RESOLUTION").unwrap_or_else(|_| "1280x720".into());
    let (width, height) = parse_resolution(&resolution);
    platform::init_screenshot_platform(width, height);

    let mut runner = JourneyRunner::from_manifest_dir();

    // Register the UI factory: creates a fresh AppWindow per journey.
    // AppWindow::new() uses the platform we just installed, so it renders
    // into our MinimalSoftwareWindow pixel buffer.
    runner.set_ui_factory(|| {
        let ui = AppWindow::new().expect("AppWindow::new() failed in screenshot mode");
        // Show the window so Slint marks it as needing a render pass
        ui.show().expect("AppWindow::show() failed");
        Box::new(ui)
    });

    journeys::register_all_journeys(&mut runner);
    runner.run_all();

    // Generate manifest.json, runs-index.json, report.html
    let run_dir = runner.run_dir();
    let runs_dir = run_dir.parent().expect("run_dir has parent");
    let run_id = run_dir
        .file_name()
        .expect("run_dir has name")
        .to_string_lossy()
        .to_string();

    report::generate_reports(run_dir, runs_dir, &run_id, runner.all_results());

    // Fail the test if any journey failed
    runner.assert_no_failures();
}

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
