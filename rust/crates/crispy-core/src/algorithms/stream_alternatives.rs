//! Stream alternative ranking for failover.
//!
//! Given a target channel, ranks all channels from other
//! sources as potential failover alternatives using a
//! 6-tier confidence model weighted by stream health.

use std::collections::HashMap;
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

use super::normalize::normalize_name;
use crate::models::Channel;

// ── Confidence tiers ────────────────────────────────

const CONFIDENCE_EXACT_NAME: f64 = 1.0;
const CONFIDENCE_TVG_ID: f64 = 0.95;
const CONFIDENCE_EPG_PLUS_NAME: f64 = 0.90;
const CONFIDENCE_EPG_ONLY: f64 = 0.65;
const CONFIDENCE_CALL_SIGN: f64 = 0.60;
const CONFIDENCE_NORMALIZED_NAME: f64 = 0.50;

/// Weight of confidence in final score.
const WEIGHT_CONFIDENCE: f64 = 0.6;

/// Weight of health score in final score.
const WEIGHT_HEALTH: f64 = 0.4;

// ── Call sign regex ─────────────────────────────────

/// Matches US broadcast call signs in parentheses: (WABC), (KCBS)
static PAREN_CALL_SIGN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\(([WKOC][A-Za-z]{2,4})\)").unwrap());

/// Matches standalone US broadcast call signs as word boundaries
static STANDALONE_CALL_SIGN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\b([WK][A-Z]{2,4})\b").unwrap());

/// Tags to strip when normalizing channel names for matching.
static QUALITY_TAGS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(hd|sd|fhd|uhd|4k|hevc|h\.?265|h\.?264|720p?|1080[pi]?|2160p?)\b").unwrap()
});

/// Region/language tags to strip.
static REGION_TAGS: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(us|usa|uk|ca|east|west|pacific|central)\b").unwrap());

// ── Types ───────────────────────────────────────────

/// A ranked alternative stream for failover.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RankedAlternative {
    /// Channel ID of the alternative.
    pub channel_id: String,
    /// Stream URL of the alternative.
    pub stream_url: String,
    /// Source ID the alternative belongs to.
    pub source_id: String,
    /// Confidence of the match (0.0–1.0).
    pub confidence: f64,
    /// Health score of the stream (0.0–1.0).
    pub health_score: f64,
    /// Combined final score: confidence * 0.6 + health * 0.4.
    pub final_score: f64,
    /// Measured or estimated latency in milliseconds (None = unknown).
    pub latency_ms: Option<u64>,
}

// ── Public API ──────────────────────────────────────

/// Rank alternative streams for a target channel.
///
/// Priority order: user sticky → quality/confidence → health score → latency → global source order.
///
/// - `sticky_source_id`: if `Some`, the alternative from that source always sorts first,
///   provided it is present and not failed (health > 0.0). Skipped if unavailable.
/// - `health_scores`: keyed by URL hash (see `url_to_hash`).
/// - `latency_scores`: keyed by URL hash, value in milliseconds. `None` entries sort last.
pub fn rank_stream_alternatives(
    target: &Channel,
    all_channels: &[Channel],
    health_scores: &HashMap<String, f64>,
    latency_scores: &HashMap<String, u64>,
    sticky_source_id: Option<&str>,
) -> Vec<RankedAlternative> {
    let target_source = target.source_id.as_deref().unwrap_or("");
    let target_name_norm = normalize_for_matching(&target.name);
    let target_tvg_id = target.tvg_id.as_deref().unwrap_or("");
    let target_call_sign = extract_call_sign(&target.name);

    let mut alternatives = Vec::new();

    for ch in all_channels {
        // Skip same source
        let ch_source = ch.source_id.as_deref().unwrap_or("");
        if ch_source == target_source {
            continue;
        }

        // Skip self
        if ch.id == target.id {
            continue;
        }

        // Try matching in confidence order (highest first)
        let confidence = match_confidence(
            target,
            &target_name_norm,
            target_tvg_id,
            target_call_sign.as_deref(),
            ch,
        );

        if let Some(conf) = confidence {
            let url_hash = url_to_hash(&ch.stream_url);
            let health = health_scores.get(&url_hash).copied().unwrap_or(0.5);
            let latency_ms = latency_scores.get(&url_hash).copied();
            let final_score = conf * WEIGHT_CONFIDENCE + health * WEIGHT_HEALTH;

            alternatives.push(RankedAlternative {
                channel_id: ch.id.clone(),
                stream_url: ch.stream_url.clone(),
                source_id: ch_source.to_string(),
                confidence: conf,
                health_score: health,
                final_score,
                latency_ms,
            });
        }
    }

    alternatives.sort_by(|a, b| {
        // 1. Sticky source wins (only when health > 0.0 — not failed/unavailable).
        if let Some(sticky) = sticky_source_id {
            let a_sticky = a.source_id == sticky && a.health_score > 0.0;
            let b_sticky = b.source_id == sticky && b.health_score > 0.0;
            if a_sticky != b_sticky {
                return if a_sticky {
                    std::cmp::Ordering::Less
                } else {
                    std::cmp::Ordering::Greater
                };
            }
        }

        // 2. Higher final_score wins.
        b.final_score
            .partial_cmp(&a.final_score)
            .unwrap_or(std::cmp::Ordering::Equal)
            // 3. Lower latency wins (None sorts last).
            .then_with(|| match (a.latency_ms, b.latency_ms) {
                (Some(la), Some(lb)) => la.cmp(&lb),
                (Some(_), None) => std::cmp::Ordering::Less,
                (None, Some(_)) => std::cmp::Ordering::Greater,
                (None, None) => std::cmp::Ordering::Equal,
            })
    });

    alternatives
}

/// Rank alternatives and return as JSON string.
pub fn rank_stream_alternatives_json(
    target: &Channel,
    all_channels: &[Channel],
    health_scores: &HashMap<String, f64>,
    latency_scores: &HashMap<String, u64>,
    sticky_source_id: Option<&str>,
) -> String {
    let ranked = rank_stream_alternatives(
        target,
        all_channels,
        health_scores,
        latency_scores,
        sticky_source_id,
    );
    serde_json::to_string(&ranked).unwrap_or_else(|_| "[]".to_string())
}

/// Extract a US broadcast call sign from a channel name.
///
/// Checks for parenthesized form first: `(WABC)`, then
/// standalone word boundaries: `WABC`. Returns uppercase.
pub fn extract_call_sign(name: &str) -> Option<String> {
    // Check parenthesized form first
    if let Some(caps) = PAREN_CALL_SIGN.captures(name) {
        return Some(caps[1].to_uppercase());
    }
    // Check standalone form (uppercase the input first)
    let upper = name.to_uppercase();
    if let Some(caps) = STANDALONE_CALL_SIGN.captures(&upper) {
        return Some(caps[1].to_string());
    }
    None
}

// ── Private helpers ─────────────────────────────────

/// Normalize a channel name for fuzzy matching.
///
/// Strips quality tags (HD/SD/4K/etc.), region tags
/// (US/UK/East/West), then applies standard normalization.
pub(crate) fn normalize_for_matching(name: &str) -> String {
    let stripped = QUALITY_TAGS.replace_all(name, "");
    let stripped = REGION_TAGS.replace_all(&stripped, "");
    normalize_name(&stripped)
}

/// Simple hash of a URL for health score lookup.
///
/// Uses a fast FNV-like hash to create a hex string.
fn url_to_hash(url: &str) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut hasher = DefaultHasher::new();
    url.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

/// Determine the confidence tier for a candidate channel.
///
/// Returns the highest applicable confidence or `None`
/// if no match criteria are met.
fn match_confidence(
    target: &Channel,
    target_name_norm: &str,
    target_tvg_id: &str,
    target_call_sign: Option<&str>,
    candidate: &Channel,
) -> Option<f64> {
    // Tier 1: Exact name match
    if target.name == candidate.name {
        return Some(CONFIDENCE_EXACT_NAME);
    }

    // Tier 2: tvg_id match (non-empty)
    let cand_tvg_id = candidate.tvg_id.as_deref().unwrap_or("");
    if !target_tvg_id.is_empty() && !cand_tvg_id.is_empty() && target_tvg_id == cand_tvg_id {
        return Some(CONFIDENCE_TVG_ID);
    }

    let cand_name_norm = normalize_for_matching(&candidate.name);

    // Tier 3: EPG channel match + normalized name match
    if !target_tvg_id.is_empty() && !cand_tvg_id.is_empty() && target_name_norm == cand_name_norm {
        return Some(CONFIDENCE_EPG_PLUS_NAME);
    }

    // Tier 4: EPG channel only (same tvg_name if available)
    let target_tvg_name = target.tvg_name.as_deref().unwrap_or("");
    let cand_tvg_name = candidate.tvg_name.as_deref().unwrap_or("");
    if !target_tvg_name.is_empty() && !cand_tvg_name.is_empty() && target_tvg_name == cand_tvg_name
    {
        return Some(CONFIDENCE_EPG_ONLY);
    }

    // Tier 5: Call sign match
    if let Some(t_sign) = target_call_sign
        && let Some(c_sign) = extract_call_sign(&candidate.name)
        && t_sign == c_sign
    {
        return Some(CONFIDENCE_CALL_SIGN);
    }

    // Tier 6: Normalized name match
    if !target_name_norm.is_empty() && target_name_norm == cand_name_norm {
        return Some(CONFIDENCE_NORMALIZED_NAME);
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_ch(id: &str, name: &str, source: &str) -> Channel {
        Channel {
            id: id.to_string(),
            name: name.to_string(),
            stream_url: format!("http://example.com/{id}"),
            number: None,
            channel_group: None,
            logo_url: None,
            tvg_id: None,
            tvg_name: None,
            is_favorite: false,
            user_agent: None,
            has_catchup: false,
            catchup_days: 0,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: Some(source.to_string()),
            added_at: None,
            updated_at: None,
            is_247: false,
        }
    }

    #[test]
    fn extract_call_sign_parenthesized() {
        assert_eq!(extract_call_sign("CBS (WCBS)"), Some("WCBS".to_string()));
        assert_eq!(extract_call_sign("ABC (KABC)"), Some("KABC".to_string()));
    }

    #[test]
    fn extract_call_sign_standalone() {
        assert_eq!(extract_call_sign("WABC"), Some("WABC".to_string()));
        assert_eq!(extract_call_sign("KCBS HD"), Some("KCBS".to_string()));
    }

    #[test]
    fn extract_call_sign_none_for_non_broadcast() {
        assert_eq!(extract_call_sign("CNN"), None);
        assert_eq!(extract_call_sign("HBO"), None);
        assert_eq!(extract_call_sign("ESPN"), None);
    }

    #[test]
    fn exact_name_match_highest_confidence() {
        let target = make_ch("t1", "CNN HD", "src1");
        let mut candidate = make_ch("c1", "CNN HD", "src2");
        candidate.stream_url = "http://other.com/cnn".to_string();

        let alts = rank_stream_alternatives(
            &target,
            &[candidate],
            &HashMap::new(),
            &HashMap::new(),
            None,
        );
        assert_eq!(alts.len(), 1);
        assert!((alts[0].confidence - CONFIDENCE_EXACT_NAME).abs() < 0.001);
    }

    #[test]
    fn tvg_id_match() {
        let mut target = make_ch("t1", "CNN", "src1");
        target.tvg_id = Some("cnn.us".to_string());

        let mut candidate = make_ch("c1", "CNN International", "src2");
        candidate.tvg_id = Some("cnn.us".to_string());

        let alts = rank_stream_alternatives(
            &target,
            &[candidate],
            &HashMap::new(),
            &HashMap::new(),
            None,
        );
        assert_eq!(alts.len(), 1);
        assert!((alts[0].confidence - CONFIDENCE_TVG_ID).abs() < 0.001);
    }

    #[test]
    fn normalized_name_match_strips_quality_tags() {
        let target = make_ch("t1", "ESPN HD", "src1");
        let candidate = make_ch("c1", "ESPN FHD", "src2");

        let alts = rank_stream_alternatives(
            &target,
            &[candidate],
            &HashMap::new(),
            &HashMap::new(),
            None,
        );
        assert_eq!(alts.len(), 1);
        assert!((alts[0].confidence - CONFIDENCE_NORMALIZED_NAME).abs() < 0.001);
    }

    #[test]
    fn same_source_excluded() {
        let target = make_ch("t1", "CNN", "src1");
        let same_src = make_ch("c1", "CNN", "src1");

        let alts =
            rank_stream_alternatives(&target, &[same_src], &HashMap::new(), &HashMap::new(), None);
        assert!(alts.is_empty());
    }

    #[test]
    fn no_match_returns_empty() {
        let target = make_ch("t1", "CNN", "src1");
        let unrelated = make_ch("c1", "Discovery Channel", "src2");

        let alts = rank_stream_alternatives(
            &target,
            &[unrelated],
            &HashMap::new(),
            &HashMap::new(),
            None,
        );
        assert!(alts.is_empty());
    }

    #[test]
    fn health_score_affects_ranking() {
        let target = make_ch("t1", "CNN", "src1");
        let alt_a = make_ch("a1", "CNN", "src2");
        let alt_b = make_ch("b1", "CNN", "src3");

        let mut health = HashMap::new();
        let hash_a = url_to_hash(&alt_a.stream_url);
        let hash_b = url_to_hash(&alt_b.stream_url);
        health.insert(hash_a, 0.9); // alt_a is healthy
        health.insert(hash_b, 0.1); // alt_b is unhealthy

        let alts =
            rank_stream_alternatives(&target, &[alt_a, alt_b], &health, &HashMap::new(), None);
        assert_eq!(alts.len(), 2);
        // alt_a should rank higher due to better health
        assert!(alts[0].final_score > alts[1].final_score);
        assert!(alts[0].health_score > alts[1].health_score);
    }

    #[test]
    fn call_sign_match() {
        let target = make_ch("t1", "CBS (WCBS)", "src1");
        let candidate = make_ch("c1", "WCBS News", "src2");

        let alts = rank_stream_alternatives(
            &target,
            &[candidate],
            &HashMap::new(),
            &HashMap::new(),
            None,
        );
        assert_eq!(alts.len(), 1);
        assert!((alts[0].confidence - CONFIDENCE_CALL_SIGN).abs() < 0.001);
    }

    #[test]
    fn sorted_by_final_score_descending() {
        let target = make_ch("t1", "CNN", "src1");
        let alt_exact = make_ch("a1", "CNN", "src2");
        let mut alt_tvg = make_ch("b1", "CNN News", "src3");
        alt_tvg.tvg_id = Some("cnn.us".to_string());

        let mut target_with_tvg = target.clone();
        target_with_tvg.tvg_id = Some("cnn.us".to_string());

        let alts = rank_stream_alternatives(
            &target_with_tvg,
            &[alt_tvg, alt_exact],
            &HashMap::new(),
            &HashMap::new(),
            None,
        );
        assert!(alts.len() >= 2);
        // Higher confidence → higher final score (equal health)
        assert!(alts[0].final_score >= alts[1].final_score);
    }

    #[test]
    fn json_output_is_valid() {
        let target = make_ch("t1", "CNN", "src1");
        let alt = make_ch("a1", "CNN", "src2");

        let json =
            rank_stream_alternatives_json(&target, &[alt], &HashMap::new(), &HashMap::new(), None);
        let parsed: Vec<RankedAlternative> = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.len(), 1);
    }

    #[test]
    fn normalize_strips_quality_and_region() {
        assert_eq!(
            normalize_for_matching("CNN HD US"),
            normalize_for_matching("CNN")
        );
        assert_eq!(
            normalize_for_matching("ESPN FHD East"),
            normalize_for_matching("ESPN")
        );
    }

    #[test]
    fn test_sticky_source_wins_when_available() {
        let target = make_ch("t1", "CNN", "src1");
        // alt_a is from sticky source but lower confidence (normalized match only)
        let alt_a = make_ch("a1", "CNN", "src_sticky");
        // alt_b is from another source with same exact name match
        let alt_b = make_ch("b1", "CNN", "src_other");

        let alts = rank_stream_alternatives(
            &target,
            &[alt_b, alt_a],
            &HashMap::new(),
            &HashMap::new(),
            Some("src_sticky"),
        );
        assert!(!alts.is_empty());
        assert_eq!(alts[0].source_id, "src_sticky");
    }

    #[test]
    fn test_sticky_source_skipped_when_unavailable() {
        let target = make_ch("t1", "CNN", "src1");
        let alt_sticky = make_ch("a1", "CNN", "src_sticky");
        let alt_healthy = make_ch("b1", "CNN", "src_other");

        // Mark sticky source stream as failed (health = 0.0)
        let mut health = HashMap::new();
        health.insert(url_to_hash(&alt_sticky.stream_url), 0.0);
        health.insert(url_to_hash(&alt_healthy.stream_url), 0.9);

        let alts = rank_stream_alternatives(
            &target,
            &[alt_sticky, alt_healthy],
            &health,
            &HashMap::new(),
            Some("src_sticky"),
        );
        assert!(!alts.is_empty());
        // sticky source has health=0 so it is skipped in favour of healthy one
        assert_eq!(alts[0].source_id, "src_other");
    }

    #[test]
    fn test_lower_latency_preferred() {
        let target = make_ch("t1", "CNN", "src1");
        let alt_fast = make_ch("a1", "CNN", "src2");
        let alt_slow = make_ch("b1", "CNN", "src3");

        // Same health so final_score is equal — latency decides
        let mut latency = HashMap::new();
        latency.insert(url_to_hash(&alt_fast.stream_url), 50u64);
        latency.insert(url_to_hash(&alt_slow.stream_url), 500u64);

        let alts = rank_stream_alternatives(
            &target,
            &[alt_slow, alt_fast],
            &HashMap::new(),
            &latency,
            None,
        );
        assert_eq!(alts.len(), 2);
        assert_eq!(alts[0].latency_ms, Some(50));
        assert_eq!(alts[1].latency_ms, Some(500));
    }
}
