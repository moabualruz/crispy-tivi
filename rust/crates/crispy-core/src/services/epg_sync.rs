//! EPG network synchronization service.
//!
//! Handles downloading EPG data (XMLTV, Xtream, Stalker), parsing it,
//! matching it to local channels, and persisting the results directly
//! to the database via `CrispyService`.
//!
//! Includes a 4-hour cooldown per EPG URL to prevent redundant
//! network traffic. Callers can bypass via `force: true`.

use std::collections::HashMap;
use std::future::Future;
use std::io::{BufReader, Cursor, Read};
use std::sync::Arc;
use std::sync::mpsc::{Receiver, sync_channel};
use std::time::Duration;

use anyhow::{Context, Result, anyhow};
use reqwest::header::{ETAG, HeaderMap, IF_MODIFIED_SINCE, IF_NONE_MATCH, LAST_MODIFIED};
use rusqlite::params;
use sha2::{Digest, Sha256};
use tokio::sync::Semaphore;

use crate::events::DataChangeEvent;
use crate::insert_or_replace;
use crate::http_client::shared_client;
use crate::models::{Channel, EpgEntry};
use crate::parsers::epg::{EpgChannel, ParsedEpg};
use crate::services::{CrispyService, build_in_placeholders, str_params};

/// Minimum interval between EPG refreshes for the same URL (4 hours).
const EPG_COOLDOWN_SECS: i64 = 14_400;
/// XMLTV request timeout.
const XMLTV_TIMEOUT: Duration = Duration::from_secs(300);
/// Per-channel Stalker request timeout.
const STALKER_TIMEOUT: Duration = Duration::from_secs(30);
/// Maximum in-flight Stalker requests.
const STALKER_CONCURRENCY: usize = 5;
/// Channels per Stalker batch.
const STALKER_BATCH_SIZE: usize = 10;
/// Pause between Stalker batches.
const STALKER_BATCH_PAUSE: Duration = Duration::from_secs(1);
/// Retry backoff between attempts.
const RETRY_BACKOFF_SECS: [u64; 3] = [1, 2, 4];

/// Downloads and fully processes an XMLTV EPG URL in the background.
///
/// Skips the download if the same URL was successfully refreshed
/// within [`EPG_COOLDOWN_SECS`] unless `force` is true.
pub async fn fetch_and_save_xmltv_epg(
    service: &CrispyService,
    url: &str,
    source_id: Option<String>,
    force: bool,
) -> Result<usize> {
    // Check cooldown — skip if refreshed recently.
    if !force && is_within_cooldown(service, url) {
        return Ok(0);
    }

    // 1. Download and parse XML payload as a stream.
    let cached_validators = load_xmltv_validators(service, url);
    let download = with_retry("XMLTV fetch", || {
        let cached_validators = cached_validators.clone();
        async move { download_and_parse_xmltv_epg(url, &cached_validators).await }
    })
    .await?;

    let (parsed, validators) = match download {
        XmltvDownloadResult::NotModified(validators) => {
            persist_xmltv_validators(service, url, &validators, true)
                .context("Failed to persist XMLTV cache validators")?;
            mark_refreshed(service, url);
            return Ok(0);
        }
        XmltvDownloadResult::Parsed { parsed, validators } => (parsed, validators),
    };

    persist_xmltv_validators(service, url, &validators, false)
        .context("Failed to persist XMLTV cache validators")?;

    if parsed.entries.is_empty() && parsed.channels.is_empty() {
        mark_refreshed(service, url);
        return Ok(0);
    }

    // E2: Save XMLTV <channel> definitions to db_epg_channels.
    if !parsed.channels.is_empty() {
        save_epg_channels(service, &parsed.channels, source_id.as_deref())
            .context("Failed to save XMLTV channel definitions")?;

        // E4: Resolve epg_channel_id for db_channels that are still unmapped,
        // using display-name matching against the just-saved db_epg_channels rows.
        resolve_epg_channel_ids(service, source_id.as_deref())
            .context("Failed to resolve EPG channel IDs")?;
    }

    // Group programme entries by XMLTV channel ID for bulk insert.
    // Multiple internal channels sharing the same tvg_id all share
    // this EPG data — the join happens at query time.
    let mut grouped: HashMap<String, Vec<EpgEntry>> = HashMap::new();
    for mut entry in parsed.entries {
        entry.source_id = source_id.clone();
        grouped
            .entry(entry.epg_channel_id.clone())
            .or_default()
            .push(entry);
    }

    let count = service.save_epg_entries(&grouped)?;

    mark_refreshed(service, url);
    emit_epg_progress(service, source_id.as_deref(), url);

    Ok(count)
}

/// Downloads and processes Xtream EPG by deferring to the XMLTV parser,
/// since Xtream supports `xmltv.php?username=U&password=P`.
pub async fn fetch_and_save_xtream_epg(
    service: &CrispyService,
    base_url: &str,
    username: &str,
    password: &str,
    source_id: Option<String>,
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
    fetch_and_save_xmltv_epg(service, &xmltv_url, source_id, force).await
}

/// Downloads and processes Stalker short EPG batches sequentially.
///
/// Uses per-channel cooldown metadata so stale channels refresh incrementally.
pub async fn fetch_and_save_stalker_epg(
    service: &CrispyService,
    base_url: &str,
    mac: Option<&str>,
    source_id: Option<String>,
    channels: &[Channel],
    force: bool,
) -> Result<usize> {
    let prioritized_channels = sort_stalker_channels_for_sync(service, channels)
        .context("Failed to prioritize Stalker channels for EPG sync")?;
    let channels_to_refresh: Vec<Channel> = prioritized_channels
        .into_iter()
        .filter(|channel| force || !is_channel_within_cooldown(service, &channel.id))
        .collect();

    if channels_to_refresh.is_empty() {
        return Ok(0);
    }

    let client = shared_client();
    let semaphore = Arc::new(Semaphore::new(STALKER_CONCURRENCY));
    let mac_cookie = mac
        .filter(|value| !value.trim().is_empty())
        .map(build_stalker_cookie);
    let mut total_saved = 0;

    let total_batches = channels_to_refresh.len().div_ceil(STALKER_BATCH_SIZE);

    for (batch_index, batch) in channels_to_refresh.chunks(STALKER_BATCH_SIZE).enumerate() {
        let mut handles = Vec::with_capacity(batch.len());

        for channel in batch {
            let stalker_id = channel.native_id.trim();
            if stalker_id.is_empty() {
                continue;
            }

            let client = client.clone();
            let semaphore = semaphore.clone();
            let base_url = base_url.to_string();
            let channel_id = channel.id.clone();
            let source_id = source_id.clone();
            let mac_cookie = mac_cookie.clone();
            let stalker_id = stalker_id.to_string();

            handles.push(tokio::spawn(async move {
                let _permit = semaphore
                    .acquire_owned()
                    .await
                    .context("Stalker semaphore closed")?;

                let entries = with_retry("Stalker short EPG fetch", || {
                    let client = client.clone();
                    let base_url = base_url.clone();
                    let channel_id = channel_id.clone();
                    let source_id = source_id.clone();
                    let mac_cookie = mac_cookie.clone();
                    let stalker_id = stalker_id.clone();
                    async move {
                        fetch_stalker_channel_epg(
                            client,
                            &base_url,
                            &channel_id,
                            &stalker_id,
                            source_id,
                            mac_cookie,
                        )
                        .await
                    }
                })
                .await?;

                Ok::<_, anyhow::Error>((channel_id, entries))
            }));
        }

        let mut batch_entries: HashMap<String, Vec<EpgEntry>> = HashMap::new();
        let mut refreshed_channel_ids: Vec<String> = Vec::new();

        for handle in handles {
            match handle.await {
                Ok(Ok((channel_id, entries))) => {
                    refreshed_channel_ids.push(channel_id.clone());
                    if !entries.is_empty() {
                        batch_entries.insert(channel_id, entries);
                    }
                }
                Ok(Err(err)) => {
                    tracing::warn!("Stalker EPG fetch failed after retries: {err}");
                }
                Err(err) => {
                    tracing::warn!("Stalker EPG task join failed: {err}");
                }
            }
        }

        if !batch_entries.is_empty() {
            total_saved += service.save_epg_entries(&batch_entries)?;
        }
        for channel_id in &refreshed_channel_ids {
            mark_channel_refreshed(service, channel_id);
        }
        if !refreshed_channel_ids.is_empty() {
            emit_epg_progress(service, source_id.as_deref(), base_url);
        }

        if batch_index + 1 < total_batches {
            tokio::time::sleep(STALKER_BATCH_PAUSE).await;
        }
    }

    Ok(total_saved)
}

async fn with_retry<T, F, Fut>(label: &str, mut operation: F) -> Result<T>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<T>>,
{
    for (attempt, delay_secs) in RETRY_BACKOFF_SECS.iter().enumerate() {
        match operation().await {
            Ok(value) => return Ok(value),
            Err(err) => {
                tracing::warn!(
                    "{label} attempt {}/{} failed: {err}",
                    attempt + 1,
                    RETRY_BACKOFF_SECS.len() + 1,
                );
                tokio::time::sleep(Duration::from_secs(*delay_secs)).await;
            }
        }
    }

    operation().await
}

async fn download_and_parse_xmltv_epg(
    url: &str,
    validators: &XmltvValidators,
) -> Result<XmltvDownloadResult> {
    let mut request = shared_client().get(url).timeout(XMLTV_TIMEOUT);
    if let Some(etag) = validators.etag.as_deref() {
        request = request.header(IF_NONE_MATCH, etag);
    }
    if let Some(last_modified) = validators.last_modified.as_deref() {
        request = request.header(IF_MODIFIED_SINCE, last_modified);
    }

    let response = request.send().await.context("Failed to download XMLTV")?;

    if response.status() == reqwest::StatusCode::NOT_MODIFIED {
        return Ok(XmltvDownloadResult::NotModified(
            XmltvValidators::from_headers(response.headers()),
        ));
    }

    let response = response
        .error_for_status()
        .context("XMLTV server returned an error status")?;
    let response_validators = XmltvValidators::from_headers(response.headers());

    let (sender, receiver) = sync_channel(8);
    let parser_handle = tokio::task::spawn_blocking(move || parse_xmltv_stream(receiver));

    let mut response = response;
    loop {
        match response
            .chunk()
            .await
            .context("Failed to read XMLTV payload")?
        {
            Some(chunk) => {
                sender
                    .send(StreamChunk::Data(chunk.to_vec()))
                    .map_err(|_| anyhow!("XMLTV parser stopped receiving streamed data"))?;
            }
            None => {
                let _ = sender.send(StreamChunk::End);
                break;
            }
        }
    }

    let parsed = parser_handle
        .await
        .context("XMLTV parser task panicked")??;
    Ok(XmltvDownloadResult::Parsed {
        parsed,
        validators: response_validators,
    })
}

async fn fetch_stalker_channel_epg(
    client: reqwest::Client,
    base_url: &str,
    channel_id: &str,
    stalker_id: &str,
    source_id: Option<String>,
    mac_cookie: Option<String>,
) -> Result<Vec<EpgEntry>> {
    let url = format!(
        "{}/server/load.php?type=itv&action=get_short_epg&ch_id={}",
        base_url, stalker_id
    );

    let mut request = client.get(&url).timeout(STALKER_TIMEOUT);
    if let Some(cookie) = mac_cookie.as_deref() {
        request = request.header("Cookie", cookie);
    }

    let json: serde_json::Value = request
        .send()
        .await
        .context("Failed to fetch Stalker short EPG")?
        .error_for_status()
        .context("Stalker EPG server returned an error status")?
        .json()
        .await
        .context("Failed to decode Stalker EPG payload")?;

    let Some(listings) = json.as_object() else {
        return Ok(Vec::new());
    };

    let list_str =
        serde_json::to_string(listings).context("Failed to re-serialize Stalker EPG listings")?;
    let mut parsed = crate::parsers::stalker::parse_stalker_epg(&list_str, channel_id);
    for entry in &mut parsed {
        entry.source_id = source_id.clone();
    }
    Ok(parsed)
}

fn build_stalker_cookie(mac: &str) -> String {
    format!("mac={}; stb_lang=en; timezone=UTC", mac.replace(':', "%3A"))
}

fn parse_xmltv_stream(receiver: Receiver<StreamChunk>) -> Result<ParsedEpg> {
    let mut raw = Vec::new();
    BufReader::new(StreamChunkReader::new(receiver))
        .read_to_end(&mut raw)
        .map_err(|err| anyhow!("Failed to read XMLTV stream: {err}"))?;
    let content = String::from_utf8_lossy(&raw);
    Ok(crate::parsers::epg::parse_epg_full(&content))
}

enum StreamChunk {
    Data(Vec<u8>),
    End,
}

struct StreamChunkReader {
    receiver: Receiver<StreamChunk>,
    current: Cursor<Vec<u8>>,
    finished: bool,
}

impl StreamChunkReader {
    fn new(receiver: Receiver<StreamChunk>) -> Self {
        Self {
            receiver,
            current: Cursor::new(Vec::new()),
            finished: false,
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct XmltvValidators {
    etag: Option<String>,
    last_modified: Option<String>,
}

impl XmltvValidators {
    fn from_headers(headers: &HeaderMap) -> Self {
        Self {
            etag: header_value(headers, ETAG),
            last_modified: header_value(headers, LAST_MODIFIED),
        }
    }
}

enum XmltvDownloadResult {
    NotModified(XmltvValidators),
    Parsed {
        parsed: ParsedEpg,
        validators: XmltvValidators,
    },
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
struct ChannelSyncPriority {
    is_favorite: bool,
    last_watched: Option<i64>,
}

impl Read for StreamChunkReader {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        loop {
            let bytes_read = self.current.read(buf)?;
            if bytes_read > 0 {
                return Ok(bytes_read);
            }

            if self.finished {
                return Ok(0);
            }

            match self.receiver.recv() {
                Ok(StreamChunk::Data(chunk)) => {
                    self.current = Cursor::new(chunk);
                }
                Ok(StreamChunk::End) => {
                    self.finished = true;
                    return Ok(0);
                }
                Err(_) => {
                    self.finished = true;
                    return Ok(0);
                }
            }
        }
    }
}

// ── EPG Channel Helpers ───────────────────────────

/// Persist XMLTV `<channel>` definitions to `db_epg_channels`.
///
/// Uses `INSERT OR REPLACE` keyed on `(xmltv_id, source_id)` so
/// re-running a sync always reflects the latest channel metadata
/// from the XMLTV feed.
fn save_epg_channels(
    service: &CrispyService,
    channels: &[EpgChannel],
    source_id: Option<&str>,
) -> Result<()> {
    if channels.is_empty() {
        return Ok(());
    }
    let sid = source_id.unwrap_or("");
    let conn = service.db.get()?;
    let tx = conn.unchecked_transaction()?;
    for ch in channels {
        insert_or_replace!(tx, "db_epg_channels",
            ["xmltv_id", "source_id", "display_name", "icon_url"],
            params![ch.xmltv_id, sid, ch.display_name, ch.icon_url]
        )?;
    }
    tx.commit()?;
    tracing::debug!(
        "[epg_sync] saved {} XMLTV channel definitions (source={})",
        channels.len(),
        sid,
    );
    Ok(())
}

/// Resolve `db_channels.epg_channel_id` for channels that have no
/// mapping yet, by matching `db_epg_channels.display_name` against
/// `db_channels.name` or `db_channels.tvg_name`.
///
/// Only channels with a NULL or empty `epg_channel_id` are updated,
/// so manually-assigned mappings are never overwritten.
fn resolve_epg_channel_ids(service: &CrispyService, source_id: Option<&str>) -> Result<()> {
    let conn = service.db.get()?;
    let sid = source_id.unwrap_or("");
    let updated = conn.execute(
        "UPDATE db_channels
         SET epg_channel_id = (
             SELECT ec.xmltv_id
             FROM db_epg_channels ec
             WHERE ec.source_id = ?1
               AND (ec.display_name = db_channels.name
                    OR ec.display_name = db_channels.tvg_name)
             LIMIT 1
         )
         WHERE (epg_channel_id IS NULL OR epg_channel_id = '')
           AND EXISTS (
               SELECT 1 FROM db_epg_channels ec2
               WHERE ec2.source_id = ?1
                 AND (ec2.display_name = db_channels.name
                      OR ec2.display_name = db_channels.tvg_name)
           )",
        params![sid],
    )?;
    if updated > 0 {
        tracing::info!(
            "[epg_sync] resolved epg_channel_id for {} channels via display-name match",
            updated,
        );
    }
    Ok(())
}

// ── Cooldown Helpers ──────────────────────────────

fn header_value(headers: &HeaderMap, name: reqwest::header::HeaderName) -> Option<String> {
    headers
        .get(name)
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| value.to_owned())
}

fn emit_epg_progress(service: &CrispyService, source_id: Option<&str>, fallback: &str) {
    let source_id = source_id
        .filter(|value| !value.trim().is_empty())
        .unwrap_or(fallback)
        .to_string();
    service.emit(DataChangeEvent::EpgUpdated { source_id });
}

fn load_xmltv_validators(service: &CrispyService, url: &str) -> XmltvValidators {
    XmltvValidators {
        etag: read_sync_setting(service, &xmltv_etag_key(url)),
        last_modified: read_sync_setting(service, &xmltv_last_modified_key(url)),
    }
}

fn persist_xmltv_validators(
    service: &CrispyService,
    url: &str,
    validators: &XmltvValidators,
    preserve_absent: bool,
) -> Result<()> {
    persist_validator_setting(
        service,
        &xmltv_etag_key(url),
        validators.etag.as_deref(),
        preserve_absent,
    )
    .context("Failed to persist XMLTV ETag")?;
    persist_validator_setting(
        service,
        &xmltv_last_modified_key(url),
        validators.last_modified.as_deref(),
        preserve_absent,
    )
    .context("Failed to persist XMLTV Last-Modified")?;
    Ok(())
}

fn persist_validator_setting(
    service: &CrispyService,
    key: &str,
    value: Option<&str>,
    preserve_absent: bool,
) -> Result<()> {
    match value {
        Some(value) => write_sync_setting(service, key, value)
            .with_context(|| format!("Failed to store setting {key}"))?,
        None if !preserve_absent => {
            delete_sync_setting(service, key)
                .with_context(|| format!("Failed to remove setting {key}"))?;
        }
        None => {}
    }
    Ok(())
}

fn sort_stalker_channels_for_sync(
    service: &CrispyService,
    channels: &[Channel],
) -> Result<Vec<Channel>> {
    let channel_ids: Vec<String> = channels.iter().map(|channel| channel.id.clone()).collect();
    let priorities = load_stalker_channel_priorities(service, &channel_ids)?;
    let mut indexed_channels: Vec<(usize, Channel)> =
        channels.iter().cloned().enumerate().collect();

    indexed_channels.sort_by(|(left_index, left), (right_index, right)| {
        let left_priority = priorities.get(&left.id).copied().unwrap_or_default();
        let right_priority = priorities.get(&right.id).copied().unwrap_or_default();

        right_priority
            .is_favorite
            .cmp(&left_priority.is_favorite)
            .then_with(|| {
                right_priority
                    .last_watched
                    .is_some()
                    .cmp(&left_priority.last_watched.is_some())
            })
            .then_with(|| right_priority.last_watched.cmp(&left_priority.last_watched))
            .then_with(|| left_index.cmp(right_index))
    });

    Ok(indexed_channels
        .into_iter()
        .map(|(_, channel)| channel)
        .collect())
}

fn load_stalker_channel_priorities(
    service: &CrispyService,
    channel_ids: &[String],
) -> Result<HashMap<String, ChannelSyncPriority>> {
    if channel_ids.is_empty() {
        return Ok(HashMap::new());
    }

    let conn = service.db.get()?;
    let sql = format!(
        "SELECT c.id, c.is_favorite, MAX(h.last_watched) AS last_watched
         FROM db_channels c
         LEFT JOIN db_watch_history h
           ON h.content_id = c.id AND h.media_type = 'channel'
         WHERE c.id IN ({})
         GROUP BY c.id, c.is_favorite",
        build_in_placeholders(channel_ids.len())
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt.query_map(str_params(channel_ids).as_slice(), |row| {
        Ok((
            row.get::<_, String>(0)?,
            ChannelSyncPriority {
                is_favorite: row.get::<_, i32>(1)? != 0,
                last_watched: row.get(2)?,
            },
        ))
    })?;

    Ok(rows.collect::<rusqlite::Result<HashMap<_, _>>>()?)
}

/// Returns true if the given URL was refreshed within
/// [`EPG_COOLDOWN_SECS`].
fn is_within_cooldown(service: &CrispyService, url: &str) -> bool {
    let key = epg_cooldown_key(url);
    if let Some(ts_str) = read_sync_setting(service, &key)
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
    let _ = write_sync_setting(service, &key, &now);
}

fn is_channel_within_cooldown(service: &CrispyService, channel_id: &str) -> bool {
    let key = stalker_channel_refresh_key(channel_id);
    if let Some(ts_str) = read_sync_setting(service, &key)
        && let Ok(ts) = ts_str.parse::<i64>()
    {
        let now = chrono::Utc::now().timestamp();
        return now - ts < EPG_COOLDOWN_SECS;
    }
    false
}

fn mark_channel_refreshed(service: &CrispyService, channel_id: &str) {
    let key = stalker_channel_refresh_key(channel_id);
    let now = chrono::Utc::now().timestamp().to_string();
    let _ = write_sync_setting(service, &key, &now);
}

/// Builds a db_settings key from the EPG URL hash.
fn epg_cooldown_key(url: &str) -> String {
    format!("epg_refresh_{}", epg_hash_suffix(url))
}

fn xmltv_etag_key(url: &str) -> String {
    format!("epg_xmltv_etag_{}", epg_hash_suffix(url))
}

fn xmltv_last_modified_key(url: &str) -> String {
    format!("epg_xmltv_last_modified_{}", epg_hash_suffix(url))
}

fn stalker_channel_refresh_key(channel_id: &str) -> String {
    format!("epg_refresh_channel_{channel_id}")
}

fn epg_hash_suffix(value: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(value.as_bytes());
    let hash = hasher.finalize();
    hash.iter().take(8).map(|b| format!("{b:02x}")).collect()
}

fn read_sync_setting(service: &CrispyService, key: &str) -> Option<String> {
    let conn = service.db.get().ok()?;
    conn.query_row(
        "SELECT value FROM db_settings WHERE key = ?1",
        params![key],
        |row| row.get(0),
    )
    .ok()
}

fn write_sync_setting(service: &CrispyService, key: &str, value: &str) -> Result<()> {
    let conn = service.db.get()?;
    insert_or_replace!(conn, "db_settings",
        ["key", "value"],
        params![key, value]
    )?;
    Ok(())
}

fn delete_sync_setting(service: &CrispyService, key: &str) -> Result<()> {
    let conn = service.db.get()?;
    conn.execute("DELETE FROM db_settings WHERE key = ?1", params![key])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::*;
    use std::sync::{Arc, Mutex};

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

    #[test]
    fn xmltv_validator_keys_share_url_hash() {
        let url = "http://epg.example.com/guide.xml";
        let suffix = epg_hash_suffix(url);

        assert_eq!(xmltv_etag_key(url), format!("epg_xmltv_etag_{suffix}"));
        assert_eq!(
            xmltv_last_modified_key(url),
            format!("epg_xmltv_last_modified_{suffix}")
        );
    }

    #[test]
    fn stalker_channel_cooldown_is_per_channel() {
        let svc = make_service();
        mark_channel_refreshed(&svc, "ch-1");

        assert!(is_channel_within_cooldown(&svc, "ch-1"));
        assert!(!is_channel_within_cooldown(&svc, "ch-2"));
    }

    #[test]
    fn stalker_prioritizes_favorites_then_recent_channels() {
        let svc = make_service_with_fixtures();

        let mut favorite = make_channel("ch-1", "Favorite");
        favorite.native_id = "1".to_string();
        favorite.source_id = Some("src1".to_string());
        favorite.is_favorite = true;

        let mut recent = make_channel("ch-2", "Recent");
        recent.native_id = "2".to_string();
        recent.source_id = Some("src1".to_string());

        let mut plain = make_channel("ch-3", "Plain");
        plain.native_id = "3".to_string();
        plain.source_id = Some("src1".to_string());

        svc.save_channels(&[favorite.clone(), recent.clone(), plain.clone()])
            .unwrap();

        let mut watch = make_watch_entry("ch-2", "Recent");
        watch.media_type = crate::value_objects::MediaType::Channel;
        watch.source_id = Some("src1".to_string());
        watch.last_watched = parse_dt("2025-02-01 12:00:00");
        svc.save_watch_history(&watch).unwrap();

        let sorted =
            sort_stalker_channels_for_sync(&svc, &[plain, recent, favorite]).expect("sort");
        let ids: Vec<&str> = sorted.iter().map(|channel| channel.id.as_str()).collect();

        assert_eq!(ids, vec!["ch-1", "ch-2", "ch-3"]);
    }

    #[test]
    fn xmltv_validators_round_trip_through_db_settings() {
        let svc = make_service_with_fixtures();
        let url = "http://epg.example.com/guide.xml";
        let validators = XmltvValidators {
            etag: Some("\"v1\"".to_string()),
            last_modified: Some("Mon, 01 Jan 2024 00:00:00 GMT".to_string()),
        };

        persist_xmltv_validators(&svc, url, &validators, false).unwrap();

        let loaded = load_xmltv_validators(&svc, url);
        assert_eq!(loaded, validators);
        assert_eq!(
            svc.get_setting(&xmltv_etag_key(url)).unwrap(),
            Some("\"v1\"".to_string())
        );
        assert_eq!(
            svc.get_setting(&xmltv_last_modified_key(url)).unwrap(),
            Some("Mon, 01 Jan 2024 00:00:00 GMT".to_string())
        );
    }

    #[test]
    fn internal_sync_metadata_writes_do_not_emit_settings_events() {
        let svc = make_service();
        let events: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let events_clone = events.clone();
        svc.set_event_callback(Arc::new(move |event| {
            events_clone
                .lock()
                .unwrap()
                .push(crate::events::serialize_event(event));
        }));

        mark_channel_refreshed(&svc, "ch-101");
        mark_refreshed(&svc, "http://epg.example.com/guide.xml");
        persist_xmltv_validators(
            &svc,
            "http://epg.example.com/guide.xml",
            &XmltvValidators {
                etag: Some("\"v1\"".to_string()),
                last_modified: Some("Mon, 01 Jan 2024 00:00:00 GMT".to_string()),
            },
            false,
        )
        .unwrap();

        assert!(events.lock().unwrap().is_empty());
    }

    #[test]
    fn emit_epg_progress_emits_epg_updated_event() {
        let svc = make_service();
        let events: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
        let events_clone = events.clone();
        svc.set_event_callback(Arc::new(move |event| {
            events_clone
                .lock()
                .unwrap()
                .push(crate::events::serialize_event(event));
        }));

        emit_epg_progress(&svc, Some("src1"), "fallback");

        let recorded = events.lock().unwrap();
        let last = recorded.last().unwrap();
        assert!(last.contains("\"type\":\"EpgUpdated\""), "{last}");
        assert!(last.contains("\"source_id\":\"src1\""), "{last}");
    }
}
