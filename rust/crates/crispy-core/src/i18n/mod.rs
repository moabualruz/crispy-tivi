//! Bundled FTL translation resources.
//!
//! Exposes each locale as a `&'static str` constant so callers can
//! pass them directly to `I18nService::load_locale` without file IO.

/// English (en) Fluent messages.
pub const EN: &str = include_str!("en.ftl");

/// Arabic (ar) Fluent messages.
pub const AR: &str = include_str!("ar.ftl");
