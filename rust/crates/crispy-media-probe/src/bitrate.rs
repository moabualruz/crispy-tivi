//! Bitrate profiling via ffmpeg.
//!
//! Translated from IPTVChecker-Python `get_video_bitrate`:
//! runs ffmpeg for a short duration and calculates bitrate from bytes read.

use std::process::Stdio;
use std::time::Duration;

use regex::Regex;
use tokio::process::Command;
use tracing::{debug, warn};

use crate::error::ProbeError;

/// Profile the approximate bitrate of a stream by sampling it.
///
/// Translated from IPTVChecker-Python `get_video_bitrate`:
/// ```python
/// command = ['ffmpeg', '-v', 'debug', '-user_agent', 'VLC/3.0.14',
///            '-i', url, '-t', '10', '-f', 'null', '-']
/// # parse "Statistics: N bytes read" from stderr
/// bitrate_kbps = (total_bytes * 8) / 1000 / duration
/// ```
///
/// Returns bitrate in bits per second.
pub async fn profile_bitrate(
    url: &str,
    duration_secs: u64,
    timeout_secs: u64,
) -> Result<u64, ProbeError> {
    let duration_str = duration_secs.to_string();

    let mut cmd = Command::new("ffmpeg");
    cmd.args([
        "-v",
        "debug",
        "-user_agent",
        "VLC/3.0.14",
        "-i",
        url,
        "-t",
        &duration_str,
        "-f",
        "null",
        "-",
    ])
    .stdout(Stdio::null())
    .stderr(Stdio::piped())
    .stdin(Stdio::null());

    debug!(url, duration_secs, "profiling bitrate");

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

    let stderr = String::from_utf8_lossy(&result.stderr);

    // Translated from Python:
    // for line in output.splitlines():
    //     if "Statistics:" in line and "bytes read" in line:
    //         size_str = parts[0].strip().split()[-1]
    //         total_bytes = int(size_str)
    let bytes_re = Regex::new(r"(\d+)\s+bytes\s+read").expect("valid regex");

    let total_bytes: u64 = stderr
        .lines()
        .filter(|line| line.contains("Statistics:") && line.contains("bytes read"))
        .filter_map(|line| {
            bytes_re
                .captures(line)
                .and_then(|caps| caps.get(1))
                .and_then(|m| m.as_str().parse::<u64>().ok())
        })
        .next_back()
        .unwrap_or(0);

    if total_bytes == 0 {
        warn!(url, "no bytes-read statistics found in ffmpeg output");
        return Err(ProbeError::ProcessFailed {
            code: result.status.code(),
            stderr: "no bytes-read statistics in ffmpeg debug output".to_string(),
        });
    }

    // Translated from Python: bitrate_kbps = (total_bytes * 8) / 1000 / 10
    // We return bits per second instead of kbps.
    let bitrate_bps = (total_bytes * 8) / duration_secs;
    debug!(url, bitrate_bps, total_bytes, "bitrate profiled");

    Ok(bitrate_bps)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bytes_read_regex_matches() {
        let re = Regex::new(r"(\d+)\s+bytes\s+read").unwrap();
        let line = "  Statistics: 1234567 bytes read, 0 seeks";
        let caps = re.captures(line).unwrap();
        assert_eq!(caps.get(1).unwrap().as_str(), "1234567");
    }

    #[test]
    fn bytes_read_regex_no_match() {
        let re = Regex::new(r"(\d+)\s+bytes\s+read").unwrap();
        assert!(re.captures("no stats here").is_none());
    }
}
