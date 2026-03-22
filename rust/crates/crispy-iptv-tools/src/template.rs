//! Template-based playlist entry overrides.
//!
//! Faithfully ported from `iptvtools/models.py::Playlist._parse(is_template=True)`.
//! When a template source is parsed, its entries override matching entries in
//! the main playlist by `tvg_id`.

use std::collections::HashMap;

use crispy_iptv_types::PlaylistEntry;

/// Apply a template source to override entries in the main list.
///
/// For each template entry that has a `tvg_id`, all main entries sharing
/// that `tvg_id` receive the template's metadata (name, group, extras)
/// while keeping their original stream URL.
///
/// Main entries without a matching template entry are kept unchanged.
/// Template entries without a match in the main list are ignored
/// (matching the Python behaviour).
pub fn apply_template(main: &[PlaylistEntry], template: &[PlaylistEntry]) -> Vec<PlaylistEntry> {
    // Build a lookup from tvg_id → template entry.
    let template_map: HashMap<&str, &PlaylistEntry> = template
        .iter()
        .filter_map(|t| t.tvg_id.as_deref().map(|id| (id, t)))
        .collect();

    main.iter()
        .map(|entry| {
            let tvg_id = entry.tvg_id.as_deref().unwrap_or("");
            if tvg_id.is_empty() {
                return entry.clone();
            }

            match template_map.get(tvg_id) {
                Some(tmpl) => {
                    let mut merged = entry.clone();

                    // Override name if template provides one.
                    if tmpl.name.is_some() {
                        merged.name = tmpl.name.clone();
                    }

                    // Override group_title if template provides one.
                    if tmpl.group_title.is_some() {
                        merged.group_title = tmpl.group_title.clone();
                    }

                    // Override tvg_logo if template provides one.
                    if tmpl.tvg_logo.is_some() {
                        merged.tvg_logo = tmpl.tvg_logo.clone();
                    }

                    // Override tvg_name if template provides one.
                    if tmpl.tvg_name.is_some() {
                        merged.tvg_name = tmpl.tvg_name.clone();
                    }

                    // Merge extras — template values win on conflict.
                    for (k, v) in &tmpl.extras {
                        merged.extras.insert(k.clone(), v.clone());
                    }

                    merged
                }
                None => entry.clone(),
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_entry(name: &str, tvg_id: &str, url: &str, group: &str) -> PlaylistEntry {
        PlaylistEntry {
            name: Some(name.to_string()),
            tvg_id: if tvg_id.is_empty() {
                None
            } else {
                Some(tvg_id.to_string())
            },
            url: Some(url.to_string()),
            group_title: if group.is_empty() {
                None
            } else {
                Some(group.to_string())
            },
            ..Default::default()
        }
    }

    #[test]
    fn template_overrides_matching_entry() {
        let main = vec![make_entry("Old Name", "bbc.uk", "http://a.com/1", "News")];
        let template = vec![make_entry("BBC One", "bbc.uk", "", "UK Channels")];

        let result = apply_template(&main, &template);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].name.as_deref(), Some("BBC One"));
        assert_eq!(result[0].group_title.as_deref(), Some("UK Channels"));
        // URL is preserved from main.
        assert_eq!(result[0].url.as_deref(), Some("http://a.com/1"));
    }

    #[test]
    fn entries_without_match_kept_as_is() {
        let main = vec![
            make_entry("BBC One", "bbc.uk", "http://a.com/1", "News"),
            make_entry("CNN", "cnn.us", "http://a.com/2", "News"),
        ];
        let template = vec![make_entry("BBC HD", "bbc.uk", "", "UK HD")];

        let result = apply_template(&main, &template);
        assert_eq!(result.len(), 2);
        // BBC One overridden.
        assert_eq!(result[0].name.as_deref(), Some("BBC HD"));
        // CNN untouched.
        assert_eq!(result[1].name.as_deref(), Some("CNN"));
        assert_eq!(result[1].group_title.as_deref(), Some("News"));
    }

    #[test]
    fn entries_without_tvg_id_are_untouched() {
        let main = vec![make_entry("No ID", "", "http://a.com/1", "Group")];
        let template = vec![make_entry("Template", "some.id", "", "Other")];

        let result = apply_template(&main, &template);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].name.as_deref(), Some("No ID"));
    }

    #[test]
    fn empty_template_is_identity() {
        let main = vec![make_entry("BBC One", "bbc.uk", "http://a.com/1", "News")];
        let result = apply_template(&main, &[]);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].name.as_deref(), Some("BBC One"));
    }
}
