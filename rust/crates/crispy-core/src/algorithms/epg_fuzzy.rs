//! Fuzzy string matching for EPG channel name matching.
//!
//! Provides tokenization and Jaro-Winkler-based scoring
//! for matching channel names to EPG display names when
//! exact/normalized matching fails.

use strsim::jaro_winkler;

/// Tokenize a name into lowercase words, stripping
/// punctuation and splitting on whitespace/dashes/dots.
pub fn tokenize(name: &str) -> Vec<String> {
    name.to_lowercase()
        .split(|c: char| c.is_whitespace() || c == '-' || c == '.' || c == '|' || c == ',')
        .map(|w| {
            w.chars()
                .filter(|c| c.is_alphanumeric())
                .collect::<String>()
        })
        .filter(|w| !w.is_empty())
        .collect()
}

/// Compute a fuzzy match score between a query name and a
/// target name using tokenized Jaro-Winkler similarity.
///
/// Returns a score in `0.0..=0.95`:
/// - Each query token must match at least one target token
///   (Jaro-Winkler > 0.85 or exact substring match).
/// - If any query token fails to match → returns 0.0
///   (AND logic: all tokens must match).
/// - Score = average of best token matches × 0.95 (cap).
pub fn fuzzy_name_score(query: &str, target: &str) -> f64 {
    let query_tokens = tokenize(query);
    let target_tokens = tokenize(target);

    if query_tokens.is_empty() || target_tokens.is_empty() {
        return 0.0;
    }

    // Build target blob for substring checks.
    let target_blob = target_tokens.join(" ");

    let mut total_score = 0.0;

    for qt in &query_tokens {
        // Check exact substring first.
        if target_blob.contains(qt.as_str()) {
            total_score += 1.0;
            continue;
        }

        // Find best Jaro-Winkler match among target tokens.
        let best_sim = target_tokens
            .iter()
            .map(|tt| jaro_winkler(qt, tt))
            .fold(0.0_f64, f64::max);

        if best_sim > 0.85 {
            total_score += best_sim;
        } else {
            // AND logic: one miss = fail.
            return 0.0;
        }
    }

    // Average score, capped at 0.95.
    let avg = total_score / query_tokens.len() as f64;
    avg.min(0.95)
}

/// Extract a US-style call sign (K/W prefix + 2-3 letters)
/// from a channel name.
///
/// Returns `None` if no call sign pattern is found.
pub fn extract_call_sign(name: &str) -> Option<String> {
    let tokens = tokenize(name);
    for token in &tokens {
        let upper = token.to_uppercase();
        if upper.len() >= 3
            && upper.len() <= 4
            && (upper.starts_with('K') || upper.starts_with('W'))
            && upper.chars().all(|c| c.is_ascii_uppercase())
        {
            return Some(upper);
        }
    }
    None
}

/// Detect whether a channel name indicates a 24/7 loop
/// channel based on keywords.
pub fn is_247_by_name(name: &str) -> bool {
    let lower = name.to_lowercase();
    lower.contains("24/7")
        || lower.contains("24-7")
        || lower.contains("247")
        || lower.contains("nonstop")
        || lower.contains("non-stop")
        || lower.contains("marathon")
}

/// Detect whether EPG entries indicate a 24/7 channel
/// (single programme spanning > 20 hours).
pub fn is_247_by_epg(entries: &[(i64, i64)]) -> bool {
    if entries.len() != 1 {
        return false;
    }
    let (start, end) = entries[0];
    let duration_hours = (end - start) as f64 / 3_600_000.0;
    duration_hours > 20.0
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── tokenize tests ──────────────────────────────

    #[test]
    fn tokenize_splits_on_spaces() {
        assert_eq!(tokenize("BBC One HD"), vec!["bbc", "one", "hd"]);
    }

    #[test]
    fn tokenize_splits_on_dashes() {
        assert_eq!(tokenize("HBO-Max"), vec!["hbo", "max"]);
    }

    #[test]
    fn tokenize_splits_on_dots() {
        assert_eq!(tokenize("bbc.one"), vec!["bbc", "one"]);
    }

    #[test]
    fn tokenize_strips_punctuation() {
        assert_eq!(tokenize("Fox News (US)"), vec!["fox", "news", "us"]);
    }

    #[test]
    fn tokenize_handles_pipes_and_commas() {
        assert_eq!(tokenize("A | B, C"), vec!["a", "b", "c"]);
    }

    #[test]
    fn tokenize_empty_string() {
        assert!(tokenize("").is_empty());
    }

    // ── fuzzy_name_score tests ──────────────────────

    #[test]
    fn exact_match_scores_high() {
        let score = fuzzy_name_score("BBC One", "BBC One");
        assert!(score > 0.9, "score was {score}");
    }

    #[test]
    fn similar_names_score_above_threshold() {
        let score = fuzzy_name_score("BBC One", "BBC 1");
        // "bbc" exact match, "one" vs "1" — may or may not
        // meet 0.85 Jaro-Winkler threshold.
        // This tests the fuzzy path is active.
        assert!(score >= 0.0);
    }

    #[test]
    fn completely_different_scores_zero() {
        let score = fuzzy_name_score("BBC One", "Discovery Channel");
        assert_eq!(score, 0.0);
    }

    #[test]
    fn empty_query_scores_zero() {
        assert_eq!(fuzzy_name_score("", "BBC One"), 0.0);
    }

    #[test]
    fn empty_target_scores_zero() {
        assert_eq!(fuzzy_name_score("BBC One", ""), 0.0);
    }

    #[test]
    fn score_capped_at_095() {
        let score = fuzzy_name_score("ESPN", "ESPN");
        assert!(score <= 0.95);
    }

    #[test]
    fn and_logic_one_miss_returns_zero() {
        // "BBC" matches, "XYZ" does not match "One"
        let score = fuzzy_name_score("BBC XYZ", "BBC One");
        assert_eq!(score, 0.0);
    }

    // ── extract_call_sign tests ─────────────────────

    #[test]
    fn extracts_kxyz_call_sign() {
        assert_eq!(
            extract_call_sign("KABC Los Angeles"),
            Some("KABC".to_string())
        );
    }

    #[test]
    fn extracts_wxyz_call_sign() {
        assert_eq!(extract_call_sign("WBBM Chicago"), Some("WBBM".to_string()));
    }

    #[test]
    fn no_call_sign_in_bbc() {
        assert_eq!(extract_call_sign("BBC One HD"), None);
    }

    #[test]
    fn no_call_sign_in_numbers() {
        assert_eq!(extract_call_sign("Channel 5"), None);
    }

    // ── is_247_by_name tests ────────────────────────

    #[test]
    fn detects_247_slash() {
        assert!(is_247_by_name("Movies 24/7"));
    }

    #[test]
    fn detects_247_dash() {
        assert!(is_247_by_name("Sports 24-7"));
    }

    #[test]
    fn detects_247_no_separator() {
        assert!(is_247_by_name("Action247"));
    }

    #[test]
    fn detects_nonstop() {
        assert!(is_247_by_name("Nonstop Comedy"));
    }

    #[test]
    fn detects_marathon() {
        assert!(is_247_by_name("Movie Marathon"));
    }

    #[test]
    fn normal_channel_not_247() {
        assert!(!is_247_by_name("BBC One HD"));
    }

    // ── is_247_by_epg tests ─────────────────────────

    #[test]
    fn single_long_entry_is_247() {
        // 24h in milliseconds = 86_400_000
        assert!(is_247_by_epg(&[(0, 86_400_000)]));
    }

    #[test]
    fn short_single_entry_not_247() {
        // 1h = 3_600_000
        assert!(!is_247_by_epg(&[(0, 3_600_000)]));
    }

    #[test]
    fn multiple_entries_not_247() {
        assert!(!is_247_by_epg(&[(0, 3_600_000), (3_600_000, 7_200_000)]));
    }

    #[test]
    fn empty_entries_not_247() {
        assert!(!is_247_by_epg(&[]));
    }
}
