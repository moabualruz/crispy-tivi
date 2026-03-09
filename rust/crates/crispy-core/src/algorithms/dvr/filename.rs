//! DVR filename sanitization.

use std::sync::LazyLock;

use regex::Regex;

/// Regex matching characters that are NOT word chars, spaces, or hyphens.
pub static RE_SANITIZE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[^\w\s-]").unwrap());

/// Sanitize a string for use as a filename by replacing
/// non-word, non-space, non-hyphen characters with `_`.
pub fn sanitize_filename(name: &str) -> String {
    RE_SANITIZE.replace_all(name, "_").into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── sanitize_filename ──────────────────────────────

    #[test]
    fn sanitize_replaces_special_chars() {
        let result = sanitize_filename("News: Live! (2026)");
        assert_eq!(result, "News_ Live_ _2026_");
    }

    #[test]
    fn sanitize_keeps_alphanumeric_and_hyphens() {
        let result = sanitize_filename("My-Show 2026_ep01");
        assert_eq!(result, "My-Show 2026_ep01");
    }

    // ── Sanitize: unicode characters ────────────────

    #[test]
    fn sanitize_unicode_word_chars_preserved() {
        // Rust regex \w matches Unicode word chars by
        // default, so accented letters and CJK ideographs
        // are kept (they are Unicode \p{Alphabetic}).
        let result = sanitize_filename("Café résumé 日本語");
        assert_eq!(result, "Café résumé 日本語");
    }

    #[test]
    fn sanitize_unicode_symbols_replaced() {
        // Symbols like ™, ©, € are NOT word chars.
        let result = sanitize_filename("Show™ ©2026 €9.99");
        assert!(!result.contains('™'));
        assert!(!result.contains('©'));
        assert!(!result.contains('€'));
        assert_eq!(result, "Show_ _2026 _9_99");
    }

    // ── Sanitize: path separators ───────────────────

    #[test]
    fn sanitize_path_separators() {
        let result = sanitize_filename("path/to\\file<name>.ts");
        // /, \, <, > are all non-word → replaced.
        assert!(!result.contains('/'));
        assert!(!result.contains('\\'));
        assert!(!result.contains('<'));
        assert!(!result.contains('>'));
        assert_eq!(result, "path_to_file_name__ts",);
    }
}
