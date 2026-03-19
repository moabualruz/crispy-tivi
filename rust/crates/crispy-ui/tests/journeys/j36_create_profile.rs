use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J36;

impl Journey for J36 {
    const ID: &'static str = "j36";
    const NAME: &'static str = "Create and Edit Profile";
    const DEPENDS_ON: &'static [&'static str] = &["j03"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
