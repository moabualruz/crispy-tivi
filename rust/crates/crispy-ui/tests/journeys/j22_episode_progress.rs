use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J22;

impl Journey for J22 {
    const ID: &'static str = "j22";
    const NAME: &'static str = "Episode Progress Tracking";
    const DEPENDS_ON: &'static [&'static str] = &["j19"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
