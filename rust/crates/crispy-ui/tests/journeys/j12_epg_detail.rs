use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J12;

impl Journey for J12 {
    const ID: &'static str = "j12";
    const NAME: &'static str = "EPG Program Detail Sheet";
    const DEPENDS_ON: &'static [&'static str] = &["j11"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
