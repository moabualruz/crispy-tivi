use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J24;

impl Journey for J24 {
    const ID: &'static str = "j24";
    const NAME: &'static str = "Browse Filters and Sorting";
    const DEPENDS_ON: &'static [&'static str] = &["j23"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
