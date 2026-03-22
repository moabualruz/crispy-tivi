//! Screenshot capture via ffmpeg.
//!
//! Translated from IPTVChecker-Python `capture_frame` and
//! `build_screenshot_filename`.

use std::process::Stdio;
use std::time::Duration;

use regex::Regex;
use tokio::process::Command;
use tracing::{debug, warn};

use crate::error::ProbeError;

/// Capture a single video frame as a screenshot.
///
/// Translated from IPTVChecker-Python `capture_frame`:
/// ```python
/// command = ['ffmpeg', '-y', '-i', url, '-frames:v', '1',
///            os.path.join(output_path, f"{file_name}.png")]
/// ```
pub async fn capture_screenshot(
    url: &str,
    output_path: &str,
    timeout_secs: u64,
) -> Result<(), ProbeError> {
    let mut cmd = Command::new("ffmpeg");
    cmd.args(["-y", "-i", url, "-frames:v", "1", output_path])
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .stdin(Stdio::null());

    debug!(url, output_path, "capturing screenshot");

    let child = cmd.spawn().map_err(|e| {
        if e.kind() == std::io::ErrorKind::NotFound {
            ProbeError::FfmpegNotFound
        } else {
            ProbeError::Io(e)
        }
    })?;

    let result = tokio::time::timeout(Duration::from_secs(timeout_secs), child.wait_with_output())
        .await
        .map_err(|_| ProbeError::Timeout {
            url: url.to_string(),
            timeout_secs,
        })?
        .map_err(ProbeError::Io)?;

    if !result.status.success() {
        let stderr = String::from_utf8_lossy(&result.stderr).to_string();
        warn!(url, stderr = %stderr, "ffmpeg screenshot failed");
        return Err(ProbeError::ProcessFailed {
            code: result.status.code(),
            stderr,
        });
    }

    debug!(output_path, "screenshot saved");
    Ok(())
}

/// Sanitize a channel name into a safe filename.
///
/// Translated from IPTVChecker-Python `build_screenshot_filename`:
/// - Removes illegal filesystem characters (`\/:*?"<>|`)
/// - Strips leading/trailing dots and whitespace
/// - Collapses multiple spaces
/// - Guards against Windows reserved names (CON, PRN, NUL, etc.)
/// - Truncates to `max_length` characters
pub fn sanitize_filename(name: &str, max_length: usize) -> String {
    // Translated from Python:
    // illegal_chars_pattern = r'[\\/:*?"<>|]'
    let re = Regex::new(r#"[\\/:*?"<>|]"#).expect("valid regex");
    let mut sanitized = re.replace_all(name, "-").to_string();

    // Strip leading/trailing whitespace and dots
    sanitized = sanitized.trim().trim_matches('.').to_string();

    // Collapse multiple spaces
    let spaces_re = Regex::new(r"\s+").expect("valid regex");
    sanitized = spaces_re.replace_all(&sanitized, " ").to_string();

    if sanitized.is_empty() {
        sanitized = "channel".to_string();
    }

    // Guard against Windows reserved names
    // Translated from Python: windows_reserved_names set
    let reserved = [
        "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8",
        "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    ];
    if reserved.iter().any(|r| r.eq_ignore_ascii_case(&sanitized)) {
        sanitized = format!("{sanitized}_channel");
    }

    // Truncate
    let effective_max = max_length.max(1);
    if sanitized.len() > effective_max {
        sanitized.truncate(effective_max);
    }

    sanitized
}

/// Check whether ffmpeg is available in PATH.
///
/// Translated from IPTVChecker-Python `check_ffmpeg_availability`.
pub async fn is_ffmpeg_available() -> bool {
    let result = Command::new("ffmpeg")
        .arg("-version")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .stdin(Stdio::null())
        .status()
        .await;

    matches!(result, Ok(status) if status.success())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sanitize_removes_illegal_chars() {
        assert_eq!(sanitize_filename(r#"CNN\HD:News"#, 200), "CNN-HD-News");
    }

    #[test]
    fn sanitize_strips_dots_and_spaces() {
        assert_eq!(sanitize_filename("  ..hello..  ", 200), "hello");
    }

    #[test]
    fn sanitize_collapses_whitespace() {
        assert_eq!(sanitize_filename("a   b   c", 200), "a b c");
    }

    #[test]
    fn sanitize_empty_becomes_channel() {
        assert_eq!(sanitize_filename("", 200), "channel");
    }

    #[test]
    fn sanitize_reserved_name_gets_suffix() {
        assert_eq!(sanitize_filename("CON", 200), "CON_channel");
        assert_eq!(sanitize_filename("nul", 200), "nul_channel");
    }

    #[test]
    fn sanitize_truncates_to_max_length() {
        let long_name = "a".repeat(300);
        let result = sanitize_filename(&long_name, 50);
        assert_eq!(result.len(), 50);
    }

    #[tokio::test]
    async fn ffmpeg_availability_does_not_panic() {
        let _available = is_ffmpeg_available().await;
    }
}
