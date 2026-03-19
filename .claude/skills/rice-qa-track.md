---
name: rice-qa-track
description: Track QA issues across test runs, detect regressions and fixes. Use when asked to "track issues", "what's still broken", "QA status", "regression check", "what changed since last run".
---

# QA Issue Tracking

Compare test runs to track issue lifecycle: new → persistent → fixed → regressed.

## Steps

1. **Determine pipeline and run range:**
   - Ask user which pipeline to track (`stub`, `cached`, `e2e`) or check all three
   - Read `tests/output/{pipeline}/runs-index.json`
   - Identify the last 2+ runs — use both `latest_path` and `previous_path` (or the runs list)

2. **Compare manifests across runs:**
   - Read `manifest.json` from each run
   - For each screenshot ID, compare `status` across runs:
     | Previous | Latest | Classification |
     |----------|--------|---------------|
     | absent   | fail   | NEW |
     | fail     | pass   | FIXED |
     | fail     | fail   | PERSISTENT |
     | pass     | fail   | REGRESSED |
     | pass     | pass   | STABLE |

3. **Load analysis files if present:**
   - Read `{run}/analysis/issues.json` from both runs
   - Match issues by `id` or by `(journey, step, type)` tuple

4. **For PERSISTENT issues, count age:**
   - Check the runs list in `runs-index.json` — how many consecutive runs has this issue appeared?
   - Flag any issue open for 3+ runs as "stale — needs immediate attention"

5. **Cross-reference with git commits:**
   ```bash
   git log --oneline {old_commit}..{new_commit}
   ```
   Where `old_commit` and `new_commit` come from the `git_sha` field in each run's `manifest.json`.

   For each NEW or REGRESSED issue:
   - Review which commits landed between runs
   - Identify the most likely culprit commit based on affected file paths

6. **Output tracking report:**
   ```markdown
   ## QA Tracking Report — {pipeline} — {date}

   ### Summary
   | Status      | Count |
   |-------------|-------|
   | REGRESSED   | X     |
   | NEW         | X     |
   | PERSISTENT  | X     |
   | FIXED       | X     |
   | STABLE      | X     |

   ### REGRESSED (highest priority — were working, now broken)
   | Issue | Journey | Screenshot | Likely Commit | Age |

   ### NEW (appeared this run)
   | Issue | Journey | Screenshot | Probable Cause |

   ### PERSISTENT (open across multiple runs)
   | Issue | Journey | Open Since | Runs Open | Screenshot |

   ### FIXED (resolved this run)
   | Issue | Journey | Fix Commit |
   ```

7. **Recommend actions:**
   - Stale persistent issues: "These X issues have been open for 3+ runs — escalate to fix plan"
   - Regressions: "Run `/rice-qa-analyze` on the regressed journeys, then bisect the commit range"
   - All stable: "No regressions. Consider running `/rice-screenshot-approve` to update golden baselines"
