use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J04;

impl Journey for J04 {
    const ID: &'static str = "j04";
    const NAME: &'static str = "First-Time Content Discovery (Guided Tour)";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
