use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process;

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct RunsIndex {
    latest: String,
    latest_path: String,
    runs: Vec<RunEntry>,
}

#[derive(Deserialize)]
struct RunEntry {
    id: String,
    path: String,
    #[allow(dead_code)]
    timestamp: String,
}

#[derive(Deserialize)]
struct Manifest {
    summary: ManifestSummary,
    journeys: Vec<ManifestJourney>,
}

#[derive(Deserialize)]
struct ManifestSummary {
    total_screenshots: usize,
    passed: usize,
    failed: usize,
    new: usize,
}

#[derive(Deserialize)]
struct ManifestJourney {
    id: String,
    name: String,
    #[allow(dead_code)]
    status: String,
    screenshots: Vec<ManifestScreenshot>,
}

#[derive(Deserialize, Clone)]
struct ManifestScreenshot {
    id: String,
    label: String,
    status: String,
    diff_pct: f64,
    paths: ScreenshotPaths,
}

#[derive(Deserialize, Clone)]
struct ScreenshotPaths {
    golden: Option<String>,
    test: String,
    #[allow(dead_code)]
    diff: Option<String>,
}

#[derive(Serialize, Deserialize, Default)]
struct Notes(HashMap<String, NoteEntry>);

#[derive(Serialize, Deserialize)]
struct NoteEntry {
    status: String,
    note: String,
    timestamp: String,
}

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

fn crate_root() -> PathBuf {
    // CARGO_MANIFEST_DIR is set at compile time to the crispy-ui crate root
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn tests_dir() -> PathBuf {
    crate_root().join("tests")
}

fn runs_index_path() -> PathBuf {
    tests_dir().join("runs").join("runs-index.json")
}

// ---------------------------------------------------------------------------
// I/O helpers
// ---------------------------------------------------------------------------

fn read_runs_index() -> anyhow::Result<RunsIndex> {
    let path = runs_index_path();
    let data = fs::read_to_string(&path)
        .map_err(|e| anyhow::anyhow!("Cannot read {}: {}", path.display(), e))?;
    let index: RunsIndex = serde_json::from_str(&data)
        .map_err(|e| anyhow::anyhow!("Invalid runs-index.json: {}", e))?;
    Ok(index)
}

fn read_manifest(latest_path: &str) -> anyhow::Result<Manifest> {
    let path = Path::new(latest_path).join("manifest.json");
    let data = fs::read_to_string(&path)
        .map_err(|e| anyhow::anyhow!("Cannot read {}: {}", path.display(), e))?;
    let manifest: Manifest =
        serde_json::from_str(&data).map_err(|e| anyhow::anyhow!("Invalid manifest.json: {}", e))?;
    Ok(manifest)
}

fn read_notes(latest_path: &str) -> anyhow::Result<Notes> {
    let path = Path::new(latest_path).join("notes.json");
    if !path.exists() {
        return Ok(Notes::default());
    }
    let data = fs::read_to_string(&path)
        .map_err(|e| anyhow::anyhow!("Cannot read {}: {}", path.display(), e))?;
    let notes: Notes =
        serde_json::from_str(&data).map_err(|e| anyhow::anyhow!("Invalid notes.json: {}", e))?;
    Ok(notes)
}

fn write_notes(latest_path: &str, notes: &Notes) -> anyhow::Result<()> {
    let path = Path::new(latest_path).join("notes.json");
    let data = serde_json::to_string_pretty(notes)?;
    fs::write(&path, data)
        .map_err(|e| anyhow::anyhow!("Cannot write {}: {}", path.display(), e))?;
    Ok(())
}

fn now_iso() -> String {
    // Simple RFC-3339 timestamp without pulling in chrono for this binary
    use std::time::{SystemTime, UNIX_EPOCH};
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    // Format as a basic timestamp; good enough for notes metadata
    format!("{}Z", secs)
}

fn copy_to_golden(shot: &ManifestScreenshot) -> anyhow::Result<()> {
    let golden = match &shot.paths.golden {
        Some(g) => PathBuf::from(g),
        None => {
            // Derive golden path from test path: replace /test/ with /golden/
            let test_path = &shot.paths.test;
            PathBuf::from(test_path.replace("/test/", "/golden/"))
        }
    };
    if let Some(parent) = golden.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| anyhow::anyhow!("Cannot create dir {}: {}", parent.display(), e))?;
    }
    fs::copy(&shot.paths.test, &golden).map_err(|e| {
        anyhow::anyhow!(
            "Cannot copy {} → {}: {}",
            shot.paths.test,
            golden.display(),
            e
        )
    })?;
    println!("  approved: {} → {}", shot.id, golden.display());
    Ok(())
}

fn note_approved(notes: &mut Notes, id: &str) {
    notes.0.insert(
        id.to_owned(),
        NoteEntry {
            status: "approved".to_owned(),
            note: String::new(),
            timestamp: now_iso(),
        },
    );
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

fn cmd_status() -> anyhow::Result<()> {
    let index = read_runs_index()?;
    let manifest = read_manifest(&index.latest_path)?;
    let s = &manifest.summary;
    println!("Run: {}  ({})", index.latest, index.latest_path);
    println!(
        "Total: {}  Passed: {}  Failed: {}  New: {}",
        s.total_screenshots, s.passed, s.failed, s.new
    );
    let failures: Vec<_> = manifest
        .journeys
        .iter()
        .flat_map(|j| j.screenshots.iter())
        .filter(|sc| sc.status == "failed" || sc.status == "new")
        .collect();
    if failures.is_empty() {
        println!("All screenshots passed.");
    } else {
        println!("\nNon-passing screenshots:");
        for sc in failures {
            println!(
                "  [{status}] {id}  diff={diff:.2}%  ({label})",
                status = sc.status,
                id = sc.id,
                diff = sc.diff_pct,
                label = sc.label
            );
        }
    }
    Ok(())
}

fn cmd_approve(id: &str) -> anyhow::Result<()> {
    let index = read_runs_index()?;
    let manifest = read_manifest(&index.latest_path)?;
    let shot = manifest
        .journeys
        .iter()
        .flat_map(|j| j.screenshots.iter())
        .find(|sc| sc.id == id)
        .ok_or_else(|| anyhow::anyhow!("Screenshot ID not found: {}", id))?
        .clone();
    copy_to_golden(&shot)?;
    let mut notes = read_notes(&index.latest_path)?;
    note_approved(&mut notes, id);
    write_notes(&index.latest_path, &notes)?;
    Ok(())
}

fn cmd_approve_all() -> anyhow::Result<()> {
    let index = read_runs_index()?;
    let manifest = read_manifest(&index.latest_path)?;
    let targets: Vec<_> = manifest
        .journeys
        .iter()
        .flat_map(|j| j.screenshots.iter())
        .filter(|sc| sc.status == "failed" || sc.status == "new")
        .cloned()
        .collect();
    if targets.is_empty() {
        println!("Nothing to approve.");
        return Ok(());
    }
    let mut notes = read_notes(&index.latest_path)?;
    for shot in &targets {
        copy_to_golden(shot)?;
        note_approved(&mut notes, &shot.id);
    }
    write_notes(&index.latest_path, &notes)?;
    println!("Approved {} screenshot(s).", targets.len());
    Ok(())
}

fn cmd_approve_journey(journey_id: &str) -> anyhow::Result<()> {
    let index = read_runs_index()?;
    let manifest = read_manifest(&index.latest_path)?;
    let journey = manifest
        .journeys
        .iter()
        .find(|j| j.id == journey_id || j.name == journey_id)
        .ok_or_else(|| anyhow::anyhow!("Journey not found: {}", journey_id))?;
    if journey.screenshots.is_empty() {
        println!("Journey '{}' has no screenshots.", journey_id);
        return Ok(());
    }
    let mut notes = read_notes(&index.latest_path)?;
    let count = journey.screenshots.len();
    for shot in &journey.screenshots {
        copy_to_golden(shot)?;
        note_approved(&mut notes, &shot.id);
    }
    write_notes(&index.latest_path, &notes)?;
    println!(
        "Approved {} screenshot(s) in journey '{}'.",
        count, journey.name
    );
    Ok(())
}

fn cmd_reject(id: &str, note_text: &str) -> anyhow::Result<()> {
    let index = read_runs_index()?;
    // Verify ID exists
    let manifest = read_manifest(&index.latest_path)?;
    let exists = manifest
        .journeys
        .iter()
        .flat_map(|j| j.screenshots.iter())
        .any(|sc| sc.id == id);
    if !exists {
        return Err(anyhow::anyhow!("Screenshot ID not found: {}", id));
    }
    let mut notes = read_notes(&index.latest_path)?;
    notes.0.insert(
        id.to_owned(),
        NoteEntry {
            status: "rejected".to_owned(),
            note: note_text.to_owned(),
            timestamp: now_iso(),
        },
    );
    write_notes(&index.latest_path, &notes)?;
    println!("Rejected: {} — \"{}\"", id, note_text);
    Ok(())
}

fn cmd_report() -> anyhow::Result<()> {
    let index = read_runs_index()?;
    let report = Path::new(&index.latest_path).join("report.html");
    let path_str = report
        .to_str()
        .ok_or_else(|| anyhow::anyhow!("Invalid path"))?;

    #[cfg(target_os = "windows")]
    {
        process::Command::new("cmd")
            .args(["/C", "start", "", path_str])
            .spawn()
            .map_err(|e| anyhow::anyhow!("Cannot open browser: {}", e))?;
    }
    #[cfg(target_os = "macos")]
    {
        process::Command::new("open")
            .arg(path_str)
            .spawn()
            .map_err(|e| anyhow::anyhow!("Cannot open browser: {}", e))?;
    }
    #[cfg(target_os = "linux")]
    {
        process::Command::new("xdg-open")
            .arg(path_str)
            .spawn()
            .map_err(|e| anyhow::anyhow!("Cannot open browser: {}", e))?;
    }

    println!("Opening: {}", report.display());
    Ok(())
}

fn cmd_clean(keep: usize) -> anyhow::Result<()> {
    let mut index = read_runs_index()?;
    // Sort by id (lexicographic; IDs are typically ISO timestamps)
    index.runs.sort_by(|a, b| a.id.cmp(&b.id));
    if index.runs.len() <= keep {
        println!(
            "Nothing to remove ({} run(s) present, keeping {}).",
            index.runs.len(),
            keep
        );
        return Ok(());
    }
    let to_remove: Vec<RunEntry> = index.runs.drain(..index.runs.len() - keep).collect();
    let mut removed = 0usize;
    for run in &to_remove {
        let run_path = Path::new(&run.path);
        if run_path.exists() {
            fs::remove_dir_all(run_path)
                .map_err(|e| anyhow::anyhow!("Cannot remove {}: {}", run_path.display(), e))?;
            println!("  removed: {}", run.id);
            removed += 1;
        } else {
            println!("  missing (skipped): {}", run.id);
        }
    }
    // Update index: latest stays correct since we kept the newest entries
    let updated = serde_json::to_string_pretty(&serde_json::json!({
        "latest": index.latest,
        "latest_path": index.latest_path,
        "runs": index.runs.iter().map(|r| serde_json::json!({
            "id": r.id,
            "path": r.path,
        })).collect::<Vec<_>>()
    }))?;
    fs::write(runs_index_path(), updated)?;
    println!("Removed {} old run(s), kept {}.", removed, keep);
    Ok(())
}

fn cmd_export() -> anyhow::Result<()> {
    let index = read_runs_index()?;
    let path = Path::new(&index.latest_path).join("manifest.json");
    let data = fs::read_to_string(&path)
        .map_err(|e| anyhow::anyhow!("Cannot read {}: {}", path.display(), e))?;
    print!("{}", data);
    Ok(())
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

fn usage() {
    eprintln!(
        r#"USAGE: screenshot-review <COMMAND>

COMMANDS:
    status                        Show summary of latest run
    approve <ID>                  Approve screenshot (copy test → golden)
    approve-all                   Approve all new + failed screenshots
    approve-journey <JOURNEY_ID>  Approve all screenshots in a journey
    reject <ID> --note <TEXT>     Reject with regression note
    report                        Open report.html in default browser
    clean [--keep N]              Remove old runs (keep latest N, default 5)
    export                        Print manifest.json to stdout
"#
    );
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        usage();
        process::exit(1);
    }

    let result = match args[1].as_str() {
        "status" => cmd_status(),

        "approve" => {
            if args.len() < 3 {
                eprintln!("Usage: screenshot-review approve <ID>");
                process::exit(1);
            }
            cmd_approve(&args[2])
        }

        "approve-all" => cmd_approve_all(),

        "approve-journey" => {
            if args.len() < 3 {
                eprintln!("Usage: screenshot-review approve-journey <JOURNEY_ID>");
                process::exit(1);
            }
            cmd_approve_journey(&args[2])
        }

        "reject" => {
            // screenshot-review reject <ID> --note <TEXT>
            if args.len() < 5 {
                eprintln!("Usage: screenshot-review reject <ID> --note <TEXT>");
                process::exit(1);
            }
            let id = &args[2];
            // Find --note flag
            let note_text = args
                .windows(2)
                .find(|w| w[0] == "--note")
                .map(|w| w[1].as_str())
                .unwrap_or_else(|| {
                    eprintln!("Missing --note <TEXT>");
                    process::exit(1);
                });
            cmd_reject(id, note_text)
        }

        "report" => cmd_report(),

        "clean" => {
            let keep = args
                .windows(2)
                .find(|w| w[0] == "--keep")
                .and_then(|w| w[1].parse::<usize>().ok())
                .unwrap_or(5);
            cmd_clean(keep)
        }

        "export" => cmd_export(),

        other => {
            eprintln!("Unknown command: {}", other);
            usage();
            process::exit(1);
        }
    };

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        process::exit(1);
    }
}
