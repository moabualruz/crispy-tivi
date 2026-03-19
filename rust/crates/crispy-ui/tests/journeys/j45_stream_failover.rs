use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J45;

impl Journey for J45 {
    const ID: &'static str = "j45";
    const NAME: &'static str = "Stream Source Failover";
    const DEPENDS_ON: &'static [&'static str] = &["j44"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
