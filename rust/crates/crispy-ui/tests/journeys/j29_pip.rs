use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J29;

impl Journey for J29 {
    const ID: &'static str = "j29";
    const NAME: &'static str = "Picture-in-Picture Mode";
    const DEPENDS_ON: &'static [&'static str] = &["j26"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
