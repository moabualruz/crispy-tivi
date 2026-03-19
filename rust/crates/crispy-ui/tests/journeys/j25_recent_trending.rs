use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J25;

impl Journey for J25 {
    const ID: &'static str = "j25";
    const NAME: &'static str = "Recent Searches and Trending";
    const DEPENDS_ON: &'static [&'static str] = &["j23"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
