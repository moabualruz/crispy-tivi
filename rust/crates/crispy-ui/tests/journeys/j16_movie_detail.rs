use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J16;

impl Journey for J16 {
    const ID: &'static str = "j16";
    const NAME: &'static str = "Movie Detail Modal";
    const DEPENDS_ON: &'static [&'static str] = &["j15"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
