use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J34;

impl Journey for J34 {
    const ID: &'static str = "j34";
    const NAME: &'static str = "Backup and Restore Settings";
    const DEPENDS_ON: &'static [&'static str] = &["j32"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
