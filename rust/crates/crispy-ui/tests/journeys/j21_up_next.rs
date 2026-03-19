use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J21;

impl Journey for J21 {
    const ID: &'static str = "j21";
    const NAME: &'static str = "Up Next Queue on Home Screen";
    const DEPENDS_ON: &'static [&'static str] = &["j19"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
