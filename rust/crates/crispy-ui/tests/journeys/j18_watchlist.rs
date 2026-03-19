use crate::harness::{db::TestDb, journey_runner::Journey, renderer::ScreenshotHarness};

pub struct J18;

impl Journey for J18 {
    const ID: &'static str = "j18";
    const NAME: &'static str = "Watchlist — Add / Remove / Browse";
    const DEPENDS_ON: &'static [&'static str] = &["j15"];

    fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
        // TODO: Implement in Phase 3
    }
}
