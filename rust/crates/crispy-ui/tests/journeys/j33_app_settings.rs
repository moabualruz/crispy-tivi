use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J33;

impl Journey for J33 {
    const ID: &'static str = "j33";
    const NAME: &'static str = "App Settings — Language / Theme / Quality";
    const DEPENDS_ON: &'static [&'static str] = &["j32"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
