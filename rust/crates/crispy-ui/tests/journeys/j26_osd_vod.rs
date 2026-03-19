use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J26;

impl Journey for J26 {
    const ID: &'static str = "j26";
    const NAME: &'static str = "Player OSD — VOD Controls";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
