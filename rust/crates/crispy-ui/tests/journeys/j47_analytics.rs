use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J47;

impl Journey for J47 {
    const ID: &'static str = "j47";
    const NAME: &'static str = "Analytics Opt-In / Opt-Out";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
