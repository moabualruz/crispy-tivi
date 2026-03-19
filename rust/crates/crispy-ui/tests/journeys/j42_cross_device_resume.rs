use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J42;

impl Journey for J42 {
    const ID: &'static str = "j42";
    const NAME: &'static str = "Cross-Device Resume via Server Mode";
    const DEPENDS_ON: &'static [&'static str] = &["j41"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
