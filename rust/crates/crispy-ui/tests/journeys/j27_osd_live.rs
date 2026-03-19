use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J27;

impl Journey for J27 {
    const ID: &'static str = "j27";
    const NAME: &'static str = "Player OSD — Live TV Controls";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
