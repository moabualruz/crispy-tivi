use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J06;

impl Journey for J06 {
    const ID: &'static str = "j06";
    const NAME: &'static str = "Instant Channel Zapping";
    const DEPENDS_ON: &'static [&'static str] = &["j05"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
