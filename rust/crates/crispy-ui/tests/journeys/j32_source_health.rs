use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J32;

impl Journey for J32 {
    const ID: &'static str = "j32";
    const NAME: &'static str = "Settings — Source Health Dashboard";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
