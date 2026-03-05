//! EPG network synchronization service.
//!
//! Handles downloading EPG data (XMLTV, Xtream, Stalker), parsing it,
//! matching it to local channels, and persisting the results directly
//! to the database via `CrispyService`.

use std::collections::HashMap;

use anyhow::{Context, Result};

use crate::algorithms;
use crate::http_client::shared_client;
use crate::models::{Channel, EpgEntry};
use crate::parsers;
use crate::services::CrispyService;

/// Downloads and fully processes an XMLTV EPG URL in the background.
pub async fn fetch_and_save_xmltv_epg(service: &CrispyService, url: &str) -> Result<usize> {
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

    // 2. Extract channel display names
    let display_names = parsers::epg::extract_channel_names(&xml_content);

    // 3. Parse EPG
    let entries = parsers::epg::parse_epg(&xml_content);

    // 4. Load all channels
    let channels = service.load_channels()?;

    // 5. Match EPG to physical channels
    let match_result =
        algorithms::epg_matching::match_epg_to_channels(&entries, &channels, &display_names);

    // 6. Save directly to the database
    let count = service.save_epg_entries(&match_result.entries)?;

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
    fetch_and_save_xmltv_epg(service, &xmltv_url).await
}

/// Downloads and processes Stalker short EPG batches sequentially.
pub async fn fetch_and_save_stalker_epg(
    service: &CrispyService,
    base_url: &str,
    channels: &[Channel],
) -> Result<usize> {
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
    }

    Ok(total_saved)
}
