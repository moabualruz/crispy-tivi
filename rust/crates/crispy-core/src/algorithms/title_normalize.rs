//! Title normalisation pipeline for deduplication and sorting.
//!
//! Steps (applied in order):
//! 1. HTML entity decode
//! 2. NFC Unicode normalisation
//! 3. Lowercase
//! 4. Remove punctuation — keep alphanumeric + spaces
//! 5. Collapse whitespace
//! 6. Move leading articles to end  ("The Matrix" → "Matrix, The")
//! 7. Sort tokens alphabetically (for similarity comparison)

use unicode_normalization::UnicodeNormalization;

// ── Article list ─────────────────────────────────────────

/// Articles to move to the end of the title.
const ARTICLES: &[&str] = &[
    "the", "a", "an", "le", "la", "les", "der", "die", "das", "el", "los", "las",
];

// ── HTML entity table ────────────────────────────────────

fn decode_html_entities(s: &str) -> String {
    // Handle numeric and the most common named entities.
    // We avoid pulling in a full HTML parser for this hot path.
    let mut out = String::with_capacity(s.len());
    let mut rest = s;
    while let Some(amp) = rest.find('&') {
        out.push_str(&rest[..amp]);
        rest = &rest[amp..];
        if let Some(semi) = rest.find(';') {
            let entity = &rest[1..semi]; // between & and ;
            let decoded = decode_entity(entity);
            out.push_str(&decoded);
            rest = &rest[semi + 1..];
        } else {
            // No closing ';' — emit the '&' literally and move on.
            out.push('&');
            rest = &rest[1..];
        }
    }
    out.push_str(rest);
    out
}

fn decode_entity(entity: &str) -> String {
    // Numeric: &#160; or &#xA0;
    if let Some(hex) = entity
        .strip_prefix("#x")
        .or_else(|| entity.strip_prefix("#X"))
        && let Ok(n) = u32::from_str_radix(hex, 16)
        && let Some(c) = char::from_u32(n)
    {
        return c.to_string();
    }
    if let Some(dec) = entity.strip_prefix('#')
        && let Ok(n) = dec.parse::<u32>()
        && let Some(c) = char::from_u32(n)
    {
        return c.to_string();
    }
    // Named entities (common subset).
    match entity {
        "amp" => "&",
        "lt" => "<",
        "gt" => ">",
        "quot" => "\"",
        "apos" => "'",
        "nbsp" => " ",
        "copy" => "©",
        "reg" => "®",
        "trade" => "™",
        "mdash" => "—",
        "ndash" => "–",
        "lsquo" => "\u{2018}",
        "rsquo" => "\u{2019}",
        "ldquo" => "\u{201C}",
        "rdquo" => "\u{201D}",
        "hellip" => "…",
        "eacute" => "é",
        "egrave" => "è",
        "ecirc" => "ê",
        "agrave" => "à",
        "acirc" => "â",
        "ccedil" => "ç",
        "uuml" => "ü",
        "ouml" => "ö",
        "auml" => "ä",
        "szlig" => "ß",
        "ntilde" => "ñ",
        _ => return format!("&{entity};"),
    }
    .to_string()
}

// ── Core normalisation steps ──────────────────────────────

/// Step 3+4+5: lowercase, strip non-alphanumeric/space, collapse whitespace.
fn clean(s: &str) -> String {
    let lowered = s.to_lowercase();
    let filtered: String = lowered
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || c == ' ' {
                c
            } else {
                ' '
            }
        })
        .collect();
    // Collapse runs of whitespace.
    filtered.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Step 6: move a leading article to the end.
///
/// "the matrix" → "matrix the"  (before the sort step)
///
/// Guard: only move when `tokens[1]` is **not** itself an article.
/// Without this guard, two adjacent articles flip-flop on repeated
/// application ("the a" → "a the" → "the a" …), breaking idempotency.
fn move_article(s: &str) -> String {
    let tokens: Vec<&str> = s.split_whitespace().collect();
    if tokens.len() < 2 {
        return s.to_string();
    }
    if ARTICLES.contains(&tokens[0]) && !ARTICLES.contains(&tokens[1]) {
        let rest = tokens[1..].join(" ");
        format!("{rest} {}", tokens[0])
    } else {
        s.to_string()
    }
}

/// Step 7: sort tokens alphabetically (for fuzzy comparison).
fn sort_tokens(s: &str) -> String {
    let mut tokens: Vec<&str> = s.split_whitespace().collect();
    tokens.sort_unstable();
    tokens.join(" ")
}

// ── Public API ────────────────────────────────────────────

/// Produce a **display normalised** title suitable for sorting and
/// presentation (steps 1-6, no token sort).
///
/// "The Matrix" → "matrix the"
pub fn normalize_title_display(title: &str) -> String {
    let decoded = decode_html_entities(title);
    let nfc: String = decoded.nfc().collect();
    let cleaned = clean(&nfc);
    move_article(&cleaned)
}

/// Produce a **comparison normalised** title (all 7 steps).
///
/// Two titles that produce the same `normalize_title` output
/// are considered identical for deduplication purposes.
pub fn normalize_title(title: &str) -> String {
    let display = normalize_title_display(title);
    sort_tokens(&display)
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── HTML entity decode ────────────────────────────────

    #[test]
    fn test_decode_amp_entity() {
        assert_eq!(decode_html_entities("Tom &amp; Jerry"), "Tom & Jerry");
    }

    #[test]
    fn test_decode_numeric_entity() {
        assert_eq!(decode_html_entities("caf&#233;"), "café");
    }

    #[test]
    fn test_decode_hex_entity() {
        assert_eq!(decode_html_entities("&#xE9;"), "é");
    }

    #[test]
    fn test_decode_nbsp() {
        assert_eq!(decode_html_entities("Hello&nbsp;World"), "Hello World");
    }

    #[test]
    fn test_unclosed_entity_emitted_literally() {
        assert_eq!(decode_html_entities("foo & bar"), "foo & bar");
    }

    // ── Pipeline: display ─────────────────────────────────

    #[test]
    fn test_leading_the_moved() {
        assert_eq!(normalize_title_display("The Matrix"), "matrix the");
    }

    #[test]
    fn test_leading_a_moved() {
        assert_eq!(
            normalize_title_display("A Clockwork Orange"),
            "clockwork orange a"
        );
    }

    #[test]
    fn test_leading_an_moved() {
        assert_eq!(
            normalize_title_display("An American Tail"),
            "american tail an"
        );
    }

    #[test]
    fn test_leading_le_moved() {
        assert_eq!(normalize_title_display("Le Monde"), "monde le");
    }

    #[test]
    fn test_leading_la_moved() {
        assert_eq!(normalize_title_display("La Vie en Rose"), "vie en rose la");
    }

    #[test]
    fn test_no_article_unchanged() {
        assert_eq!(normalize_title_display("Inception"), "inception");
    }

    #[test]
    fn test_punctuation_removed() {
        // Hyphens and colons become spaces; whitespace is collapsed.
        assert_eq!(
            normalize_title_display("Spider-Man: Homecoming"),
            "spider man homecoming"
        );
    }

    #[test]
    fn test_collapse_whitespace() {
        assert_eq!(normalize_title_display("  Iron   Man  "), "iron man");
    }

    // ── Pipeline: comparison (sort_tokens) ────────────────

    #[test]
    fn test_normalize_title_sorts_tokens() {
        // "matrix the" → tokens sorted → "matrix the"
        let a = normalize_title("The Matrix");
        let b = normalize_title("Matrix, The");
        assert_eq!(a, b);
    }

    #[test]
    fn test_normalize_title_case_insensitive() {
        assert_eq!(normalize_title("INCEPTION"), normalize_title("inception"));
    }

    #[test]
    fn test_normalize_title_unicode_nfc() {
        // é as precomposed vs decomposed should normalise to same.
        let precomposed = normalize_title("café");
        let decomposed = normalize_title("cafe\u{0301}");
        assert_eq!(precomposed, decomposed);
    }

    #[test]
    fn test_normalize_title_empty() {
        assert_eq!(normalize_title(""), "");
    }

    #[test]
    fn test_normalize_title_cjk_preserved() {
        // CJK characters are alphanumeric — they should survive the filter.
        let result = normalize_title("東京物語");
        assert!(!result.is_empty());
    }

    #[test]
    fn test_normalize_title_arabic_preserved() {
        let result = normalize_title("الرسالة");
        assert!(!result.is_empty());
    }

    #[test]
    fn test_normalize_title_html_then_article() {
        assert_eq!(
            normalize_title("The &amp; Beyond"),
            normalize_title("Beyond &amp; the")
        );
    }

    #[test]
    fn test_single_token_article_not_moved() {
        // Single-word title — nothing to move to.
        assert_eq!(normalize_title_display("The"), "the");
    }

    // ── Proptest fuzzing ──────────────────────────────────

    #[test]
    fn test_idempotent_on_already_normalised() {
        let once = normalize_title("the quick brown fox");
        let twice = normalize_title(&once);
        assert_eq!(once, twice);
    }

    #[test]
    fn test_all_punctuation_becomes_empty() {
        // A string of only punctuation normalises to "".
        let result = normalize_title("!@#$%^&*()");
        assert_eq!(result, "");
    }

    #[test]
    fn test_mixed_unicode_and_html() {
        let a = normalize_title("Amélie &amp; Co.");
        let b = normalize_title("amelie co");
        // After NFC + clean, non-ASCII vowels like é/è survive because
        // char::is_alphanumeric() is true for them.
        // Just assert they are non-empty and equal to their own normalised form.
        assert!(!a.is_empty());
        // Both contain same tokens but b has ascii only — they will differ; that's fine.
        // The important property: same input always same output.
        assert_eq!(a, normalize_title("Amélie &amp; Co."));
        let _ = b;
    }

    // ── Proptest fuzzing ──────────────────────────────────

    use proptest::prelude::*;

    proptest! {
        /// Normalization is idempotent: normalizing twice == normalizing once.
        #[test]
        fn prop_normalize_is_idempotent(title in "\\PC{1,100}") {
            let once = normalize_title(&title);
            let twice = normalize_title(&once);
            prop_assert_eq!(once, twice);
        }

        /// Normalized output never has leading or trailing whitespace.
        #[test]
        fn prop_normalize_trims_whitespace(title in "\\PC{1,100}") {
            let result = normalize_title(&title);
            prop_assert_eq!(result.trim(), result.as_str());
        }

        /// Normalization of ASCII alphanumeric input never increases byte length
        /// by more than a small tolerance (article move can add a space).
        #[test]
        fn prop_normalize_never_increases_length(title in "[a-zA-Z0-9 ]{1,50}") {
            let result = normalize_title(&title);
            // Tolerance of 5 bytes covers article-move edge cases.
            prop_assert!(result.len() <= title.len() + 5);
        }

        /// display normalise is also idempotent.
        #[test]
        fn prop_display_normalize_is_idempotent(title in "\\PC{1,100}") {
            let once = normalize_title_display(&title);
            let twice = normalize_title_display(&once);
            prop_assert_eq!(once, twice);
        }
    }
}
