use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J10;

impl Journey for J10 {
    const ID: &'static str = "j10";
    const NAME: &'static str = "Mini-Guide / Now-Next Overlay";
    const DEPENDS_ON: &'static [&'static str] = &["j05"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
