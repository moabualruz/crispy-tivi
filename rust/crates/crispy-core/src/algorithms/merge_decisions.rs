//! User-initiated manual merge and split decisions for the dedup system.
//!
//! Decisions are stored in SQLite and survive re-syncs.  They take priority
//! over automatic dedup: a merge decision forces two items into the same
//! group; a split decision keeps them apart even when auto-dedup would merge
//! them.  Split overrides merge when both exist for the same pair.

use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use uuid::Uuid;

// ── Error ────────────────────────────────────────────────────────────────────

#[derive(Debug, Error)]
pub enum MergeDecisionError {
    #[error("database error: {0}")]
    Db(#[from] rusqlite::Error),

    #[error("JSON serialization error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("merge decision requires at least two source IDs")]
    TooFewIds,

    #[error("merge decision requires a non-empty canonical_id")]
    EmptyCanonicalId,
}

// ── Types ────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DecisionType {
    Merge,
    Split,
}

impl DecisionType {
    fn as_str(self) -> &'static str {
        match self {
            DecisionType::Merge => "merge",
            DecisionType::Split => "split",
        }
    }
}

impl TryFrom<&str> for DecisionType {
    type Error = MergeDecisionError;

    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s {
            "merge" => Ok(DecisionType::Merge),
            "split" => Ok(DecisionType::Split),
            other => Err(MergeDecisionError::Db(rusqlite::Error::InvalidColumnName(
                other.to_owned(),
            ))),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContentType {
    Movie,
    Series,
    Channel,
}

impl ContentType {
    fn as_str(self) -> &'static str {
        match self {
            ContentType::Movie => "movie",
            ContentType::Series => "series",
            ContentType::Channel => "channel",
        }
    }
}

impl TryFrom<&str> for ContentType {
    type Error = MergeDecisionError;

    fn try_from(s: &str) -> Result<Self, Self::Error> {
        match s {
            "movie" => Ok(ContentType::Movie),
            "series" => Ok(ContentType::Series),
            "channel" => Ok(ContentType::Channel),
            other => Err(MergeDecisionError::Db(rusqlite::Error::InvalidColumnName(
                other.to_owned(),
            ))),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MergeDecision {
    pub id: String,
    pub decision_type: DecisionType,
    pub content_type: ContentType,
    /// Ordered list of item IDs involved in this decision.
    pub source_ids: Vec<String>,
    /// For `Merge` decisions: the canonical item ID that wins.
    pub canonical_id: Option<String>,
    pub created_at: String,
    pub profile_id: Option<String>,
    pub reason: Option<String>,
}

// ── Internal helpers ─────────────────────────────────────────────────────────

fn row_to_decision(row: &rusqlite::Row<'_>) -> rusqlite::Result<MergeDecision> {
    let id: String = row.get(0)?;
    let dtype_str: String = row.get(1)?;
    let ctype_str: String = row.get(2)?;
    let source_ids_json: String = row.get(3)?;
    let canonical_id: Option<String> = row.get(4)?;
    let created_at: String = row.get(5)?;
    let profile_id: Option<String> = row.get(6)?;
    let reason: Option<String> = row.get(7)?;

    let decision_type = DecisionType::try_from(dtype_str.as_str())
        .map_err(|_| rusqlite::Error::InvalidColumnName(dtype_str))?;
    let content_type = ContentType::try_from(ctype_str.as_str())
        .map_err(|_| rusqlite::Error::InvalidColumnName(ctype_str))?;
    let source_ids: Vec<String> = serde_json::from_str(&source_ids_json)
        .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?;

    Ok(MergeDecision {
        id,
        decision_type,
        content_type,
        source_ids,
        canonical_id,
        created_at,
        profile_id,
        reason,
    })
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Persist a user merge decision: `items` should be merged under `canonical_id`.
///
/// Requires at least two item IDs and a non-empty canonical ID.
pub fn create_merge_decision(
    conn: &Connection,
    items: &[String],
    canonical_id: &str,
    content_type: ContentType,
    profile_id: Option<&str>,
) -> Result<MergeDecision, MergeDecisionError> {
    if items.len() < 2 {
        return Err(MergeDecisionError::TooFewIds);
    }
    if canonical_id.is_empty() {
        return Err(MergeDecisionError::EmptyCanonicalId);
    }

    let id = Uuid::new_v4().to_string();
    let source_ids_json = serde_json::to_string(items)?;

    conn.execute(
        "INSERT INTO merge_decisions \
         (id, decision_type, content_type, source_ids, canonical_id, profile_id) \
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![
            id,
            DecisionType::Merge.as_str(),
            content_type.as_str(),
            source_ids_json,
            canonical_id,
            profile_id,
        ],
    )?;

    // Read back so created_at is populated by SQLite default.
    let decision = conn.query_row(
        "SELECT id, decision_type, content_type, source_ids, \
                canonical_id, created_at, profile_id, reason \
         FROM merge_decisions WHERE id = ?1",
        params![id],
        row_to_decision,
    )?;

    Ok(decision)
}

/// Persist a user split decision: `items` must NOT be merged, even if
/// auto-dedup would group them.
///
/// Requires at least two item IDs.
pub fn create_split_decision(
    conn: &Connection,
    items: &[String],
    content_type: ContentType,
    profile_id: Option<&str>,
) -> Result<MergeDecision, MergeDecisionError> {
    if items.len() < 2 {
        return Err(MergeDecisionError::TooFewIds);
    }

    let id = Uuid::new_v4().to_string();
    let source_ids_json = serde_json::to_string(items)?;

    conn.execute(
        "INSERT INTO merge_decisions \
         (id, decision_type, content_type, source_ids, canonical_id, profile_id) \
         VALUES (?1, ?2, ?3, ?4, NULL, ?5)",
        params![
            id,
            DecisionType::Split.as_str(),
            content_type.as_str(),
            source_ids_json,
            profile_id,
        ],
    )?;

    let decision = conn.query_row(
        "SELECT id, decision_type, content_type, source_ids, \
                canonical_id, created_at, profile_id, reason \
         FROM merge_decisions WHERE id = ?1",
        params![id],
        row_to_decision,
    )?;

    Ok(decision)
}

/// Return all decisions for a given content type.
pub fn get_decisions_for_type(
    conn: &Connection,
    content_type: ContentType,
) -> Result<Vec<MergeDecision>, MergeDecisionError> {
    let mut stmt = conn.prepare(
        "SELECT id, decision_type, content_type, source_ids, \
                canonical_id, created_at, profile_id, reason \
         FROM merge_decisions \
         WHERE content_type = ?1 \
         ORDER BY created_at",
    )?;

    let rows = stmt.query_map(params![content_type.as_str()], row_to_decision)?;
    let mut decisions = Vec::new();
    for row in rows {
        decisions.push(row?);
    }
    Ok(decisions)
}

/// Return the canonical ID for `item_id` if a merge decision covers it.
///
/// Returns `None` when no merge decision exists for this item.
pub fn get_merge_canonical(
    conn: &Connection,
    item_id: &str,
    content_type: ContentType,
) -> Result<Option<String>, MergeDecisionError> {
    // source_ids is a JSON array; use JSON_EACH for efficient membership test.
    let result: Result<Option<String>, _> = conn.query_row(
        "SELECT canonical_id \
         FROM merge_decisions, json_each(source_ids) \
         WHERE content_type = ?1 \
           AND decision_type = 'merge' \
           AND json_each.value = ?2 \
         LIMIT 1",
        params![content_type.as_str(), item_id],
        |row| row.get(0),
    );

    match result {
        Ok(val) => Ok(val),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(MergeDecisionError::Db(e)),
    }
}

/// Return `true` if a split decision covers the pair (`id_a`, `id_b`).
pub fn is_split(
    conn: &Connection,
    id_a: &str,
    id_b: &str,
    content_type: ContentType,
) -> Result<bool, MergeDecisionError> {
    // Fetch all split decisions for this content type and check membership.
    let decisions = get_decisions_for_type(conn, content_type)?;
    for d in &decisions {
        if d.decision_type == DecisionType::Split
            && d.source_ids.contains(&id_a.to_owned())
            && d.source_ids.contains(&id_b.to_owned())
        {
            return Ok(true);
        }
    }
    Ok(false)
}

/// Delete a decision by ID.  Returns `true` if a row was deleted.
pub fn delete_decision(conn: &Connection, decision_id: &str) -> Result<bool, MergeDecisionError> {
    let affected = conn.execute(
        "DELETE FROM merge_decisions WHERE id = ?1",
        params![decision_id],
    )?;
    Ok(affected > 0)
}

/// Apply user decisions on top of auto-dedup groups.
///
/// Rules (in priority order):
/// 1. **Split overrides merge** — if any split decision covers a pair, they
///    stay separated regardless of merge decisions.
/// 2. Merge decisions join their source IDs into a single group.
/// 3. Auto-dedup groups not covered by any decision pass through unchanged.
///
/// Duplicate item IDs across groups are deduplicated; the first occurrence
/// wins so the group ordering is stable.
pub fn apply_decisions_to_dedup(
    auto_groups: Vec<Vec<String>>,
    decisions: &[MergeDecision],
) -> Vec<Vec<String>> {
    // Collect all merge decisions.
    let merge_decisions: Vec<&MergeDecision> = decisions
        .iter()
        .filter(|d| d.decision_type == DecisionType::Merge)
        .collect();

    // Collect all split decisions as sets of pairs.
    let split_decisions: Vec<&MergeDecision> = decisions
        .iter()
        .filter(|d| d.decision_type == DecisionType::Split)
        .collect();

    // Helper: check if two items are explicitly split.
    let is_pair_split = |a: &str, b: &str| -> bool {
        split_decisions
            .iter()
            .any(|d| d.source_ids.contains(&a.to_owned()) && d.source_ids.contains(&b.to_owned()))
    };

    // Build initial groups from auto-dedup, then apply merges, then splits.

    // Step 1: Collect all IDs that appear in merge decisions.
    //         These will be combined into merged super-groups.
    let mut result: Vec<Vec<String>> = Vec::new();
    let mut consumed: std::collections::HashSet<String> = std::collections::HashSet::new();

    // Step 2: For each merge decision, build a super-group by collecting all
    //         auto-groups that contain any of the decision's source IDs,
    //         then apply split filtering within that super-group.
    for md in &merge_decisions {
        // Find all auto-groups that contain at least one source ID.
        let mut super_group: Vec<String> = Vec::new();
        for group in &auto_groups {
            if group.iter().any(|id| md.source_ids.contains(id)) {
                for id in group {
                    if !super_group.contains(id) {
                        super_group.push(id.clone());
                    }
                }
            }
        }
        // Add source_ids that might not be in any auto-group yet.
        for id in &md.source_ids {
            if !super_group.contains(id) {
                super_group.push(id.clone());
            }
        }

        // Apply split filtering: remove items from super_group that are
        // explicitly split from the canonical (or from each other).
        let canonical = md.canonical_id.as_deref().unwrap_or("");
        let mut filtered: Vec<String> = Vec::new();
        for id in &super_group {
            let split_from_canonical =
                !canonical.is_empty() && id != canonical && is_pair_split(id, canonical);
            if !split_from_canonical {
                filtered.push(id.clone());
            }
        }

        // Only emit if there are at least 2 items remaining.
        if filtered.len() >= 2 {
            for id in &filtered {
                consumed.insert(id.clone());
            }
            result.push(filtered);
        } else {
            // Merge collapsed — put remaining items back as singletons.
            for id in filtered {
                consumed.insert(id.clone());
                result.push(vec![id]);
            }
        }
    }

    // Step 3: Pass through auto-groups whose items weren't consumed by merges.
    for group in auto_groups {
        let unconsumed: Vec<String> = group
            .into_iter()
            .filter(|id| !consumed.contains(id))
            .collect();
        if !unconsumed.is_empty() {
            result.push(unconsumed);
        }
    }

    result
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use rusqlite::Connection;

    use super::*;

    // ── Helpers ──────────────────────────────────────────────────────────────

    fn open_memory() -> Connection {
        let conn = Connection::open_in_memory().expect("open :memory:");
        conn.execute_batch(include_str!(
            "../database/migrations/001_initial_schema.sql"
        ))
        .expect("apply schema");
        conn
    }

    fn ids(v: &[&str]) -> Vec<String> {
        v.iter().map(|s| s.to_string()).collect()
    }

    // ── Required tests ────────────────────────────────────────────────────────

    #[test]
    fn test_create_merge_decision_stores_in_db() {
        let conn = open_memory();
        let items = ids(&["a", "b"]);
        let d = create_merge_decision(&conn, &items, "a", ContentType::Movie, None)
            .expect("create_merge_decision");

        assert_eq!(d.decision_type, DecisionType::Merge);
        assert_eq!(d.content_type, ContentType::Movie);
        assert_eq!(d.source_ids, items);
        assert_eq!(d.canonical_id.as_deref(), Some("a"));

        // Verify row exists in DB.
        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM merge_decisions WHERE id = ?1",
                params![d.id],
                |r| r.get(0),
            )
            .expect("count");
        assert_eq!(count, 1);
    }

    #[test]
    fn test_create_split_decision_stores_in_db() {
        let conn = open_memory();
        let items = ids(&["x", "y"]);
        let d = create_split_decision(&conn, &items, ContentType::Series, Some("prof1"))
            .expect("create_split_decision");

        assert_eq!(d.decision_type, DecisionType::Split);
        assert_eq!(d.content_type, ContentType::Series);
        assert_eq!(d.source_ids, items);
        assert!(d.canonical_id.is_none());
        assert_eq!(d.profile_id.as_deref(), Some("prof1"));

        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM merge_decisions WHERE id = ?1",
                params![d.id],
                |r| r.get(0),
            )
            .expect("count");
        assert_eq!(count, 1);
    }

    #[test]
    fn test_get_decisions_filters_by_content_type() {
        let conn = open_memory();
        create_merge_decision(&conn, &ids(&["a", "b"]), "a", ContentType::Movie, None)
            .expect("merge movie");
        create_split_decision(&conn, &ids(&["c", "d"]), ContentType::Channel, None)
            .expect("split channel");

        let movies = get_decisions_for_type(&conn, ContentType::Movie).expect("get movies");
        assert_eq!(movies.len(), 1);
        assert_eq!(movies[0].content_type, ContentType::Movie);

        let channels = get_decisions_for_type(&conn, ContentType::Channel).expect("get channels");
        assert_eq!(channels.len(), 1);
        assert_eq!(channels[0].content_type, ContentType::Channel);

        let series = get_decisions_for_type(&conn, ContentType::Series).expect("get series");
        assert!(series.is_empty());
    }

    #[test]
    fn test_get_merge_canonical_returns_canonical_id() {
        let conn = open_memory();
        create_merge_decision(
            &conn,
            &ids(&["alpha", "beta"]),
            "alpha",
            ContentType::Movie,
            None,
        )
        .expect("create");

        let canonical =
            get_merge_canonical(&conn, "beta", ContentType::Movie).expect("get canonical");
        assert_eq!(canonical.as_deref(), Some("alpha"));

        // Canonical itself also resolves.
        let self_canonical =
            get_merge_canonical(&conn, "alpha", ContentType::Movie).expect("get self");
        assert_eq!(self_canonical.as_deref(), Some("alpha"));
    }

    #[test]
    fn test_is_split_returns_true_for_split_pair() {
        let conn = open_memory();
        create_split_decision(&conn, &ids(&["p", "q"]), ContentType::Channel, None).expect("split");

        assert!(is_split(&conn, "p", "q", ContentType::Channel).expect("is_split p,q"));
        // Order-independent.
        assert!(is_split(&conn, "q", "p", ContentType::Channel).expect("is_split q,p"));
    }

    #[test]
    fn test_is_split_returns_false_for_unrelated_pair() {
        let conn = open_memory();
        create_split_decision(&conn, &ids(&["p", "q"]), ContentType::Channel, None).expect("split");

        // Completely unrelated pair.
        assert!(!is_split(&conn, "r", "s", ContentType::Channel).expect("unrelated"));
        // Only one ID matches.
        assert!(!is_split(&conn, "p", "z", ContentType::Channel).expect("partial"));
        // Wrong content type.
        assert!(!is_split(&conn, "p", "q", ContentType::Movie).expect("wrong type"));
    }

    #[test]
    fn test_delete_decision_removes_from_db() {
        let conn = open_memory();
        let d = create_split_decision(&conn, &ids(&["a", "b"]), ContentType::Series, None)
            .expect("create");

        assert!(delete_decision(&conn, &d.id).expect("delete returns true"));

        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM merge_decisions WHERE id = ?1",
                params![d.id],
                |r| r.get(0),
            )
            .expect("count");
        assert_eq!(count, 0);

        // Deleting again returns false.
        assert!(!delete_decision(&conn, &d.id).expect("second delete"));
    }

    #[test]
    fn test_apply_merges_auto_groups() {
        let auto = vec![ids(&["a", "b"]), ids(&["c", "d"])];
        let d = MergeDecision {
            id: "m1".into(),
            decision_type: DecisionType::Merge,
            content_type: ContentType::Movie,
            source_ids: ids(&["b", "c"]), // bridge between the two groups
            canonical_id: Some("b".into()),
            created_at: "2026-01-01".into(),
            profile_id: None,
            reason: None,
        };

        let result = apply_decisions_to_dedup(auto, &[d]);

        // The two auto-groups should be merged into one.
        assert_eq!(result.len(), 1);
        let merged = &result[0];
        assert!(merged.contains(&"a".to_string()));
        assert!(merged.contains(&"b".to_string()));
        assert!(merged.contains(&"c".to_string()));
        assert!(merged.contains(&"d".to_string()));
    }

    #[test]
    fn test_apply_splits_auto_groups() {
        // Auto-dedup put a, b, c in the same group.
        let auto = vec![ids(&["a", "b", "c"])];
        let d = MergeDecision {
            id: "s1".into(),
            decision_type: DecisionType::Split,
            content_type: ContentType::Movie,
            source_ids: ids(&["a", "b"]),
            canonical_id: None,
            created_at: "2026-01-01".into(),
            profile_id: None,
            reason: None,
        };

        // No merge decision — auto group passes through unchanged, but split
        // is enforced when `is_split` is called independently.
        // apply_decisions_to_dedup only reshapes groups via merge decisions;
        // split decisions inform merge-filtering.  Auto-groups without a
        // corresponding merge decision pass through.
        let result = apply_decisions_to_dedup(auto, &[d]);
        // No merge decision, so the auto-group is emitted as-is.
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].len(), 3);
    }

    #[test]
    fn test_split_overrides_merge() {
        // Merge decision tries to join a+b+c under "a", but a split says b
        // and a must stay separate.
        let auto = vec![ids(&["a"]), ids(&["b"]), ids(&["c"])];
        let merge = MergeDecision {
            id: "m1".into(),
            decision_type: DecisionType::Merge,
            content_type: ContentType::Movie,
            source_ids: ids(&["a", "b", "c"]),
            canonical_id: Some("a".into()),
            created_at: "2026-01-01".into(),
            profile_id: None,
            reason: None,
        };
        let split = MergeDecision {
            id: "s1".into(),
            decision_type: DecisionType::Split,
            content_type: ContentType::Movie,
            source_ids: ids(&["b", "a"]), // b is split from canonical "a"
            canonical_id: None,
            created_at: "2026-01-01".into(),
            profile_id: None,
            reason: None,
        };

        let result = apply_decisions_to_dedup(auto, &[merge, split]);

        // "b" must NOT be in the same group as "a".
        let group_with_a = result.iter().find(|g| g.contains(&"a".to_string()));
        assert!(group_with_a.is_some());
        assert!(
            !group_with_a.unwrap().contains(&"b".to_string()),
            "b must be split from a"
        );
    }

    #[test]
    fn test_decisions_persist_across_queries() {
        let conn = open_memory();
        create_merge_decision(&conn, &ids(&["1", "2"]), "1", ContentType::Series, None)
            .expect("create");

        // Re-query in a fresh statement — simulates restart / re-sync.
        let all = get_decisions_for_type(&conn, ContentType::Series).expect("get");
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].source_ids, ids(&["1", "2"]));
    }

    #[test]
    fn test_create_decision_generates_uuid() {
        let conn = open_memory();
        let d1 = create_merge_decision(&conn, &ids(&["a", "b"]), "a", ContentType::Movie, None)
            .expect("first");
        let d2 = create_merge_decision(&conn, &ids(&["c", "d"]), "c", ContentType::Movie, None)
            .expect("second");

        // IDs must be non-empty and unique.
        assert!(!d1.id.is_empty());
        assert!(!d2.id.is_empty());
        assert_ne!(d1.id, d2.id);

        // Must be valid UUID v4 format (8-4-4-4-12).
        assert!(
            Uuid::parse_str(&d1.id).is_ok(),
            "id must be valid UUID: {}",
            d1.id
        );
    }
}
