use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::{path::Path, process::Command};

use super::journey_runner::{JourneyRunResult, JourneyStatus};
use super::renderer::{ScreenshotResult, ScreenshotStatus};

// ---------------------------------------------------------------------------
// Manifest types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub run_id: String,
    pub timestamp: String,
    pub resolution: String,
    pub diff_threshold: f64,
    pub pixel_tolerance: f64,
    pub git_commit: String,
    pub git_branch: String,
    pub summary: ManifestSummary,
    pub journeys: Vec<ManifestJourney>,
    pub design_refs: DesignRefs,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManifestSummary {
    pub total_screenshots: usize,
    pub passed: usize,
    pub failed: usize,
    pub new: usize,
    pub skipped: usize,
    pub total_journeys: usize,
    pub journeys_passed: usize,
    pub journeys_failed: usize,
    pub journeys_blocked: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManifestJourney {
    pub id: String,
    pub name: String,
    pub status: String,
    pub blocked_by: Option<String>,
    pub screenshots: Vec<ManifestScreenshot>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManifestScreenshot {
    pub id: String,
    pub label: String,
    pub journey_step: String,
    pub journey_expectation: String,
    pub status: String,
    pub diff_pct: f64,
    pub paths: ScreenshotPaths,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScreenshotPaths {
    pub golden: Option<String>,
    pub test: String,
    pub diff: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DesignRefs {
    pub design_spec: String,
    pub journey_spec: String,
    pub theme_tokens: String,
    pub impeccable: String,
}

// ---------------------------------------------------------------------------
// runs-index types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunsIndex {
    pub latest: String,
    pub latest_path: String,
    pub runs: Vec<RunEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunEntry {
    pub id: String,
    pub path: String,
    pub timestamp: String,
    pub git_commit: String,
    pub summary: IndexSummary,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IndexSummary {
    pub total: usize,
    pub passed: usize,
    pub failed: usize,
    pub new: usize,
}

// ---------------------------------------------------------------------------
// Git helpers
// ---------------------------------------------------------------------------

fn git_short_commit() -> String {
    Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                String::from_utf8(o.stdout)
                    .ok()
                    .map(|s| s.trim().to_owned())
            } else {
                None
            }
        })
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "unknown".into())
}

fn git_branch() -> String {
    Command::new("git")
        .args(["branch", "--show-current"])
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                String::from_utf8(o.stdout)
                    .ok()
                    .map(|s| s.trim().to_owned())
            } else {
                None
            }
        })
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "unknown".into())
}

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

fn path_to_string(p: &Path) -> String {
    p.to_string_lossy().replace('\\', "/")
}

fn relative_path(base: &Path, target: &Path) -> String {
    // Best-effort relative path using stdlib; fall back to absolute string.
    // Strip the common prefix, then prepend one "../" per remaining base component.
    let base_abs = base.canonicalize().unwrap_or_else(|_| base.to_path_buf());
    let target_abs = target
        .canonicalize()
        .unwrap_or_else(|_| target.to_path_buf());

    let base_comps: Vec<_> = base_abs.components().collect();
    let target_comps: Vec<_> = target_abs.components().collect();

    let common = base_comps
        .iter()
        .zip(target_comps.iter())
        .take_while(|(a, b)| a == b)
        .count();

    let up = base_comps.len() - common;
    let mut parts: Vec<String> = std::iter::repeat("..".to_owned()).take(up).collect();
    for c in &target_comps[common..] {
        parts.push(c.as_os_str().to_string_lossy().into_owned());
    }

    if parts.is_empty() {
        ".".into()
    } else {
        parts.join("/")
    }
}

fn screenshot_status_str(s: &ScreenshotStatus) -> &'static str {
    match s {
        ScreenshotStatus::Pass => "pass",
        ScreenshotStatus::Fail => "fail",
        ScreenshotStatus::New => "new",
        ScreenshotStatus::Skipped => "skipped",
    }
}

fn journey_status_str(s: &JourneyStatus) -> &'static str {
    match s {
        JourneyStatus::Pass => "pass",
        JourneyStatus::Fail => "fail",
        JourneyStatus::Blocked => "blocked",
        JourneyStatus::Skipped => "skipped",
    }
}

// ---------------------------------------------------------------------------
// Manifest generation
// ---------------------------------------------------------------------------

pub fn generate_manifest(
    run_dir: &Path,
    run_id: &str,
    journey_results: &[JourneyRunResult],
) -> Manifest {
    let git_commit = git_short_commit();
    let git_branch = git_branch();

    let resolution = std::env::var("CRISPY_TEST_RESOLUTION").unwrap_or_else(|_| "1280x720".into());
    let diff_threshold = std::env::var("CRISPY_DIFF_THRESHOLD")
        .ok()
        .and_then(|v| v.parse::<f64>().ok())
        .unwrap_or(0.05);
    let pixel_tolerance = std::env::var("CRISPY_PIXEL_TOLERANCE")
        .ok()
        .and_then(|v| v.parse::<f64>().ok())
        .unwrap_or(30.0);

    // Aggregate counts
    let mut total_screenshots = 0usize;
    let mut passed = 0usize;
    let mut failed = 0usize;
    let mut new = 0usize;
    let mut skipped = 0usize;

    let mut journeys_passed = 0usize;
    let mut journeys_failed = 0usize;
    let mut journeys_blocked = 0usize;

    let journeys: Vec<ManifestJourney> = journey_results
        .iter()
        .map(|jr| {
            match jr.status {
                JourneyStatus::Pass => journeys_passed += 1,
                JourneyStatus::Fail => journeys_failed += 1,
                JourneyStatus::Blocked => journeys_blocked += 1,
                JourneyStatus::Skipped => {}
            }

            let screenshots: Vec<ManifestScreenshot> = jr
                .screenshots
                .iter()
                .map(|sr| {
                    total_screenshots += 1;
                    match sr.status {
                        ScreenshotStatus::Pass => passed += 1,
                        ScreenshotStatus::Fail => failed += 1,
                        ScreenshotStatus::New => new += 1,
                        ScreenshotStatus::Skipped => skipped += 1,
                    }

                    ManifestScreenshot {
                        id: sr.id.clone(),
                        label: sr.label.clone(),
                        journey_step: sr.journey_step.clone(),
                        journey_expectation: sr.journey_expectation.clone(),
                        status: screenshot_status_str(&sr.status).to_owned(),
                        diff_pct: sr.diff_pct,
                        paths: ScreenshotPaths {
                            golden: sr.golden_path.as_deref().map(|p| relative_path(run_dir, p)),
                            test: relative_path(run_dir, &sr.test_path),
                            diff: sr.diff_path.as_deref().map(|p| relative_path(run_dir, p)),
                        },
                    }
                })
                .collect();

            ManifestJourney {
                id: jr.id.clone(),
                name: jr.name.clone(),
                status: journey_status_str(&jr.status).to_owned(),
                blocked_by: jr.blocked_by.clone(),
                screenshots,
            }
        })
        .collect();

    Manifest {
        run_id: run_id.to_owned(),
        timestamp: Utc::now().to_rfc3339(),
        resolution,
        diff_threshold,
        pixel_tolerance,
        git_commit,
        git_branch,
        summary: ManifestSummary {
            total_screenshots,
            passed,
            failed,
            new,
            skipped,
            total_journeys: journey_results.len(),
            journeys_passed,
            journeys_failed,
            journeys_blocked,
        },
        journeys,
        design_refs: DesignRefs {
            design_spec: ".ai/crispy_tivi_design_spec.md".into(),
            journey_spec: ".ai/planning/USER-JOURNEYS.md".into(),
            theme_tokens: "rust/crates/crispy-ui/ui/globals/theme.slint".into(),
            impeccable: ".impeccable.md".into(),
        },
    }
}

// ---------------------------------------------------------------------------
// runs-index update
// ---------------------------------------------------------------------------

pub fn update_runs_index(runs_dir: &Path, run_id: &str, manifest: &Manifest) {
    let index_path = runs_dir.join("runs-index.json");

    let mut index: RunsIndex = if index_path.exists() {
        std::fs::read_to_string(&index_path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_else(|| RunsIndex {
                latest: String::new(),
                latest_path: String::new(),
                runs: Vec::new(),
            })
    } else {
        RunsIndex {
            latest: String::new(),
            latest_path: String::new(),
            runs: Vec::new(),
        }
    };

    let run_path = runs_dir.join(run_id);
    let run_path_str = path_to_string(&run_path);

    let entry = RunEntry {
        id: run_id.to_owned(),
        path: run_path_str.clone(),
        timestamp: manifest.timestamp.clone(),
        git_commit: manifest.git_commit.clone(),
        summary: IndexSummary {
            total: manifest.summary.total_screenshots,
            passed: manifest.summary.passed,
            failed: manifest.summary.failed,
            new: manifest.summary.new,
        },
    };

    // Remove any existing entry with same id before appending
    index.runs.retain(|r| r.id != run_id);
    index.runs.push(entry);
    index.latest = run_id.to_owned();
    index.latest_path = run_path_str;

    let json = serde_json::to_string_pretty(&index).expect("runs-index serialization failed");
    std::fs::create_dir_all(runs_dir).ok();
    std::fs::write(&index_path, json).expect("failed to write runs-index.json");
}

// ---------------------------------------------------------------------------
// HTML report generation
// ---------------------------------------------------------------------------

pub fn generate_report_html(run_dir: &Path, manifest: &Manifest) {
    let mut html = String::with_capacity(64 * 1024);

    // ---- header + CSS ----
    html.push_str(r#"<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CrispyTivi Screenshot Report</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:Inter,system-ui,sans-serif;background:#0d0d0f;color:#e0e0e6;font-size:14px}
  header{background:#1a1a20;border-bottom:1px solid #2a2a35;padding:16px 24px;display:flex;align-items:center;gap:24px;flex-wrap:wrap}
  header h1{font-size:18px;font-weight:700;color:#fff}
  .meta{font-size:12px;color:#888;margin-left:auto}
  .stats{display:flex;gap:12px;flex-wrap:wrap;padding:16px 24px;background:#111115;border-bottom:1px solid #1e1e28}
  .stat{padding:8px 16px;border-radius:8px;font-weight:600;font-size:13px}
  .stat.total{background:#1e1e28;color:#ccc}
  .stat.pass{background:#0f2e1a;color:#4ade80}
  .stat.fail{background:#2e0f0f;color:#f87171}
  .stat.new{background:#0f1e2e;color:#60a5fa}
  .stat.skip{background:#1e1e1e;color:#9ca3af}
  .filters{padding:12px 24px;display:flex;gap:8px;background:#0d0d0f;border-bottom:1px solid #1a1a20}
  .filter-btn{padding:6px 14px;border-radius:20px;border:1px solid #2a2a35;background:#1a1a20;color:#aaa;cursor:pointer;font-size:12px;font-weight:600;transition:all .15s}
  .filter-btn:hover,.filter-btn.active{background:#fff;color:#000;border-color:#fff}
  .journey{margin:24px;border:1px solid #1e1e28;border-radius:12px;overflow:hidden}
  .journey-header{padding:12px 20px;display:flex;align-items:center;gap:12px;background:#14141a}
  .journey-name{font-weight:700;font-size:15px}
  .badge{padding:3px 10px;border-radius:12px;font-size:11px;font-weight:700;text-transform:uppercase}
  .badge.pass{background:#0f2e1a;color:#4ade80}
  .badge.fail{background:#2e0f0f;color:#f87171}
  .badge.blocked{background:#2e1f0f;color:#fbbf24}
  .badge.skipped{background:#1e1e1e;color:#9ca3af}
  .badge.new{background:#0f1e2e;color:#60a5fa}
  .screenshots{display:grid;gap:1px;background:#1a1a20}
  .screenshot{background:#0d0d0f;padding:16px 20px}
  .screenshot.hidden{display:none}
  .screenshot-label{font-weight:600;font-size:13px;margin-bottom:4px;display:flex;align-items:center;gap:8px}
  .screenshot-meta{font-size:11px;color:#666;margin-bottom:10px}
  .screenshot-step{color:#888;font-size:11px}
  .images{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px}
  .img-col{display:flex;flex-direction:column;gap:4px}
  .img-col-label{font-size:10px;font-weight:700;color:#555;text-transform:uppercase;letter-spacing:.5px}
  .img-col img{width:100%;border-radius:6px;border:1px solid #1e1e28;background:#111}
  .img-col .no-img{width:100%;aspect-ratio:16/9;border-radius:6px;border:1px dashed #222;display:flex;align-items:center;justify-content:center;color:#333;font-size:11px}
  .diff-pct{font-size:11px;color:#666}
</style>
</head>
<body>
"#);

    // ---- header ----
    html.push_str(&format!(
        r#"<header>
  <h1>CrispyTivi Screenshot Report</h1>
  <div class="meta">Run: {run_id} &nbsp;|&nbsp; {ts} &nbsp;|&nbsp; {res} &nbsp;|&nbsp; {branch} @ {commit}</div>
</header>
"#,
        run_id = escape_html(&manifest.run_id),
        ts = escape_html(&manifest.timestamp),
        res = escape_html(&manifest.resolution),
        branch = escape_html(&manifest.git_branch),
        commit = escape_html(&manifest.git_commit),
    ));

    // ---- stats bar ----
    let s = &manifest.summary;
    html.push_str(&format!(
        r#"<div class="stats">
  <div class="stat total">Total: {total}</div>
  <div class="stat pass">Passed: {passed}</div>
  <div class="stat fail">Failed: {failed}</div>
  <div class="stat new">New: {new}</div>
  <div class="stat skip">Skipped: {skipped}</div>
</div>
"#,
        total = s.total_screenshots,
        passed = s.passed,
        failed = s.failed,
        new = s.new,
        skipped = s.skipped,
    ));

    // ---- filter buttons ----
    html.push_str(
        r#"<div class="filters">
  <button class="filter-btn active" onclick="filter('all')">All</button>
  <button class="filter-btn" onclick="filter('fail')">Failed</button>
  <button class="filter-btn" onclick="filter('new')">New</button>
  <button class="filter-btn" onclick="filter('pass')">Passed</button>
</div>
"#,
    );

    // ---- journeys ----
    for journey in &manifest.journeys {
        let badge_class = &journey.status;
        html.push_str(&format!(
            r#"<div class="journey" data-journey-status="{status}">
  <div class="journey-header">
    <span class="journey-name">{name}</span>
    <span class="badge {badge_class}">{status}</span>
    {blocked}
  </div>
  <div class="screenshots">
"#,
            status = escape_html(&journey.status),
            name = escape_html(&journey.name),
            badge_class = escape_html(badge_class),
            blocked = journey
                .blocked_by
                .as_deref()
                .map(|b| format!(
                    r#"<span style="font-size:11px;color:#fbbf24">blocked by: {}</span>"#,
                    escape_html(b)
                ))
                .unwrap_or_default(),
        ));

        for ss in &journey.screenshots {
            let diff_label = if ss.diff_pct > 0.0 {
                format!(" &mdash; diff {:.2}%", ss.diff_pct * 100.0)
            } else {
                String::new()
            };

            html.push_str(&format!(
                r#"<div class="screenshot status-{status}" data-status="{status}">
  <div class="screenshot-label">
    <span class="badge {status}">{status}</span>
    {label}{diff_label}
  </div>
  <div class="screenshot-meta">
    <span class="screenshot-step">{step}</span>
    {expectation}
  </div>
  <div class="images">
    <div class="img-col">
      <div class="img-col-label">Golden</div>
      {golden}
    </div>
    <div class="img-col">
      <div class="img-col-label">Test</div>
      <img src="{test}" alt="test screenshot" loading="lazy">
    </div>
    <div class="img-col">
      <div class="img-col-label">Diff</div>
      {diff}
    </div>
  </div>
</div>
"#,
                status = escape_html(&ss.status),
                label = escape_html(&ss.label),
                diff_label = diff_label,
                step = escape_html(&ss.journey_step),
                expectation = if ss.journey_expectation.is_empty() {
                    String::new()
                } else {
                    format!(
                        r#"<span style="color:#555">&mdash; {}</span>"#,
                        escape_html(&ss.journey_expectation)
                    )
                },
                golden = ss
                    .paths
                    .golden
                    .as_deref()
                    .map(|p| format!(
                        r#"<img src="{}" alt="golden" loading="lazy">"#,
                        escape_html(p)
                    ))
                    .unwrap_or_else(|| r#"<div class="no-img">no golden</div>"#.into()),
                test = escape_html(&ss.paths.test),
                diff = ss
                    .paths
                    .diff
                    .as_deref()
                    .map(|p| format!(
                        r#"<img src="{}" alt="diff" loading="lazy">"#,
                        escape_html(p)
                    ))
                    .unwrap_or_else(|| r#"<div class="no-img">no diff</div>"#.into()),
            ));
        }

        html.push_str("  </div>\n</div>\n");
    }

    // ---- JS for filter toggling ----
    html.push_str(
        r#"<script>
function filter(status) {
  document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
  event.target.classList.add('active');
  document.querySelectorAll('.screenshot').forEach(el => {
    if (status === 'all' || el.dataset.status === status) {
      el.classList.remove('hidden');
    } else {
      el.classList.add('hidden');
    }
  });
}
</script>
</body>
</html>
"#,
    );

    let out_path = run_dir.join("report.html");
    std::fs::write(&out_path, html).expect("failed to write report.html");
}

// ---------------------------------------------------------------------------
// HTML escaping
// ---------------------------------------------------------------------------

fn escape_html(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn generate_reports(
    run_dir: &Path,
    runs_dir: &Path,
    run_id: &str,
    journey_results: &[JourneyRunResult],
) {
    let manifest = generate_manifest(run_dir, run_id, journey_results);
    let json = serde_json::to_string_pretty(&manifest).expect("manifest serialization failed");
    std::fs::write(run_dir.join("manifest.json"), &json).expect("failed to write manifest.json");
    update_runs_index(runs_dir, run_id, &manifest);
    generate_report_html(run_dir, &manifest);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use tempfile::TempDir;

    fn fake_screenshot(id: &str, status: ScreenshotStatus) -> ScreenshotResult {
        ScreenshotResult {
            id: id.to_owned(),
            label: id.to_owned(),
            journey_step: format!("step for {id}"),
            journey_expectation: format!("expects {id}"),
            status,
            diff_pct: 0.0,
            golden_path: Some(PathBuf::from(format!("golden/{id}.png"))),
            test_path: PathBuf::from(format!("test/{id}.png")),
            diff_path: None,
        }
    }

    fn fake_journey(
        id: &str,
        status: JourneyStatus,
        shots: Vec<ScreenshotResult>,
    ) -> JourneyRunResult {
        JourneyRunResult {
            id: id.to_owned(),
            name: format!("Journey {id}"),
            status,
            screenshots: shots,
            blocked_by: None,
            error: None,
        }
    }

    fn make_journey_results() -> Vec<JourneyRunResult> {
        vec![
            fake_journey(
                "onboarding",
                JourneyStatus::Pass,
                vec![
                    fake_screenshot("splash", ScreenshotStatus::Pass),
                    fake_screenshot("welcome", ScreenshotStatus::Pass),
                ],
            ),
            fake_journey(
                "channel_list",
                JourneyStatus::Fail,
                vec![
                    fake_screenshot("channel_load", ScreenshotStatus::Fail),
                    fake_screenshot("channel_new", ScreenshotStatus::New),
                ],
            ),
            fake_journey(
                "epg",
                JourneyStatus::Skipped,
                vec![fake_screenshot("epg_skipped", ScreenshotStatus::Skipped)],
            ),
        ]
    }

    #[test]
    fn test_manifest_json_roundtrips() {
        let tmp = TempDir::new().unwrap();
        let run_dir = tmp.path().join("run001");
        std::fs::create_dir_all(&run_dir).unwrap();

        let results = make_journey_results();
        let manifest = generate_manifest(&run_dir, "run001", &results);

        // Verify counts
        assert_eq!(manifest.summary.total_screenshots, 5);
        assert_eq!(manifest.summary.passed, 2);
        assert_eq!(manifest.summary.failed, 1);
        assert_eq!(manifest.summary.new, 1);
        assert_eq!(manifest.summary.skipped, 1);
        assert_eq!(manifest.summary.total_journeys, 3);
        assert_eq!(manifest.summary.journeys_passed, 1);
        assert_eq!(manifest.summary.journeys_failed, 1);
        // skipped journeys not counted in blocked
        assert_eq!(manifest.summary.journeys_blocked, 0);

        // Serialize → deserialize roundtrip
        let json = serde_json::to_string_pretty(&manifest).unwrap();
        let decoded: Manifest = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.run_id, "run001");
        assert_eq!(decoded.summary.total_screenshots, 5);
        assert_eq!(decoded.journeys.len(), 3);
        assert_eq!(
            decoded.design_refs.design_spec,
            ".ai/crispy_tivi_design_spec.md"
        );
        assert_eq!(
            decoded.design_refs.journey_spec,
            ".ai/planning/USER-JOURNEYS.md"
        );
        assert_eq!(
            decoded.design_refs.theme_tokens,
            "rust/crates/crispy-ui/ui/globals/theme.slint"
        );
        assert_eq!(decoded.design_refs.impeccable, ".impeccable.md");
    }

    #[test]
    fn test_runs_index_appends_new_run() {
        let tmp = TempDir::new().unwrap();
        let runs_dir = tmp.path().join("runs");
        std::fs::create_dir_all(&runs_dir).unwrap();

        let results = make_journey_results();

        // First run
        let run1_dir = runs_dir.join("run001");
        std::fs::create_dir_all(&run1_dir).unwrap();
        let m1 = generate_manifest(&run1_dir, "run001", &results);
        update_runs_index(&runs_dir, "run001", &m1);

        let idx_path = runs_dir.join("runs-index.json");
        let raw = std::fs::read_to_string(&idx_path).unwrap();
        let idx: RunsIndex = serde_json::from_str(&raw).unwrap();
        assert_eq!(idx.runs.len(), 1);
        assert_eq!(idx.latest, "run001");

        // Second run
        let run2_dir = runs_dir.join("run002");
        std::fs::create_dir_all(&run2_dir).unwrap();
        let m2 = generate_manifest(&run2_dir, "run002", &results);
        update_runs_index(&runs_dir, "run002", &m2);

        let raw2 = std::fs::read_to_string(&idx_path).unwrap();
        let idx2: RunsIndex = serde_json::from_str(&raw2).unwrap();
        assert_eq!(idx2.runs.len(), 2);
        assert_eq!(idx2.latest, "run002");
        assert_eq!(idx2.runs[0].id, "run001");
        assert_eq!(idx2.runs[1].id, "run002");
    }

    #[test]
    fn test_report_html_is_valid() {
        let tmp = TempDir::new().unwrap();
        let run_dir = tmp.path().join("run001");
        std::fs::create_dir_all(&run_dir).unwrap();

        let results = make_journey_results();
        let manifest = generate_manifest(&run_dir, "run001", &results);
        generate_report_html(&run_dir, &manifest);

        let report_path = run_dir.join("report.html");
        assert!(report_path.exists(), "report.html should be created");

        let content = std::fs::read_to_string(&report_path).unwrap();
        assert!(
            content.contains("<!DOCTYPE html>"),
            "must be valid HTML doc"
        );
        assert!(
            content.contains("CrispyTivi Screenshot Report"),
            "must have title"
        );
        assert!(content.contains("run001"), "must include run id");
        assert!(
            content.contains("Journey onboarding"),
            "must include journey name"
        );
        assert!(
            content.contains("Journey channel_list"),
            "must include failing journey"
        );
        assert!(
            content.contains(r#"class="stat pass""#),
            "must have pass stat"
        );
        assert!(
            content.contains(r#"class="stat fail""#),
            "must have fail stat"
        );
        assert!(
            content.contains(r#"class="stat new""#),
            "must have new stat"
        );
        assert!(content.contains("filter("), "must have filter JS");
        assert!(
            content.ends_with('\n') || content.contains("</html>"),
            "must close html tag"
        );
    }
}
