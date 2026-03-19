use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J37;

impl Journey for J37 {
    const ID: &'static str = "j37";
    const NAME: &'static str = "Kids Profile Setup";
    const DEPENDS_ON: &'static [&'static str] = &["j36"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
