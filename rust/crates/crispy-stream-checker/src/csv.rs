//! CSV export with formula injection prevention.
//!
//! Translated from IPTVChecker-Python `sanitize_csv_field()`:
//!
//! ```python
//! def sanitize_csv_field(value):
//!     if value is None:
//!         return ""
//!     normalized = str(value).replace('\r', ' ').replace('\n', ' ').replace('\t', ' ')
//!     check_value = normalized.lstrip()
//!     if check_value.startswith(('=', '+', '-', '@')):
//!         return "'" + normalized
//!     return normalized
//! ```

/// Sanitize a CSV field to prevent formula injection attacks.
///
/// Spreadsheet applications (Excel, Google Sheets, LibreOffice Calc) interpret
/// cells starting with `=`, `+`, `-`, or `@` as formulas. Malicious payloads
/// can exfiltrate data or execute commands.
///
/// This function:
/// 1. Replaces CR, LF, and TAB with spaces (prevent multi-line injection).
/// 2. Prepends a single quote `'` if the trimmed value starts with a
///    formula-triggering character.
pub fn sanitize_csv_field(value: &str) -> String {
    let normalized = value.replace(['\r', '\n', '\t'], " ");

    let trimmed = normalized.trim_start();
    if trimmed.starts_with('=')
        || trimmed.starts_with('+')
        || trimmed.starts_with('-')
        || trimmed.starts_with('@')
    {
        format!("'{normalized}")
    } else {
        normalized
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn passthrough_safe_value() {
        assert_eq!(sanitize_csv_field("Hello World"), "Hello World");
    }

    #[test]
    fn prepend_quote_for_equals() {
        assert_eq!(sanitize_csv_field("=CMD()"), "'=CMD()");
    }

    #[test]
    fn prepend_quote_for_plus() {
        assert_eq!(sanitize_csv_field("+1234"), "'+1234");
    }

    #[test]
    fn prepend_quote_for_minus() {
        assert_eq!(sanitize_csv_field("-formula"), "'-formula");
    }

    #[test]
    fn prepend_quote_for_at() {
        assert_eq!(sanitize_csv_field("@SUM(A1)"), "'@SUM(A1)");
    }

    #[test]
    fn prepend_quote_for_leading_whitespace_then_equals() {
        // "  =CMD()" — after lstrip, starts with '=', so prepend quote to original
        assert_eq!(sanitize_csv_field("  =CMD()"), "'  =CMD()");
    }

    #[test]
    fn replaces_control_characters() {
        assert_eq!(
            sanitize_csv_field("line1\r\nline2\ttab"),
            "line1  line2 tab"
        );
    }

    #[test]
    fn empty_string_passthrough() {
        assert_eq!(sanitize_csv_field(""), "");
    }

    #[test]
    fn newline_followed_by_formula_char() {
        // "\n=CMD()" → " =CMD()" — trimmed starts with '=', prepend quote
        assert_eq!(sanitize_csv_field("\n=CMD()"), "' =CMD()");
    }
}
