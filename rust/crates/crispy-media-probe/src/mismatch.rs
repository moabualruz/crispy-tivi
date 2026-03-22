//! Label vs actual resolution mismatch detection.
//!
//! Translated from IPTVChecker-Python `check_label_mismatch`:
//! validates that channel names claiming a resolution (e.g. "HD", "4K")
//! actually match the detected stream resolution.

use crispy_iptv_types::Resolution;
use regex::Regex;

/// Check if a channel name implies a resolution that doesn't match the actual
/// detected resolution.
///
/// Returns a list of mismatch descriptions (empty if no mismatches).
///
/// Translated from IPTVChecker-Python `check_label_mismatch`:
/// ```python
/// if re.search(r'\b4k\b', channel_name_lower) or re.search(r'\buhd\b', ...):
///     if resolution != "4K":
///         mismatches.append(f"Expected 4K, got {resolution}")
/// elif re.search(r'\b1080p\b', ...) or re.search(r'\bfhd\b', ...):
///     if resolution != "1080p":
///         mismatches.append(...)
/// elif re.search(r'\bhd\b', ...):
///     if resolution not in ["1080p", "720p"]:
///         mismatches.append(...)
/// elif resolution == "4K":
///     mismatches.append("4K channel not labeled as such")
/// ```
pub fn check_label_mismatch(name: &str, resolution: &Resolution) -> Vec<String> {
    let lower = name.to_ascii_lowercase();
    let mut mismatches = Vec::new();

    let has_4k = word_boundary_match(&lower, r"\b4k\b");
    let has_uhd = word_boundary_match(&lower, r"\buhd\b");
    let has_1080p = word_boundary_match(&lower, r"\b1080p\b");
    let has_fhd = word_boundary_match(&lower, r"\bfhd\b");
    let has_hd = word_boundary_match(&lower, r"\bhd\b");

    if has_4k || has_uhd {
        if *resolution != Resolution::UHD {
            mismatches.push(format!("Expected 4K, got {resolution}"));
        }
    } else if has_1080p || has_fhd {
        if *resolution != Resolution::FHD {
            mismatches.push(format!("Expected 1080p, got {resolution}"));
        }
    } else if has_hd {
        if *resolution != Resolution::FHD && *resolution != Resolution::HD {
            mismatches.push(format!("Expected 720p or 1080p, got {resolution}"));
        }
    } else if *resolution == Resolution::UHD {
        mismatches.push("4K channel not labeled as such".to_string());
    }

    mismatches
}

/// Check if a pattern matches using word boundaries.
fn word_boundary_match(text: &str, pattern: &str) -> bool {
    Regex::new(pattern)
        .map(|re| re.is_match(text))
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_4k_label_with_sd_resolution() {
        let mismatches = check_label_mismatch("Sports 4K Ultra", &Resolution::SD);
        assert_eq!(mismatches.len(), 1);
        assert!(mismatches[0].contains("Expected 4K"));
    }

    #[test]
    fn detects_uhd_label_with_fhd_resolution() {
        let mismatches = check_label_mismatch("Movie UHD", &Resolution::FHD);
        assert_eq!(mismatches.len(), 1);
        assert!(mismatches[0].contains("Expected 4K"));
    }

    #[test]
    fn no_mismatch_for_correct_4k() {
        let mismatches = check_label_mismatch("Sports 4K", &Resolution::UHD);
        assert!(mismatches.is_empty());
    }

    #[test]
    fn detects_1080p_label_with_sd_resolution() {
        let mismatches = check_label_mismatch("HBO 1080p", &Resolution::SD);
        assert_eq!(mismatches.len(), 1);
        assert!(mismatches[0].contains("Expected 1080p"));
    }

    #[test]
    fn detects_fhd_label_with_hd_resolution() {
        let mismatches = check_label_mismatch("FHD Sports", &Resolution::HD);
        assert_eq!(mismatches.len(), 1);
        assert!(mismatches[0].contains("Expected 1080p"));
    }

    #[test]
    fn no_mismatch_for_correct_fhd() {
        let mismatches = check_label_mismatch("News FHD", &Resolution::FHD);
        assert!(mismatches.is_empty());
    }

    #[test]
    fn detects_hd_label_with_sd_resolution() {
        let mismatches = check_label_mismatch("CNN HD", &Resolution::SD);
        assert_eq!(mismatches.len(), 1);
        assert!(mismatches[0].contains("Expected 720p or 1080p"));
    }

    #[test]
    fn hd_label_accepts_720p() {
        let mismatches = check_label_mismatch("BBC HD", &Resolution::HD);
        assert!(mismatches.is_empty());
    }

    #[test]
    fn hd_label_accepts_1080p() {
        let mismatches = check_label_mismatch("Fox HD", &Resolution::FHD);
        assert!(mismatches.is_empty());
    }

    #[test]
    fn unlabeled_4k_channel_flagged() {
        let mismatches = check_label_mismatch("Sports Channel", &Resolution::UHD);
        assert_eq!(mismatches.len(), 1);
        assert!(mismatches[0].contains("not labeled"));
    }

    #[test]
    fn no_mismatch_for_unlabeled_sd() {
        let mismatches = check_label_mismatch("Basic Channel", &Resolution::SD);
        assert!(mismatches.is_empty());
    }

    #[test]
    fn hd_word_boundary_avoids_false_positive() {
        // "SHADOW" contains "HD" but not as a word boundary
        // Note: \bhd\b won't match inside "shadow" since 'h' follows 's'
        let mismatches = check_label_mismatch("Shadow TV", &Resolution::SD);
        assert!(mismatches.is_empty());
    }
}
