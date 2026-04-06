//! Template variable substitution engine for catchup URLs.
//!
//! Translated from the anonymous namespace functions in `CatchupController.cpp`:
//! - `FormatDateTime()` — full template processing
//! - `FormatTime()` — single-char time format specifiers (`{Y}`, `{m}`, etc.)
//! - `FormatUnits()` — divisible time units (`{duration:N}`, `{offset:N}`)
//! - `FormatUtc()` — absolute timestamp substitution

use chrono::{DateTime, Datelike, Local, TimeZone, Timelike, Utc};
use regex::Regex;

/// Format a catchup URL template by substituting all time-related placeholders.
///
/// This is the main entry point, translated from `FormatDateTime()` in
/// `CatchupController.cpp`.
///
/// # Arguments
/// * `template` - URL template with placeholders
/// * `start` - Programme start time (UTC epoch seconds)
/// * `duration_secs` - Programme duration in seconds
/// * `catchup_id` - Optional programme catchup ID for `{catchup-id}` substitution
/// * `timezone_shift_secs` - Timezone offset to apply (channel tvg-shift + correction)
pub fn format_catchup_url(
    template: &str,
    start: i64,
    duration_secs: i64,
    catchup_id: Option<&str>,
    timezone_shift_secs: i32,
) -> String {
    format_catchup_url_with_granularity(
        template,
        start,
        duration_secs,
        catchup_id,
        timezone_shift_secs,
        1,
    )
}

/// Format a catchup URL template with granularity clamping.
///
/// When `granularity_secs > 1`, the effective duration is clamped (rounded down)
/// to the nearest multiple of `granularity_secs`. This matches Kodi's behaviour
/// where `FindCatchupSourceGranularitySeconds()` controls time precision.
///
/// # Arguments
/// * `template` - URL template with placeholders
/// * `start` - Programme start time (UTC epoch seconds)
/// * `duration_secs` - Programme duration in seconds
/// * `catchup_id` - Optional programme catchup ID for `{catchup-id}` substitution
/// * `timezone_shift_secs` - Timezone offset to apply (channel tvg-shift + correction)
/// * `granularity_secs` - Time granularity in seconds (1 = no clamping, 60 = minute boundaries)
pub fn format_catchup_url_with_granularity(
    template: &str,
    start: i64,
    duration_secs: i64,
    catchup_id: Option<&str>,
    timezone_shift_secs: i32,
    granularity_secs: i32,
) -> String {
    let clamped_duration = if granularity_secs > 1 {
        let g = granularity_secs as i64;
        (duration_secs / g) * g
    } else {
        duration_secs
    };

    let adjusted_start = start - timezone_shift_secs as i64;
    let now = Utc::now().timestamp() - timezone_shift_secs as i64;
    let end = adjusted_start + clamped_duration;

    let dt_start = timestamp_to_local(adjusted_start);
    let dt_end = timestamp_to_local(end);
    let dt_now = timestamp_to_local(now);

    let mut result = template.to_string();

    // Single-char time specifiers based on start time: {Y}, {m}, {d}, {H}, {M}, {S}
    format_time_char('Y', &dt_start, &mut result);
    format_time_char('m', &dt_start, &mut result);
    format_time_char('d', &dt_start, &mut result);
    format_time_char('H', &dt_start, &mut result);
    format_time_char('M', &dt_start, &mut result);
    format_time_char('S', &dt_start, &mut result);

    // Absolute UTC timestamps
    format_utc("{utc}", adjusted_start, &mut result);
    format_utc("${start}", adjusted_start, &mut result);
    format_utc("{utcend}", end, &mut result);
    format_utc("${end}", end, &mut result);
    format_utc("{lutc}", now, &mut result);
    format_utc("${now}", now, &mut result);
    format_utc("${timestamp}", now, &mut result);
    format_utc("${duration}", clamped_duration, &mut result);
    format_utc("{duration}", clamped_duration, &mut result);
    format_units("duration", clamped_duration, &mut result);
    format_utc("${offset}", now - adjusted_start, &mut result);
    format_units("offset", now - adjusted_start, &mut result);

    // Named time format strings: {utc:YmdHMS}, ${start:Y-m-d}, etc.
    format_time_named("utc", &dt_start, &mut result, false);
    format_time_named("start", &dt_start, &mut result, true);
    format_time_named("utcend", &dt_end, &mut result, false);
    format_time_named("end", &dt_end, &mut result, true);
    format_time_named("lutc", &dt_now, &mut result, false);
    format_time_named("now", &dt_now, &mut result, true);
    format_time_named("timestamp", &dt_now, &mut result, true);

    // {catchup-id} substitution
    if let Some(id) = catchup_id {
        result = result.replace("{catchup-id}", id);
    }

    result
}

/// Format only "now"-related timestamps in a URL template.
///
/// Used for live stream URL processing where only current-time placeholders
/// need substitution. Translated from `FormatDateTimeNowOnly()`.
///
/// If `programme_start > 0`, also processes start/end/duration specifiers.
pub fn format_now_only(
    template: &str,
    timezone_shift_secs: i32,
    programme_start: i64,
    programme_duration: i64,
) -> String {
    let now = Utc::now().timestamp() - timezone_shift_secs as i64;
    let dt_now = timestamp_to_local(now);

    let mut result = template.to_string();

    format_utc("{lutc}", now, &mut result);
    format_utc("${now}", now, &mut result);
    format_utc("${timestamp}", now, &mut result);
    format_time_named("lutc", &dt_now, &mut result, false);
    format_time_named("now", &dt_now, &mut result, true);
    format_time_named("timestamp", &dt_now, &mut result, true);

    if programme_start > 0 {
        let adjusted_start = programme_start - timezone_shift_secs as i64;
        let end = adjusted_start + programme_duration;
        let dt_start = timestamp_to_local(adjusted_start);
        let dt_end = timestamp_to_local(end);

        format_time_char('Y', &dt_start, &mut result);
        format_time_char('m', &dt_start, &mut result);
        format_time_char('d', &dt_start, &mut result);
        format_time_char('H', &dt_start, &mut result);
        format_time_char('M', &dt_start, &mut result);
        format_time_char('S', &dt_start, &mut result);

        format_utc("{utc}", adjusted_start, &mut result);
        format_utc("${start}", adjusted_start, &mut result);
        format_utc("{utcend}", end, &mut result);
        format_utc("${end}", end, &mut result);
        format_utc("{lutc}", now, &mut result);
        format_utc("${now}", now, &mut result);
        format_utc("${timestamp}", now, &mut result);
        format_utc("${duration}", programme_duration, &mut result);
        format_utc("{duration}", programme_duration, &mut result);
        format_units("duration", programme_duration, &mut result);
        format_utc("${offset}", now - adjusted_start, &mut result);
        format_units("offset", now - adjusted_start, &mut result);

        format_time_named("utc", &dt_start, &mut result, false);
        format_time_named("start", &dt_start, &mut result, true);
        format_time_named("utcend", &dt_end, &mut result, false);
        format_time_named("end", &dt_end, &mut result, true);
        format_time_named("lutc", &dt_now, &mut result, false);
        format_time_named("now", &dt_now, &mut result, true);
        format_time_named("timestamp", &dt_now, &mut result, true);
    }

    result
}

/// Validate whether a requested catchup time is within the allowed window.
///
/// # Arguments
/// * `requested_time` - The requested start time (UTC epoch seconds)
/// * `catchup_days` - Number of days in the catchup window (-1 to ignore)
///
/// Returns `true` if the time is within the window or the window is ignored.
pub fn is_within_catchup_window(requested_time: i64, catchup_days: i32) -> bool {
    if catchup_days < 0 {
        return true; // IGNORE_CATCHUP_DAYS
    }
    if catchup_days == 0 {
        return false;
    }
    let window_start = Utc::now().timestamp() - (catchup_days as i64 * 24 * 60 * 60);
    requested_time >= window_start
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Convert a UTC epoch timestamp to a local `DateTime`.
fn timestamp_to_local(epoch: i64) -> DateTime<Local> {
    Local
        .timestamp_opt(epoch, 0)
        .single()
        .unwrap_or_else(Local::now)
}

/// Replace a single-char time specifier `{ch}` with the formatted value.
///
/// Translated from `FormatTime(const char ch, ...)` in `CatchupController.cpp`.
/// Supports: Y (4-digit year), m (2-digit month), d (2-digit day),
/// H (2-digit hour), M (2-digit minute), S (2-digit second).
fn format_time_char(ch: char, dt: &DateTime<Local>, url: &mut String) {
    let placeholder = format!("{{{ch}}}");
    if !url.contains(&placeholder) {
        return;
    }

    let replacement = match ch {
        'Y' => format!("{:04}", dt.year()),
        'm' => format!("{:02}", dt.month()),
        'd' => format!("{:02}", dt.day()),
        'H' => format!("{:02}", dt.hour()),
        'M' => format!("{:02}", dt.minute()),
        'S' => format!("{:02}", dt.second()),
        _ => return,
    };

    while url.contains(&placeholder) {
        *url = url.replacen(&placeholder, &replacement, 1);
    }
}

/// Replace an absolute UTC timestamp placeholder with the epoch value.
///
/// Translated from `FormatUtc()` in `CatchupController.cpp`.
fn format_utc(placeholder: &str, epoch: i64, url: &mut String) {
    if let Some(pos) = url.find(placeholder) {
        let value = epoch.to_string();
        url.replace_range(pos..pos + placeholder.len(), &value);
    }
}

/// Replace `{name:N}` divisible-unit specifiers.
///
/// Translated from `FormatUnits()` in `CatchupController.cpp`.
/// E.g., `{duration:60}` divides the duration by 60 to get minutes.
fn format_units(name: &str, time: i64, url: &mut String) {
    let pattern = format!(r"\{{{}:(\d+)\}}", regex::escape(name));
    let re = Regex::new(&pattern).expect("dynamic units regex");

    if let Some(caps) = re.captures(url) {
        let full_match = caps.get(0).unwrap();
        let divider: i64 = caps.get(1).unwrap().as_str().parse().unwrap_or(1);

        if divider != 0 {
            let units = std::cmp::max(0, time / divider);
            let match_str = full_match.as_str().to_string();
            *url = url.replacen(&match_str, &units.to_string(), 1);
        }
    }
}

/// Replace named time format strings like `{utc:Y-m-d H:M:S}` or `${start:YmdHMS}`.
///
/// Translated from `FormatTime(const std::string name, ...)` in
/// `CatchupController.cpp`.
///
/// The format string inside the braces uses single-char specifiers:
/// Y, m, d, H, M, S — each replaced with the strftime equivalent `%Y`, etc.
fn format_time_named(name: &str, dt: &DateTime<Local>, url: &mut String, has_var_prefix: bool) {
    let qualifier = if has_var_prefix {
        format!("${{{name}:")
    } else {
        format!("{{{name}:")
    };

    let Some(found) = url.find(&qualifier) else {
        return;
    };

    let start = found + qualifier.len();
    let end = match url[start..].find('}') {
        Some(pos) => start + pos,
        None => return,
    };

    let format_str = &url[start..end];

    // Replace each single-char specifier with its value
    let mut formatted = format_str.to_string();
    formatted = formatted.replace('Y', &format!("{:04}", dt.year()));
    formatted = formatted.replace('m', &format!("{:02}", dt.month()));
    formatted = formatted.replace('d', &format!("{:02}", dt.day()));
    formatted = formatted.replace('H', &format!("{:02}", dt.hour()));
    formatted = formatted.replace('M', &format!("{:02}", dt.minute()));
    formatted = formatted.replace('S', &format!("{:02}", dt.second()));

    // Replace the entire qualifier...format} with the result
    let total_end = end + 1; // include closing '}'
    url.replace_range(found..total_end, &formatted);
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    /// Helper: create a fixed UTC timestamp for reproducible tests.
    /// 2024-03-15 14:30:45 UTC
    fn fixed_start() -> i64 {
        Utc.with_ymd_and_hms(2024, 3, 15, 14, 30, 45)
            .unwrap()
            .timestamp()
    }

    // Use a deterministic template test that doesn't depend on "now"
    // by using a template that only references start/end/duration.

    #[test]
    fn single_char_time_specifiers() {
        let start = fixed_start();
        let template = "http://example.com/{Y}/{m}/{d}/{H}/{M}/{S}";
        let result = format_catchup_url(template, start, 3600, None, 0);

        // The exact values depend on local timezone, but we can verify
        // the placeholders were replaced (no braces remain for those chars)
        assert!(!result.contains("{Y}"));
        assert!(!result.contains("{m}"));
        assert!(!result.contains("{d}"));
        assert!(!result.contains("{H}"));
        assert!(!result.contains("{M}"));
        assert!(!result.contains("{S}"));
    }

    #[test]
    fn absolute_utc_timestamps() {
        let start = fixed_start();
        let duration = 3600i64;
        let template = "http://example.com?start={utc}&end={utcend}&dur={duration}";
        let result = format_catchup_url(template, start, duration, None, 0);

        assert!(result.contains(&format!("start={start}")));
        assert!(result.contains(&format!("end={}", start + duration)));
        assert!(result.contains(&format!("dur={duration}")));
    }

    #[test]
    fn dollar_prefixed_timestamps() {
        let start = fixed_start();
        let duration = 7200i64;
        let template = "http://example.com?s=${start}&e=${end}&d=${duration}";
        let result = format_catchup_url(template, start, duration, None, 0);

        assert!(result.contains(&format!("s={start}")));
        assert!(result.contains(&format!("e={}", start + duration)));
        assert!(result.contains(&format!("d={duration}")));
    }

    #[test]
    fn duration_divisor_units() {
        let start = fixed_start();
        let duration = 7200i64; // 2 hours = 120 minutes
        let template = "http://example.com?dur={duration:60}";
        let result = format_catchup_url(template, start, duration, None, 0);

        assert_eq!(result, "http://example.com?dur=120");
    }

    #[test]
    fn duration_divisor_seconds() {
        let start = fixed_start();
        let duration = 3600i64;
        let template = "http://example.com?dur={duration:1}";
        let result = format_catchup_url(template, start, duration, None, 0);

        assert_eq!(result, "http://example.com?dur=3600");
    }

    #[test]
    fn named_time_format_utc() {
        let start = fixed_start();
        let template = "http://example.com?t={utc:Y-m-d H:M:S}";
        let result = format_catchup_url(template, start, 3600, None, 0);

        // Verify braces are gone and format is applied
        assert!(!result.contains("{utc:"));
        // Should contain date-like pattern (digits and separators)
        assert!(result.contains("?t="));
        // Verify it contains hyphens and colons from the format
        let time_part = result.split("?t=").nth(1).unwrap();
        assert!(time_part.contains('-'));
        assert!(time_part.contains(':'));
    }

    #[test]
    fn named_time_format_with_dollar_prefix() {
        let start = fixed_start();
        let template = "http://example.com?t=${start:Y-m-d}";
        let result = format_catchup_url(template, start, 3600, None, 0);

        assert!(!result.contains("${start:"));
        let time_part = result.split("?t=").nth(1).unwrap();
        assert!(time_part.contains('-'));
    }

    #[test]
    fn catchup_id_substitution() {
        let start = fixed_start();
        let template = "http://example.com/{catchup-id}";
        let result = format_catchup_url(template, start, 3600, Some("prog_12345"), 0);

        assert_eq!(result, "http://example.com/prog_12345");
    }

    #[test]
    fn catchup_id_no_substitution_when_none() {
        let start = fixed_start();
        let template = "http://example.com/{catchup-id}";
        let result = format_catchup_url(template, start, 3600, None, 0);

        assert_eq!(result, "http://example.com/{catchup-id}");
    }

    #[test]
    fn timezone_offset_applied() {
        let start = fixed_start();
        let duration = 3600i64;
        // Apply a 2-hour timezone shift
        let tz_shift = 7200;
        let template = "http://example.com?start={utc}";
        let result = format_catchup_url(template, start, duration, None, tz_shift);

        let expected_shifted = start - tz_shift as i64;
        assert!(result.contains(&format!("start={expected_shifted}")));
    }

    #[test]
    fn xtream_codes_full_template() {
        let start = fixed_start();
        let duration = 3600i64;
        let template =
            "http://list.tv:8080/timeshift/user/pass/{duration:60}/{Y}-{m}-{d}:{H}-{M}/1477.ts";
        let result = format_catchup_url(template, start, duration, None, 0);

        // Duration in minutes
        assert!(result.contains("/60/"));
        // No unresolved placeholders
        assert!(!result.contains("{duration"));
        assert!(!result.contains("{Y}"));
        assert!(!result.contains("{m}"));
        assert!(!result.contains("{d}"));
        assert!(!result.contains("{H}"));
        assert!(!result.contains("{M}"));
    }

    #[test]
    fn catchup_window_within() {
        let now = Utc::now().timestamp();
        // 1 hour ago is within a 7-day window
        assert!(is_within_catchup_window(now - 3600, 7));
    }

    #[test]
    fn catchup_window_outside() {
        let now = Utc::now().timestamp();
        // 8 days ago is outside a 7-day window
        assert!(!is_within_catchup_window(now - 8 * 86400, 7));
    }

    #[test]
    fn catchup_window_ignore() {
        // IGNORE_CATCHUP_DAYS (-1) always returns true
        assert!(is_within_catchup_window(0, -1));
    }

    #[test]
    fn catchup_window_zero_days() {
        let now = Utc::now().timestamp();
        assert!(!is_within_catchup_window(now, 0));
    }

    #[test]
    fn format_now_only_basic() {
        let template = "http://example.com?now=${now}";
        let result = format_now_only(template, 0, 0, 0);

        // ${now} should be replaced with a timestamp
        assert!(!result.contains("${now}"));
        let time_str = result.split("now=").nth(1).unwrap();
        let _ts: i64 = time_str.parse().expect("should be a number");
    }

    #[test]
    fn format_now_only_with_programme() {
        let start = fixed_start();
        let duration = 3600i64;
        let template = "http://example.com?s={utc}&d={duration}";
        let result = format_now_only(template, 0, start, duration);

        assert!(result.contains(&format!("s={start}")));
        assert!(result.contains(&format!("d={duration}")));
    }

    #[test]
    fn offset_units_specifier() {
        let start = fixed_start();
        let template = "http://example.com?o={offset:1}";
        let result = format_catchup_url(template, start, 3600, None, 0);

        // {offset:1} should be replaced with seconds since start
        assert!(!result.contains("{offset:"));
        let offset_str = result.split("o=").nth(1).unwrap();
        let offset: i64 = offset_str.parse().expect("should be a number");
        assert!(offset >= 0);
    }

    #[test]
    fn multiple_same_char_specifiers() {
        let start = fixed_start();
        let template = "http://example.com/{Y}/{Y}";
        let result = format_catchup_url(template, start, 3600, None, 0);

        // Both {Y} should be replaced
        assert!(!result.contains("{Y}"));
        let parts: Vec<&str> = result
            .trim_start_matches("http://example.com/")
            .split('/')
            .collect();
        assert_eq!(parts.len(), 2);
        assert_eq!(parts[0], parts[1]); // both should be the same year
    }

    #[test]
    fn negative_duration_clamped_to_zero() {
        let start = fixed_start();
        let template = "http://example.com?dur={duration:60}";
        let result = format_catchup_url(template, start, -120, None, 0);

        // Negative duration divided by 60 = negative, clamped to 0
        assert_eq!(result, "http://example.com?dur=0");
    }

    // -----------------------------------------------------------------------
    // Granularity clamping tests
    // -----------------------------------------------------------------------

    #[test]
    fn granularity_60_clamps_90s_to_60s() {
        let start = fixed_start();
        // 90s duration with 60s granularity → clamped to 60s
        let template = "http://example.com?dur=${duration}";
        let result = format_catchup_url_with_granularity(template, start, 90, None, 0, 60);

        assert!(result.contains("dur=60"));
    }

    #[test]
    fn granularity_1_no_clamping() {
        let start = fixed_start();
        // 90s duration with 1s granularity → no clamping, stays 90s
        let template = "http://example.com?dur=${duration}";
        let result = format_catchup_url_with_granularity(template, start, 90, None, 0, 1);

        assert!(result.contains("dur=90"));
    }

    #[test]
    fn granularity_60_clamps_duration_units_too() {
        let start = fixed_start();
        // 150s with granularity=60 → clamped to 120s. {duration:60} = 120/60 = 2 minutes
        let template = "http://example.com?dur={duration:60}";
        let result = format_catchup_url_with_granularity(template, start, 150, None, 0, 60);

        assert_eq!(result, "http://example.com?dur=2");
    }
}
