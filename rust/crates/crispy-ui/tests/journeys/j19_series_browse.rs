use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J19;

impl Journey for J19 {
    const ID: &'static str = "j19";
    const NAME: &'static str = "Series — Browse and Season Navigation";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
