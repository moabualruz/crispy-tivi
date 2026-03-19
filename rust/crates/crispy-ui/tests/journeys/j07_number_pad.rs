use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J07;

impl Journey for J07 {
    const ID: &'static str = "j07";
    const NAME: &'static str = "Number-Pad Channel Entry";
    const DEPENDS_ON: &'static [&'static str] = &["j05"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
