// Bring all Slint-generated types (AppWindow, AppState, OnboardingState, …)
// into scope for this test binary. This is required because `crispy-ui` is a
// binary crate; the generated types are not exported from a library.
slint::include_modules!();

mod harness;
mod journeys;

use harness::{journey_runner::JourneyRunner, logger::TestLogger, platform, report};
use slint::ComponentHandle;

// ── Pipeline selector ─────────────────────────────────────────────────────────

/// Determine which pipeline to run from the `CRISPY_PIPELINE` env var.
///
/// | Value    | Behaviour                                                       |
/// |----------|-----------------------------------------------------------------|
/// | `stub`   | Stub data only (default — always runs in CI)                    |
/// | `cached` | Pre-seeded DB from fixture files                                |
/// | `e2e`    | Fresh DB, real network sync (requires `.local` settings file)   |
/// | `all`    | `stub` always; `cached`+`e2e` when `.local` files are present   |
fn pipeline() -> String {
    std::env::var("CRISPY_PIPELINE").unwrap_or_else(|_| "stub".into())
}

#[test]
fn screenshot_journeys() {
    let pipe = pipeline();
    match pipe.as_str() {
        "stub" => run_pipeline("stub"),
        "cached" => run_pipeline("cached"),
        "e2e" => run_pipeline_e2e(),
        "all" => {
            run_pipeline("stub");
            let fixtures = fixtures_dir();
            if fixtures.join("test-settings.local.json").exists() {
                if fixtures.join("test-seed.local.json").exists() {
                    run_pipeline("cached");
                }
                run_pipeline_e2e();
            }
        }
        _ => panic!(
            "Unknown CRISPY_PIPELINE={pipe}. Valid values: stub | cached | e2e | all"
        ),
    }
}

// ── Shared pipeline helpers ───────────────────────────────────────────────────

fn run_pipeline(name: &str) {
    let (width, height) = resolution();
    platform::init_screenshot_platform(width, height);

    let manifest_dir = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let output_dir = manifest_dir.join("tests/output").join(name);
    let golden_dir = manifest_dir.join("tests/golden").join(name);
    std::fs::create_dir_all(&golden_dir).unwrap();

    let timestamp = chrono::Utc::now().format("%Y-%m-%dT%H-%M-%S").to_string();
    let run_dir = output_dir.join(&timestamp);
    std::fs::create_dir_all(&run_dir).unwrap();

    let logger = TestLogger::new(&run_dir);
    logger.event(
        "pipeline",
        "start",
        &[("name", name), ("ts", &timestamp)],
    );

    let db = harness::db::TestDb::init();
    let mut runner = JourneyRunner::new(run_dir.clone(), golden_dir, db);

    runner.set_ui_factory(|| {
        let ui = AppWindow::new().expect("AppWindow::new() failed in screenshot mode");
        ui.show().expect("AppWindow::show() failed");
        Box::new(ui)
    });

    journeys::register_all_journeys(&mut runner);
    runner.run_all();

    let runs_dir = &output_dir;
    report::generate_reports(&run_dir, runs_dir, &timestamp, runner.all_results());

    logger.event("pipeline", "done", &[("name", name)]);
    logger.flush();

    runner.assert_no_failures();
}

fn run_pipeline_e2e() {
    let fixtures = fixtures_dir();
    if !fixtures.join("test-settings.local.json").exists() {
        eprintln!("[E2E] SKIPPED — tests/fixtures/test-settings.local.json not found");
        return;
    }

    let (width, height) = resolution();
    platform::init_screenshot_platform(width, height);

    let manifest_dir = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let output_dir = manifest_dir.join("tests/output/e2e");
    let golden_dir = manifest_dir.join("tests/golden/e2e");
    std::fs::create_dir_all(&golden_dir).unwrap();

    let timestamp = chrono::Utc::now().format("%Y-%m-%dT%H-%M-%S").to_string();
    let run_dir = output_dir.join(&timestamp);
    std::fs::create_dir_all(&run_dir).unwrap();

    let logger = TestLogger::new(&run_dir);
    logger.event("pipeline", "start", &[("name", "e2e"), ("ts", &timestamp)]);

    // E2E: sources from .local settings, NO seed data — journeys drive real sync.
    let db = harness::db::TestDb::init_e2e();
    let mut runner = JourneyRunner::new(run_dir.clone(), golden_dir, db);

    runner.set_ui_factory(|| {
        let ui = AppWindow::new().expect("AppWindow::new() failed in screenshot mode");
        ui.show().expect("AppWindow::show() failed");
        Box::new(ui)
    });

    journeys::register_all_journeys(&mut runner);
    runner.run_all();

    let runs_dir = &output_dir;
    report::generate_reports(&run_dir, runs_dir, &timestamp, runner.all_results());

    logger.event("pipeline", "done", &[("name", "e2e")]);
    logger.flush();

    // E2E does not assert_no_failures — all results are emitted for AI review.
    eprintln!("[E2E] Complete. Results in: {}", run_dir.display());
}

// ── Utility ───────────────────────────────────────────────────────────────────

fn fixtures_dir() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}

fn resolution() -> (u32, u32) {
    let s = std::env::var("CRISPY_TEST_RESOLUTION").unwrap_or_else(|_| "1280x720".into());
    parse_resolution(&s)
}

fn parse_resolution(s: &str) -> (u32, u32) {
    let parts: Vec<&str> = s.splitn(2, 'x').collect();
    if parts.len() == 2 {
        (
            parts[0].parse::<u32>().unwrap_or(1280),
            parts[1].parse::<u32>().unwrap_or(720),
        )
    } else {
        (1280, 720)
    }
}
