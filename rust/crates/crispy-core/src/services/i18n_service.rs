//! Fluent-based i18n service for runtime message formatting.
//!
//! Holds one `FluentBundle` per loaded locale. Supports named
//! placeholders via `FluentArgs`, built-in plural rules (all 6
//! CLDR categories), and locale switching.
//!
//! # Usage
//! ```ignore
//! let mut svc = I18nService::new();
//! svc.load_locale("en", include_str!("../i18n/en.ftl")).unwrap();
//! let msg = svc.format_message("en", "app-name", None);
//! assert_eq!(msg, "CrispyTivi");
//! ```

use std::collections::HashMap;
use std::sync::{Arc, RwLock};

use fluent_bundle::{FluentArgs, FluentBundle, FluentResource, FluentValue};
use unic_langid::LanguageIdentifier;

// ── Public re-exports ────────────────────────────────────────────────────────

pub use fluent_bundle::FluentArgs as I18nArgs;

// ── Error ────────────────────────────────────────────────────────────────────

/// Errors produced by `I18nService`.
#[derive(Debug, thiserror::Error)]
pub enum I18nError {
    /// The FTL source text could not be parsed.
    #[error("FTL parse error for locale '{locale}': {detail}")]
    ParseError { locale: String, detail: String },

    /// The locale identifier string is not valid BCP-47.
    #[error("Invalid locale identifier: {0}")]
    InvalidLocale(String),
}

// ── I18nService ──────────────────────────────────────────────────────────────

/// Thread-safe Fluent i18n service.
///
/// Bundles are stored behind an `Arc<RwLock<…>>` so the service can
/// be cloned and shared across threads without copying message data.
#[derive(Clone)]
pub struct I18nService {
    inner: Arc<RwLock<I18nInner>>,
}

struct I18nInner {
    /// Map from locale string (e.g. `"en"`, `"ar"`) to bundle.
    bundles: HashMap<String, FluentBundle<FluentResource>>,
    /// Currently active locale.
    active: String,
    /// Ordered list of loaded locales (insertion order).
    locales: Vec<String>,
}

impl I18nService {
    /// Create a new, empty service. No messages are available until
    /// `load_locale` is called.
    pub fn new() -> Self {
        Self {
            inner: Arc::new(RwLock::new(I18nInner {
                bundles: HashMap::new(),
                active: "en".to_string(),
                locales: Vec::new(),
            })),
        }
    }

    /// Parse `ftl_content` and register it under `locale`.
    ///
    /// Calling this again for the same locale replaces the bundle.
    /// Returns `Err` if the FTL source contains parse errors.
    pub fn load_locale(&self, locale: &str, ftl_content: &str) -> Result<(), I18nError> {
        let lang_id: LanguageIdentifier = locale
            .parse()
            .map_err(|_| I18nError::InvalidLocale(locale.to_string()))?;

        let resource =
            FluentResource::try_new(ftl_content.to_string()).map_err(|(_, errors)| {
                let detail = errors
                    .iter()
                    .map(|e| format!("{e:?}"))
                    .collect::<Vec<_>>()
                    .join("; ");
                I18nError::ParseError {
                    locale: locale.to_string(),
                    detail,
                }
            })?;

        let mut bundle = FluentBundle::new(vec![lang_id]);
        // Allow overlapping message IDs in the same bundle (e.g. re-load).
        bundle.add_resource_overriding(resource);

        let mut inner = self.inner.write().unwrap_or_else(|e| e.into_inner());
        if !inner.locales.contains(&locale.to_string()) {
            inner.locales.push(locale.to_string());
        }
        inner.bundles.insert(locale.to_string(), bundle);
        Ok(())
    }

    /// Set the active locale. Does not fail if the locale is not yet
    /// loaded — it will simply produce fallback strings until loaded.
    pub fn set_locale(&self, locale: &str) {
        let mut inner = self.inner.write().unwrap_or_else(|e| e.into_inner());
        inner.active = locale.to_string();
    }

    /// Return the currently active locale string.
    pub fn active_locale(&self) -> String {
        self.inner
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .active
            .clone()
    }

    /// Return the list of loaded locale strings in insertion order.
    pub fn get_available_locales(&self) -> Vec<String> {
        self.inner
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .locales
            .clone()
    }

    /// Format message `msg_id` using the given `locale`.
    ///
    /// Falls back to `msg_id` itself when:
    /// - the locale is not loaded,
    /// - the message ID is not found,
    /// - formatting produces errors.
    pub fn format_message(&self, locale: &str, msg_id: &str, args: Option<&FluentArgs>) -> String {
        let inner = self.inner.read().unwrap_or_else(|e| e.into_inner());
        let Some(bundle) = inner.bundles.get(locale) else {
            return msg_id.to_string();
        };
        let Some(pattern) = bundle.get_message(msg_id).and_then(|m| m.value()) else {
            return msg_id.to_string();
        };
        let mut errors = Vec::new();
        let result = bundle.format_pattern(pattern, args, &mut errors);
        if !errors.is_empty() {
            // Log format errors without requiring the tracing crate in crispy-core.
            eprintln!("[i18n] format errors for locale={locale} msg_id={msg_id}: {errors:?}");
        }
        result.into_owned()
    }

    /// Convenience: format using the currently active locale.
    pub fn format(&self, msg_id: &str, args: Option<&FluentArgs>) -> String {
        let locale = self.active_locale();
        self.format_message(&locale, msg_id, args)
    }

    /// Build a `FluentArgs` with a single numeric `count` key.
    ///
    /// Useful for plural-category messages like `channel-count`.
    pub fn count_args(count: u64) -> FluentArgs<'static> {
        let mut args = FluentArgs::new();
        args.set("count", FluentValue::from(count));
        args
    }

    /// Build a `FluentArgs` with a single string placeholder.
    pub fn str_arg<'a>(key: &'a str, value: &'a str) -> FluentArgs<'a> {
        let mut args = FluentArgs::new();
        args.set(key, FluentValue::from(value));
        args
    }
}

impl Default for I18nService {
    fn default() -> Self {
        Self::new()
    }
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    const EN_FTL: &str = include_str!("../i18n/en.ftl");
    const AR_FTL: &str = include_str!("../i18n/ar.ftl");

    fn loaded_service() -> I18nService {
        let svc = I18nService::new();
        svc.load_locale("en", EN_FTL).unwrap();
        svc.load_locale("ar", AR_FTL).unwrap();
        svc
    }

    // ── Basic message lookup ──────────────────────────────────────────────

    #[test]
    fn test_format_message_returns_english_app_name() {
        let svc = loaded_service();
        let msg = svc.format_message("en", "app-name", None);
        assert_eq!(msg, "CrispyTivi");
    }

    #[test]
    fn test_format_message_returns_arabic_app_name() {
        let svc = loaded_service();
        let msg = svc.format_message("ar", "app-name", None);
        assert_eq!(msg, "كريسبي تيفي");
    }

    #[test]
    fn test_format_message_fallback_for_missing_locale() {
        let svc = I18nService::new();
        let msg = svc.format_message("fr", "app-name", None);
        assert_eq!(msg, "app-name");
    }

    #[test]
    fn test_format_message_fallback_for_missing_key() {
        let svc = loaded_service();
        let msg = svc.format_message("en", "nonexistent-key", None);
        assert_eq!(msg, "nonexistent-key");
    }

    // ── Named placeholders ────────────────────────────────────────────────

    #[test]
    fn test_placeholder_query_in_empty_search() {
        let svc = loaded_service();
        let args = I18nService::str_arg("query", "breaking bad");
        let msg = svc.format_message("en", "empty-search", Some(&args));
        assert!(strip_bidi(&msg).contains("breaking bad"), "got: {msg}");
    }

    #[test]
    fn test_placeholder_source_in_sync_done() {
        let svc = loaded_service();
        let args = I18nService::str_arg("source", "MyIPTV");
        let msg = svc.format_message("en", "sync-done", Some(&args));
        assert!(strip_bidi(&msg).contains("MyIPTV"), "got: {msg}");
    }

    #[test]
    fn test_placeholder_arabic_sync_done() {
        let svc = loaded_service();
        let args = I18nService::str_arg("source", "MyIPTV");
        let msg = svc.format_message("ar", "sync-done", Some(&args));
        assert!(strip_bidi(&msg).contains("MyIPTV"), "got: {msg}");
    }

    // ── Arabic plural rules (all 6 CLDR categories) ───────────────────────

    #[test]
    fn test_arabic_plural_zero() {
        let svc = loaded_service();
        let args = I18nService::count_args(0);
        let msg = svc.format_message("ar", "channel-count", Some(&args));
        // zero category
        assert!(msg.contains("لا قنوات"), "zero plural, got: {msg}");
    }

    #[test]
    fn test_arabic_plural_one() {
        let svc = loaded_service();
        let args = I18nService::count_args(1);
        let msg = svc.format_message("ar", "channel-count", Some(&args));
        // one category
        assert!(msg.contains("واحدة"), "one plural, got: {msg}");
    }

    #[test]
    fn test_arabic_plural_two() {
        let svc = loaded_service();
        let args = I18nService::count_args(2);
        let msg = svc.format_message("ar", "channel-count", Some(&args));
        // two category
        assert!(msg.contains("قناتان"), "two plural, got: {msg}");
    }

    #[test]
    fn test_arabic_plural_few() {
        let svc = loaded_service();
        // few = 3–10
        let args = I18nService::count_args(5);
        let msg = svc.format_message("ar", "channel-count", Some(&args));
        let stripped = strip_bidi(&msg);
        assert!(
            stripped.contains("5") && stripped.contains("قنوات"),
            "few plural, got: {msg}"
        );
    }

    #[test]
    fn test_arabic_plural_many() {
        let svc = loaded_service();
        // many = 11–99
        let args = I18nService::count_args(25);
        let msg = svc.format_message("ar", "channel-count", Some(&args));
        let stripped = strip_bidi(&msg);
        assert!(
            stripped.contains("25") && stripped.contains("قناة"),
            "many plural, got: {msg}"
        );
    }

    #[test]
    fn test_arabic_plural_other() {
        let svc = loaded_service();
        // other = 100+
        let args = I18nService::count_args(150);
        let msg = svc.format_message("ar", "channel-count", Some(&args));
        let stripped = strip_bidi(&msg);
        assert!(
            stripped.contains("150") && stripped.contains("قناة"),
            "other plural, got: {msg}"
        );
    }

    // ── English plural ────────────────────────────────────────────────────

    /// Strip Unicode bidi isolate marks that Fluent injects around interpolated values.
    /// U+2068 FIRST STRONG ISOLATE and U+2069 POP DIRECTIONAL ISOLATE are format
    /// characters (not control chars), so `char::is_control` does not catch them.
    fn strip_bidi(s: &str) -> String {
        s.chars()
            .filter(|&c| c != '\u{2068}' && c != '\u{2069}')
            .collect()
    }

    #[test]
    fn test_english_plural_one() {
        let svc = loaded_service();
        let args = I18nService::count_args(1);
        let msg = svc.format_message("en", "channel-count", Some(&args));
        let stripped = strip_bidi(&msg);
        assert!(
            stripped.contains("1 channel") && !stripped.contains("channels"),
            "got: {msg}"
        );
    }

    #[test]
    fn test_english_plural_other() {
        let svc = loaded_service();
        let args = I18nService::count_args(42);
        let msg = svc.format_message("en", "channel-count", Some(&args));
        let stripped = strip_bidi(&msg);
        assert!(stripped.contains("42 channels"), "got: {msg}");
    }

    // ── Locale switching ──────────────────────────────────────────────────

    #[test]
    fn test_set_locale_changes_active() {
        let svc = loaded_service();
        svc.set_locale("ar");
        assert_eq!(svc.active_locale(), "ar");
    }

    #[test]
    fn test_format_uses_active_locale() {
        let svc = loaded_service();
        svc.set_locale("ar");
        let msg = svc.format("nav-live", None);
        assert_eq!(msg, "مباشر");
    }

    #[test]
    fn test_format_english_after_switch_back() {
        let svc = loaded_service();
        svc.set_locale("ar");
        svc.set_locale("en");
        let msg = svc.format("nav-live", None);
        assert_eq!(msg, "Live");
    }

    // ── Available locales ─────────────────────────────────────────────────

    #[test]
    fn test_get_available_locales_returns_loaded() {
        let svc = loaded_service();
        let locales = svc.get_available_locales();
        assert!(locales.contains(&"en".to_string()));
        assert!(locales.contains(&"ar".to_string()));
    }

    #[test]
    fn test_get_available_locales_empty_before_load() {
        let svc = I18nService::new();
        assert!(svc.get_available_locales().is_empty());
    }

    // ── Invalid FTL / locale ──────────────────────────────────────────────

    #[test]
    fn test_invalid_locale_id_returns_error() {
        let svc = I18nService::new();
        // "not a valid BCP-47" — unic-langid accepts most strings,
        // but an empty string should fail.
        let result = svc.load_locale("", "key = value");
        assert!(result.is_err(), "empty locale should fail");
    }
}
