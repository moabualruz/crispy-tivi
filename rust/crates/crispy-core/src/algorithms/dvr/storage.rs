//! DVR storage breakdown and file filtering/sorting.

/// Compute storage breakdown statistics for a list of recordings.
///
/// Input: JSON array of recording objects with fields:
///   `id`, `status`, `channel_name`, `file_size_bytes` (nullable i64),
///   `end_time` (epoch ms).
///
/// Output JSON:
/// ```json
/// {
///   "total_bytes": N,
///   "total_count": N,
///   "categories": [{"label":"Completed","count":N,"bytes":N}],
///   "channel_bytes": {"channel_name": N},
///   "channel_counts": {"channel_name": N},
///   "cleanup_candidate_ids": ["id1", ...]
/// }
/// ```
///
/// Cleanup candidates: completed recordings older than 30 days +
/// all failed recordings, capped at 10.
pub fn compute_storage_breakdown(recordings_json: &str, now_ms: i64) -> String {
    use std::collections::HashMap;

    const EMPTY: &str = r#"{"total_bytes":0,"total_count":0,"categories":[],"channel_bytes":{},"channel_counts":{},"cleanup_candidate_ids":[]}"#;

    let Ok(arr) = serde_json::from_str::<serde_json::Value>(recordings_json) else {
        return EMPTY.to_string();
    };
    let Some(items) = arr.as_array() else {
        return EMPTY.to_string();
    };

    let thirty_days_ms: i64 = 30 * 24 * 60 * 60 * 1000;
    let cutoff_ms = now_ms - thirty_days_ms;

    let mut total_bytes: i64 = 0;
    // category label → (count, bytes)
    let mut category_map: HashMap<String, (i64, i64)> = HashMap::new();
    // channel → bytes (completed only)
    let mut channel_bytes: HashMap<String, i64> = HashMap::new();
    // channel → count (completed only)
    let mut channel_counts: HashMap<String, i64> = HashMap::new();
    let mut cleanup_candidates: Vec<String> = Vec::new();

    for item in items {
        let id = item.get("id").and_then(|v| v.as_str()).unwrap_or("");
        let status = item.get("status").and_then(|v| v.as_str()).unwrap_or("");
        let channel = item
            .get("channel_name")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let file_bytes = item
            .get("file_size_bytes")
            .and_then(|v| v.as_i64())
            .unwrap_or(0);
        let end_time = item.get("end_time").and_then(|v| v.as_i64()).unwrap_or(0);

        total_bytes += file_bytes;

        let label = match status {
            "completed" => "Completed",
            "scheduled" => "Scheduled",
            "recording" => "Recording",
            "failed" => "Failed",
            other => other,
        };

        let entry = category_map.entry(label.to_string()).or_insert((0, 0));
        entry.0 += 1;
        entry.1 += file_bytes;

        if status == "completed" {
            *channel_bytes.entry(channel.to_string()).or_insert(0) += file_bytes;
            *channel_counts.entry(channel.to_string()).or_insert(0) += 1;

            if end_time < cutoff_ms && cleanup_candidates.len() < 10 {
                cleanup_candidates.push(id.to_string());
            }
        } else if status == "failed" && cleanup_candidates.len() < 10 {
            cleanup_candidates.push(id.to_string());
        }
    }

    // Build ordered categories list (non-empty groups only).
    let mut categories: Vec<serde_json::Value> = category_map
        .iter()
        .map(|(label, (count, bytes))| {
            serde_json::json!({
                "label": label,
                "count": count,
                "bytes": bytes,
            })
        })
        .collect();
    // Sort by label for deterministic output.
    categories.sort_by(|a, b| {
        a["label"]
            .as_str()
            .unwrap_or("")
            .cmp(b["label"].as_str().unwrap_or(""))
    });

    let result = serde_json::json!({
        "total_bytes": total_bytes,
        "total_count": items.len() as i64,
        "categories": categories,
        "channel_bytes": channel_bytes,
        "channel_counts": channel_counts,
        "cleanup_candidate_ids": cleanup_candidates,
    });

    serde_json::to_string(&result).unwrap_or_else(|_| EMPTY.to_string())
}

/// Filter recordings by a search query.
///
/// Input: JSON array of recording objects with:
///   `id`, `program_name`, `channel_name`, `start_time` (epoch ms).
///
/// If `query` is empty, returns the input array unchanged.
/// Otherwise performs a case-insensitive search across `program_name`,
/// `channel_name`, and the formatted date (`YYYY-MM-DD` of `start_time`).
///
/// Returns: JSON array of matching recording objects.
pub fn filter_recordings(recordings_json: &str, query: &str) -> String {
    use chrono::{DateTime, Utc};

    if query.is_empty() {
        return recordings_json.to_string();
    }

    let Ok(arr) = serde_json::from_str::<serde_json::Value>(recordings_json) else {
        return "[]".to_string();
    };
    let Some(items) = arr.as_array() else {
        return "[]".to_string();
    };

    let q = query.to_lowercase();

    let matched: Vec<&serde_json::Value> = items
        .iter()
        .filter(|item| {
            let program = item
                .get("program_name")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_lowercase();
            let channel = item
                .get("channel_name")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_lowercase();
            let start_ms = item.get("start_time").and_then(|v| v.as_i64()).unwrap_or(0);
            let date_str = DateTime::from_timestamp_millis(start_ms)
                .unwrap_or_else(|| DateTime::<Utc>::from_timestamp(0, 0).unwrap())
                .format("%Y-%m-%d")
                .to_string();

            program.contains(&q) || channel.contains(&q) || date_str.contains(&q)
        })
        .collect();

    serde_json::to_string(&matched).unwrap_or_else(|_| "[]".to_string())
}

/// Classify a filename's extension as "video", "audio", "subtitle", or "other".
///
/// Extension matching is case-insensitive. Files with no extension return "other".
pub fn classify_file_type(filename: &str) -> String {
    let ext = std::path::Path::new(filename)
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_lowercase());

    match ext.as_deref() {
        Some(
            "mp4" | "mkv" | "avi" | "mov" | "ts" | "mpg" | "mpeg" | "m2ts" | "wmv" | "flv" | "webm"
            | "m4v",
        ) => "video".to_string(),
        Some("mp3" | "aac" | "flac" | "ogg" | "wav" | "opus" | "m4a" | "wma" | "ac3" | "eac3") => {
            "audio".to_string()
        }
        Some("srt" | "ass" | "ssa" | "vtt" | "sub" | "idx" | "sup" | "dfxp" | "ttml") => {
            "subtitle".to_string()
        }
        _ => "other".to_string(),
    }
}

/// Sort a JSON array of remote file objects.
///
/// Input: JSON array of objects with:
///   `name` (string), `is_directory` (bool), `modified_at` (epoch ms),
///   `size_bytes` (i64).
///
/// Directories are always sorted before non-directories.
///
/// `order` values: `"name_asc"`, `"name_desc"`, `"date_newest"`,
/// `"date_oldest"`, `"size_largest"`, `"size_smallest"`.
/// Unknown orders default to `"name_asc"`.
///
/// Returns: sorted JSON array.
pub fn sort_remote_files(files_json: &str, order: &str) -> String {
    let Ok(arr) = serde_json::from_str::<serde_json::Value>(files_json) else {
        return "[]".to_string();
    };
    let Some(items) = arr.as_array() else {
        return "[]".to_string();
    };

    let mut files: Vec<&serde_json::Value> = items.iter().collect();

    files.sort_by(|a, b| {
        let a_dir = a
            .get("is_directory")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        let b_dir = b
            .get("is_directory")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);

        // Directories always come first.
        match (a_dir, b_dir) {
            (true, false) => return std::cmp::Ordering::Less,
            (false, true) => return std::cmp::Ordering::Greater,
            _ => {}
        }

        let a_name = a
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();
        let b_name = b
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();
        let a_date = a.get("modified_at").and_then(|v| v.as_i64()).unwrap_or(0);
        let b_date = b.get("modified_at").and_then(|v| v.as_i64()).unwrap_or(0);
        let a_size = a.get("size_bytes").and_then(|v| v.as_i64()).unwrap_or(0);
        let b_size = b.get("size_bytes").and_then(|v| v.as_i64()).unwrap_or(0);

        match order {
            "name_desc" => b_name.cmp(&a_name),
            "date_newest" => b_date.cmp(&a_date),
            "date_oldest" => a_date.cmp(&b_date),
            "size_largest" => b_size.cmp(&a_size),
            "size_smallest" => a_size.cmp(&b_size),
            // "name_asc" and any unknown order
            _ => a_name.cmp(&b_name),
        }
    });

    serde_json::to_string(&files).unwrap_or_else(|_| "[]".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── compute_storage_breakdown ───────────────────

    #[test]
    fn storage_breakdown_empty_input_returns_zeroes() {
        let result = compute_storage_breakdown("[]", 1_000_000_000);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["total_bytes"], 0);
        assert_eq!(v["total_count"], 0);
        assert!(v["categories"].as_array().unwrap().is_empty());
    }

    #[test]
    fn storage_breakdown_multiple_statuses_aggregated() {
        let json = r#"[
            {"id":"r1","status":"completed","channel_name":"BBC","file_size_bytes":1000,"end_time":0},
            {"id":"r2","status":"completed","channel_name":"CNN","file_size_bytes":2000,"end_time":0},
            {"id":"r3","status":"recording","channel_name":"ITV","file_size_bytes":500,"end_time":0},
            {"id":"r4","status":"scheduled","channel_name":"SKY","file_size_bytes":null,"end_time":0},
            {"id":"r5","status":"failed","channel_name":"BBC","file_size_bytes":0,"end_time":0}
        ]"#;
        let result = compute_storage_breakdown(json, 9_999_999_999_999);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["total_bytes"], 3500);
        assert_eq!(v["total_count"], 5);

        let cats = v["categories"].as_array().unwrap();
        // Completed, Failed, Recording, Scheduled are all present.
        assert_eq!(cats.len(), 4);
    }

    #[test]
    fn storage_breakdown_per_channel_aggregation_completed_only() {
        let json = r#"[
            {"id":"r1","status":"completed","channel_name":"BBC","file_size_bytes":1000,"end_time":0},
            {"id":"r2","status":"completed","channel_name":"BBC","file_size_bytes":2000,"end_time":0},
            {"id":"r3","status":"recording","channel_name":"BBC","file_size_bytes":500,"end_time":0}
        ]"#;
        // now_ms far in future so no cleanup candidates.
        let result = compute_storage_breakdown(json, 9_999_999_999_999);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        // Only completed recordings count for channel stats.
        assert_eq!(v["channel_bytes"]["BBC"], 3000);
        assert_eq!(v["channel_counts"]["BBC"], 2);
    }

    #[test]
    fn storage_breakdown_cleanup_candidates_threshold_30_days() {
        // 1 day = 86_400_000 ms.
        // now = 40 days, cutoff = now - 30 days = 10 days.
        let forty_days_ms: i64 = 40 * 86_400_000;
        // 5 days < cutoff (10 days) → candidate.
        let five_days_ms: i64 = 5 * 86_400_000;
        // 20 days > cutoff (10 days) → not candidate.
        let twenty_days_ms: i64 = 20 * 86_400_000;

        let json = format!(
            r#"[
                {{"id":"old","status":"completed","channel_name":"CH","file_size_bytes":0,"end_time":{five_days_ms}}},
                {{"id":"new","status":"completed","channel_name":"CH","file_size_bytes":0,"end_time":{twenty_days_ms}}}
            ]"#
        );
        let result = compute_storage_breakdown(&json, forty_days_ms);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let candidates = v["cleanup_candidate_ids"].as_array().unwrap();
        assert_eq!(candidates.len(), 1);
        assert_eq!(candidates[0], "old");
    }

    #[test]
    fn storage_breakdown_failed_recordings_are_cleanup_candidates() {
        let json = r#"[
            {"id":"f1","status":"failed","channel_name":"BBC","file_size_bytes":0,"end_time":0},
            {"id":"f2","status":"failed","channel_name":"CNN","file_size_bytes":0,"end_time":0}
        ]"#;
        let result = compute_storage_breakdown(json, 9_999_999_999_999);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let candidates = v["cleanup_candidate_ids"].as_array().unwrap();
        assert_eq!(candidates.len(), 2);
    }

    #[test]
    fn storage_breakdown_cleanup_candidates_capped_at_10() {
        // 15 failed recordings — only 10 should appear in candidates.
        let items: Vec<String> = (0..15)
            .map(|i| {
                format!(
                    r#"{{"id":"f{i}","status":"failed","channel_name":"CH","file_size_bytes":0,"end_time":0}}"#
                )
            })
            .collect();
        let json = format!("[{}]", items.join(","));
        let result = compute_storage_breakdown(&json, 9_999_999_999_999);
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["cleanup_candidate_ids"].as_array().unwrap().len(), 10);
    }

    // ── filter_recordings ────────────────────────────

    #[test]
    fn filter_recordings_empty_query_returns_input_unchanged() {
        let json = r#"[{"id":"r1","program_name":"News","channel_name":"BBC","start_time":0}]"#;
        let result = filter_recordings(json, "");
        assert_eq!(result, json);
    }

    #[test]
    fn filter_recordings_match_by_program_name() {
        let json = r#"[
            {"id":"r1","program_name":"Evening News","channel_name":"BBC","start_time":0},
            {"id":"r2","program_name":"Sport Live","channel_name":"BBC","start_time":0}
        ]"#;
        let result = filter_recordings(json, "news");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["id"], "r1");
    }

    #[test]
    fn filter_recordings_match_by_channel_name() {
        let json = r#"[
            {"id":"r1","program_name":"Show A","channel_name":"BBC One","start_time":0},
            {"id":"r2","program_name":"Show B","channel_name":"CNN","start_time":0}
        ]"#;
        let result = filter_recordings(json, "bbc");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["id"], "r1");
    }

    #[test]
    fn filter_recordings_match_by_formatted_date() {
        // epoch 0 ms → 1970-01-01; 1000000000000 ms → 2001-09-09.
        let json = r#"[
            {"id":"r1","program_name":"Show","channel_name":"CH","start_time":0},
            {"id":"r2","program_name":"Other","channel_name":"CH","start_time":1000000000000}
        ]"#;
        let result = filter_recordings(json, "1970-01-01");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0]["id"], "r1");
    }

    #[test]
    fn filter_recordings_no_match_returns_empty_array() {
        let json = r#"[
            {"id":"r1","program_name":"Evening News","channel_name":"BBC","start_time":0}
        ]"#;
        let result = filter_recordings(json, "zzznomatch");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(v.as_array().unwrap().is_empty());
    }

    // ── classify_file_type ───────────────────────────

    #[test]
    fn classify_video_extensions() {
        let exts = [
            "mp4", "mkv", "avi", "mov", "ts", "mpg", "mpeg", "m2ts", "wmv", "flv", "webm", "m4v",
        ];
        for ext in &exts {
            let filename = format!("recording.{ext}");
            assert_eq!(classify_file_type(&filename), "video", "failed for .{ext}");
        }
    }

    #[test]
    fn classify_audio_extensions() {
        let exts = [
            "mp3", "aac", "flac", "ogg", "wav", "opus", "m4a", "wma", "ac3", "eac3",
        ];
        for ext in &exts {
            let filename = format!("track.{ext}");
            assert_eq!(classify_file_type(&filename), "audio", "failed for .{ext}");
        }
    }

    #[test]
    fn classify_subtitle_extensions() {
        let exts = [
            "srt", "ass", "ssa", "vtt", "sub", "idx", "sup", "dfxp", "ttml",
        ];
        for ext in &exts {
            let filename = format!("subtitles.{ext}");
            assert_eq!(
                classify_file_type(&filename),
                "subtitle",
                "failed for .{ext}"
            );
        }
    }

    #[test]
    fn classify_unknown_extension_returns_other() {
        assert_eq!(classify_file_type("document.pdf"), "other");
        assert_eq!(classify_file_type("archive.zip"), "other");
    }

    #[test]
    fn classify_no_extension_returns_other() {
        assert_eq!(classify_file_type("noextension"), "other");
        assert_eq!(classify_file_type(""), "other");
    }

    #[test]
    fn classify_extension_case_insensitive() {
        assert_eq!(classify_file_type("video.MP4"), "video");
        assert_eq!(classify_file_type("audio.AAC"), "audio");
        assert_eq!(classify_file_type("sub.SRT"), "subtitle");
    }

    // ── sort_remote_files ────────────────────────────

    #[test]
    fn sort_remote_files_directories_always_first() {
        let json = r#"[
            {"name":"z_file.mp4","is_directory":false,"modified_at":0,"size_bytes":100},
            {"name":"a_dir","is_directory":true,"modified_at":0,"size_bytes":0},
            {"name":"b_file.ts","is_directory":false,"modified_at":0,"size_bytes":200}
        ]"#;
        let result = sort_remote_files(json, "name_asc");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["name"], "a_dir");
        assert_eq!(arr[0]["is_directory"], true);
    }

    #[test]
    fn sort_remote_files_name_asc() {
        let json = r#"[
            {"name":"Charlie.mp4","is_directory":false,"modified_at":0,"size_bytes":0},
            {"name":"Alpha.mp4","is_directory":false,"modified_at":0,"size_bytes":0},
            {"name":"Beta.mp4","is_directory":false,"modified_at":0,"size_bytes":0}
        ]"#;
        let result = sort_remote_files(json, "name_asc");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["name"], "Alpha.mp4");
        assert_eq!(arr[1]["name"], "Beta.mp4");
        assert_eq!(arr[2]["name"], "Charlie.mp4");
    }

    #[test]
    fn sort_remote_files_name_desc() {
        let json = r#"[
            {"name":"Alpha.mp4","is_directory":false,"modified_at":0,"size_bytes":0},
            {"name":"Charlie.mp4","is_directory":false,"modified_at":0,"size_bytes":0},
            {"name":"Beta.mp4","is_directory":false,"modified_at":0,"size_bytes":0}
        ]"#;
        let result = sort_remote_files(json, "name_desc");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["name"], "Charlie.mp4");
        assert_eq!(arr[1]["name"], "Beta.mp4");
        assert_eq!(arr[2]["name"], "Alpha.mp4");
    }

    #[test]
    fn sort_remote_files_date_newest() {
        let json = r#"[
            {"name":"old.mp4","is_directory":false,"modified_at":1000,"size_bytes":0},
            {"name":"new.mp4","is_directory":false,"modified_at":3000,"size_bytes":0},
            {"name":"mid.mp4","is_directory":false,"modified_at":2000,"size_bytes":0}
        ]"#;
        let result = sort_remote_files(json, "date_newest");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["name"], "new.mp4");
        assert_eq!(arr[1]["name"], "mid.mp4");
        assert_eq!(arr[2]["name"], "old.mp4");
    }

    #[test]
    fn sort_remote_files_date_oldest() {
        let json = r#"[
            {"name":"new.mp4","is_directory":false,"modified_at":3000,"size_bytes":0},
            {"name":"old.mp4","is_directory":false,"modified_at":1000,"size_bytes":0},
            {"name":"mid.mp4","is_directory":false,"modified_at":2000,"size_bytes":0}
        ]"#;
        let result = sort_remote_files(json, "date_oldest");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["name"], "old.mp4");
        assert_eq!(arr[2]["name"], "new.mp4");
    }

    #[test]
    fn sort_remote_files_size_largest() {
        let json = r#"[
            {"name":"small.mp4","is_directory":false,"modified_at":0,"size_bytes":100},
            {"name":"large.mp4","is_directory":false,"modified_at":0,"size_bytes":9999},
            {"name":"medium.mp4","is_directory":false,"modified_at":0,"size_bytes":500}
        ]"#;
        let result = sort_remote_files(json, "size_largest");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["name"], "large.mp4");
        assert_eq!(arr[2]["name"], "small.mp4");
    }

    #[test]
    fn sort_remote_files_size_smallest() {
        let json = r#"[
            {"name":"large.mp4","is_directory":false,"modified_at":0,"size_bytes":9999},
            {"name":"small.mp4","is_directory":false,"modified_at":0,"size_bytes":100},
            {"name":"medium.mp4","is_directory":false,"modified_at":0,"size_bytes":500}
        ]"#;
        let result = sort_remote_files(json, "size_smallest");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        assert_eq!(arr[0]["name"], "small.mp4");
        assert_eq!(arr[2]["name"], "large.mp4");
    }

    #[test]
    fn sort_remote_files_mixed_dirs_and_files_dirs_first() {
        let json = r#"[
            {"name":"z_file.ts","is_directory":false,"modified_at":0,"size_bytes":0},
            {"name":"b_dir","is_directory":true,"modified_at":0,"size_bytes":0},
            {"name":"a_file.mp4","is_directory":false,"modified_at":0,"size_bytes":0},
            {"name":"a_dir","is_directory":true,"modified_at":0,"size_bytes":0}
        ]"#;
        let result = sort_remote_files(json, "name_asc");
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let arr = v.as_array().unwrap();
        // Dirs first: a_dir, b_dir; then files: a_file.mp4, z_file.ts
        assert_eq!(arr[0]["name"], "a_dir");
        assert_eq!(arr[1]["name"], "b_dir");
        assert_eq!(arr[2]["name"], "a_file.mp4");
        assert_eq!(arr[3]["name"], "z_file.ts");
    }
}
