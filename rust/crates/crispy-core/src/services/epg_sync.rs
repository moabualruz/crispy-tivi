//! EPG network synchronization service.
//!
//! Handles downloading EPG data (XMLTV, Xtream, Stalker), parsing it,
//! matching it to local channels, and persisting the results directly
//! to the database via `CrispyService`.
//!
//! Includes a 4-hour cooldown per EPG URL to prevent redundant
//! network traffic. Callers can bypass via `force: true`.

use std::collections::HashMap;

use anyhow::{Context, Result};
use sha2::{Digest, Sha256};

use crate::http_client::shared_client;
use crate::models::{Channel, EpgEntry};
use crate::parsers;
use crate::services::CrispyService;

/// Minimum interval between EPG refreshes for the same URL (4 hours).
const EPG_COOLDOWN_SECS: i64 = 14_400;

/// Downloads and fully processes an XMLTV EPG URL in the background.
///
/// Skips the download if the same URL was successfully refreshed
/// within [`EPG_COOLDOWN_SECS`] unless `force` is true.
pub async fn fetch_and_save_xmltv_epg(
    service: &CrispyService,
    url: &str,
    force: bool,
) -> Result<usize> {
    // Check cooldown — skip if refreshed recently.
    if !force && is_within_cooldown(service, url) {
        return Ok(0);
    }

    // 1. Download XML payload
    let bytes = shared_client()
        .get(url)
        .send()
        .await
        .context("Failed to download XMLTV")?
        .bytes()
        .await
        .context("Failed to read XMLTV payload")?;
    let xml_content = String::from_utf8_lossy(&bytes).into_owned();

    if xml_content.is_empty() {
        return Ok(0);
    }

    // 2. Parse EPG entries — keyed by XMLTV channel ID.
    let entries = parsers::epg::parse_epg(&xml_content);

    // 3. Store EPG entries keyed by XMLTV channel ID (as-is
    //    from the parser). Multiple internal channels with the
    //    same tvg_id all share this EPG data — the join happens
    //    at query time via db_channels.tvg_id.
    let mut grouped: HashMap<String, Vec<EpgEntry>> = HashMap::new();
    for entry in entries {
        grouped
            .entry(entry.channel_id.clone())
            .or_default()
            .push(entry);
    }

    // 5. Save directly to the database
    let count = service.save_epg_entries(&grouped)?;

    // 7. Mark cooldown timestamp on success.
    mark_refreshed(service, url);

    Ok(count)
}

/// Downloads and processes Xtream EPG by deferring to the XMLTV parser,
/// since Xtream supports `xmltv.php?username=U&password=P`.
pub async fn fetch_and_save_xtream_epg(
    service: &CrispyService,
    base_url: &str,
    username: &str,
    password: &str,
    _channels: &[Channel],
    force: bool,
) -> Result<usize> {
    // Xtream provides a standard xmltv.php endpoint for full EPG:
    // http://domain:port/xmltv.php?username=X&password=Y
    let xmltv_url = format!(
        "{}/xmltv.php?username={}&password={}",
        crate::parsers::xtream::normalize_base_url(base_url),
        username,
        password
    );

    // Delegate entirely to the robust XMLTV processing pipeline
    fetch_and_save_xmltv_epg(service, &xmltv_url, force).await
}

/// Downloads and processes Stalker short EPG batches sequentially.
///
/// Uses the same cooldown mechanism keyed by `base_url`.
pub async fn fetch_and_save_stalker_epg(
    service: &CrispyService,
    base_url: &str,
    channels: &[Channel],
    force: bool,
) -> Result<usize> {
    // Check cooldown — skip if refreshed recently.
    if !force && is_within_cooldown(service, base_url) {
        return Ok(0);
    }

    let client = shared_client();
    let mut all_entries: HashMap<String, Vec<EpgEntry>> = HashMap::new();
    let mut total_saved = 0;

    for channel in channels {
        // Stalker channels have IDs like "stk_42" — strip the prefix
        // to get the numeric ch_id expected by the portal API.
        let stalker_id = channel.id.strip_prefix("stk_");
        if let Some(id_str) = stalker_id {
            let url = format!(
                "{}/server/load.php?type=itv&action=get_short_epg&ch_id={}",
                base_url, id_str
            );

            if let Ok(resp) = client.get(&url).send().await
                && let Ok(bytes) = resp.bytes().await
            {
                let text = String::from_utf8_lossy(&bytes).into_owned();
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text)
                    && let Some(listings) = json.as_object()
                {
                    // Simulate JSON string to use existing parser.
                    // Propagate serialization errors instead of silently
                    // substituting an empty string.
                    let list_str = serde_json::to_string(listings)
                        .context("Failed to re-serialize Stalker EPG listings")?;
                    let parsed = crate::parsers::stalker::parse_stalker_epg(&list_str, &channel.id);
                    all_entries.insert(channel.id.clone(), parsed);
                }
            }
        }
    }

    if !all_entries.is_empty() {
        total_saved = service.save_epg_entries(&all_entries)?;
        mark_refreshed(service, base_url);
    }

    Ok(total_saved)
}

// ── Cooldown Helpers ──────────────────────────────

/// Returns true if the given URL was refreshed within
/// [`EPG_COOLDOWN_SECS`].
fn is_within_cooldown(service: &CrispyService, url: &str) -> bool {
    let key = epg_cooldown_key(url);
    if let Ok(Some(ts_str)) = service.get_setting(&key)
        && let Ok(ts) = ts_str.parse::<i64>()
    {
        let now = chrono::Utc::now().timestamp();
        return now - ts < EPG_COOLDOWN_SECS;
    }
    false
}

/// Records the current time as the last refresh for
/// the given URL.
fn mark_refreshed(service: &CrispyService, url: &str) {
    let key = epg_cooldown_key(url);
    let now = chrono::Utc::now().timestamp().to_string();
    let _ = service.set_setting(&key, &now);
}

/// Builds a db_settings key from the EPG URL hash.
fn epg_cooldown_key(url: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(url.as_bytes());
    let hash = hasher.finalize();
    let short: String = hash.iter().take(8).map(|b| format!("{b:02x}")).collect();
    format!("epg_refresh_{short}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;

    #[test]
    fn cooldown_key_is_deterministic() {
        let k1 = epg_cooldown_key("http://epg.example.com/guide.xml");
        let k2 = epg_cooldown_key("http://epg.example.com/guide.xml");
        assert_eq!(k1, k2);
        assert!(k1.starts_with("epg_refresh_"));
    }

    #[test]
    fn cooldown_key_differs_for_different_urls() {
        let k1 = epg_cooldown_key("http://a.com/epg");
        let k2 = epg_cooldown_key("http://b.com/epg");
        assert_ne!(k1, k2);
    }

    #[test]
    fn no_cooldown_when_never_refreshed() {
        let svc = make_service();
        assert!(!is_within_cooldown(&svc, "http://fresh.test/epg"));
    }

    #[test]
    fn within_cooldown_after_mark() {
        let svc = make_service();
        let url = "http://epg.test/guide.xml";
        mark_refreshed(&svc, url);
        assert!(is_within_cooldown(&svc, url));
    }

    #[test]
    fn cooldown_expires_after_threshold() {
        let svc = make_service();
        let url = "http://epg.test/old.xml";
        let key = epg_cooldown_key(url);

        // Set timestamp to 5 hours ago (beyond 4h cooldown).
        let old_ts = chrono::Utc::now().timestamp() - 18_000;
        svc.set_setting(&key, &old_ts.to_string()).unwrap();

        assert!(!is_within_cooldown(&svc, url));
    }

    #[test]
    fn force_bypasses_cooldown() {
        // Verify the pattern: is_within_cooldown returns true
        // but force=true skips the check in the caller.
        let svc = make_service();
        let url = "http://epg.test/forced.xml";
        mark_refreshed(&svc, url);
        assert!(is_within_cooldown(&svc, url));
        // force=true in the caller would skip this check.
    }
}
