//! Shared JSON parsing utilities for algorithm modules.
//!
//! Provides a typed helper that avoids the repeated
//! `match serde_json::from_str { Ok(v) => v, Err(_) => return "[]" }`
//! boilerplate found across algorithm entry points.

use serde::de::DeserializeOwned;

/// Parse a JSON string into a `Vec<T>`.
///
/// Returns `None` on any parse error, allowing call sites
/// to define their own fallback return value.
pub fn parse_json_vec<T: DeserializeOwned>(json: &str) -> Option<Vec<T>> {
    serde_json::from_str(json).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── parse_json_vec ─────────────────────────────────────

    #[test]
    fn valid_json_array_returns_some_vec() {
        let result: Option<Vec<i32>> = parse_json_vec("[1, 2, 3]");
        assert!(result.is_some());
        assert_eq!(result.unwrap(), vec![1, 2, 3]);
    }

    #[test]
    fn empty_json_array_returns_some_empty_vec() {
        let result: Option<Vec<String>> = parse_json_vec("[]");
        assert!(result.is_some());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn malformed_json_returns_none() {
        let result: Option<Vec<i32>> = parse_json_vec("not valid json");
        assert!(result.is_none());
    }
}
