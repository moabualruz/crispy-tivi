use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J17;

impl Journey for J17 {
    const ID: &'static str = "j17";
    const NAME: &'static str = "Movie Resume Playback";
    const DEPENDS_ON: &'static [&'static str] = &["j16"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
