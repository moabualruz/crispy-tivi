use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J44;

impl Journey for J44 {
    const ID: &'static str = "j44";
    const NAME: &'static str = "Network Failure Recovery";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
