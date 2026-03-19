use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J28;

impl Journey for J28 {
    const ID: &'static str = "j28";
    const NAME: &'static str = "Audio and Subtitle Track Picker";
    const DEPENDS_ON: &'static [&'static str] = &["j26"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
