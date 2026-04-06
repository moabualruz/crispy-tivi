//! Throttled EPG fetcher with concurrency control and request dedup.
//!
//! Wraps the per-channel Xtream/Stalker API calls with:
//! - `tokio::Semaphore(5)` — max 5 concurrent HTTP requests
//! - `singleflight_async::SingleFlight` — dedup in-flight requests for the same channel
//!
//! 20 UI widgets requesting EPG for 5 channels = 5 HTTP calls, not 20.

use std::collections::HashMap;
use std::sync::Arc;

use singleflight_async::SingleFlight;
use tokio::sync::Semaphore;

use crate::http_client::shared_client;
use crate::models::{EpgEntry, Source};
use crate::parsers::xtream;

/// Maximum concurrent per-channel EPG fetches.
const MAX_CONCURRENT_FETCHES: usize = 5;

/// Per-channel EPG request timeout (seconds).
const PER_CHANNEL_TIMEOUT_SECS: u64 = 10;

#[derive(Clone, Debug)]
pub struct ChannelEpgRequest {
    pub channel_id: String,
    pub provider_channel_id: Option<String>,
}

// ── ThrottledEpgFetcher ──────────────────────────────

/// Throttled fetcher for per-channel EPG API calls.
#[derive(Clone)]
pub struct ThrottledEpgFetcher {
    semaphore: Arc<Semaphore>,
    dedup: Arc<SingleFlight<String, Vec<EpgEntry>>>,
}

impl ThrottledEpgFetcher {
    /// Create a new fetcher with concurrency limit.
    pub fn new() -> Self {
        Self {
            semaphore: Arc::new(Semaphore::new(MAX_CONCURRENT_FETCHES)),
            dedup: Arc::new(SingleFlight::new()),
        }
    }

    /// Fetch EPG for a single Xtream channel via `get_short_epg`.
    ///
    /// Concurrent identical requests are coalesced via singleflight.
    /// Returns empty vec on network errors (logged, not propagated).
    pub async fn fetch_xtream_channel(
        &self,
        source: &Source,
        channel_id: &str,
        xtream_stream_id: Option<&str>,
    ) -> Vec<EpgEntry> {
        let dedup_id = xtream_stream_id.unwrap_or(channel_id);
        let key = format!("xtream:{}:{}", source.id, dedup_id);
        let source_clone = source.clone();
        let ch_id = channel_id.to_string();
        let stream_id = xtream_stream_id.map(str::to_string);
        let sem = self.semaphore.clone();

        self.dedup
            .work(key, || async move {
                let Ok(_permit) = sem.acquire().await else {
                    return vec![];
                };
                fetch_xtream_short_epg(&source_clone, &ch_id, stream_id.as_deref())
                    .await
                    .unwrap_or_else(|e| {
                        tracing::warn!("Xtream EPG fetch failed for {ch_id}: {e}");
                        vec![]
                    })
            })
            .await
    }

    /// Fetch EPG for a single Stalker channel via `get_short_epg`.
    pub async fn fetch_stalker_channel(
        &self,
        source: &Source,
        channel_id: &str,
        stalker_channel_id: Option<&str>,
    ) -> Vec<EpgEntry> {
        let dedup_id = stalker_channel_id.unwrap_or(channel_id);
        let key = format!("stalker:{}:{}", source.id, dedup_id);
        let source_clone = source.clone();
        let ch_id = channel_id.to_string();
        let provider_id = stalker_channel_id.map(str::to_string);
        let sem = self.semaphore.clone();

        self.dedup
            .work(key, || async move {
                let Ok(_permit) = sem.acquire().await else {
                    return vec![];
                };
                fetch_stalker_short_epg(&source_clone, &ch_id, provider_id.as_deref())
                    .await
                    .unwrap_or_else(|e| {
                        tracing::warn!("Stalker EPG fetch failed for {ch_id}: {e}");
                        vec![]
                    })
            })
            .await
    }

    /// Batch fetch EPG for multiple channels from the same source.
    ///
    /// Returns a map of channel_id → Vec<EpgEntry>.
    /// Errors for individual channels are logged and skipped.
    pub async fn fetch_batch(
        &self,
        source: &Source,
        channels: &[ChannelEpgRequest],
    ) -> HashMap<String, Vec<EpgEntry>> {
        let mut results = HashMap::new();
        let mut handles = Vec::with_capacity(channels.len());

        for channel in channels {
            let fetcher = self.clone();
            let src = source.clone();
            let cid = channel.channel_id.clone();
            let provider_id = channel.provider_channel_id.clone();

            let handle = tokio::spawn(async move {
                let entries = match src.source_type {
                    crate::value_objects::SourceType::Xtream => {
                        fetcher
                            .fetch_xtream_channel(&src, &cid, provider_id.as_deref())
                            .await
                    }
                    crate::value_objects::SourceType::Stalker => {
                        fetcher
                            .fetch_stalker_channel(&src, &cid, provider_id.as_deref())
                            .await
                    }
                    _ => vec![],
                };
                (cid, entries)
            });
            handles.push(handle);
        }

        for handle in handles {
            if let Ok((ch_id, entries)) = handle.await
                && !entries.is_empty()
            {
                results.insert(ch_id, entries);
            }
        }

        results
    }
}

impl Default for ThrottledEpgFetcher {
    fn default() -> Self {
        Self::new()
    }
}

// ── Internal fetch functions ─────────────────────────

/// Fetch Xtream per-channel EPG via `get_short_epg&stream_id=X`.
async fn fetch_xtream_short_epg(
    source: &Source,
    channel_id: &str,
    xtream_stream_id: Option<&str>,
) -> anyhow::Result<Vec<EpgEntry>> {
    let stream_id = xtream_stream_id
        .map(str::to_string)
        .ok_or_else(|| anyhow::anyhow!("missing Xtream stream ID for channel: {channel_id}"))?;

    let username = source.username.as_deref().unwrap_or("");
    let password = source.password.as_deref().unwrap_or("");
    let base_url = xtream::normalize_base_url(&source.url);

    let url = xtream::build_xtream_action_url(
        &base_url,
        username,
        password,
        "get_short_epg",
        &[("stream_id".to_string(), stream_id)],
    );

    let client = shared_client();
    let resp = client
        .get(&url)
        .timeout(std::time::Duration::from_secs(PER_CHANNEL_TIMEOUT_SECS))
        .send()
        .await?;

    let data: serde_json::Value = resp.json().await?;

    // Response format: { "epg_listings": [...] }
    let listings = data
        .get("epg_listings")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    Ok(xtream::parse_short_epg(&listings, channel_id))
}

/// Fetch Stalker per-channel EPG via `get_short_epg&ch_id=X`.
async fn fetch_stalker_short_epg(
    source: &Source,
    channel_id: &str,
    stalker_channel_id: Option<&str>,
) -> anyhow::Result<Vec<EpgEntry>> {
    let stalker_id = stalker_channel_id
        .ok_or_else(|| anyhow::anyhow!("missing Stalker channel ID for channel: {channel_id}"))?;

    let url = format!(
        "{}/server/load.php?type=itv&action=get_short_epg&ch_id={}",
        source.url, stalker_id
    );

    let client = shared_client();
    let resp = client
        .get(&url)
        .timeout(std::time::Duration::from_secs(PER_CHANNEL_TIMEOUT_SECS))
        .send()
        .await?;

    let data: serde_json::Value = resp.json().await?;

    if let Some(listings) = data.as_object() {
        let list_str = serde_json::to_string(listings)?;
        Ok(crate::parsers::stalker::parse_stalker_epg(
            &list_str, channel_id,
        ))
    } else {
        Ok(vec![])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fetcher_creation() {
        let fetcher = ThrottledEpgFetcher::new();
        assert_eq!(
            fetcher.semaphore.available_permits(),
            MAX_CONCURRENT_FETCHES
        );
    }

    #[test]
    fn default_creates_same_as_new() {
        let fetcher = ThrottledEpgFetcher::default();
        assert_eq!(
            fetcher.semaphore.available_permits(),
            MAX_CONCURRENT_FETCHES
        );
    }
}
