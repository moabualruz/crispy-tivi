use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J03;

impl Journey for J03 {
    const ID: &'static str = "j03";
    const NAME: &'static str = "Returning User — Profile Picker to Resume";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
