//! `From` implementations to convert new IPTV crate types into
//! crispy-core domain models.
//!
//! These keep the mapping logic co-located and make the parser
//! adapters one-liners (`entry.into()`).

use sha2::{Digest, Sha256};

use crate::models::{Channel, EpgEntry, Movie, Series};
use crate::utils::image_sanitizer::sanitize_image_url;

// ── Helpers ─────────────────────────────────────────

/// SHA-256 hash of `input`, truncated to the first 8 bytes (16 hex chars).
fn sha256_short(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    let hash = hasher.finalize();
    hash.iter()
        .take(8)
        .map(|b| format!("{b:02x}"))
        .collect::<String>()
}

/// Parse a `serde_json::Value` that may be a number or numeric string
/// into an `i64`.
fn json_value_as_i64(v: &serde_json::Value) -> Option<i64> {
    v.as_i64()
        .or_else(|| v.as_str().and_then(|s| s.parse::<i64>().ok()))
}

/// Parse a `serde_json::Value` into an `f64`.
fn json_value_as_f64(v: &serde_json::Value) -> Option<f64> {
    v.as_f64()
        .or_else(|| v.as_str().and_then(|s| s.parse::<f64>().ok()))
}

/// Extract a non-empty `String` from a `serde_json::Value`.
fn json_value_as_string(v: &serde_json::Value) -> Option<String> {
    v.as_str()
        .filter(|s| !s.is_empty())
        .map(String::from)
        .or_else(|| {
            // Fallback: stringify non-string values (e.g. integers).
            if !v.is_null() && !v.is_string() {
                Some(v.to_string())
            } else {
                None
            }
        })
}

// ── M3U → Channel ───────────────────────────────────

impl From<crispy_m3u::M3uEntry> for Channel {
    fn from(e: crispy_m3u::M3uEntry) -> Self {
        let url = e.url.clone().unwrap_or_default();
        let native_id = sha256_short(&url);

        let name = e.name.clone().unwrap_or_default();

        // Catchup detection.
        let catchup_type = e.catchup.clone();
        let catchup_days: i32 = e
            .catchup_days
            .as_deref()
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        let catchup_source = e.catchup_source.clone();
        let has_catchup = catchup_type.as_ref().is_some_and(|t| !t.is_empty()) && catchup_days > 0;

        // Channel number from tvg-chno.
        let number = e.tvg_chno.as_deref().and_then(|s| s.parse::<i32>().ok());

        // Timeshift.
        let tvg_shift = e.timeshift.as_deref().and_then(|s| s.parse::<f64>().ok());

        Channel {
            id: native_id.clone(),
            native_id,
            name,
            stream_url: url,
            number,
            channel_group: e.group_title,
            logo_url: sanitize_image_url(e.tvg_logo),
            tvg_id: e.tvg_id,
            tvg_name: e.tvg_name,
            is_favorite: false,
            user_agent: None,
            has_catchup,
            catchup_days,
            catchup_type,
            catchup_source,
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
            is_247: false,
            tvg_shift,
            tvg_language: e.tvg_language,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: e.tvg_rec,
            is_adult: false,
            custom_sid: None,
            direct_source: None,
            epg_channel_id: None,
            stalker_cmd: None,
            resolved_url: None,
            resolved_at: None,
        }
    }
}

// ── Xtream → Channel ───────────────────────────────

impl From<crispy_xtream::types::XtreamChannel> for Channel {
    fn from(xc: crispy_xtream::types::XtreamChannel) -> Self {
        let native_id = xc.stream_id.to_string();
        let id = format!("xc_{}", xc.stream_id);

        let tv_archive = xc.tv_archive.unwrap_or(0);
        let archive_dur = xc.tv_archive_duration.unwrap_or(0) as i32;
        let has_catchup = tv_archive == 1 && archive_dur > 0;

        let number = xc.num.map(|n| n as i32);

        let epg_channel_id = xc.epg_channel_id.clone();

        // tvg_id: use epg_channel_id if present, else stream_id.
        let tvg_id = epg_channel_id
            .clone()
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| native_id.clone());

        let added_at = xc
            .added
            .as_deref()
            .and_then(|s| s.parse::<i64>().ok())
            .and_then(|ts| chrono::DateTime::from_timestamp(ts, 0))
            .map(|dt| dt.naive_utc());

        Channel {
            id,
            native_id,
            name: xc.name.clone(),
            stream_url: xc.url.unwrap_or_default(),
            number,
            channel_group: xc.category_id.clone(),
            logo_url: sanitize_image_url(xc.stream_icon),
            tvg_id: Some(tvg_id),
            tvg_name: Some(xc.name),
            epg_channel_id,
            is_favorite: false,
            user_agent: None,
            has_catchup,
            catchup_days: archive_dur,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: None,
            added_at,
            updated_at: None,
            is_247: false,
            tvg_shift: None,
            tvg_language: None,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: None,
            is_adult: false,
            custom_sid: xc.custom_sid.filter(|s| !s.is_empty()),
            direct_source: xc.direct_source.filter(|s| !s.is_empty()),
            stalker_cmd: None,
            resolved_url: None,
            resolved_at: None,
        }
    }
}

// ── Stalker → Channel ──────────────────────────────

impl From<crispy_stalker::types::StalkerChannel> for Channel {
    fn from(sc: crispy_stalker::types::StalkerChannel) -> Self {
        let native_id = sc.id.clone();
        let id = format!("stk_{}", sc.id);

        let has_catchup = sc.has_archive && sc.archive_days > 0;

        Channel {
            id,
            native_id,
            name: sc.name,
            // The cmd is stored as stalker_cmd for later resolution;
            // stream_url is left empty until resolved.
            stream_url: String::new(),
            number: sc.number.map(|n| n as i32),
            channel_group: sc.tv_genre_id,
            logo_url: sanitize_image_url(sc.logo),
            tvg_id: None,
            tvg_name: None,
            epg_channel_id: sc.epg_channel_id,
            is_favorite: false,
            user_agent: None,
            has_catchup,
            catchup_days: sc.archive_days as i32,
            catchup_type: None,
            catchup_source: None,
            resolution: None,
            source_id: None,
            added_at: None,
            updated_at: None,
            is_247: false,
            tvg_shift: None,
            tvg_language: None,
            tvg_country: None,
            parent_code: None,
            is_radio: false,
            tvg_rec: None,
            is_adult: sc.is_censored,
            custom_sid: None,
            direct_source: None,
            stalker_cmd: Some(sc.cmd),
            resolved_url: None,
            resolved_at: None,
        }
    }
}

// ── XtreamMovieListing → Movie ─────────────────────

impl From<crispy_xtream::types::XtreamMovieListing> for Movie {
    fn from(m: crispy_xtream::types::XtreamMovieListing) -> Self {
        let native_id = m.stream_id.to_string();
        let id = format!("vod_{}", m.stream_id);

        let year = m.year.as_deref().and_then(|s| s.parse::<i32>().ok());

        let rating = m.rating.as_ref().and_then(json_value_as_string);
        let rating_5based = m.rating_5based.as_ref().and_then(json_value_as_f64);

        let duration_minutes = m
            .episode_run_time
            .as_ref()
            .and_then(|v| json_value_as_i64(v).map(|n| n as i32));

        let added_at = m
            .added
            .as_deref()
            .and_then(|s| s.parse::<i64>().ok())
            .and_then(|ts| chrono::DateTime::from_timestamp(ts, 0))
            .map(|dt| dt.naive_utc());

        Movie {
            id,
            source_id: String::new(),
            native_id,
            name: m.name,
            original_name: m.title,
            poster_url: sanitize_image_url(m.stream_icon),
            backdrop_url: None,
            description: m.plot.or(m.direct_source.clone().and(None)),
            stream_url: m.url,
            container_ext: m.container_extension,
            stalker_cmd: None,
            resolved_url: None,
            resolved_at: None,
            year,
            duration_minutes,
            rating,
            rating_5based,
            content_rating: None,
            genre: m.genre,
            youtube_trailer: m.youtube_trailer,
            tmdb_id: None,
            cast_names: m.cast,
            director: m.director,
            is_adult: false,
            added_at,
            updated_at: None,
        }
    }
}

// ── XtreamShowListing → Series ─────────────────────

impl From<crispy_xtream::types::XtreamShowListing> for Series {
    fn from(s: crispy_xtream::types::XtreamShowListing) -> Self {
        let native_id = s.series_id.to_string();
        let id = format!("series_{}", s.series_id);

        let year = s.year.as_deref().and_then(|y| y.parse::<i32>().ok());

        let rating = s.rating.as_ref().and_then(json_value_as_string);
        let rating_5based = s.rating_5based.as_ref().and_then(json_value_as_f64);

        let backdrop_url = s
            .backdrop_path
            .as_ref()
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .map(String::from);

        Series {
            id,
            source_id: String::new(),
            native_id,
            name: s.name,
            original_name: s.title,
            poster_url: sanitize_image_url(s.cover),
            backdrop_url,
            description: s.plot,
            year,
            genre: s.genre,
            content_rating: None,
            rating,
            rating_5based,
            youtube_trailer: s.youtube_trailer,
            tmdb_id: None,
            cast_names: s.cast,
            director: s.director,
            is_adult: false,
            added_at: None,
            updated_at: None,
        }
    }
}

// ── StalkerVodItem → Movie ─────────────────────────

impl From<crispy_stalker::types::StalkerVodItem> for Movie {
    fn from(v: crispy_stalker::types::StalkerVodItem) -> Self {
        let native_id = v.id.clone();
        let id = format!("stk_vod_{}", v.id);

        let year = v.year.as_deref().and_then(|s| s.parse::<i32>().ok());

        Movie {
            id,
            source_id: String::new(),
            native_id,
            name: v.name,
            original_name: None,
            poster_url: sanitize_image_url(v.logo),
            backdrop_url: None,
            description: v.description,
            stream_url: None,
            container_ext: None,
            stalker_cmd: Some(v.cmd),
            resolved_url: None,
            resolved_at: None,
            year,
            duration_minutes: None,
            rating: v.rating,
            rating_5based: None,
            content_rating: None,
            genre: v.genre,
            youtube_trailer: None,
            tmdb_id: v.tmdb_id,
            cast_names: v.cast,
            director: v.director,
            is_adult: false,
            added_at: None,
            updated_at: None,
        }
    }
}

// ── StalkerSeriesItem → Series ─────────────────────

impl From<crispy_stalker::types::StalkerSeriesItem> for Series {
    fn from(s: crispy_stalker::types::StalkerSeriesItem) -> Self {
        let native_id = s.id.clone();
        let id = format!("stk_series_{}", s.id);

        let year = s.year.as_deref().and_then(|y| y.parse::<i32>().ok());

        Series {
            id,
            source_id: String::new(),
            native_id,
            name: s.name,
            original_name: None,
            poster_url: sanitize_image_url(s.logo),
            backdrop_url: None,
            description: s.description,
            year,
            genre: s.genre,
            content_rating: None,
            rating: s.rating,
            rating_5based: None,
            youtube_trailer: None,
            tmdb_id: None,
            cast_names: s.cast,
            director: s.director,
            is_adult: false,
            added_at: None,
            updated_at: None,
        }
    }
}

// ── EpgProgramme (shared type) → EpgEntry ──────────

impl From<crispy_iptv_types::epg::EpgProgramme> for EpgEntry {
    fn from(p: crispy_iptv_types::epg::EpgProgramme) -> Self {
        let title = p.title.first().map(|t| t.value.clone()).unwrap_or_default();

        let description = p
            .desc
            .first()
            .map(|d| d.value.clone())
            .filter(|s| !s.is_empty());

        let sub_title = p
            .sub_title
            .first()
            .map(|s| s.value.clone())
            .filter(|s| !s.is_empty());

        let category = if p.category.is_empty() {
            None
        } else {
            Some(
                p.category
                    .iter()
                    .map(|c| c.value.as_str())
                    .collect::<Vec<_>>()
                    .join("; "),
            )
        };

        let icon_url = p.icon.as_ref().map(|i| i.src.clone());

        // Parse episode numbering (xmltv_ns format: "S.E.P").
        let (season, episode, episode_label) = parse_episode_numbers(&p.episode_num);

        let air_date = p.date.clone();

        let content_rating = p.rating.first().map(|r| r.value.clone());

        let star_rating = p.star_rating.first().map(|r| r.value.clone());

        let length_minutes = p.length.map(|l| l as i32);

        // Serialize credits to JSON if present.
        let credits_json = p
            .credits
            .as_ref()
            .and_then(|c| serde_json::to_string(c).ok());

        let start_time = p
            .start
            .and_then(|ts| chrono::DateTime::from_timestamp(ts, 0))
            .map(|dt| dt.naive_utc())
            .unwrap_or_else(|| {
                chrono::NaiveDateTime::new(
                    chrono::NaiveDate::from_ymd_opt(1970, 1, 1).unwrap(),
                    chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap(),
                )
            });

        let end_time = p
            .stop
            .and_then(|ts| chrono::DateTime::from_timestamp(ts, 0))
            .map(|dt| dt.naive_utc())
            .unwrap_or(start_time);

        EpgEntry {
            channel_id: p.channel,
            xmltv_id: None,
            title,
            start_time,
            end_time,
            description,
            category,
            icon_url,
            source_id: None,
            is_placeholder: false,
            sub_title,
            season,
            episode,
            episode_label,
            air_date,
            content_rating,
            star_rating,
            credits_json,
            language: None,
            country: None,
            is_rerun: p.is_rerun,
            is_new: p.is_new,
            is_premiere: p.is_premiere,
            length_minutes,
        }
    }
}

// ── Episode number parsing ──────────────────────────

/// Parse XMLTV episode numbering from the episode_num list.
///
/// Supports `xmltv_ns` format ("S.E.P" — zero-indexed) and
/// `onscreen` format (e.g. "S01E05").
fn parse_episode_numbers(
    nums: &[crispy_iptv_types::epg::EpgEpisodeNumber],
) -> (Option<i32>, Option<i32>, Option<String>) {
    let mut season = None;
    let mut episode = None;
    let mut label = None;

    for num in nums {
        match num.system.as_deref() {
            Some("xmltv_ns") => {
                // Format: "season.episode.part" — all zero-indexed.
                let parts: Vec<&str> = num.value.split('.').collect();
                if let Some(s) = parts.first()
                    && let Ok(n) = s.trim().parse::<i32>()
                {
                    season = Some(n + 1); // Convert to 1-indexed.
                }
                if let Some(e) = parts.get(1)
                    && let Ok(n) = e.trim().parse::<i32>()
                {
                    episode = Some(n + 1);
                }
            }
            Some("onscreen") => {
                label = Some(num.value.clone());
            }
            _ => {}
        }
    }

    (season, episode, label)
}

// ── Tests ───────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crispy_iptv_types::epg::{EpgEpisodeNumber, EpgIcon, EpgProgramme, EpgRating};

    #[test]
    fn m3u_entry_to_channel_basic() {
        let entry = crispy_m3u::M3uEntry {
            url: Some("http://example.com/stream".into()),
            name: Some("Test Channel".into()),
            tvg_id: Some("ch1".into()),
            group_title: Some("News".into()),
            tvg_logo: Some("http://logo.example.com/ch1.png".into()),
            ..Default::default()
        };

        let ch: Channel = entry.into();
        assert_eq!(ch.name, "Test Channel");
        assert_eq!(ch.tvg_id.as_deref(), Some("ch1"));
        assert_eq!(ch.channel_group.as_deref(), Some("News"));
        assert!(!ch.native_id.is_empty());
        assert_eq!(ch.stream_url, "http://example.com/stream");
    }

    #[test]
    fn m3u_entry_native_id_is_sha256_of_url() {
        let entry = crispy_m3u::M3uEntry {
            url: Some("http://example.com/stream".into()),
            name: Some("Test".into()),
            ..Default::default()
        };
        let ch: Channel = entry.into();
        assert_eq!(ch.native_id.len(), 16); // 8 bytes = 16 hex chars
        assert_eq!(ch.id, ch.native_id);
    }

    #[test]
    fn xtream_channel_to_channel() {
        let xc = crispy_xtream::types::XtreamChannel {
            stream_id: 42,
            name: "BBC One".into(),
            epg_channel_id: Some("bbc1.uk".into()),
            stream_icon: Some("http://icon.png".into()),
            tv_archive: Some(1),
            tv_archive_duration: Some(7),
            num: Some(5),
            url: Some("http://tv.example.com/live/u/p/42.ts".into()),
            stream_type: None,
            thumbnail: None,
            added: None,
            category_id: None,
            category_ids: Vec::new(),
            custom_sid: None,
            direct_source: None,
        };

        let ch: Channel = xc.into();
        assert_eq!(ch.id, "xc_42");
        assert_eq!(ch.native_id, "42");
        assert_eq!(ch.name, "BBC One");
        assert_eq!(ch.epg_channel_id.as_deref(), Some("bbc1.uk"));
        assert_eq!(ch.tvg_id.as_deref(), Some("bbc1.uk"));
        assert!(ch.has_catchup);
        assert_eq!(ch.catchup_days, 7);
        assert_eq!(ch.number, Some(5));
    }

    #[test]
    fn stalker_channel_to_channel() {
        let sc = crispy_stalker::types::StalkerChannel {
            id: "100".into(),
            name: "Local TV".into(),
            cmd: "ffrt http://stream.example.com/live".into(),
            has_archive: true,
            archive_days: 3,
            is_censored: true,
            epg_channel_id: Some("local.epg".into()),
            number: None,
            tv_genre_id: None,
            logo: None,
        };

        let ch: Channel = sc.into();
        assert_eq!(ch.id, "stk_100");
        assert_eq!(ch.native_id, "100");
        assert_eq!(
            ch.stalker_cmd.as_deref(),
            Some("ffrt http://stream.example.com/live"),
        );
        assert!(ch.has_catchup);
        assert_eq!(ch.catchup_days, 3);
        assert!(ch.is_adult);
        assert_eq!(ch.epg_channel_id.as_deref(), Some("local.epg"));
    }

    #[test]
    fn xtream_movie_listing_to_movie() {
        let ml = crispy_xtream::types::XtreamMovieListing {
            stream_id: 99,
            name: "Test Movie".into(),
            year: Some("2024".into()),
            genre: Some("Action".into()),
            container_extension: Some("mkv".into()),
            url: Some("http://example.com/movie/u/p/99.mkv".into()),
            num: None,
            title: None,
            stream_type: None,
            stream_icon: None,
            rating: None,
            rating_5based: None,
            added: None,
            episode_run_time: None,
            category_id: None,
            category_ids: Vec::new(),
            custom_sid: None,
            direct_source: None,
            release_date: None,
            cast: None,
            director: None,
            plot: None,
            youtube_trailer: None,
        };

        let movie: Movie = ml.into();
        assert_eq!(movie.id, "vod_99");
        assert_eq!(movie.native_id, "99");
        assert_eq!(movie.name, "Test Movie");
        assert_eq!(movie.year, Some(2024));
        assert_eq!(movie.genre.as_deref(), Some("Action"));
        assert_eq!(movie.container_ext.as_deref(), Some("mkv"));
    }

    #[test]
    fn xtream_show_listing_to_series() {
        let sl = crispy_xtream::types::XtreamShowListing {
            series_id: 55,
            name: "Test Series".into(),
            year: Some("2023".into()),
            genre: Some("Drama".into()),
            cover: Some("http://cover.png".into()),
            num: None,
            title: None,
            stream_type: None,
            plot: None,
            cast: None,
            director: None,
            release_date: None,
            last_modified: None,
            rating: None,
            rating_5based: None,
            backdrop_path: None,
            youtube_trailer: None,
            episode_run_time: None,
            category_id: None,
            category_ids: Vec::new(),
        };

        let series: Series = sl.into();
        assert_eq!(series.id, "series_55");
        assert_eq!(series.native_id, "55");
        assert_eq!(series.name, "Test Series");
        assert_eq!(series.year, Some(2023));
    }

    #[test]
    fn stalker_vod_item_to_movie() {
        let vi = crispy_stalker::types::StalkerVodItem {
            id: "200".into(),
            name: "Stalker Movie".into(),
            cmd: "ffrt http://stream/movie".into(),
            year: Some("2022".into()),
            rating: Some("7.5".into()),
            tmdb_id: Some(12345),
            category_id: None,
            logo: None,
            description: None,
            genre: None,
            director: None,
            cast: None,
            duration: None,
        };

        let movie: Movie = vi.into();
        assert_eq!(movie.id, "stk_vod_200");
        assert_eq!(movie.native_id, "200");
        assert_eq!(
            movie.stalker_cmd.as_deref(),
            Some("ffrt http://stream/movie"),
        );
        assert_eq!(movie.year, Some(2022));
        assert_eq!(movie.tmdb_id, Some(12345));
    }

    #[test]
    fn stalker_series_item_to_series() {
        let si = crispy_stalker::types::StalkerSeriesItem {
            id: "300".into(),
            name: "Stalker Series".into(),
            year: Some("2021".into()),
            genre: Some("Comedy".into()),
            category_id: None,
            logo: None,
            description: None,
            rating: None,
            director: None,
            cast: None,
        };

        let series: Series = si.into();
        assert_eq!(series.id, "stk_series_300");
        assert_eq!(series.native_id, "300");
        assert_eq!(series.year, Some(2021));
    }

    #[test]
    fn epg_programme_to_epg_entry() {
        use crispy_iptv_types::epg::EpgStringWithLang;

        let mut prog = EpgProgramme {
            channel: "ch1".into(),
            start: Some(1705320000),
            stop: Some(1705323600),
            is_new: true,
            is_rerun: false,
            is_premiere: true,
            length: Some(60),
            ..Default::default()
        };
        prog.title.push(EpgStringWithLang::new("Morning Show"));
        prog.desc.push(EpgStringWithLang::new("Daily news"));
        prog.sub_title.push(EpgStringWithLang::new("Episode 5"));
        prog.category.push(EpgStringWithLang::new("News"));
        prog.category
            .push(EpgStringWithLang::new("Current Affairs"));
        prog.icon = Some(EpgIcon {
            src: "http://icon.png".into(),
            width: None,
            height: None,
        });
        prog.episode_num.push(EpgEpisodeNumber {
            value: "2.4.0".into(),
            system: Some("xmltv_ns".into()),
        });
        prog.rating.push(EpgRating {
            value: "PG-13".into(),
            system: None,
        });
        prog.star_rating.push(EpgRating {
            value: "7.5/10".into(),
            system: None,
        });

        let entry: EpgEntry = prog.into();
        assert_eq!(entry.channel_id, "ch1");
        assert_eq!(entry.title, "Morning Show");
        assert_eq!(entry.description.as_deref(), Some("Daily news"));
        assert_eq!(entry.sub_title.as_deref(), Some("Episode 5"));
        assert_eq!(entry.category.as_deref(), Some("News; Current Affairs"),);
        assert_eq!(entry.icon_url.as_deref(), Some("http://icon.png"));
        assert_eq!(entry.season, Some(3)); // 2 + 1 (zero-indexed)
        assert_eq!(entry.episode, Some(5)); // 4 + 1
        assert_eq!(entry.content_rating.as_deref(), Some("PG-13"));
        assert_eq!(entry.star_rating.as_deref(), Some("7.5/10"));
        assert!(entry.is_new);
        assert!(entry.is_premiere);
        assert!(!entry.is_rerun);
        assert_eq!(entry.length_minutes, Some(60));
    }

    #[test]
    fn epg_programme_empty_title_maps_empty() {
        let prog = EpgProgramme {
            channel: "ch2".into(),
            start: Some(1705320000),
            stop: Some(1705323600),
            ..Default::default()
        };

        let entry: EpgEntry = prog.into();
        assert!(entry.title.is_empty());
    }

    #[test]
    fn parse_episode_numbers_xmltv_ns() {
        let nums = vec![EpgEpisodeNumber {
            value: "1.3.0".into(),
            system: Some("xmltv_ns".into()),
        }];

        let (s, e, _) = parse_episode_numbers(&nums);
        assert_eq!(s, Some(2));
        assert_eq!(e, Some(4));
    }

    #[test]
    fn parse_episode_numbers_onscreen() {
        let nums = vec![EpgEpisodeNumber {
            value: "S01E05".into(),
            system: Some("onscreen".into()),
        }];

        let (_, _, label) = parse_episode_numbers(&nums);
        assert_eq!(label.as_deref(), Some("S01E05"));
    }
}
