//! Logo resolution service using the tv-logo/tv-logos GitHub repository.
//!
//! Provides channel name normalisation, 4-strategy matching cascade,
//! and KV-store-based caching with 24-hour expiry.

use std::collections::HashMap;
use std::sync::LazyLock;

use regex::Regex;
use rusqlite::params;
use serde::Deserialize;

use super::ServiceContext;
use crate::database::DbError;
use crate::insert_or_replace;

// ── Constants ──────────────────────────────────────────

const LOGO_INDEX_KEY: &str = "logo_index";
const LOGO_INDEX_TS_KEY: &str = "logo_index_ts";
const CACHE_DURATION_SECS: i64 = 24 * 60 * 60;

const BASE_URL: &str = "https://raw.githubusercontent.com/tv-logo/tv-logos/main/countries";
const API_BASE: &str = "https://api.github.com/repos/tv-logo/tv-logos/contents/countries";

const DIRECTORIES: &[&str] = &["united-states", "international", "canada", "united-kingdom"];

const NOISE_SUFFIXES: &[&str] = &["-news", "-sport", "-nfl", "-nba"];

// ── Regex patterns ─────────────────────────────────────

static IPTV_PREFIX: LazyLock<Regex> = LazyLock::new(|| {
    // Matches: "US-P|", "CA:", "[UK]", "US ", etc.
    Regex::new(
        r"(?i)^(\[?[A-Za-z]{2}\]?[-]?[A-Za-z]?\|\s*|\[?[A-Za-z]{2}\]?:\s*|\[?[A-Za-z]{2}\]?\s+)",
    )
    .unwrap()
});

static QUALITY_TAG: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\b(HD|FHD|4K|UHD|HEVC|H\.?265|SD)\b").unwrap());

static PARENS: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\([^)]*\)").unwrap());

static NON_ALNUM: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[^a-z0-9]+").unwrap());

static MULTI_HYPHEN: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"-+").unwrap());

// ── Name normalisation ─────────────────────────────────

/// Normalise a channel name for logo matching.
///
/// Steps: strip IPTV prefixes, remove quality tags,
/// remove parenthesised content, lowercase, replace
/// non-alphanumeric with hyphens, collapse, trim.
pub fn normalize_logo_name(name: &str) -> String {
    let mut n = name.to_lowercase();
    n = n.trim().to_string();

    // Strip IPTV prefixes.
    let stripped = IPTV_PREFIX.replace(&n, "").to_string();
    if stripped.is_empty() {
        // If stripping emptied it, keep original.
    } else {
        n = stripped;
    }

    // Remove quality tags.
    n = QUALITY_TAG.replace_all(&n, "").to_string();

    // Remove parenthesised content.
    n = PARENS.replace_all(&n, "").to_string();

    // Replace non-alphanumeric with hyphens.
    n = NON_ALNUM.replace_all(&n, "-").to_string();

    // Collapse multiple hyphens.
    n = MULTI_HYPHEN.replace_all(&n, "-").to_string();

    // Trim leading/trailing hyphens.
    n.trim_matches('-').to_string()
}

/// Normalise a logo filename: strip `.png` and country suffixes.
fn normalize_filename(filename: &str) -> String {
    let mut name = filename.replace(".png", "");
    for suffix in ["-us", "-uk", "-ca", "-int"] {
        if name.ends_with(suffix) {
            name.truncate(name.len() - suffix.len());
            break;
        }
    }
    name.to_lowercase().trim().to_string()
}

/// Generate common aliases for channel name matching.
fn get_aliases(normalized: &str) -> Vec<String> {
    let mut aliases = Vec::new();

    // Strip known suffixes.
    if normalized.contains("-network") {
        aliases.push(normalized.replace("-network", ""));
    }
    if normalized.contains("-channel") {
        aliases.push(normalized.replace("-channel", ""));
    }

    // Strip known prefixes.
    if let Some(rest) = normalized.strip_prefix("the-") {
        aliases.push(rest.to_string());
    }
    for prefix in ["usa-", "us-", "ca-", "uk-"] {
        if let Some(rest) = normalized.strip_prefix(prefix) {
            aliases.push(rest.to_string());
        }
    }

    // Add common suffixes.
    aliases.push(format!("{normalized}-network"));
    aliases.push(format!("{normalized}-channel"));
    aliases.push(format!("{normalized}-hz"));
    aliases.push(format!("{normalized}-logo-white"));
    aliases.push(format!("{normalized}-logo-2013-default"));

    aliases
}

// ── Core resolution algorithm ──────────────────────────

/// Resolve a channel name against the cached index using
/// the 4-strategy cascade.
fn resolve_from_index(index: &HashMap<String, String>, channel_name: &str) -> Option<String> {
    let normalized = normalize_logo_name(channel_name);
    if normalized.is_empty() {
        return None;
    }

    // Strategy 1: Exact match.
    if let Some(url) = index.get(&normalized) {
        return Some(url.clone());
    }

    // Strategy 2: Alias variants.
    for alias in get_aliases(&normalized) {
        if let Some(url) = index.get(&alias) {
            return Some(url.clone());
        }
    }

    // Strategy 3: Prefix match — prefer shortest non-noise.
    let prefix_matches: Vec<&String> = index
        .keys()
        .filter(|k| k.starts_with(&normalized))
        .collect();

    if !prefix_matches.is_empty() {
        // Prefer "-logo" variants.
        let logo_prefix = format!("{normalized}-logo");
        let mut logo_variants: Vec<&&String> = prefix_matches
            .iter()
            .filter(|k| k.starts_with(&logo_prefix))
            .collect();
        if !logo_variants.is_empty() {
            logo_variants.sort_by_key(|k| k.len());
            return index.get(*logo_variants[0]).cloned();
        }

        // Filter out noise, pick shortest.
        let mut plain: Vec<&&String> = prefix_matches
            .iter()
            .filter(|k| !NOISE_SUFFIXES.iter().any(|s| k.contains(s)))
            .collect();
        if !plain.is_empty() {
            plain.sort_by_key(|k| k.len());
            return index.get(*plain[0]).cloned();
        }

        // Fallback: shortest overall.
        let shortest = prefix_matches.iter().min_by_key(|k| k.len()).unwrap();
        return index.get(*shortest).cloned();
    }

    // Strategy 4: Contains match — prefer closest length.
    let mut contains_matches: Vec<&String> = index
        .keys()
        .filter(|k| (k.contains(&normalized) || normalized.contains(k.as_str())) && k.len() > 2)
        .collect();

    if !contains_matches.is_empty() {
        contains_matches.sort_by_key(|k| (k.len() as i64 - normalized.len() as i64).unsigned_abs());
        return index.get(contains_matches[0]).cloned();
    }

    None
}

// ── CrispyService methods ──────────────────────────────

/// Domain service for logo resolution operations.
pub struct LogoService(pub ServiceContext);

impl LogoService {
    /// Check whether the cached logo index is stale (>24 h).
    pub fn is_logo_index_stale(&self) -> Result<bool, DbError> {
        match self.0.get_setting(LOGO_INDEX_TS_KEY)? {
            None => Ok(true),
            Some(ts_str) => {
                let ts: i64 = ts_str.parse().unwrap_or(0);
                let now = chrono::Utc::now().timestamp();
                Ok(now - ts > CACHE_DURATION_SECS)
            }
        }
    }

    /// Persist the logo index and set the fetched-at timestamp.
    pub fn save_logo_index(&self, index: &HashMap<String, String>) -> Result<(), DbError> {
        let json = serde_json::to_string(index).map_err(|e| DbError::Migration(e.to_string()))?;
        self.0.set_setting(LOGO_INDEX_KEY, &json)?;
        let now = chrono::Utc::now().timestamp().to_string();
        // Write timestamp silently (no event emit).
        let conn = self.0.db.get()?;
        insert_or_replace!(
            conn,
            "db_settings",
            ["key", "value"],
            params![LOGO_INDEX_TS_KEY, now],
        )?;
        Ok(())
    }

    /// Load the cached logo index from the KV store.
    fn load_logo_index(&self) -> Result<HashMap<String, String>, DbError> {
        match self.0.get_setting(LOGO_INDEX_KEY)? {
            None => Ok(HashMap::new()),
            Some(json) => {
                serde_json::from_str(&json).map_err(|e| DbError::Migration(e.to_string()))
            }
        }
    }

    /// Resolve a single channel name to a tv-logos URL.
    pub fn resolve_logo(&self, channel_name: &str) -> Result<Option<String>, DbError> {
        let index = self.load_logo_index()?;
        if index.is_empty() {
            return Ok(None);
        }
        Ok(resolve_from_index(&index, channel_name))
    }

    /// Resolve logos for a batch of channel names.
    ///
    /// Returns a map of `name → url` for names that matched.
    pub fn resolve_logos_batch(
        &self,
        names: &[String],
    ) -> Result<HashMap<String, String>, DbError> {
        let index = self.load_logo_index()?;
        if index.is_empty() {
            return Ok(HashMap::new());
        }

        let mut results = HashMap::new();
        for name in names {
            if let Some(url) = resolve_from_index(&index, name) {
                results.insert(name.clone(), url);
            }
        }
        Ok(results)
    }
}

// ── Async index fetch ──────────────────────────────────

/// GitHub Contents API response entry.
#[derive(Deserialize)]
struct GitHubEntry {
    name: String,
    #[serde(rename = "type")]
    entry_type: String,
}

/// Fetch the logo index from the GitHub API.
///
/// Scans the configured directories in the `tv-logo/tv-logos`
/// repository and builds a `normalized-name → raw URL` map.
/// First directory match wins (US priority).
pub async fn fetch_logo_index() -> anyhow::Result<HashMap<String, String>> {
    let client = crate::http_client::shared_client();
    let mut index = HashMap::new();

    for dir in DIRECTORIES {
        let url = format!("{API_BASE}/{dir}");
        let resp = client
            .get(&url)
            .header("Accept", "application/vnd.github.v3+json")
            .send()
            .await;

        let entries: Vec<GitHubEntry> = match resp {
            Ok(r) if r.status().is_success() => r.json().await.unwrap_or_default(),
            _ => continue,
        };

        for entry in entries {
            if entry.entry_type != "file" || !entry.name.ends_with(".png") {
                continue;
            }
            // Skip mosaic/readme files.
            if entry.name.starts_with("0_") {
                continue;
            }

            let key = normalize_filename(&entry.name);
            let raw_url = format!("{BASE_URL}/{dir}/{}", entry.name);
            // First match wins (US priority).
            index.entry(key).or_insert(raw_url);
        }
    }

    Ok(index)
}

// ── BlurHash decoding ─────────────────────────────────

/// Decode a BlurHash string into BMP image bytes.
///
/// Returns a minimal 32-bit BMP that Flutter's `Image.memory()`
/// can display directly. The default decode size is 16×16 which
/// produces a ~1 KB image — suitable as a placeholder while the
/// full image loads.
pub fn decode_blurhash_to_bmp(hash: &str, width: u32, height: u32) -> anyhow::Result<Vec<u8>> {
    let rgba = blurhash::decode(hash, width, height, 1.0)
        .map_err(|e| anyhow::anyhow!("BlurHash decode: {e}"))?;
    Ok(rgba_to_bmp(&rgba, width, height))
}

/// Encode RGBA pixel data as a minimal 32-bit BMP.
///
/// Uses negative height for top-down row order (no row reversal needed).
fn rgba_to_bmp(rgba: &[u8], width: u32, height: u32) -> Vec<u8> {
    let pixel_bytes = (width * height * 4) as usize;
    let file_size = 54 + pixel_bytes;
    let mut bmp = Vec::with_capacity(file_size);

    // ── File header (14 bytes) ──
    bmp.extend_from_slice(b"BM");
    bmp.extend_from_slice(&(file_size as u32).to_le_bytes());
    bmp.extend_from_slice(&[0u8; 4]); // reserved
    bmp.extend_from_slice(&54u32.to_le_bytes()); // pixel data offset

    // ── BITMAPINFOHEADER (40 bytes) ──
    bmp.extend_from_slice(&40u32.to_le_bytes()); // header size
    bmp.extend_from_slice(&(width as i32).to_le_bytes());
    bmp.extend_from_slice(&(-(height as i32)).to_le_bytes()); // negative = top-down
    bmp.extend_from_slice(&1u16.to_le_bytes()); // planes
    bmp.extend_from_slice(&32u16.to_le_bytes()); // bits per pixel
    bmp.extend_from_slice(&0u32.to_le_bytes()); // compression (BI_RGB)
    bmp.extend_from_slice(&(pixel_bytes as u32).to_le_bytes());
    bmp.extend_from_slice(&2835u32.to_le_bytes()); // h-res (72 dpi)
    bmp.extend_from_slice(&2835u32.to_le_bytes()); // v-res
    bmp.extend_from_slice(&0u32.to_le_bytes()); // palette colors
    bmp.extend_from_slice(&0u32.to_le_bytes()); // important colors

    // ── Pixel data (BGRA) ──
    for chunk in rgba.chunks_exact(4) {
        bmp.push(chunk[2]); // B
        bmp.push(chunk[1]); // G
        bmp.push(chunk[0]); // R
        bmp.push(chunk[3]); // A
    }

    bmp
}

// ── Tests ──────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── normalize_logo_name ────────────────────────────

    #[test]
    fn strips_iptv_prefix_pipe() {
        assert_eq!(normalize_logo_name("US-P| CBS"), "cbs");
    }

    #[test]
    fn strips_iptv_prefix_colon() {
        assert_eq!(normalize_logo_name("CA: CBC"), "cbc");
    }

    #[test]
    fn strips_iptv_prefix_bracket() {
        assert_eq!(normalize_logo_name("[UK] BBC One"), "bbc-one");
    }

    #[test]
    fn strips_iptv_prefix_space() {
        assert_eq!(normalize_logo_name("US ESPN"), "espn");
    }

    #[test]
    fn removes_quality_tags() {
        assert_eq!(normalize_logo_name("HBO HD"), "hbo");
        assert_eq!(normalize_logo_name("CNN 4K"), "cnn");
        assert_eq!(normalize_logo_name("Fox FHD"), "fox");
        assert_eq!(normalize_logo_name("MTV HEVC"), "mtv");
    }

    #[test]
    fn removes_parenthesised_content() {
        assert_eq!(normalize_logo_name("ESPN (East)"), "espn",);
        assert_eq!(normalize_logo_name("Fox News (West)"), "fox-news",);
    }

    #[test]
    fn combined_normalisation() {
        assert_eq!(normalize_logo_name("US-P| HBO HD (East)"), "hbo",);
    }

    #[test]
    fn empty_input() {
        assert_eq!(normalize_logo_name(""), "");
    }

    #[test]
    fn plain_name_unchanged() {
        assert_eq!(normalize_logo_name("discovery"), "discovery");
    }

    #[test]
    fn special_chars_become_hyphens() {
        assert_eq!(normalize_logo_name("A&E Network"), "a-e-network",);
    }

    // ── normalize_filename ─────────────────────────────

    #[test]
    fn filename_strips_png_and_country() {
        assert_eq!(normalize_filename("hbo-us.png"), "hbo");
        assert_eq!(normalize_filename("bbc-uk.png"), "bbc");
        assert_eq!(normalize_filename("discovery-int.png"), "discovery",);
    }

    #[test]
    fn filename_no_country_suffix() {
        assert_eq!(normalize_filename("espn.png"), "espn");
    }

    // ── get_aliases ────────────────────────────────────

    #[test]
    fn aliases_strip_network() {
        let aliases = get_aliases("food-network");
        assert!(aliases.contains(&"food".to_string()));
    }

    #[test]
    fn aliases_strip_channel() {
        let aliases = get_aliases("weather-channel");
        assert!(aliases.contains(&"weather".to_string()));
    }

    #[test]
    fn aliases_strip_the_prefix() {
        let aliases = get_aliases("the-cw");
        assert!(aliases.contains(&"cw".to_string()));
    }

    #[test]
    fn aliases_add_suffixes() {
        let aliases = get_aliases("hbo");
        assert!(aliases.contains(&"hbo-hz".to_string()));
        assert!(aliases.contains(&"hbo-network".to_string()));
        assert!(aliases.contains(&"hbo-channel".to_string()));
    }

    // ── resolve_from_index ─────────────────────────────

    fn test_index() -> HashMap<String, String> {
        let mut m = HashMap::new();
        m.insert("cbs".into(), "https://example.com/cbs.png".into());
        m.insert(
            "food-network".into(),
            "https://example.com/food-network.png".into(),
        );
        m.insert("hbo-logo".into(), "https://example.com/hbo-logo.png".into());
        m.insert(
            "hbo-logo-white".into(),
            "https://example.com/hbo-logo-white.png".into(),
        );
        m.insert("espn".into(), "https://example.com/espn.png".into());
        m.insert(
            "espn-news".into(),
            "https://example.com/espn-news.png".into(),
        );
        m.insert("espn-hz".into(), "https://example.com/espn-hz.png".into());
        m.insert(
            "discovery".into(),
            "https://example.com/discovery.png".into(),
        );
        m.insert("abc".into(), "https://example.com/abc.png".into());
        m
    }

    #[test]
    fn strategy1_exact_match() {
        let idx = test_index();
        assert_eq!(
            resolve_from_index(&idx, "CBS"),
            Some("https://example.com/cbs.png".into()),
        );
    }

    #[test]
    fn strategy2_alias_strips_network() {
        let idx = test_index();
        // "food" normalises to "food", alias "food-network" matches.
        assert_eq!(
            resolve_from_index(&idx, "Food"),
            Some("https://example.com/food-network.png".into()),
        );
    }

    #[test]
    fn strategy3_prefix_prefers_logo() {
        // Custom index without alias-matchable entries.
        let mut idx = HashMap::new();
        idx.insert("nbc-logo".into(), "https://example.com/nbc-logo.png".into());
        idx.insert(
            "nbc-logo-alt".into(),
            "https://example.com/nbc-logo-alt.png".into(),
        );
        // "nbc" has no exact match → aliases don't match →
        // prefix "nbc-logo" wins (shorter logo variant).
        let result = resolve_from_index(&idx, "NBC");
        assert_eq!(result, Some("https://example.com/nbc-logo.png".into()),);
    }

    #[test]
    fn strategy3_prefix_skips_noise() {
        let idx = test_index();
        // "espn" matches exactly (strategy 1), so test with
        // a name that only prefix-matches.
        let mut idx2 = HashMap::new();
        idx2.insert("fox".into(), "https://example.com/fox.png".into());
        idx2.insert("fox-news".into(), "https://example.com/fox-news.png".into());
        idx2.insert(
            "fox-sport".into(),
            "https://example.com/fox-sport.png".into(),
        );
        // "fox" exact matches, so remove it to test prefix only.
        idx2.remove("fox");

        // Without "fox" in index, strategy 3 kicks in.
        // Both "fox-news" and "fox-sport" are noise → fallback
        // to shortest overall.
        let result = resolve_from_index(&idx2, "Fox");
        assert!(result.is_some());
    }

    #[test]
    fn strategy4_contains_closest_length() {
        let mut idx = HashMap::new();
        idx.insert(
            "super-discovery-channel".into(),
            "https://example.com/super-discovery-channel.png".into(),
        );
        // "discovery" is contained in "super-discovery-channel".
        let result = resolve_from_index(&idx, "Discovery");
        assert_eq!(
            result,
            Some("https://example.com/super-discovery-channel.png".into()),
        );
    }

    #[test]
    fn no_match_returns_none() {
        let idx = test_index();
        assert_eq!(resolve_from_index(&idx, "ZZZ Unknown"), None);
    }

    #[test]
    fn empty_name_returns_none() {
        let idx = test_index();
        assert_eq!(resolve_from_index(&idx, ""), None);
    }

    // ── LogoService integration ──────────────────────

    fn make_logo_service() -> LogoService {
        LogoService(ServiceContext::open_in_memory().unwrap())
    }

    #[test]
    fn stale_when_no_timestamp() {
        let svc = make_logo_service();
        assert!(svc.is_logo_index_stale().unwrap());
    }

    #[test]
    fn not_stale_after_save() {
        let svc = make_logo_service();
        let index = test_index();
        svc.save_logo_index(&index).unwrap();
        assert!(!svc.is_logo_index_stale().unwrap());
    }

    #[test]
    fn resolve_after_save() {
        let svc = make_logo_service();
        let index = test_index();
        svc.save_logo_index(&index).unwrap();

        let result = svc.resolve_logo("CBS").unwrap();
        assert_eq!(result, Some("https://example.com/cbs.png".into()),);
    }

    #[test]
    fn resolve_returns_none_without_index() {
        let svc = make_logo_service();
        assert_eq!(svc.resolve_logo("CBS").unwrap(), None);
    }

    #[test]
    fn batch_resolve() {
        let svc = make_logo_service();
        let index = test_index();
        svc.save_logo_index(&index).unwrap();

        let names = vec!["CBS".to_string(), "ESPN".to_string(), "Unknown".to_string()];
        let results = svc.resolve_logos_batch(&names).unwrap();
        assert_eq!(results.len(), 2);
        assert!(results.contains_key("CBS"));
        assert!(results.contains_key("ESPN"));
        assert!(!results.contains_key("Unknown"));
    }

    #[test]
    fn iptv_prefix_resolves() {
        let svc = make_logo_service();
        let index = test_index();
        svc.save_logo_index(&index).unwrap();

        assert_eq!(
            svc.resolve_logo("US-P| CBS").unwrap(),
            Some("https://example.com/cbs.png".into()),
        );
    }

    #[test]
    fn quality_tag_resolves() {
        let svc = make_logo_service();
        let index = test_index();
        svc.save_logo_index(&index).unwrap();

        assert_eq!(
            svc.resolve_logo("ESPN HD").unwrap(),
            Some("https://example.com/espn.png".into()),
        );
    }

    // ── BlurHash ──────────────────────────────────────

    #[test]
    fn blurhash_decode_produces_valid_bmp() {
        // A known blurhash from the spec.
        let bmp = decode_blurhash_to_bmp("LGF5]+Yk^6#M@-5c,1J5@[or[Q6.", 16, 16).unwrap();

        // BMP signature.
        assert_eq!(&bmp[0..2], b"BM");
        // File size = 54 header + 16*16*4 pixels = 1078.
        let file_size = u32::from_le_bytes([bmp[2], bmp[3], bmp[4], bmp[5]]);
        assert_eq!(file_size, 1078);
        assert_eq!(bmp.len(), 1078);
    }

    #[test]
    fn blurhash_invalid_hash_returns_error() {
        let result = decode_blurhash_to_bmp("!!invalid!!", 16, 16);
        assert!(result.is_err());
    }

    #[test]
    fn blurhash_different_sizes() {
        let bmp = decode_blurhash_to_bmp("LEHV6nWB2yk8pyo0adR*.7kCMdnj", 4, 3).unwrap();
        // 54 + 4*3*4 = 102 bytes.
        assert_eq!(bmp.len(), 102);
    }
}
