use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J30;

impl Journey for J30 {
    const ID: &'static str = "j30";
    const NAME: &'static str = "Skip Intro / Skip Recap";
    const DEPENDS_ON: &'static [&'static str] = &["j26"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
