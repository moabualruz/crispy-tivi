use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J20;

impl Journey for J20 {
    const ID: &'static str = "j20";
    const NAME: &'static str = "Binge Watch — Episode Auto-Advance";
    const DEPENDS_ON: &'static [&'static str] = &["j19"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
