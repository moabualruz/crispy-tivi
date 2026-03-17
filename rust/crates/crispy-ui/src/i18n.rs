//! Localization infrastructure using rust-i18n.

rust_i18n::i18n!("locales", fallback = "en");

/// Available languages with display names. Used by language picker (Phase 2+).
#[allow(dead_code)]
pub const LANGUAGES: &[(&str, &str)] = &[
    ("en", "English"),
    ("ar", "العربية"),
    ("de", "Deutsch"),
    ("fr", "Français"),
    ("es", "Español"),
];

/// Returns true if the given language code uses RTL layout.
pub fn is_rtl(lang: &str) -> bool {
    matches!(lang, "ar" | "he" | "fa" | "ur")
}

/// Set the active locale.
pub fn set_locale(lang: &str) {
    rust_i18n::set_locale(lang);
    tracing::info!(locale = %lang, "Locale set");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_rtl_arabic() {
        assert!(is_rtl("ar"));
    }

    #[test]
    fn test_is_rtl_english() {
        assert!(!is_rtl("en"));
    }

    #[test]
    fn test_languages_count() {
        assert_eq!(LANGUAGES.len(), 5);
    }

    #[test]
    fn test_languages_include_all_required() {
        let codes: Vec<&str> = LANGUAGES.iter().map(|(c, _)| *c).collect();
        assert!(codes.contains(&"en"));
        assert!(codes.contains(&"ar"));
        assert!(codes.contains(&"de"));
        assert!(codes.contains(&"fr"));
        assert!(codes.contains(&"es"));
    }
}
