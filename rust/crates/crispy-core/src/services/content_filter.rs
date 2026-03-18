//! Content blocking logic for parental controls.
//!
//! Supports four blocking modes:
//! 1. Per-channel block (by `channel_id`)
//! 2. Per-VOD-title block (by `vod_item_id`)
//! 3. Per-genre block (list of blocked genre strings, case-insensitive)
//! 4. Keyword scan on title + description
//!
//! Allow-list mode (youngest profiles): only explicitly approved content is
//! visible; everything else is blocked.

use std::collections::HashSet;

// ── ContentItem ───────────────────────────────────────────────────────────────

/// Minimal content descriptor passed to the filter.
#[derive(Debug, Clone)]
pub struct ContentItem {
    /// Unique channel ID (None for pure VOD items).
    pub channel_id: Option<String>,
    /// Unique VOD item ID (None for live channels).
    pub vod_item_id: Option<String>,
    /// Genre / category list (e.g. `["Action", "Drama"]`).
    pub genres: Vec<String>,
    /// Display title used for keyword scanning.
    pub title: String,
    /// Optional description / synopsis used for keyword scanning.
    pub description: Option<String>,
}

// ── ProfileContentPolicy ──────────────────────────────────────────────────────

/// Per-profile content filtering policy.
#[derive(Debug, Clone, Default)]
pub struct ProfileContentPolicy {
    /// Explicitly blocked channel IDs.
    pub blocked_channel_ids: HashSet<String>,
    /// Explicitly blocked VOD item IDs.
    pub blocked_vod_ids: HashSet<String>,
    /// Blocked genre strings (stored lowercase for case-insensitive matching).
    pub blocked_genres: HashSet<String>,
    /// Keywords whose presence in title/description blocks the item.
    pub blocked_keywords: Vec<String>,
    /// If `true`, only `allowed_channel_ids` / `allowed_vod_ids` are visible.
    pub allow_list_mode: bool,
    /// Explicitly allowed channel IDs (used only when `allow_list_mode = true`).
    pub allowed_channel_ids: HashSet<String>,
    /// Explicitly allowed VOD item IDs (used only when `allow_list_mode = true`).
    pub allowed_vod_ids: HashSet<String>,
}

impl ProfileContentPolicy {
    /// Create an empty (permissive) policy.
    pub fn new() -> Self {
        Self::default()
    }
}

// ── is_blocked ────────────────────────────────────────────────────────────────

/// Return `true` if `content` should be hidden for a profile with `policy`.
pub fn is_blocked(content: &ContentItem, policy: &ProfileContentPolicy) -> bool {
    // ── Allow-list mode ───────────────────────────────────────────────────────
    if policy.allow_list_mode {
        let channel_allowed = content
            .channel_id
            .as_ref()
            .map(|id| policy.allowed_channel_ids.contains(id.as_str()))
            .unwrap_or(false);
        let vod_allowed = content
            .vod_item_id
            .as_ref()
            .map(|id| policy.allowed_vod_ids.contains(id.as_str()))
            .unwrap_or(false);
        // In allow-list mode, block unless at least one ID is explicitly allowed
        return !(channel_allowed || vod_allowed);
    }

    // ── Per-channel block ─────────────────────────────────────────────────────
    if let Some(ch_id) = &content.channel_id {
        if policy.blocked_channel_ids.contains(ch_id.as_str()) {
            return true;
        }
    }

    // ── Per-VOD block ─────────────────────────────────────────────────────────
    if let Some(vod_id) = &content.vod_item_id {
        if policy.blocked_vod_ids.contains(vod_id.as_str()) {
            return true;
        }
    }

    // ── Per-genre block (case-insensitive both sides) ─────────────────────────
    for genre in &content.genres {
        let genre_lower = genre.to_ascii_lowercase();
        if policy
            .blocked_genres
            .iter()
            .any(|blocked| blocked.to_ascii_lowercase() == genre_lower)
        {
            return true;
        }
    }

    // ── Keyword scan ──────────────────────────────────────────────────────────
    let searchable = format!(
        "{} {}",
        content.title.to_ascii_lowercase(),
        content
            .description
            .as_deref()
            .unwrap_or("")
            .to_ascii_lowercase()
    );
    for kw in &policy.blocked_keywords {
        if searchable.contains(kw.to_ascii_lowercase().as_str()) {
            return true;
        }
    }

    false
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn make_channel(id: &str, genres: &[&str], title: &str) -> ContentItem {
        ContentItem {
            channel_id: Some(id.to_string()),
            vod_item_id: None,
            genres: genres.iter().map(|s| s.to_string()).collect(),
            title: title.to_string(),
            description: None,
        }
    }

    fn make_vod(id: &str, genres: &[&str], title: &str, desc: Option<&str>) -> ContentItem {
        ContentItem {
            channel_id: None,
            vod_item_id: Some(id.to_string()),
            genres: genres.iter().map(|s| s.to_string()).collect(),
            title: title.to_string(),
            description: desc.map(str::to_string),
        }
    }

    #[test]
    fn test_empty_policy_nothing_blocked() {
        let policy = ProfileContentPolicy::new();
        let item = make_channel("ch1", &["News"], "CNN");
        assert!(!is_blocked(&item, &policy));
    }

    #[test]
    fn test_blocked_channel_id() {
        let mut policy = ProfileContentPolicy::new();
        policy.blocked_channel_ids.insert("adult-ch".to_string());
        let item = make_channel("adult-ch", &[], "Bad Channel");
        assert!(is_blocked(&item, &policy));
    }

    #[test]
    fn test_unblocked_channel_passes() {
        let mut policy = ProfileContentPolicy::new();
        policy.blocked_channel_ids.insert("adult-ch".to_string());
        let item = make_channel("kids-ch", &[], "Kids Channel");
        assert!(!is_blocked(&item, &policy));
    }

    #[test]
    fn test_blocked_vod_id() {
        let mut policy = ProfileContentPolicy::new();
        policy.blocked_vod_ids.insert("vod-123".to_string());
        let item = make_vod("vod-123", &[], "Violent Movie", None);
        assert!(is_blocked(&item, &policy));
    }

    #[test]
    fn test_blocked_genre_case_insensitive() {
        let mut policy = ProfileContentPolicy::new();
        policy.blocked_genres.insert("adult".to_string());
        let item = make_vod("v1", &["Adult", "Drama"], "Title", None);
        assert!(is_blocked(&item, &policy));
    }

    #[test]
    fn test_blocked_genre_different_case_in_policy() {
        let mut policy = ProfileContentPolicy::new();
        policy.blocked_genres.insert("HORROR".to_string());
        let item = make_vod("v1", &["horror"], "Scary Movie", None);
        assert!(is_blocked(&item, &policy));
    }

    #[test]
    fn test_keyword_in_title_blocked() {
        let mut policy = ProfileContentPolicy::new();
        policy.blocked_keywords.push("explicit".to_string());
        let item = make_channel("ch1", &[], "Explicit Content Channel");
        assert!(is_blocked(&item, &policy));
    }

    #[test]
    fn test_keyword_in_description_blocked() {
        let mut policy = ProfileContentPolicy::new();
        policy.blocked_keywords.push("violence".to_string());
        let item = ContentItem {
            channel_id: None,
            vod_item_id: Some("v1".to_string()),
            genres: vec![],
            title: "Action Film".to_string(),
            description: Some("Contains intense violence and gore".to_string()),
        };
        assert!(is_blocked(&item, &policy));
    }

    #[test]
    fn test_keyword_not_present_passes() {
        let mut policy = ProfileContentPolicy::new();
        policy.blocked_keywords.push("violence".to_string());
        let item = make_channel("ch1", &[], "Family Friendly Show");
        assert!(!is_blocked(&item, &policy));
    }

    #[test]
    fn test_allow_list_mode_blocks_unrecognised() {
        let mut policy = ProfileContentPolicy::new();
        policy.allow_list_mode = true;
        policy.allowed_channel_ids.insert("safe-ch".to_string());

        let safe = make_channel("safe-ch", &[], "Safe Channel");
        let unknown = make_channel("unknown-ch", &[], "Unknown Channel");

        assert!(!is_blocked(&safe, &policy));
        assert!(is_blocked(&unknown, &policy));
    }

    #[test]
    fn test_allow_list_mode_vod() {
        let mut policy = ProfileContentPolicy::new();
        policy.allow_list_mode = true;
        policy.allowed_vod_ids.insert("approved-vod".to_string());

        let approved = make_vod("approved-vod", &[], "Approved Film", None);
        let random = make_vod("random-vod", &[], "Random Film", None);

        assert!(!is_blocked(&approved, &policy));
        assert!(is_blocked(&random, &policy));
    }

    #[test]
    fn test_allow_list_mode_empty_allowlist_blocks_all() {
        let mut policy = ProfileContentPolicy::new();
        policy.allow_list_mode = true;
        // No IDs in allowlist
        let item = make_channel("ch1", &[], "Any Channel");
        assert!(is_blocked(&item, &policy));
    }
}
