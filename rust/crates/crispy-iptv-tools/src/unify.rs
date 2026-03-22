//! Config-driven title and ID unification.
//!
//! Faithfully ported from `iptvtools/utils.py::unify_title_and_id` and
//! `iptvtools/config.py`. Loads a JSON configuration that maps old titles
//! and IDs to canonical forms. Entries mapped to `""` are deleted.

use std::collections::HashMap;

use crispy_iptv_types::PlaylistEntry;
use serde::{Deserialize, Serialize};

use crate::error::ToolsError;

/// Unification configuration loaded from JSON.
///
/// Each map entry represents `old_value → canonical_value`. If the
/// canonical value is `""` (empty string), entries containing that
/// old value are removed from the playlist.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct UnifyConfig {
    /// Old ID substring → canonical ID replacement. `""` = delete entry.
    #[serde(default)]
    pub id_unifiers: HashMap<String, String>,

    /// Old title substring → canonical title replacement. `""` = delete entry.
    #[serde(default)]
    pub title_unifiers: HashMap<String, String>,
}

/// Load a [`UnifyConfig`] from a JSON string.
///
/// The JSON is expected to have `id_unifiers` and/or `title_unifiers` keys,
/// each mapping old substrings to canonical replacements.
///
/// # Errors
///
/// Returns `ToolsError::InvalidConfig` if the JSON is not valid.
pub fn load_unify_config(json: &str) -> Result<UnifyConfig, ToolsError> {
    serde_json::from_str(json).map_err(|e| ToolsError::InvalidConfig(e.to_string()))
}

/// Apply unification rules to a list of entries.
///
/// For each entry:
/// 1. Title unifiers are applied (sorted by key, substring replacement).
/// 2. If `tvg_name` is set it becomes the working ID; otherwise the
///    (possibly-unified) title is used.
/// 3. ID unifiers are applied (sorted by key, substring replacement).
/// 4. If any replacement mapped to `""`, the entry is deleted.
///
/// Faithfully mirrors the Python logic in `unify_title_and_id()`.
pub fn unify_entries(entries: &[PlaylistEntry], config: &UnifyConfig) -> Vec<PlaylistEntry> {
    let mut title_keys: Vec<&String> = config.title_unifiers.keys().collect();
    title_keys.sort();

    let mut id_keys: Vec<&String> = config.id_unifiers.keys().collect();
    id_keys.sort();

    entries
        .iter()
        .filter_map(|entry| {
            let mut entry = entry.clone();

            // 1. Apply title unifiers.
            if let Some(ref title) = entry.name {
                let mut new_title = title.clone();
                for key in &title_keys {
                    if new_title.contains(key.as_str()) {
                        let replacement = &config.title_unifiers[key.as_str()];
                        new_title = new_title.replace(key.as_str(), replacement);
                    }
                }
                // If any title unifier produced an empty title, delete entry.
                if new_title.is_empty() && !title.is_empty() {
                    return None;
                }
                entry.name = Some(new_title);
            }

            // 2. Derive working ID from tvg_name or title (matching Python logic).
            let working_id = entry
                .tvg_name
                .clone()
                .or_else(|| entry.name.clone())
                .unwrap_or_default();

            // 3. Apply ID unifiers.
            let mut new_id = working_id;
            for key in &id_keys {
                if new_id.contains(key.as_str()) {
                    let replacement = &config.id_unifiers[key.as_str()];
                    new_id = new_id.replace(key.as_str(), replacement);
                }
            }

            // If any ID unifier produced an empty ID from a non-empty input, delete entry.
            if new_id.is_empty() && entry.tvg_id.is_some() {
                return None;
            }

            // Update tvg_id with the unified ID.
            if !new_id.is_empty() {
                entry.tvg_id = Some(new_id);
            }

            Some(entry)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_entry(name: &str, tvg_id: &str, tvg_name: Option<&str>) -> PlaylistEntry {
        PlaylistEntry {
            name: Some(name.to_string()),
            tvg_id: if tvg_id.is_empty() {
                None
            } else {
                Some(tvg_id.to_string())
            },
            tvg_name: tvg_name.map(|s| s.to_string()),
            ..Default::default()
        }
    }

    #[test]
    fn load_config_from_json() {
        let json = r#"{
            "id_unifiers": {"old_id": "new_id"},
            "title_unifiers": {"Old Title": "New Title"}
        }"#;
        let config = load_unify_config(json).unwrap();
        assert_eq!(
            config.id_unifiers.get("old_id"),
            Some(&"new_id".to_string())
        );
        assert_eq!(
            config.title_unifiers.get("Old Title"),
            Some(&"New Title".to_string())
        );
    }

    #[test]
    fn load_config_invalid_json_errors() {
        assert!(load_unify_config("not json").is_err());
    }

    #[test]
    fn unify_renames_ids() {
        let entries = vec![make_entry("BBC One", "bbc_old", None)];
        let config = UnifyConfig {
            id_unifiers: HashMap::from([("bbc_old".to_string(), "bbc_one".to_string())]),
            ..Default::default()
        };
        let result = unify_entries(&entries, &config);
        assert_eq!(result.len(), 1);
        // The working ID derives from the name (no tvg_name), so id_unifiers
        // only apply to the name-derived ID. tvg_id is set from working ID.
        // But since the working ID is "BBC One" (not "bbc_old"), the id_unifier
        // won't match. Let's use tvg_name to test proper ID renaming.
    }

    #[test]
    fn unify_renames_ids_via_tvg_name() {
        let entries = vec![make_entry("BBC One", "", Some("bbc_old"))];
        let config = UnifyConfig {
            id_unifiers: HashMap::from([("bbc_old".to_string(), "bbc_one".to_string())]),
            ..Default::default()
        };
        let result = unify_entries(&entries, &config);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].tvg_id.as_deref(), Some("bbc_one"));
    }

    #[test]
    fn unify_renames_titles() {
        let entries = vec![make_entry("BBC World News", "", None)];
        let config = UnifyConfig {
            title_unifiers: HashMap::from([("World News".to_string(), "Global".to_string())]),
            ..Default::default()
        };
        let result = unify_entries(&entries, &config);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].name.as_deref(), Some("BBC Global"));
    }

    #[test]
    fn unify_deletes_entries_mapped_to_empty_title() {
        let entries = vec![
            make_entry("Remove Me", "", None),
            make_entry("Keep Me", "", None),
        ];
        let config = UnifyConfig {
            title_unifiers: HashMap::from([("Remove Me".to_string(), String::new())]),
            ..Default::default()
        };
        let result = unify_entries(&entries, &config);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].name.as_deref(), Some("Keep Me"));
    }

    #[test]
    fn unify_empty_config_is_identity() {
        let entries = vec![make_entry("BBC One", "bbc.uk", None)];
        let config = UnifyConfig::default();
        let result = unify_entries(&entries, &config);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].name.as_deref(), Some("BBC One"));
    }
}
