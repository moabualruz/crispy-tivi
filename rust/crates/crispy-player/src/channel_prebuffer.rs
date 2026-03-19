//! Channel pre-buffer manager for instant channel switching.
//!
//! Warms TCP+TLS connections for adjacent channels so that switching
//! channels feels near-instant (< 1 s TTFF target).
//!
//! Since libmpv is a singleton, this module does NOT create multiple mpv
//! contexts. Instead it issues HEAD requests to the stream URLs of the
//! prev/next N channels using a shared `reqwest::Client` (which pools
//! connections and caches TLS sessions). When the user actually switches
//! to a pre-warmed channel the TCP handshake and TLS negotiation are
//! already done, dramatically reducing time-to-first-frame.

use std::{collections::HashMap, sync::Arc, time::Instant};

use thiserror::Error;
use tokio::sync::RwLock;
use tracing::{debug, warn};

// ── Errors ───────────────────────────────────────────────────────────────────

#[derive(Debug, Error)]
pub enum PrebufferError {
    #[error("HTTP warmup failed for {url}: {source}")]
    WarmupFailed {
        url: String,
        #[source]
        source: reqwest::Error,
    },
}

// ── Config ────────────────────────────────────────────────────────────────────

/// Configuration for the channel pre-buffer pool.
#[derive(Debug, Clone)]
pub struct ChannelPrebufferConfig {
    /// Number of channels to pre-warm in each direction (default: 2).
    pub adjacent_count: usize,
    /// Timeout for each warmup HEAD request in milliseconds (default: 3000).
    pub warmup_timeout_ms: u64,
    /// Whether pre-buffering is active.
    pub enabled: bool,
}

impl Default for ChannelPrebufferConfig {
    fn default() -> Self {
        Self {
            adjacent_count: 2,
            warmup_timeout_ms: 3000,
            enabled: true,
        }
    }
}

// ── Warmup status ─────────────────────────────────────────────────────────────

/// Result of a single warmup probe.
#[derive(Debug, Clone)]
pub enum WarmupStatus {
    /// Probe dispatched but not yet resolved.
    Pending,
    /// Probe completed successfully; includes observed round-trip latency.
    Warmed { latency_ms: u64 },
    /// Probe failed (timeout, connection refused, DNS error, …).
    Failed { reason: String },
}

// ── Channel context ───────────────────────────────────────────────────────────

/// Minimal per-channel data required by the pre-buffer and the zap overlay.
#[derive(Debug, Clone)]
pub struct ChannelContext {
    pub channel_id: String,
    pub stream_url: String,
    pub channel_name: String,
    pub logo_url: Option<String>,
    pub current_program: Option<String>,
    /// Fractional progress through the current programme (0.0 – 1.0).
    pub program_progress: Option<f32>,
}

// ── Zap overlay ───────────────────────────────────────────────────────────────

/// Data needed to render the channel-change overlay in the UI.
#[derive(Debug, Clone)]
pub struct ZapOverlay {
    pub channel_name: String,
    pub channel_number: Option<u32>,
    pub logo_url: Option<String>,
    pub current_program: Option<String>,
    pub program_progress: Option<f32>,
}

// ── Manager ───────────────────────────────────────────────────────────────────

/// Manages background warmup probes for channels adjacent to the current one.
pub struct ChannelPrebuffer {
    config: ChannelPrebufferConfig,
    http_client: reqwest::Client,
    warmed_urls: Arc<RwLock<HashMap<String, WarmupStatus>>>,
}

impl ChannelPrebuffer {
    /// Create a new manager with the given config and a shared HTTP client.
    pub fn new(config: ChannelPrebufferConfig, http_client: reqwest::Client) -> Self {
        Self {
            config,
            http_client,
            warmed_urls: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Update the warmup pool based on the current channel position.
    ///
    /// Computes the prev/next `adjacent_count` channels, marks them
    /// `Pending`, then spawns Tokio tasks that issue HEAD requests.
    /// Channels already `Warmed` are not re-probed.
    pub async fn update_adjacent(&self, current_index: usize, channels: &[ChannelContext]) {
        if !self.config.enabled || channels.is_empty() {
            return;
        }

        let n = channels.len();
        let count = self.config.adjacent_count;

        // Collect indices to pre-warm (saturating at list boundaries).
        let start = current_index.saturating_sub(count);
        let end = (current_index + count + 1).min(n);

        let mut targets: Vec<String> = Vec::new();
        {
            let mut map = self.warmed_urls.write().await;
            for (idx, ch) in channels[start..end]
                .iter()
                .enumerate()
                .map(|(i, ch)| (start + i, ch))
            {
                if idx == current_index {
                    continue;
                }
                let url = &ch.stream_url;
                if matches!(map.get(url.as_str()), Some(WarmupStatus::Warmed { .. })) {
                    // Already warm — skip.
                    continue;
                }
                map.insert(url.clone(), WarmupStatus::Pending);
                targets.push(url.clone());
            }
        }

        for url in targets {
            let client = self.http_client.clone();
            let warmed_urls = Arc::clone(&self.warmed_urls);
            let timeout_ms = self.config.warmup_timeout_ms;

            tokio::spawn(async move {
                let result = Self::probe(&client, &url, timeout_ms).await;
                let mut map = warmed_urls.write().await;
                match result {
                    Ok(latency_ms) => {
                        debug!(url = %url, latency_ms, "channel pre-warm succeeded");
                        map.insert(url, WarmupStatus::Warmed { latency_ms });
                    }
                    Err(e) => {
                        warn!(url = %url, error = %e, "channel pre-warm failed");
                        map.insert(
                            url.clone(),
                            WarmupStatus::Failed {
                                reason: e.to_string(),
                            },
                        );
                    }
                }
            });
        }
    }

    /// Return the warmup status for a given URL, if known.
    pub fn warmup_status(&self, url: &str) -> Option<WarmupStatus> {
        // Synchronous read: try_read is fine here; callers in tests hold no write lock.
        self.warmed_urls.try_read().ok()?.get(url).cloned()
    }

    /// Build a [`ZapOverlay`] from a [`ChannelContext`].
    pub fn build_zap_overlay(channel: &ChannelContext) -> ZapOverlay {
        ZapOverlay {
            channel_name: channel.channel_name.clone(),
            channel_number: None, // resolved by caller from channel list position
            logo_url: channel.logo_url.clone(),
            current_program: channel.current_program.clone(),
            program_progress: channel.program_progress,
        }
    }

    /// Cancel all pending probes by clearing the map.
    ///
    /// Spawned Tokio tasks run to completion but their results are discarded
    /// because the map no longer contains their URLs as `Pending`.
    pub async fn cancel_all(&self) {
        self.warmed_urls.write().await.clear();
    }

    /// Return a snapshot of all currently tracked (warm + pending + failed) URLs.
    pub async fn warmed_urls(&self) -> Vec<String> {
        self.warmed_urls.read().await.keys().cloned().collect()
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    async fn probe(
        client: &reqwest::Client,
        url: &str,
        timeout_ms: u64,
    ) -> Result<u64, PrebufferError> {
        let timeout = std::time::Duration::from_millis(timeout_ms);
        let t0 = Instant::now();
        client
            .head(url)
            .timeout(timeout)
            .send()
            .await
            .map_err(|e| PrebufferError::WarmupFailed {
                url: url.to_owned(),
                source: e,
            })?;
        Ok(t0.elapsed().as_millis() as u64)
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use wiremock::{
        Mock, MockServer, ResponseTemplate,
        matchers::{method, path},
    };

    fn make_client() -> reqwest::Client {
        reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(5))
            .build()
            .expect("reqwest client")
    }

    fn make_channel(id: &str, url: &str) -> ChannelContext {
        ChannelContext {
            channel_id: id.to_owned(),
            stream_url: url.to_owned(),
            channel_name: format!("Channel {id}"),
            logo_url: Some(format!("https://logos.test/{id}.png")),
            current_program: Some("Evening News".to_owned()),
            program_progress: Some(0.42),
        }
    }

    // ── 1 ─────────────────────────────────────────────────────────────────────

    #[test]
    fn test_new_creates_with_default_config() {
        let cfg = ChannelPrebufferConfig::default();
        let pb = ChannelPrebuffer::new(cfg.clone(), make_client());
        assert_eq!(pb.config.adjacent_count, 2);
        assert_eq!(pb.config.warmup_timeout_ms, 3000);
        assert!(pb.config.enabled);
    }

    // ── 2 ─────────────────────────────────────────────────────────────────────

    #[test]
    fn test_build_zap_overlay_includes_all_fields() {
        let ch = ChannelContext {
            channel_id: "42".to_owned(),
            stream_url: "http://example.test/live/42.ts".to_owned(),
            channel_name: "Sports HD".to_owned(),
            logo_url: Some("http://example.test/logos/42.png".to_owned()),
            current_program: Some("World Cup Final".to_owned()),
            program_progress: Some(0.75),
        };
        let overlay = ChannelPrebuffer::build_zap_overlay(&ch);
        assert_eq!(overlay.channel_name, "Sports HD");
        assert_eq!(
            overlay.logo_url.as_deref(),
            Some("http://example.test/logos/42.png")
        );
        assert_eq!(overlay.current_program.as_deref(), Some("World Cup Final"));
        assert!((overlay.program_progress.unwrap() - 0.75).abs() < f32::EPSILON);
        assert!(overlay.channel_number.is_none());
    }

    // ── 3 ─────────────────────────────────────────────────────────────────────

    #[test]
    fn test_build_zap_overlay_handles_missing_optional_fields() {
        let ch = ChannelContext {
            channel_id: "1".to_owned(),
            stream_url: "http://example.test/1.ts".to_owned(),
            channel_name: "Basic".to_owned(),
            logo_url: None,
            current_program: None,
            program_progress: None,
        };
        let overlay = ChannelPrebuffer::build_zap_overlay(&ch);
        assert_eq!(overlay.channel_name, "Basic");
        assert!(overlay.logo_url.is_none());
        assert!(overlay.current_program.is_none());
        assert!(overlay.program_progress.is_none());
    }

    // ── 4 ─────────────────────────────────────────────────────────────────────

    #[test]
    fn test_warmup_status_returns_none_for_unknown_url() {
        let pb = ChannelPrebuffer::new(ChannelPrebufferConfig::default(), make_client());
        assert!(pb.warmup_status("http://unknown.test/stream.ts").is_none());
    }

    // ── 5 ─────────────────────────────────────────────────────────────────────

    #[tokio::test]
    async fn test_update_adjacent_warms_correct_channels() {
        let server = MockServer::start().await;
        Mock::given(method("HEAD"))
            .and(path("/live/1.ts"))
            .respond_with(ResponseTemplate::new(200))
            .mount(&server)
            .await;
        Mock::given(method("HEAD"))
            .and(path("/live/3.ts"))
            .respond_with(ResponseTemplate::new(200))
            .mount(&server)
            .await;

        let base = server.uri();
        let channels: Vec<ChannelContext> = (0u32..5)
            .map(|i| make_channel(&i.to_string(), &format!("{base}/live/{i}.ts")))
            .collect();

        let cfg = ChannelPrebufferConfig {
            adjacent_count: 1,
            warmup_timeout_ms: 2000,
            enabled: true,
        };
        let pb = ChannelPrebuffer::new(cfg, make_client());
        pb.update_adjacent(2, &channels).await;

        // Give spawned tasks time to finish.
        tokio::time::sleep(std::time::Duration::from_millis(300)).await;

        let warmed = pb.warmed_urls().await;
        assert!(
            warmed.contains(&format!("{base}/live/1.ts")),
            "channel 1 should be warmed"
        );
        assert!(
            warmed.contains(&format!("{base}/live/3.ts")),
            "channel 3 should be warmed"
        );
        // Channel at current_index should NOT be in the map.
        assert!(
            !warmed.contains(&format!("{base}/live/2.ts")),
            "current channel should not be pre-warmed"
        );
    }

    // ── 6 ─────────────────────────────────────────────────────────────────────

    #[tokio::test]
    async fn test_update_adjacent_handles_edge_of_list() {
        let server = MockServer::start().await;
        Mock::given(method("HEAD"))
            .respond_with(ResponseTemplate::new(200))
            .mount(&server)
            .await;

        let base = server.uri();
        let channels: Vec<ChannelContext> = (0u32..3)
            .map(|i| make_channel(&i.to_string(), &format!("{base}/edge/{i}.ts")))
            .collect();

        let cfg = ChannelPrebufferConfig {
            adjacent_count: 5, // asks for more than list has
            warmup_timeout_ms: 2000,
            enabled: true,
        };
        let pb = ChannelPrebuffer::new(cfg, make_client());
        // At position 0 — no previous channels exist.
        pb.update_adjacent(0, &channels).await;

        tokio::time::sleep(std::time::Duration::from_millis(300)).await;

        let warmed = pb.warmed_urls().await;
        // Only channels 1 and 2 should appear (channel 0 = current).
        assert!(!warmed.contains(&format!("{base}/edge/0.ts")));
        assert!(warmed.contains(&format!("{base}/edge/1.ts")));
        assert!(warmed.contains(&format!("{base}/edge/2.ts")));
    }

    // ── 7 ─────────────────────────────────────────────────────────────────────

    #[tokio::test]
    async fn test_cancel_all_clears_warmed_urls() {
        let pb = ChannelPrebuffer::new(ChannelPrebufferConfig::default(), make_client());
        {
            let mut map = pb.warmed_urls.write().await;
            map.insert(
                "http://a.test/1.ts".to_owned(),
                WarmupStatus::Warmed { latency_ms: 50 },
            );
            map.insert("http://a.test/2.ts".to_owned(), WarmupStatus::Pending);
        }
        assert_eq!(pb.warmed_urls().await.len(), 2);
        pb.cancel_all().await;
        assert!(pb.warmed_urls().await.is_empty());
    }

    // ── 8 ─────────────────────────────────────────────────────────────────────

    #[tokio::test]
    async fn test_warmed_urls_returns_current_pool() {
        let pb = ChannelPrebuffer::new(ChannelPrebufferConfig::default(), make_client());
        {
            let mut map = pb.warmed_urls.write().await;
            map.insert(
                "http://pool.test/ch1.ts".to_owned(),
                WarmupStatus::Warmed { latency_ms: 120 },
            );
            map.insert(
                "http://pool.test/ch2.ts".to_owned(),
                WarmupStatus::Failed {
                    reason: "timeout".to_owned(),
                },
            );
        }
        let urls = pb.warmed_urls().await;
        assert_eq!(urls.len(), 2);
        assert!(urls.contains(&"http://pool.test/ch1.ts".to_owned()));
        assert!(urls.contains(&"http://pool.test/ch2.ts".to_owned()));
    }
}
