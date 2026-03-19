use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J02;

impl Journey for J02 {
    const ID: &'static str = "j02";
    const NAME: &'static str = "Add Additional Source (Post-Onboarding)";
    const DEPENDS_ON: &'static [&'static str] = &["j01"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
