//! Title and group manipulation utilities.
//!
//! Faithfully ported from `iptvtools/models.py::Playlist.export()` —
//! specifically the `replace_group_by_source` and `resolution_on_title`
//! features.

use crispy_iptv_types::PlaylistEntry;

use crate::resolution::detect_resolution;

/// Replace the `group_title` of every entry with `source_name`.
///
/// Mirrors the Python `replace_group_by_source` flag that replaces each
/// entry's `group-title` with the source filename during export.
pub fn replace_group_by_source(entries: &mut [PlaylistEntry], source_name: &str) {
    for entry in entries.iter_mut() {
        entry.group_title = Some(source_name.to_string());
    }
}

/// Append a resolution suffix to each entry's display name.
///
/// Detects resolution from the entry's name, URL, and extras, then
/// appends it as a suffix: `"Channel" → "Channel [FHD]"`.
///
/// Mirrors the Python `resolution_on_title` flag. Entries with
/// `Resolution::Unknown` get no suffix appended.
pub fn append_resolution_to_name(entries: &mut [PlaylistEntry]) {
    for entry in entries.iter_mut() {
        let name = entry.name.as_deref().unwrap_or("");
        let url = entry.url.as_deref().unwrap_or("");
        let resolution = detect_resolution(name, url, &entry.extras);

        if resolution != crispy_iptv_types::Resolution::Unknown {
            let suffix = format!(" [{resolution}]");
            let new_name = format!("{name}{suffix}");
            entry.name = Some(new_name);
        }
    }
}

/// Map a pixel height value to a human-readable resolution label.
///
/// Faithfully ported from `iptvtools/utils.py::height_to_resolution`.
/// Returns `""` for height 0, `"8K"` for ≥4320, `"4K"` for ≥2160,
/// `"1080p"` for ≥1080, `"720p"` for ≥720, or `"{height}p"` otherwise.
pub fn height_to_label(height: u32) -> String {
    if height == 0 {
        return String::new();
    }
    if height >= 4320 {
        return "8K".to_string();
    }
    if height >= 2160 {
        return "4K".to_string();
    }
    if height >= 1080 {
        return "1080p".to_string();
    }
    if height >= 720 {
        return "720p".to_string();
    }
    format!("{height}p")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_entry(name: &str, group: &str, url: &str) -> PlaylistEntry {
        PlaylistEntry {
            name: Some(name.to_string()),
            group_title: if group.is_empty() {
                None
            } else {
                Some(group.to_string())
            },
            url: Some(url.to_string()),
            ..Default::default()
        }
    }

    #[test]
    fn replace_group_sets_all_groups() {
        let mut entries = vec![
            make_entry("A", "News", "http://a.com/1"),
            make_entry("B", "Sports", "http://a.com/2"),
            make_entry("C", "", "http://a.com/3"),
        ];
        replace_group_by_source(&mut entries, "my_source");
        for entry in &entries {
            assert_eq!(entry.group_title.as_deref(), Some("my_source"));
        }
    }

    #[test]
    fn append_resolution_adds_suffix() {
        let mut entries = vec![make_entry("BBC One FHD", "News", "http://a.com/1")];
        append_resolution_to_name(&mut entries);
        let name = entries[0].name.as_deref().unwrap();
        assert!(name.contains("[FHD]"), "expected FHD suffix, got: {name}");
    }

    #[test]
    fn append_resolution_skips_unknown() {
        let mut entries = vec![make_entry("Plain Channel", "News", "http://a.com/1")];
        append_resolution_to_name(&mut entries);
        let name = entries[0].name.as_deref().unwrap();
        assert_eq!(name, "Plain Channel");
    }

    #[test]
    fn height_to_label_8k() {
        assert_eq!(height_to_label(4320), "8K");
        assert_eq!(height_to_label(8640), "8K");
    }

    #[test]
    fn height_to_label_4k() {
        assert_eq!(height_to_label(2160), "4K");
        assert_eq!(height_to_label(3000), "4K");
    }

    #[test]
    fn height_to_label_1080p() {
        assert_eq!(height_to_label(1080), "1080p");
        assert_eq!(height_to_label(1440), "1080p");
    }

    #[test]
    fn height_to_label_720p() {
        assert_eq!(height_to_label(720), "720p");
        assert_eq!(height_to_label(900), "720p");
    }

    #[test]
    fn height_to_label_low_res() {
        assert_eq!(height_to_label(480), "480p");
        assert_eq!(height_to_label(576), "576p");
    }

    #[test]
    fn height_to_label_zero() {
        assert_eq!(height_to_label(0), "");
    }
}
