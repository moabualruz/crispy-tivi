//! Stable ID generation for M3U entries using the DJB2 hash algorithm.
//!
//! Faithfully translated from ynotv's `generateStableStreamId()` and
//! `stableHash()` functions in `m3u-parser.ts`.

use std::collections::HashSet;

/// DJB2 hash function.
///
/// Translated from ynotv: `hash = 5381; for c in s { hash = hash * 33 + c }`.
/// Uses wrapping arithmetic to match JavaScript's 32-bit integer overflow.
fn djb2_hash(input: &str) -> u32 {
    let mut hash: u32 = 5381;
    for c in input.bytes() {
        hash = hash.wrapping_mul(33).wrapping_add(u32::from(c));
    }
    hash
}

/// Generate a stable ID for an M3U entry using the DJB2 hash algorithm.
///
/// Priority: `tvg_id` > `url` > `name`. Falls back to `"unknown"` if all
/// are `None`.
///
/// Translated from ynotv's `generateStableStreamId()`:
/// - Uses tvg_id first (sanitized), then URL hash, then name hash.
/// - Appends `_1`, `_2`, etc. suffixes on collision.
pub fn generate_stable_id(
    tvg_id: Option<&str>,
    url: Option<&str>,
    name: Option<&str>,
    seen_ids: &mut HashSet<String>,
) -> String {
    // Try tvg_id first (sanitized).
    if let Some(tvg_id) = tvg_id {
        let sanitized: String = tvg_id
            .chars()
            .map(|c| {
                if c.is_ascii_alphanumeric() || c == '.' || c == '_' || c == '-' {
                    c
                } else {
                    '_'
                }
            })
            .collect();

        if !sanitized.is_empty() {
            if !seen_ids.contains(&sanitized) {
                seen_ids.insert(sanitized.clone());
                return sanitized;
            }

            // Collision — append URL hash suffix for stability.
            if let Some(url) = url {
                let url_hash = format!("{:x}", djb2_hash(url));
                let unique_id = format!("{sanitized}_{url_hash}");
                seen_ids.insert(unique_id.clone());
                return unique_id;
            }

            // No URL — use counter suffix.
            return resolve_collision(&sanitized, seen_ids);
        }
    }

    // No tvg_id — use URL hash.
    if let Some(url) = url {
        let url_hash = format!("url_{:x}", djb2_hash(url));

        if !seen_ids.contains(&url_hash) {
            seen_ids.insert(url_hash.clone());
            return url_hash;
        }

        return resolve_collision(&url_hash, seen_ids);
    }

    // No URL — use name hash.
    if let Some(name) = name {
        let name_hash = format!("name_{:x}", djb2_hash(name));

        if !seen_ids.contains(&name_hash) {
            seen_ids.insert(name_hash.clone());
            return name_hash;
        }

        return resolve_collision(&name_hash, seen_ids);
    }

    // Nothing available — use "unknown" with collision handling.
    let base = "unknown".to_string();
    if !seen_ids.contains(&base) {
        seen_ids.insert(base.clone());
        return base;
    }
    resolve_collision(&base, seen_ids)
}

/// Resolve a collision by appending `_1`, `_2`, etc. suffixes.
///
/// Translated from ynotv's collision handling loop.
fn resolve_collision(base: &str, seen_ids: &mut HashSet<String>) -> String {
    let mut counter = 1u32;
    loop {
        let candidate = format!("{base}_{counter}");
        if !seen_ids.contains(&candidate) {
            seen_ids.insert(candidate.clone());
            return candidate;
        }
        counter += 1;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn djb2_hash_is_consistent() {
        let h1 = djb2_hash("hello");
        let h2 = djb2_hash("hello");
        assert_eq!(h1, h2);
        assert_ne!(djb2_hash("hello"), djb2_hash("world"));
    }

    #[test]
    fn stable_id_prefers_tvg_id() {
        let mut seen = HashSet::new();
        let id = generate_stable_id(
            Some("CNN.us"),
            Some("http://example.com/cnn"),
            Some("CNN"),
            &mut seen,
        );
        assert_eq!(id, "CNN.us");
    }

    #[test]
    fn stable_id_falls_back_to_url_hash() {
        let mut seen = HashSet::new();
        let id = generate_stable_id(
            None,
            Some("http://example.com/stream"),
            Some("My Channel"),
            &mut seen,
        );
        assert!(id.starts_with("url_"));
    }

    #[test]
    fn stable_id_falls_back_to_name_hash() {
        let mut seen = HashSet::new();
        let id = generate_stable_id(None, None, Some("My Channel"), &mut seen);
        assert!(id.starts_with("name_"));
    }

    #[test]
    fn collision_handling_appends_suffix() {
        let mut seen = HashSet::new();
        let id1 = generate_stable_id(Some("ch1"), None, None, &mut seen);
        let id2 = generate_stable_id(Some("ch1"), None, None, &mut seen);
        assert_eq!(id1, "ch1");
        assert_eq!(id2, "ch1_1");
    }

    #[test]
    fn collision_with_url_uses_url_hash_suffix() {
        let mut seen = HashSet::new();
        let id1 = generate_stable_id(
            Some("ESPN"),
            Some("http://example.com/espn1"),
            None,
            &mut seen,
        );
        let id2 = generate_stable_id(
            Some("ESPN"),
            Some("http://example.com/espn2"),
            None,
            &mut seen,
        );
        assert_eq!(id1, "ESPN");
        assert!(id2.starts_with("ESPN_"));
        assert_ne!(id1, id2);
    }

    #[test]
    fn url_hash_collision_appends_counter() {
        let mut seen = HashSet::new();
        let id1 = generate_stable_id(None, Some("http://example.com/s"), None, &mut seen);
        // Force collision by inserting same URL hash.
        let id2 = generate_stable_id(None, Some("http://example.com/s"), None, &mut seen);
        assert_ne!(id1, id2);
        assert!(id2.ends_with("_1"));
    }

    #[test]
    fn sanitizes_special_chars_in_tvg_id() {
        let mut seen = HashSet::new();
        let id = generate_stable_id(Some("ch@1 (HD)"), None, None, &mut seen);
        assert_eq!(id, "ch_1__HD_");
    }

    #[test]
    fn multiple_collisions_increment_counter() {
        let mut seen = HashSet::new();
        let id1 = generate_stable_id(Some("dup"), None, None, &mut seen);
        let id2 = generate_stable_id(Some("dup"), None, None, &mut seen);
        let id3 = generate_stable_id(Some("dup"), None, None, &mut seen);
        assert_eq!(id1, "dup");
        assert_eq!(id2, "dup_1");
        assert_eq!(id3, "dup_2");
    }
}
