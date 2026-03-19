use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J13;

impl Journey for J13 {
    const ID: &'static str = "j13";
    const NAME: &'static str = "Multi-Day EPG Navigation";
    const DEPENDS_ON: &'static [&'static str] = &["j11"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
