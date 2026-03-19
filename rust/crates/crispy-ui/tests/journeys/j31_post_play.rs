use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J31;

impl Journey for J31 {
    const ID: &'static str = "j31";
    const NAME: &'static str = "Post-Play — Next Episode / Related";
    const DEPENDS_ON: &'static [&'static str] = &["j26"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
