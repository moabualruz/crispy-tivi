use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J01;

impl Journey for J01 {
    const ID: &'static str = "j01";
    const NAME: &'static str = "Cold First Launch — Cinematic Welcome to First Content";
    const DEPENDS_ON: &'static [&'static str] = &[];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
