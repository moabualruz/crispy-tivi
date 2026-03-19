use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J38;

impl Journey for J38 {
    const ID: &'static str = "j38";
    const NAME: &'static str = "Parental Controls — PIN and Rating Locks";
    const DEPENDS_ON: &'static [&'static str] = &["j36"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
