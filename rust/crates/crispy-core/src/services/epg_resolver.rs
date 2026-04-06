//! EPG fallback resolver — determines how to fetch EPG for a channel.
//!
//! Resolution chain:
//! 1. XMLTV source enabled + data in SQLite? → use cached XMLTV data
//! 2. Xtream source? → per-channel `get_short_epg` API via throttled fetcher
//! 3. Stalker source? → per-channel `get_short_epg` API via throttled fetcher
//! 4. All failed → return empty

use std::collections::HashMap;

use anyhow::Result;

use super::epg_fetcher::{ChannelEpgRequest, ThrottledEpgFetcher};
use crate::models::{EpgEntry, Source};
use crate::services::CrispyService;

/// Resolve EPG for a list of channels from a specific source.
///
/// First checks if SQLite already has data covering the requested
/// time window. If not, fetches via the appropriate API.
pub async fn resolve_epg_for_channels(
    service: &CrispyService,
    source: &Source,
    channel_ids: &[String],
    start_time: i64,
    end_time: i64,
    fetcher: &ThrottledEpgFetcher,
) -> Result<HashMap<String, Vec<EpgEntry>>> {
    // Step 1: Check SQLite L2 cache.
    let cached = service.get_epgs_for_channels(channel_ids, start_time, end_time)?;

    // Find channels with no cached data.
    let missing: Vec<String> = channel_ids
        .iter()
        .filter(|id| cached.get(*id).map(|v| v.is_empty()).unwrap_or(true))
        .cloned()
        .collect();

    if missing.is_empty() {
        return Ok(cached);
    }

    // Step 2: Fetch missing channels via per-channel API.
    let fetched = match source.source_type {
        crate::value_objects::SourceType::Xtream | crate::value_objects::SourceType::Stalker => {
            let requests = build_epg_requests(service, source, &missing)?;
            fetcher.fetch_batch(source, &requests).await
        }
        _ => HashMap::new(),
    };

    // Step 3: Save fetched entries to SQLite (write-through).
    if !fetched.is_empty() {
        let _ = service.save_epg_entries(&fetched);
    }

    // Merge cached + fetched.
    let mut result = cached;
    for (ch_id, entries) in fetched {
        result.insert(ch_id, entries);
    }

    Ok(result)
}

fn build_epg_requests(
    service: &CrispyService,
    source: &Source,
    channel_ids: &[String],
) -> Result<Vec<ChannelEpgRequest>> {
    let channels = service.get_channels_by_ids(channel_ids)?;
    let mut by_id: HashMap<String, crate::models::Channel> = channels
        .into_iter()
        .map(|channel| (channel.id.clone(), channel))
        .collect();

    Ok(channel_ids
        .iter()
        .map(|channel_id| {
            let provider_channel_id = match source.source_type {
                crate::value_objects::SourceType::Xtream => by_id
                    .remove(channel_id)
                    .and_then(|channel| channel.xtream_stream_id),
                crate::value_objects::SourceType::Stalker => {
                    by_id.remove(channel_id).map(|channel| channel.native_id)
                }
                _ => None,
            };

            ChannelEpgRequest {
                channel_id: channel_id.clone(),
                provider_channel_id,
            }
        })
        .collect())
}

/// Resolve EPG for a single channel, returning up to `count` entries.
pub async fn resolve_epg_for_channel(
    service: &CrispyService,
    source: &Source,
    epg_channel_id: &str,
    count: usize,
    fetcher: &ThrottledEpgFetcher,
) -> Result<Vec<EpgEntry>> {
    let now = chrono::Utc::now().timestamp();
    // Look ahead 24 hours by default.
    let end = now + 86_400;

    let result = resolve_epg_for_channels(
        service,
        source,
        &[epg_channel_id.to_string()],
        now,
        end,
        fetcher,
    )
    .await?;

    let mut entries = result.get(epg_channel_id).cloned().unwrap_or_default();

    // Sort by start time and truncate.
    entries.sort_by_key(|e| e.start_time);
    entries.truncate(count);

    Ok(entries)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;

    #[test]
    fn resolve_returns_cached_data() {
        let svc = make_service();
        let mut ch = make_channel("ch1", "Test Channel");
        ch.tvg_id = Some("tvg_ch1".to_string());
        svc.save_channels(&[ch]).unwrap();

        let dt = parse_dt("2025-01-15 10:00:00");
        let dt_end = parse_dt("2025-01-15 11:00:00");
        let entry = EpgEntry {
            epg_channel_id: "tvg_ch1".to_string(),
            title: "Cached Show".to_string(),
            start_time: dt,
            end_time: dt_end,
            ..EpgEntry::default()
        };
        let mut map = HashMap::new();
        map.insert("tvg_ch1".to_string(), vec![entry]);
        svc.save_epg_entries(&map).unwrap();

        // The resolver should find the cached data without fetching.
        let cached = svc
            .get_epgs_for_channels(
                &["ch1".to_string()],
                dt.and_utc().timestamp() - 1,
                dt_end.and_utc().timestamp() + 1,
            )
            .unwrap();
        assert_eq!(cached["ch1"].len(), 1);
        assert_eq!(cached["ch1"][0].title, "Cached Show");
    }
}
