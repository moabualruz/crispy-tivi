use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J35;

impl Journey for J35 {
    const ID: &'static str = "j35";
    const NAME: &'static str = "Diagnostics and Debug Info";
    const DEPENDS_ON: &'static [&'static str] = &["j32"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
