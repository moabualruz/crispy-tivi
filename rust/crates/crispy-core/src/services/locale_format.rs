//! Locale-aware formatting for numbers, durations, dates, and relative time.
//!
//! All functions are pure — no global state — and accept a locale string
//! (`"en"`, `"ar"`, …) to select the appropriate format.

use chrono::{Datelike, NaiveDateTime};

// ── Arabic digits ─────────────────────────────────────────────────────────────

/// Replace ASCII digits with Arabic-Indic digits (U+0660–U+0669).
fn to_arabic_digits(s: &str) -> String {
    s.chars()
        .map(|c| match c {
            '0' => '٠',
            '1' => '١',
            '2' => '٢',
            '3' => '٣',
            '4' => '٤',
            '5' => '٥',
            '6' => '٦',
            '7' => '٧',
            '8' => '٨',
            '9' => '٩',
            other => other,
        })
        .collect()
}

// ── Number formatting ─────────────────────────────────────────────────────────

/// Format a number with locale-appropriate thousands separator and decimal point.
///
/// | Locale | Thousands | Decimal |
/// |--------|-----------|---------|
/// | `en`   | `,`       | `.`     |
/// | `ar`   | `٬` (U+202F narrow nb-sp, displayed as `،`) | `٫` |
/// | others | `,`       | `.`     |
pub fn format_number(n: f64, locale: &str) -> String {
    let is_ar = locale.starts_with("ar");

    // Decide decimal places based on whether there's a fractional part.
    if n.fract() == 0.0 {
        format_integer(n as i64, is_ar)
    } else {
        format_decimal(n, is_ar)
    }
}

fn format_integer(n: i64, arabic: bool) -> String {
    let abs = n.unsigned_abs();
    let s = insert_thousands(abs, if arabic { "٬" } else { "," });
    let result = if n < 0 { format!("-{s}") } else { s };
    if arabic {
        to_arabic_digits(&result)
    } else {
        result
    }
}

fn format_decimal(n: f64, arabic: bool) -> String {
    // Two decimal places
    let int_part = n.trunc() as i64;
    let frac = (n.abs().fract() * 100.0).round() as u64;
    let int_str = insert_thousands(int_part.unsigned_abs(), if arabic { "٬" } else { "," });
    let sep = if arabic { "٫" } else { "." };
    let result = if int_part < 0 {
        format!("-{int_str}{sep}{frac:02}")
    } else {
        format!("{int_str}{sep}{frac:02}")
    };
    if arabic {
        to_arabic_digits(&result)
    } else {
        result
    }
}

fn insert_thousands(n: u64, sep: &str) -> String {
    let s = n.to_string();
    let chars: Vec<char> = s.chars().collect();
    let len = chars.len();
    let mut out = String::with_capacity(s.len() + (len / 3) * sep.len());
    for (i, ch) in chars.iter().enumerate() {
        if i > 0 && (len - i).is_multiple_of(3) {
            out.push_str(sep);
        }
        out.push(*ch);
    }
    out
}

// ── Duration formatting ───────────────────────────────────────────────────────

/// Format a duration in minutes as a human-readable string.
///
/// - `en`: `"1h 30m"` / `"45m"`
/// - `ar`: `"١ ساعة ٣٠ دقيقة"` / `"٤٥ دقيقة"`
pub fn format_duration(total_minutes: u32, locale: &str) -> String {
    let hours = total_minutes / 60;
    let minutes = total_minutes % 60;
    let is_ar = locale.starts_with("ar");

    if is_ar {
        if hours == 0 {
            let m = to_arabic_digits(&minutes.to_string());
            format!("{m} دقيقة")
        } else if minutes == 0 {
            let h = to_arabic_digits(&hours.to_string());
            format!("{h} ساعة")
        } else {
            let h = to_arabic_digits(&hours.to_string());
            let m = to_arabic_digits(&minutes.to_string());
            format!("{h} ساعة {m} دقيقة")
        }
    } else if hours == 0 {
        format!("{minutes}m")
    } else if minutes == 0 {
        format!("{hours}h")
    } else {
        format!("{hours}h {minutes}m")
    }
}

// ── Date formatting ───────────────────────────────────────────────────────────

/// Format a `NaiveDateTime` using locale-appropriate date representation.
///
/// - `en`: `"March 18, 2026"`
/// - `ar`: `"١٨ مارس ٢٠٢٦"`
/// - others: ISO `"2026-03-18"`
pub fn format_date(date: NaiveDateTime, locale: &str) -> String {
    let lang = locale.split('-').next().unwrap_or(locale);
    match lang {
        "en" => {
            let month = english_month(date.month());
            format!("{month} {}, {}", date.day(), date.year())
        }
        "ar" => {
            let day = to_arabic_digits(&date.day().to_string());
            let month = arabic_month(date.month());
            let year = to_arabic_digits(&date.year().to_string());
            format!("{day} {month} {year}")
        }
        _ => {
            // ISO 8601 fallback
            format!("{}", date.format("%Y-%m-%d"))
        }
    }
}

fn english_month(m: u32) -> &'static str {
    match m {
        1 => "January",
        2 => "February",
        3 => "March",
        4 => "April",
        5 => "May",
        6 => "June",
        7 => "July",
        8 => "August",
        9 => "September",
        10 => "October",
        11 => "November",
        12 => "December",
        _ => "Unknown",
    }
}

fn arabic_month(m: u32) -> &'static str {
    match m {
        1 => "يناير",
        2 => "فبراير",
        3 => "مارس",
        4 => "أبريل",
        5 => "مايو",
        6 => "يونيو",
        7 => "يوليو",
        8 => "أغسطس",
        9 => "سبتمبر",
        10 => "أكتوبر",
        11 => "نوفمبر",
        12 => "ديسمبر",
        _ => "غير معروف",
    }
}

// ── Relative time formatting ──────────────────────────────────────────────────

/// Format a relative time offset as a human-readable string.
///
/// - `en`: `"just now"`, `"5 minutes ago"`, `"2 hours ago"`, `"3 days ago"`
/// - `ar`: `"الآن"`, `"منذ ٥ دقائق"`, `"منذ ٢ ساعة"`, `"منذ ٣ أيام"`
///
/// Negative values are treated as future ("in N minutes") in English,
/// but the current implementation clamps to `"just now"` for simplicity.
pub fn format_relative_time(seconds_ago: i64, locale: &str) -> String {
    let is_ar = locale.starts_with("ar");
    let abs = seconds_ago.abs();

    if abs < 60 {
        if is_ar {
            "الآن".to_string()
        } else {
            "just now".to_string()
        }
    } else if abs < 3600 {
        let minutes = abs / 60;
        if is_ar {
            let m = to_arabic_digits(&minutes.to_string());
            format!("منذ {m} {}", arabic_minutes_word(minutes as u64))
        } else {
            let unit = if minutes == 1 { "minute" } else { "minutes" };
            format!("{minutes} {unit} ago")
        }
    } else if abs < 86_400 {
        let hours = abs / 3600;
        if is_ar {
            let h = to_arabic_digits(&hours.to_string());
            format!("منذ {h} {}", arabic_hours_word(hours as u64))
        } else {
            let unit = if hours == 1 { "hour" } else { "hours" };
            format!("{hours} {unit} ago")
        }
    } else {
        let days = abs / 86_400;
        if is_ar {
            let d = to_arabic_digits(&days.to_string());
            format!("منذ {d} {}", arabic_days_word(days as u64))
        } else {
            let unit = if days == 1 { "day" } else { "days" };
            format!("{days} {unit} ago")
        }
    }
}

/// Selects the Arabic word for "minutes" based on count (simplified plural).
fn arabic_minutes_word(n: u64) -> &'static str {
    match n {
        1 => "دقيقة",
        2 => "دقيقتان",
        3..=10 => "دقائق",
        _ => "دقيقة",
    }
}

fn arabic_hours_word(n: u64) -> &'static str {
    match n {
        1 => "ساعة",
        2 => "ساعتان",
        3..=10 => "ساعات",
        _ => "ساعة",
    }
}

fn arabic_days_word(n: u64) -> &'static str {
    match n {
        1 => "يوم",
        2 => "يومان",
        3..=10 => "أيام",
        _ => "يوم",
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;

    // ── format_number ─────────────────────────────────────────────────────

    #[test]
    fn test_format_number_en_integer() {
        assert_eq!(format_number(1_000_000.0, "en"), "1,000,000");
    }

    #[test]
    fn test_format_number_en_decimal() {
        assert_eq!(format_number(1_234.56, "en"), "1,234.56");
    }

    #[test]
    fn test_format_number_en_small() {
        assert_eq!(format_number(42.0, "en"), "42");
    }

    #[test]
    fn test_format_number_ar_integer() {
        let result = format_number(1_000.0, "ar");
        // Should contain Arabic digits
        assert!(
            result.contains('١') || result.contains('٠'),
            "got: {result}"
        );
    }

    #[test]
    fn test_format_number_ar_decimal_uses_arabic_decimal_sep() {
        let result = format_number(3.14, "ar");
        assert!(
            result.contains('٫'),
            "expected Arabic decimal sep, got: {result}"
        );
    }

    #[test]
    fn test_format_number_negative_en() {
        assert_eq!(format_number(-5_000.0, "en"), "-5,000");
    }

    // ── format_duration ───────────────────────────────────────────────────

    #[test]
    fn test_format_duration_en_hours_minutes() {
        assert_eq!(format_duration(90, "en"), "1h 30m");
    }

    #[test]
    fn test_format_duration_en_minutes_only() {
        assert_eq!(format_duration(45, "en"), "45m");
    }

    #[test]
    fn test_format_duration_en_hours_only() {
        assert_eq!(format_duration(120, "en"), "2h");
    }

    #[test]
    fn test_format_duration_ar_hours_minutes() {
        let result = format_duration(90, "ar");
        assert!(
            result.contains("ساعة") && result.contains("دقيقة"),
            "got: {result}"
        );
        // Should use Arabic digits
        assert!(result.contains('١'), "got: {result}");
    }

    #[test]
    fn test_format_duration_ar_minutes_only() {
        let result = format_duration(30, "ar");
        assert!(result.contains("دقيقة"), "got: {result}");
    }

    #[test]
    fn test_format_duration_zero_minutes() {
        assert_eq!(format_duration(0, "en"), "0m");
    }

    // ── format_date ───────────────────────────────────────────────────────

    #[test]
    fn test_format_date_en() {
        let dt = NaiveDate::from_ymd_opt(2026, 3, 18)
            .unwrap()
            .and_hms_opt(0, 0, 0)
            .unwrap();
        assert_eq!(format_date(dt, "en"), "March 18, 2026");
    }

    #[test]
    fn test_format_date_ar() {
        let dt = NaiveDate::from_ymd_opt(2026, 3, 18)
            .unwrap()
            .and_hms_opt(0, 0, 0)
            .unwrap();
        let result = format_date(dt, "ar");
        assert!(result.contains("مارس"), "got: {result}");
        assert!(
            result.contains('١'),
            "expected Arabic digits, got: {result}"
        );
    }

    #[test]
    fn test_format_date_fallback_iso() {
        let dt = NaiveDate::from_ymd_opt(2026, 3, 18)
            .unwrap()
            .and_hms_opt(0, 0, 0)
            .unwrap();
        assert_eq!(format_date(dt, "de"), "2026-03-18");
    }

    // ── format_relative_time ──────────────────────────────────────────────

    #[test]
    fn test_relative_time_en_just_now() {
        assert_eq!(format_relative_time(30, "en"), "just now");
    }

    #[test]
    fn test_relative_time_en_minutes() {
        assert_eq!(format_relative_time(300, "en"), "5 minutes ago");
    }

    #[test]
    fn test_relative_time_en_one_minute() {
        assert_eq!(format_relative_time(60, "en"), "1 minute ago");
    }

    #[test]
    fn test_relative_time_en_hours() {
        assert_eq!(format_relative_time(7200, "en"), "2 hours ago");
    }

    #[test]
    fn test_relative_time_en_one_hour() {
        assert_eq!(format_relative_time(3600, "en"), "1 hour ago");
    }

    #[test]
    fn test_relative_time_en_days() {
        assert_eq!(format_relative_time(86_400 * 3, "en"), "3 days ago");
    }

    #[test]
    fn test_relative_time_ar_just_now() {
        assert_eq!(format_relative_time(10, "ar"), "الآن");
    }

    #[test]
    fn test_relative_time_ar_minutes() {
        let result = format_relative_time(300, "ar");
        assert!(
            result.contains("منذ") && result.contains("دقائق"),
            "got: {result}"
        );
    }

    #[test]
    fn test_relative_time_ar_hours() {
        let result = format_relative_time(7200, "ar");
        assert!(
            result.contains("منذ") && result.contains("ساعتان"),
            "got: {result}"
        );
    }

    #[test]
    fn test_relative_time_ar_days() {
        let result = format_relative_time(86_400 * 5, "ar");
        assert!(
            result.contains("منذ") && result.contains("أيام"),
            "got: {result}"
        );
    }
}
