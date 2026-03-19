use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J08;

impl Journey for J08 {
    const ID: &'static str = "j08";
    const NAME: &'static str = "Favorites — Add / Remove / Browse";
    const DEPENDS_ON: &'static [&'static str] = &["j05"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
