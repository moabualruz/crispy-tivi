mod harness;
mod journeys;

use harness::journey_runner::JourneyRunner;
use harness::report;

#[test]
fn screenshot_journeys() {
    i_slint_backend_testing::init_no_event_loop();

    let mut runner = JourneyRunner::from_manifest_dir();
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

    report::generate_reports(
        run_dir,
        runs_dir,
        &run_id,
        runner.all_results(),
    );

    // Fail the test if any journey failed
    runner.assert_no_failures();
}
