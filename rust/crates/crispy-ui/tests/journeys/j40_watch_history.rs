use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J40;

impl Journey for J40 {
    const ID: &'static str = "j40";
    const NAME: &'static str = "Watch History Browser";
    const DEPENDS_ON: &'static [&'static str] = &["j39"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
