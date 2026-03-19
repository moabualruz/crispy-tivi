use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J11;

impl Journey for J11 {
    const ID: &'static str = "j11";
    const NAME: &'static str = "EPG Grid — Full-Screen TV Guide";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
