use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J14;

impl Journey for J14 {
    const ID: &'static str = "j14";
    const NAME: &'static str = "EPG Search";
    const DEPENDS_ON: &'static [&'static str] = &["j11"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
