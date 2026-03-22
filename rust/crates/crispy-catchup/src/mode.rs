//! Catchup mode enum and configuration.
//!
//! Translated from Kodi pvr.iptvsimple `CatchupMode` enum in `Channel.h`
//! and the `ConfigureCatchupMode()` / validation helpers in `Channel.cpp`.

use serde::{Deserialize, Serialize};

use crate::error::CatchupError;
use crate::provider;

/// Catchup playback modes.
///
/// Mirrors the 8 modes from Kodi pvr.iptvsimple `CatchupMode` enum.
/// `Timeshift` is obsolete but still used by some providers; it behaves
/// identically to `Shift`.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CatchupMode {
    #[default]
    Disabled = 0,
    Default = 1,
    Append = 2,
    Shift = 3,
    Flussonic = 4,
    XtreamCodes = 5,
    Timeshift = 6,
    Vod = 7,
}

impl CatchupMode {
    /// Human-readable label for the mode.
    pub fn label(self) -> &'static str {
        match self {
            Self::Disabled => "Disabled",
            Self::Default => "Default",
            Self::Append => "Append",
            Self::Shift | Self::Timeshift => "Shift (SIPTV)",
            Self::Flussonic => "Flussonic",
            Self::XtreamCodes => "Xtream codes",
            Self::Vod => "VOD",
        }
    }
}

/// Convert from `crispy_iptv_types::CatchupType` to our `CatchupMode`.
impl From<crispy_iptv_types::CatchupType> for CatchupMode {
    fn from(ct: crispy_iptv_types::CatchupType) -> Self {
        match ct {
            crispy_iptv_types::CatchupType::Default => Self::Default,
            crispy_iptv_types::CatchupType::Append => Self::Append,
            crispy_iptv_types::CatchupType::Shift => Self::Shift,
            crispy_iptv_types::CatchupType::Flussonic => Self::Flussonic,
            crispy_iptv_types::CatchupType::Fs => Self::Flussonic,
            crispy_iptv_types::CatchupType::Xc => Self::XtreamCodes,
        }
    }
}

/// Fully resolved catchup configuration for a channel after
/// `ConfigureCatchupMode()` processing.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CatchupConfig {
    /// The active catchup mode.
    pub mode: CatchupMode,

    /// The fully-resolved URL template for catchup playback.
    /// Contains placeholders like `{utc}`, `{duration}`, `${start}`, etc.
    pub source: String,

    /// Number of catchup days available.
    pub catchup_days: i32,

    /// Whether the catchup source supports live-stream timeshifting.
    pub supports_timeshifting: bool,

    /// Whether the catchup stream terminates (has end-time specifier).
    pub terminates: bool,

    /// Granularity in seconds (1 = second-level, 60 = minute-level).
    pub granularity_seconds: i32,

    /// Whether the catchup stream is a TS (MPEG-TS) stream.
    pub is_ts_stream: bool,
}

impl Default for CatchupConfig {
    fn default() -> Self {
        Self {
            mode: CatchupMode::Disabled,
            source: String::new(),
            catchup_days: 0,
            supports_timeshifting: false,
            terminates: false,
            granularity_seconds: 1,
            is_ts_stream: false,
        }
    }
}

/// Sentinel value meaning "ignore catchup days limit".
pub const IGNORE_CATCHUP_DAYS: i32 = -1;

/// Configure catchup mode for a channel, generating the catchup source URL
/// template and determining stream properties.
///
/// Translated from `Channel::ConfigureCatchupMode()` in `Channel.cpp`.
///
/// # Arguments
/// * `mode` - The catchup mode from the M3U entry.
/// * `stream_url` - The channel's primary stream URL.
/// * `catchup_source` - The raw `catchup-source` attribute from M3U (may be empty).
/// * `catchup_days` - Number of catchup days (0 uses default, -1 ignores limit).
/// * `default_days` - Default catchup days from settings.
/// * `default_query_format` - Default catchup query format from settings.
/// * `is_ts_hint` - Whether the M3U entry hinted at a TS stream (e.g., "flussonic-ts" or "fs").
pub fn configure_catchup(
    mode: CatchupMode,
    stream_url: &str,
    catchup_source: &str,
    catchup_days: i32,
    default_days: i32,
    default_query_format: &str,
    is_ts_hint: bool,
) -> Result<CatchupConfig, CatchupError> {
    // Separate protocol options after "|" (Kodi convention)
    let (url, protocol_options) = split_protocol_options(stream_url);

    let mut append_protocol_options = true;
    let mut is_ts_stream = is_ts_hint;

    let resolved_source = match mode {
        CatchupMode::Disabled => {
            return Err(CatchupError::Disabled);
        }
        CatchupMode::Default => {
            if !catchup_source.is_empty() {
                if catchup_source.contains('|') {
                    append_protocol_options = false;
                }
                catchup_source.to_string()
            } else {
                generate_append_source(url, catchup_source, default_query_format)?
            }
        }
        CatchupMode::Append => generate_append_source(url, catchup_source, default_query_format)?,
        CatchupMode::Shift | CatchupMode::Timeshift => generate_shift_source(url),
        CatchupMode::Flussonic => {
            let (source, ts) = provider::generate_flussonic_source(url, is_ts_hint)?;
            is_ts_stream = ts;
            source
        }
        CatchupMode::XtreamCodes => {
            let (source, ts) = provider::generate_xtream_codes_source(url)?;
            is_ts_stream = ts;
            source
        }
        CatchupMode::Vod => {
            if !catchup_source.is_empty() {
                if catchup_source.contains('|') {
                    append_protocol_options = false;
                }
                catchup_source.to_string()
            } else {
                "{catchup-id}".to_string()
            }
        }
    };

    let mut source = resolved_source;
    if !protocol_options.is_empty() && append_protocol_options {
        source.push_str(protocol_options);
    }

    let days = if catchup_days > 0 || catchup_days == IGNORE_CATCHUP_DAYS {
        catchup_days
    } else {
        default_days
    };

    Ok(CatchupConfig {
        mode,
        supports_timeshifting: is_valid_timeshifting_source(&source, mode),
        terminates: is_terminating_source(&source),
        granularity_seconds: find_granularity_seconds(&source),
        source,
        catchup_days: days,
        is_ts_stream,
    })
}

/// Split a URL at the first `|` to separate Kodi protocol options.
fn split_protocol_options(url: &str) -> (&str, &str) {
    match url.find('|') {
        Some(pos) => (&url[..pos], &url[pos..]),
        None => (url, ""),
    }
}

/// Generate an "append" catchup source: base URL + query string.
///
/// From `Channel::GenerateAppendCatchupSource()`.
fn generate_append_source(
    url: &str,
    catchup_source: &str,
    default_query_format: &str,
) -> Result<String, CatchupError> {
    if !catchup_source.is_empty() {
        Ok(format!("{url}{catchup_source}"))
    } else if !default_query_format.is_empty() {
        Ok(format!("{url}{default_query_format}"))
    } else {
        Err(CatchupError::InvalidSource(
            "append mode requires a catchup source or default query format".to_string(),
        ))
    }
}

/// Generate a "shift" (SIPTV) catchup source.
///
/// From `Channel::GenerateShiftCatchupSource()`.
fn generate_shift_source(url: &str) -> String {
    if url.contains('?') {
        format!("{url}&utc={{utc}}&lutc={{lutc}}")
    } else {
        format!("{url}?utc={{utc}}&lutc={{lutc}}")
    }
}

/// Check if a catchup source supports live-stream timeshifting.
///
/// From `IsValidTimeshiftingCatchupSource()` in `Channel.cpp`.
fn is_valid_timeshifting_source(source: &str, mode: CatchupMode) -> bool {
    let specifier_re = regex::Regex::new(r"\{[^{]+\}").expect("static regex");
    let count = specifier_re.find_iter(source).count();

    if count > 0 {
        // If we only have {catchup-id} and nothing else, can't timeshift
        if (source.contains("{catchup-id}") && count == 1) || mode == CatchupMode::Vod {
            return false;
        }
        return true;
    }

    false
}

/// Check if a catchup source terminates (has end-time specifiers).
///
/// From `IsTerminatingCatchupSource()` in `Channel.cpp`.
fn is_terminating_source(source: &str) -> bool {
    source.contains("{duration}")
        || source.contains("{duration:")
        || source.contains("{lutc}")
        || source.contains("{lutc:")
        || source.contains("${timestamp}")
        || source.contains("${timestamp:")
        || source.contains("{utcend}")
        || source.contains("{utcend:")
        || source.contains("${end}")
        || source.contains("${end:")
}

/// Determine the granularity (in seconds) of a catchup source.
///
/// From `FindCatchupSourceGranularitySeconds()` in `Channel.cpp`.
fn find_granularity_seconds(source: &str) -> i32 {
    if source.contains("{utc}")
        || source.contains("{utc:")
        || source.contains("${start}")
        || source.contains("${start:")
        || source.contains("{S}")
        || source.contains("{offset:1}")
    {
        1
    } else {
        60
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn disabled_mode_returns_error() {
        let result = configure_catchup(
            CatchupMode::Disabled,
            "http://example.com/stream",
            "",
            7,
            7,
            "",
            false,
        );
        assert!(result.is_err());
    }

    #[test]
    fn default_mode_with_source() {
        let cfg = configure_catchup(
            CatchupMode::Default,
            "http://example.com/stream",
            "http://example.com/catchup?start={utc}&end={utcend}",
            5,
            7,
            "",
            false,
        )
        .unwrap();
        assert_eq!(cfg.mode, CatchupMode::Default);
        assert!(cfg.source.contains("{utc}"));
        assert_eq!(cfg.catchup_days, 5);
        assert!(cfg.supports_timeshifting);
        assert!(cfg.terminates); // has {utcend}
        assert_eq!(cfg.granularity_seconds, 1); // has {utc}
    }

    #[test]
    fn default_mode_falls_back_to_append() {
        let cfg = configure_catchup(
            CatchupMode::Default,
            "http://example.com/stream",
            "",
            0,
            7,
            "?utc={utc}&lutc={lutc}",
            false,
        )
        .unwrap();
        assert!(cfg.source.starts_with("http://example.com/stream?utc="));
    }

    #[test]
    fn append_mode_with_query() {
        let cfg = configure_catchup(
            CatchupMode::Append,
            "http://example.com/stream",
            "?start={utc}&dur={duration}",
            3,
            7,
            "",
            false,
        )
        .unwrap();
        assert_eq!(
            cfg.source,
            "http://example.com/stream?start={utc}&dur={duration}"
        );
        assert!(cfg.terminates);
        assert_eq!(cfg.granularity_seconds, 1);
    }

    #[test]
    fn shift_mode_without_query() {
        let cfg = configure_catchup(
            CatchupMode::Shift,
            "http://example.com/stream",
            "",
            7,
            7,
            "",
            false,
        )
        .unwrap();
        assert_eq!(
            cfg.source,
            "http://example.com/stream?utc={utc}&lutc={lutc}"
        );
        assert!(cfg.supports_timeshifting);
        assert!(cfg.terminates); // has {lutc}
        assert_eq!(cfg.granularity_seconds, 1); // has {utc}
    }

    #[test]
    fn shift_mode_with_existing_query() {
        let cfg = configure_catchup(
            CatchupMode::Shift,
            "http://example.com/stream?token=abc",
            "",
            7,
            7,
            "",
            false,
        )
        .unwrap();
        assert_eq!(
            cfg.source,
            "http://example.com/stream?token=abc&utc={utc}&lutc={lutc}"
        );
    }

    #[test]
    fn timeshift_mode_behaves_like_shift() {
        let cfg = configure_catchup(
            CatchupMode::Timeshift,
            "http://example.com/stream",
            "",
            7,
            7,
            "",
            false,
        )
        .unwrap();
        assert!(cfg.source.contains("utc={utc}"));
    }

    #[test]
    fn vod_mode_uses_catchup_id() {
        let cfg = configure_catchup(
            CatchupMode::Vod,
            "http://example.com/stream",
            "",
            -1,
            7,
            "",
            false,
        )
        .unwrap();
        assert_eq!(cfg.source, "{catchup-id}");
        assert!(!cfg.supports_timeshifting); // VOD doesn't support timeshifting
        assert_eq!(cfg.catchup_days, IGNORE_CATCHUP_DAYS);
    }

    #[test]
    fn vod_mode_with_custom_source() {
        let cfg = configure_catchup(
            CatchupMode::Vod,
            "http://example.com/stream",
            "http://example.com/vod/{catchup-id}",
            7,
            7,
            "",
            false,
        )
        .unwrap();
        assert_eq!(cfg.source, "http://example.com/vod/{catchup-id}");
    }

    #[test]
    fn protocol_options_appended() {
        let cfg = configure_catchup(
            CatchupMode::Shift,
            "http://example.com/stream|User-Agent=test",
            "",
            7,
            7,
            "",
            false,
        )
        .unwrap();
        assert!(cfg.source.ends_with("|User-Agent=test"));
    }

    #[test]
    fn catchup_days_uses_default_when_zero() {
        let cfg = configure_catchup(
            CatchupMode::Shift,
            "http://example.com/stream",
            "",
            0,
            14,
            "",
            false,
        )
        .unwrap();
        assert_eq!(cfg.catchup_days, 14);
    }

    #[test]
    fn catchup_id_only_source_cannot_timeshift() {
        assert!(!is_valid_timeshifting_source(
            "http://example.com/{catchup-id}",
            CatchupMode::Default
        ));
    }

    #[test]
    fn terminating_source_detection() {
        assert!(is_terminating_source("url?d={duration}"));
        assert!(is_terminating_source("url?d={duration:60}"));
        assert!(is_terminating_source("url?e={utcend}"));
        assert!(is_terminating_source("url?e=${end}"));
        assert!(is_terminating_source("url?l={lutc}"));
        assert!(is_terminating_source("url?t=${timestamp}"));
        assert!(!is_terminating_source("url?s={utc}"));
    }

    #[test]
    fn granularity_detection() {
        assert_eq!(find_granularity_seconds("url?s={utc}"), 1);
        assert_eq!(find_granularity_seconds("url?s=${start}"), 1);
        assert_eq!(find_granularity_seconds("url?s={S}"), 1);
        assert_eq!(find_granularity_seconds("url?o={offset:1}"), 1);
        assert_eq!(
            find_granularity_seconds("url?d={duration:60}&t={Y}-{m}-{d}:{H}-{M}"),
            60
        );
    }
}
