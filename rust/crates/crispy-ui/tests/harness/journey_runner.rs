//! Journey runner — dependency-ordered execution of screenshot journeys.
//!
//! Journeys declare their dependencies via `Journey::DEPENDS_ON`. The runner
//! performs a topological sort (Kahn's algorithm) and executes journeys in
//! order. A panicking journey is caught via `catch_unwind`; all its transitive
//! dependents are marked `Blocked`.
//!
//! Filtering: set `CRISPY_JOURNEY_FILTER` to a prefix/glob pattern (e.g.
//! `"j05"` or `"j0*"`) to run only matching journey IDs.

use std::{
    any::Any,
    collections::{HashMap, HashSet, VecDeque},
    env,
    panic::{self, AssertUnwindSafe},
    path::{Path, PathBuf},
};

use super::{db::TestDb, input::InputEmulation, renderer::ScreenshotHarness, renderer::ScreenshotResult};
use slint::platform::Key;

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum JourneyStatus {
    Pass,
    Fail,
    Blocked,
    Skipped,
}

#[derive(Debug, Clone)]
pub struct JourneyRunResult {
    pub id: String,
    pub name: String,
    pub status: JourneyStatus,
    pub screenshots: Vec<ScreenshotResult>,
    pub blocked_by: Option<String>,
    pub error: Option<String>,
}

// ---------------------------------------------------------------------------
// Journey trait
// ---------------------------------------------------------------------------

/// A single user-journey screenshot test.
///
/// Implementors declare:
/// - `ID`        — short kebab-style id matching the spec (e.g. `"j01"`)
/// - `NAME`      — human-readable name from the journey spec
/// - `DEPENDS_ON`— journey IDs this journey requires to have passed first
///
/// `run()` receives the shared harness and DB.  It calls `harness` methods to
/// inject input and capture screenshots.  No `AppWindow` parameter — the
/// harness owns the software window.
pub trait Journey {
    const ID: &'static str;
    const NAME: &'static str;
    const DEPENDS_ON: &'static [&'static str];

    fn run(harness: &ScreenshotHarness, db: &TestDb);
}

// ---------------------------------------------------------------------------
// Internal registration entry
// ---------------------------------------------------------------------------

/// Type-erased journey entry stored inside `JourneyRunner`.
struct JourneyEntry {
    id: &'static str,
    name: &'static str,
    depends_on: &'static [&'static str],
    run_fn: fn(&ScreenshotHarness, &TestDb),
}

// ---------------------------------------------------------------------------
// Viewport boundary helper
// ---------------------------------------------------------------------------

/// Capture scroll-boundary screenshots for a scrollable view.
///
/// For each enabled axis the function navigates from the current position to
/// top/left, then scans to mid, then to bottom/right, then returns.  Each
/// position captures one screenshot.
///
/// Call this at the end of any journey step that lands on a scrollable screen.
pub fn viewport_boundary_test(
    harness: &ScreenshotHarness,
    view_name: &str,
    vertical_items: Option<u32>,
    horizontal_items: Option<u32>,
) {
    // --- Vertical axis ---
    if let Some(total) = vertical_items {
        if total == 0 {
            return;
        }

        // Capture top boundary (assume we're already at top after journey setup)
        harness.capture_state(
            &format!("{view_name}_vscroll_top"),
            "Viewport at vertical top boundary",
        );

        // Scroll to midpoint
        let mid = total / 2;
        if mid > 0 {
            harness.press_n(
                Key::DownArrow,
                mid,
                &format!("{view_name}_vscroll_mid"),
                "Viewport at vertical midpoint",
            );
        }

        // Scroll to bottom
        let remaining = total.saturating_sub(mid);
        if remaining > 0 {
            harness.press_n(
                Key::DownArrow,
                remaining,
                &format!("{view_name}_vscroll_bot"),
                "Viewport at vertical bottom boundary",
            );
        }

        // Return to top
        harness.press_n(
            Key::UpArrow,
            total,
            &format!("{view_name}_vscroll_top_ret"),
            "Viewport returned to vertical top",
        );
    }

    // --- Horizontal axis ---
    if let Some(total) = horizontal_items {
        if total == 0 {
            return;
        }

        harness.capture_state(
            &format!("{view_name}_hscroll_left"),
            "Viewport at horizontal left boundary",
        );

        let mid = total / 2;
        if mid > 0 {
            harness.press_n(
                Key::RightArrow,
                mid,
                &format!("{view_name}_hscroll_mid"),
                "Viewport at horizontal midpoint",
            );
        }

        let remaining = total.saturating_sub(mid);
        if remaining > 0 {
            harness.press_n(
                Key::RightArrow,
                remaining,
                &format!("{view_name}_hscroll_right"),
                "Viewport at horizontal right boundary",
            );
        }

        harness.press_n(
            Key::LeftArrow,
            total,
            &format!("{view_name}_hscroll_left_ret"),
            "Viewport returned to horizontal left",
        );
    }
}

// ---------------------------------------------------------------------------
// JourneyRunner
// ---------------------------------------------------------------------------

pub struct JourneyRunner {
    run_dir: PathBuf,
    golden_dir: PathBuf,
    db: TestDb,
    entries: Vec<JourneyEntry>,
    results: Vec<JourneyRunResult>,
    /// Factory that creates the UI component once per journey.
    /// Returns a type-erased `Box<dyn Any>` holding e.g. `AppWindow`.
    /// If `None`, journeys run without a UI handle (harness-only mode).
    ui_factory: Option<Box<dyn Fn() -> Box<dyn Any>>>,
}

impl JourneyRunner {
    /// Create a new runner.
    ///
    /// - `run_dir`    — timestamped directory under `tests/runs/`
    /// - `golden_dir` — `tests/golden/` containing approved reference PNGs
    /// - `db`         — shared in-memory DB seeded with fixture data
    pub fn new(run_dir: PathBuf, golden_dir: PathBuf, db: TestDb) -> Self {
        Self {
            run_dir,
            golden_dir,
            db,
            entries: Vec::new(),
            results: Vec::new(),
            ui_factory: None,
        }
    }

    /// Set a factory closure that creates the UI component for each journey.
    ///
    /// The factory is called once per journey run to produce a fresh
    /// type-erased handle stored in `harness.ui_handle`.
    ///
    /// ```ignore
    /// runner.set_ui_factory(|| Box::new(AppWindow::new().unwrap()));
    /// ```
    pub fn set_ui_factory<F>(&mut self, factory: F)
    where
        F: Fn() -> Box<dyn Any> + 'static,
    {
        self.ui_factory = Some(Box::new(factory));
    }

    /// Convenience constructor: resolves standard paths relative to
    /// `CARGO_MANIFEST_DIR` and creates a timestamped run directory.
    pub fn from_manifest_dir() -> Self {
        let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let tests_dir = manifest.join("tests");

        let golden_dir = tests_dir.join("golden");
        std::fs::create_dir_all(&golden_dir).expect("create golden dir");

        let timestamp = chrono::Utc::now().format("%Y-%m-%dT%H-%M-%S").to_string();
        let run_dir = tests_dir.join("runs").join(&timestamp);
        std::fs::create_dir_all(&run_dir).expect("create run dir");

        let db = TestDb::init();

        Self::new(run_dir, golden_dir, db)
    }

    /// Register a journey type.
    pub fn register<J: Journey>(&mut self) {
        self.entries.push(JourneyEntry {
            id: J::ID,
            name: J::NAME,
            depends_on: J::DEPENDS_ON,
            run_fn: J::run,
        });
    }

    /// Execute all registered journeys in topological order.
    pub fn run_all(&mut self) {
        let order = self.topological_order();
        self.execute_in_order(&order, None);
    }

    /// Execute journeys filtered by `filter` (prefix match on journey ID).
    ///
    /// Also honours the `CRISPY_JOURNEY_FILTER` environment variable; the env
    /// var takes precedence if both are provided.
    pub fn run_filtered(&mut self, filter: &str) {
        let active_filter = env::var("CRISPY_JOURNEY_FILTER")
            .unwrap_or_else(|_| filter.to_owned());
        let order = self.topological_order();
        self.execute_in_order(&order, Some(&active_filter));
    }

    /// Return all journey results collected so far.
    pub fn all_results(&self) -> &[JourneyRunResult] {
        &self.results
    }

    /// Return the run output directory path.
    pub fn run_dir(&self) -> &Path {
        &self.run_dir
    }

    /// Panic with a summary message if any journey failed.
    pub fn assert_no_failures(&self) {
        let failures: Vec<&JourneyRunResult> = self
            .results
            .iter()
            .filter(|r| r.status == JourneyStatus::Fail)
            .collect();

        if !failures.is_empty() {
            let summary: Vec<String> = failures
                .iter()
                .map(|r| {
                    format!(
                        "  {} ({}) — {}",
                        r.id,
                        r.name,
                        r.error.as_deref().unwrap_or("assertion failed")
                    )
                })
                .collect();
            panic!(
                "{} journey(s) failed:\n{}",
                failures.len(),
                summary.join("\n")
            );
        }
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// Kahn's algorithm topological sort.
    ///
    /// Returns journey IDs in execution order.  Panics if a cycle is detected.
    fn topological_order(&self) -> Vec<&'static str> {
        // Build adjacency: id → set of ids that depend ON it (successors)
        let ids: Vec<&'static str> = self.entries.iter().map(|e| e.id).collect();
        let id_set: HashSet<&str> = ids.iter().copied().collect();

        // In-degree: how many unresolved dependencies each journey has
        let mut in_degree: HashMap<&str, usize> = ids.iter().map(|&id| (id, 0)).collect();
        // Successor list: when journey X finishes, decrement successors
        let mut successors: HashMap<&str, Vec<&str>> = ids.iter().map(|&id| (id, vec![])).collect();

        for entry in &self.entries {
            for &dep in entry.depends_on {
                if id_set.contains(dep) {
                    *in_degree.entry(entry.id).or_insert(0) += 1;
                    successors.entry(dep).or_default().push(entry.id);
                }
                // Unknown deps (not registered) are silently ignored — the
                // dependency will appear as blocked at runtime.
            }
        }

        // Collect all roots (zero in-degree) — sort for determinism
        let mut queue: VecDeque<&str> = {
            let mut roots: Vec<&str> = in_degree
                .iter()
                .filter(|(_, deg)| **deg == 0)
                .map(|(&id, _)| id)
                .collect();
            roots.sort_unstable();
            roots.into()
        };

        let mut order: Vec<&str> = Vec::with_capacity(ids.len());

        while let Some(id) = queue.pop_front() {
            order.push(id);
            let mut next_ids: Vec<&str> = successors
                .get(id)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|succ| {
                    let deg = in_degree.get_mut(succ)?;
                    *deg = deg.saturating_sub(1);
                    if *deg == 0 { Some(succ) } else { None }
                })
                .collect();
            next_ids.sort_unstable();
            queue.extend(next_ids);
        }

        if order.len() != ids.len() {
            // Find nodes still with non-zero in-degree — those are in cycles
            let cycle_members: Vec<&str> = in_degree
                .iter()
                .filter(|(_, deg)| **deg > 0)
                .map(|(&id, _)| id)
                .collect();
            panic!(
                "Journey dependency cycle detected among: {:?}",
                cycle_members
            );
        }

        order
    }

    /// Execute journeys in the given order, catching panics.
    ///
    /// `filter` is an optional prefix filter on journey ID.
    fn execute_in_order(&mut self, order: &[&str], filter: Option<&str>) {
        // Build a lookup: id → entry index
        let entry_by_id: HashMap<&str, usize> = self
            .entries
            .iter()
            .enumerate()
            .map(|(i, e)| (e.id, i))
            .collect();

        // Track which journey IDs succeeded
        let mut passed: HashSet<String> = HashSet::new();
        // Track which journey IDs failed (used to block dependents)
        let mut failed: HashSet<String> = HashSet::new();

        for &id in order {
            let Some(&idx) = entry_by_id.get(id) else {
                continue;
            };
            let entry = &self.entries[idx];

            // Apply filter
            if let Some(f) = filter {
                if !glob_matches(f, id) {
                    self.results.push(JourneyRunResult {
                        id: id.to_owned(),
                        name: entry.name.to_owned(),
                        status: JourneyStatus::Skipped,
                        screenshots: vec![],
                        blocked_by: None,
                        error: Some(format!("filtered out by '{f}'")),
                    });
                    continue;
                }
            }

            // Check if any dependency failed
            let blocking_dep = entry
                .depends_on
                .iter()
                .find(|&&dep| failed.contains(dep));

            if let Some(&blocker) = blocking_dep {
                self.results.push(JourneyRunResult {
                    id: id.to_owned(),
                    name: entry.name.to_owned(),
                    status: JourneyStatus::Blocked,
                    screenshots: vec![],
                    blocked_by: Some(blocker.to_owned()),
                    error: None,
                });
                // A blocked journey propagates as failed for downstream
                failed.insert(id.to_owned());
                continue;
            }

            // Build harness for this journey
            let mut harness = if self.ui_factory.is_some() {
                // Use the platform's shared window so AppWindow renders into our pixel buffer
                let window = super::platform::get_shared_window();
                ScreenshotHarness::new(id, &self.run_dir, &self.golden_dir, window)
            } else {
                ScreenshotHarness::new_standalone(id, &self.run_dir, &self.golden_dir)
            };

            // Attach a fresh UI handle if a factory is configured
            if let Some(ref factory) = self.ui_factory {
                harness.ui_handle = Some(factory());
                // Pump timers so Slint initialises the component fully
                slint::platform::update_timers_and_animations();
            }

            // Run with panic catch
            // SAFETY: ScreenshotHarness is not truly UnwindSafe because of
            // RefCell/Cell interior mutability, but we don't access the
            // harness after a panic — we only read `harness.results()` on
            // success, so wrapping is safe here.
            let run_fn = entry.run_fn;
            let result = panic::catch_unwind(AssertUnwindSafe(|| {
                run_fn(&harness, &self.db);
            }));

            let screenshots = harness.results();

            match result {
                Ok(()) => {
                    passed.insert(id.to_owned());
                    self.results.push(JourneyRunResult {
                        id: id.to_owned(),
                        name: entry.name.to_owned(),
                        status: JourneyStatus::Pass,
                        screenshots,
                        blocked_by: None,
                        error: None,
                    });
                }
                Err(panic_payload) => {
                    failed.insert(id.to_owned());
                    let msg = extract_panic_message(&panic_payload);
                    self.results.push(JourneyRunResult {
                        id: id.to_owned(),
                        name: entry.name.to_owned(),
                        status: JourneyStatus::Fail,
                        screenshots,
                        blocked_by: None,
                        error: Some(msg),
                    });
                }
            }
        }

        let _ = passed; // suppress unused warning
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Simple glob matching: only `*` wildcard supported (matches any sequence).
/// `"j05"` matches `"j05"` exactly; `"j0*"` matches any id starting with `"j0"`.
fn glob_matches(pattern: &str, id: &str) -> bool {
    if pattern == "*" {
        return true;
    }
    if let Some(prefix) = pattern.strip_suffix('*') {
        id.starts_with(prefix)
    } else {
        pattern == id
    }
}

/// Extract a human-readable string from a `Box<dyn Any>` panic payload.
fn extract_panic_message(payload: &Box<dyn std::any::Any + Send>) -> String {
    if let Some(s) = payload.downcast_ref::<&str>() {
        s.to_string()
    } else if let Some(s) = payload.downcast_ref::<String>() {
        s.clone()
    } else {
        "panic with unknown payload".to_owned()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    // ── Minimal journey stubs ───────────────────────────────────────────────

    struct JourneyA;
    impl Journey for JourneyA {
        const ID: &'static str = "j_a";
        const NAME: &'static str = "Journey A";
        const DEPENDS_ON: &'static [&'static str] = &[];
        fn run(_harness: &ScreenshotHarness, _db: &TestDb) {}
    }

    struct JourneyB;
    impl Journey for JourneyB {
        const ID: &'static str = "j_b";
        const NAME: &'static str = "Journey B";
        const DEPENDS_ON: &'static [&'static str] = &["j_a"];
        fn run(_harness: &ScreenshotHarness, _db: &TestDb) {}
    }

    struct JourneyC;
    impl Journey for JourneyC {
        const ID: &'static str = "j_c";
        const NAME: &'static str = "Journey C";
        const DEPENDS_ON: &'static [&'static str] = &["j_b"];
        fn run(_harness: &ScreenshotHarness, _db: &TestDb) {}
    }

    struct JourneyPanic;
    impl Journey for JourneyPanic {
        const ID: &'static str = "j_panic";
        const NAME: &'static str = "Panicking Journey";
        const DEPENDS_ON: &'static [&'static str] = &[];
        fn run(_harness: &ScreenshotHarness, _db: &TestDb) {
            panic!("intentional test panic");
        }
    }

    struct JourneyAfterPanic;
    impl Journey for JourneyAfterPanic {
        const ID: &'static str = "j_after_panic";
        const NAME: &'static str = "After Panicking Journey";
        const DEPENDS_ON: &'static [&'static str] = &["j_panic"];
        fn run(_harness: &ScreenshotHarness, _db: &TestDb) {}
    }

    fn make_runner(tmp: &TempDir) -> JourneyRunner {
        // Use i-slint-backend-testing for runner unit tests — no AppWindow needed.
        // No ui_factory is set so the runner uses new_standalone() for each harness.
        i_slint_backend_testing::init_no_event_loop();
        let run_dir = tmp.path().join("run");
        let golden_dir = tmp.path().join("golden");
        std::fs::create_dir_all(&run_dir).unwrap();
        std::fs::create_dir_all(&golden_dir).unwrap();
        let db = TestDb::init();
        JourneyRunner::new(run_dir, golden_dir, db)
    }

    // ── Tests ───────────────────────────────────────────────────────────────

    #[test]
    fn test_topological_sort_respects_dependencies() {
        let tmp = TempDir::new().unwrap();
        let mut runner = make_runner(&tmp);
        // Register in reverse order to ensure sort, not insertion order, drives execution
        runner.register::<JourneyC>();
        runner.register::<JourneyB>();
        runner.register::<JourneyA>();

        let order = runner.topological_order();
        let pos_a = order.iter().position(|&id| id == "j_a").unwrap();
        let pos_b = order.iter().position(|&id| id == "j_b").unwrap();
        let pos_c = order.iter().position(|&id| id == "j_c").unwrap();

        assert!(
            pos_a < pos_b,
            "j_a must execute before j_b (pos_a={pos_a}, pos_b={pos_b})"
        );
        assert!(
            pos_b < pos_c,
            "j_b must execute before j_c (pos_b={pos_b}, pos_c={pos_c})"
        );
    }

    #[test]
    fn test_blocked_journeys_skip_when_dependency_fails() {
        let tmp = TempDir::new().unwrap();
        let mut runner = make_runner(&tmp);
        runner.register::<JourneyPanic>();
        runner.register::<JourneyAfterPanic>();

        runner.run_all();

        let results = runner.all_results();
        let panic_result = results.iter().find(|r| r.id == "j_panic").unwrap();
        let after_result = results.iter().find(|r| r.id == "j_after_panic").unwrap();

        assert_eq!(
            panic_result.status,
            JourneyStatus::Fail,
            "panicking journey must be marked Fail"
        );
        assert_eq!(
            after_result.status,
            JourneyStatus::Blocked,
            "dependent of failed journey must be Blocked"
        );
        assert_eq!(
            after_result.blocked_by.as_deref(),
            Some("j_panic"),
            "blocked_by must name the failing dependency"
        );
    }

    #[test]
    fn test_journey_filter_respects_glob() {
        let tmp = TempDir::new().unwrap();
        let mut runner = make_runner(&tmp);
        runner.register::<JourneyA>(); // "j_a"
        runner.register::<JourneyB>(); // "j_b"
        runner.register::<JourneyC>(); // "j_c"

        // Filter to only "j_a" (exact match)
        runner.run_filtered("j_a");

        let results = runner.all_results();
        let a = results.iter().find(|r| r.id == "j_a").unwrap();
        let b = results.iter().find(|r| r.id == "j_b").unwrap();
        let c = results.iter().find(|r| r.id == "j_c").unwrap();

        assert_ne!(
            a.status,
            JourneyStatus::Skipped,
            "j_a matches filter and must not be skipped"
        );
        assert_eq!(b.status, JourneyStatus::Skipped, "j_b must be skipped");
        assert_eq!(c.status, JourneyStatus::Skipped, "j_c must be skipped");
    }

    #[test]
    fn test_journey_filter_glob_wildcard() {
        let tmp = TempDir::new().unwrap();
        let mut runner = make_runner(&tmp);
        runner.register::<JourneyA>(); // "j_a"
        runner.register::<JourneyB>(); // "j_b"
        runner.register::<JourneyC>(); // "j_c"

        // Wildcard: all start with "j_" → all run
        runner.run_filtered("j_*");

        let results = runner.all_results();
        for r in results {
            assert_ne!(
                r.status,
                JourneyStatus::Skipped,
                "{} should not be skipped by 'j_*' filter",
                r.id
            );
        }
    }

    #[test]
    fn test_all_passing_journeys_assert_no_failures_passes() {
        let tmp = TempDir::new().unwrap();
        let mut runner = make_runner(&tmp);
        runner.register::<JourneyA>();
        runner.register::<JourneyB>();
        runner.register::<JourneyC>();
        runner.run_all();
        // Must not panic
        runner.assert_no_failures();
    }

    #[test]
    #[should_panic(expected = "journey(s) failed")]
    fn test_assert_no_failures_panics_on_fail() {
        let tmp = TempDir::new().unwrap();
        let mut runner = make_runner(&tmp);
        runner.register::<JourneyPanic>();
        runner.run_all();
        runner.assert_no_failures();
    }
}
