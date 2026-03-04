//! JSON deep-merge and nested value setter.
//!
//! Ports `_deepMerge()` and `_setNestedValue()` from
//! Dart's `ConfigService` to Rust. Operates on raw JSON
//! strings so callers don't need to deserialize first.

use serde_json::Value;

/// Deep-merge two JSON objects.
///
/// - Override values replace base values.
/// - When both base and override have a nested object at
///   the same key, they are recursively merged.
/// - Non-object overrides replace entirely (arrays, nulls,
///   scalars).
/// - Returns the merged JSON string.
///
/// If either input is not valid JSON or not an object,
/// the other is returned as-is. If both are invalid,
/// returns `"{}"`.
pub fn deep_merge_json(base_json: &str, overrides_json: &str) -> String {
    let base: Value =
        serde_json::from_str(base_json).unwrap_or(Value::Object(serde_json::Map::new()));
    let overrides: Value =
        serde_json::from_str(overrides_json).unwrap_or(Value::Object(serde_json::Map::new()));

    let merged = merge_values(base, overrides);
    serde_json::to_string(&merged).unwrap_or_else(|_| "{}".to_string())
}

/// Recursively merge two `serde_json::Value`s.
fn merge_values(base: Value, overrides: Value) -> Value {
    match (base, overrides) {
        (Value::Object(mut b), Value::Object(o)) => {
            for (key, o_val) in o {
                let merged = match b.remove(&key) {
                    Some(b_val) => merge_values(b_val, o_val),
                    None => o_val,
                };
                b.insert(key, merged);
            }
            Value::Object(b)
        }
        // Non-object override replaces entirely.
        (_base, overrides) => overrides,
    }
}

/// Set a value at a dot-separated path in a JSON object.
///
/// - Splits `dot_path` by `'.'`.
/// - Traverses (or creates) nested objects along the path.
/// - Sets the final key to `value_json` (parsed).
/// - Returns the updated JSON string.
///
/// If `map_json` is not a valid JSON object, starts from
/// an empty object. If `value_json` is not valid JSON, it
/// is stored as a JSON string.
///
/// # Examples
///
/// ```
/// use crispy_core::algorithms::config_merge::*;
///
/// let result = set_nested_value(
///     r#"{"a": 1}"#,
///     "b.c",
///     "42",
/// );
/// assert!(result.contains("\"b\""));
/// ```
pub fn set_nested_value(map_json: &str, dot_path: &str, value_json: &str) -> String {
    let mut root: Value =
        serde_json::from_str(map_json).unwrap_or(Value::Object(serde_json::Map::new()));

    let value: Value =
        serde_json::from_str(value_json).unwrap_or(Value::String(value_json.to_string()));

    if dot_path.is_empty() {
        // No path — return original unchanged.
        return serde_json::to_string(&root).unwrap_or_else(|_| "{}".to_string());
    }

    let keys: Vec<&str> = dot_path.split('.').collect();
    set_at_path(&mut root, &keys, value);

    serde_json::to_string(&root).unwrap_or_else(|_| "{}".to_string())
}

/// Recursively traverse/create nested objects and set the
/// leaf value.
fn set_at_path(node: &mut Value, keys: &[&str], value: Value) {
    if keys.is_empty() {
        return;
    }

    // Ensure node is an object.
    if !node.is_object() {
        *node = Value::Object(serde_json::Map::new());
    }

    let map = node.as_object_mut().unwrap();

    if keys.len() == 1 {
        map.insert(keys[0].to_string(), value);
        return;
    }

    // Traverse or create intermediate object.
    let child = map
        .entry(keys[0].to_string())
        .or_insert_with(|| Value::Object(serde_json::Map::new()));

    // If existing child is not an object, replace it.
    if !child.is_object() {
        *child = Value::Object(serde_json::Map::new());
    }

    set_at_path(child, &keys[1..], value);
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── deep_merge_json ────────────────────────────────

    #[test]
    fn simple_override() {
        let base = r#"{"a": 1, "b": 2}"#;
        let over = r#"{"b": 99}"#;
        let result = deep_merge_json(base, over);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["a"], 1);
        assert_eq!(v["b"], 99);
    }

    #[test]
    fn nested_merge() {
        let base = r#"{"ui": {"theme": "dark", "font": 14}}"#;
        let over = r#"{"ui": {"theme": "light"}}"#;
        let result = deep_merge_json(base, over);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["ui"]["theme"], "light");
        assert_eq!(v["ui"]["font"], 14);
    }

    #[test]
    fn array_replacement() {
        let base = r#"{"tags": [1, 2, 3]}"#;
        let over = r#"{"tags": [4, 5]}"#;
        let result = deep_merge_json(base, over);
        let v: Value = serde_json::from_str(&result).unwrap();
        let arr = v["tags"].as_array().unwrap();
        assert_eq!(arr.len(), 2);
        assert_eq!(arr[0], 4);
        assert_eq!(arr[1], 5);
    }

    #[test]
    fn null_override() {
        let base = r#"{"a": 1, "b": 2}"#;
        let over = r#"{"a": null}"#;
        let result = deep_merge_json(base, over);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert!(v["a"].is_null());
        assert_eq!(v["b"], 2);
    }

    #[test]
    fn empty_maps() {
        assert_eq!(deep_merge_json("{}", "{}"), "{}");
        let base = r#"{"x": 1}"#;
        let result = deep_merge_json(base, "{}");
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["x"], 1);
    }

    #[test]
    fn deeply_nested_merge() {
        let base = r#"{"a":{"b":{"c":1,"d":2}}}"#;
        let over = r#"{"a":{"b":{"c":99,"e":3}}}"#;
        let result = deep_merge_json(base, over);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["a"]["b"]["c"], 99);
        assert_eq!(v["a"]["b"]["d"], 2);
        assert_eq!(v["a"]["b"]["e"], 3);
    }

    // ── set_nested_value ───────────────────────────────

    #[test]
    fn top_level_key() {
        let result = set_nested_value(r#"{"a": 1}"#, "b", "42");
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["a"], 1);
        assert_eq!(v["b"], 42);
    }

    #[test]
    fn nested_key() {
        let result = set_nested_value("{}", "ui.theme.primary", r#""blue""#);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["ui"]["theme"]["primary"], "blue");
    }

    #[test]
    fn creates_intermediate_maps() {
        let result = set_nested_value("{}", "a.b.c", "true");
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["a"]["b"]["c"], true);
    }

    #[test]
    fn empty_path_returns_unchanged() {
        let input = r#"{"x": 1}"#;
        let result = set_nested_value(input, "", r#""ignored""#);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["x"], 1);
        assert!(v.get("").is_none());
    }

    #[test]
    fn overwrites_existing_nested_value() {
        let input = r#"{"ui": {"theme": "dark"}}"#;
        let result = set_nested_value(input, "ui.theme", r#""light""#);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["ui"]["theme"], "light");
    }

    #[test]
    fn overwrites_non_object_intermediate() {
        // "ui" is a string, but path goes deeper —
        // it gets replaced with an object.
        let input = r#"{"ui": "old"}"#;
        let result = set_nested_value(input, "ui.theme", r#""dark""#);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["ui"]["theme"], "dark");
    }
}
