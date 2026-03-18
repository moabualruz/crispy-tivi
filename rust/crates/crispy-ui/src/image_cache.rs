//! HTTP image cache with touch-TTL and LRU eviction.
//!
//! - Downloads images via reqwest with ETag/If-None-Match headers
//! - Stores raw bytes on disk in content-addressable files (SHA256 of URL)
//! - Tracks metadata (ETag, last_accessed, size) in a sidecar JSON index
//! - 7-day TTL refreshed on each access ("touch on read")
//! - LRU eviction when total disk usage exceeds quota (default 500 MB)
//! - Decodes to `slint::Image` on demand

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, SystemTime};

use reqwest::Client;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use slint::Image;
use tokio::sync::RwLock;

// ── Constants ────────────────────────────────────────────────────────────────

const DEFAULT_TTL_SECS: u64 = 7 * 24 * 3600; // 7 days
const DEFAULT_MAX_BYTES: u64 = 500 * 1024 * 1024; // 500 MB
const INDEX_FILE: &str = "index.json";

// ── CacheEntry ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
struct CacheEntry {
    url: String,
    etag: Option<String>,
    last_accessed: u64,
    size_bytes: u64,
}

// ── ImageCache ───────────────────────────────────────────────────────────────

#[derive(Clone)]
pub struct ImageCache {
    client: Client,
    cache_dir: PathBuf,
    entries: Arc<RwLock<HashMap<String, CacheEntry>>>,
    ttl: Duration,
    max_bytes: u64,
}

impl ImageCache {
    /// Create a new image cache backed by the platform cache directory.
    pub fn new(client: Client) -> Self {
        let cache_dir = dirs::cache_dir()
            .unwrap_or_else(|| PathBuf::from(".cache"))
            .join("crispy-tivi")
            .join("images");
        let _ = std::fs::create_dir_all(&cache_dir);

        let mut cache = Self {
            client,
            cache_dir,
            entries: Arc::new(RwLock::new(HashMap::new())),
            ttl: Duration::from_secs(DEFAULT_TTL_SECS),
            max_bytes: DEFAULT_MAX_BYTES,
        };
        cache.load_index();
        cache
    }

    /// Load the index from disk (synchronous — called once at startup).
    fn load_index(&mut self) {
        let index_path = self.cache_dir.join(INDEX_FILE);
        if let Ok(data) = std::fs::read_to_string(&index_path)
            && let Ok(entries) = serde_json::from_str::<HashMap<String, CacheEntry>>(&data)
        {
            tracing::info!(count = entries.len(), "Image cache index loaded");
            *self.entries.blocking_write() = entries;
        }
    }

    /// Persist the index to disk.
    fn save_index(&self, entries: &HashMap<String, CacheEntry>) {
        let index_path = self.cache_dir.join(INDEX_FILE);
        if let Ok(json) = serde_json::to_string(entries) {
            let _ = std::fs::write(&index_path, json);
        }
    }

    /// Fetch an image from cache or network. Returns decoded Slint SharedPixelBuffer.
    ///
    /// Handles HTTP URLs (with ETag caching) and `data:` URIs (inline base64).
    /// Touch-refreshes TTL on every access. Only revalidates via HTTP when
    /// >80% of TTL has elapsed.
    pub async fn get_image_buffer(
        &self,
        url: &str,
    ) -> Option<slint::SharedPixelBuffer<slint::Rgba8Pixel>> {
        // Handle data: URIs (inline base64-encoded images)
        if let Some(buf) = Self::decode_data_uri(url) {
            return Some(buf);
        }

        let hash = Self::url_to_hash(url);
        let now = now_secs();

        // Check if we have a valid cached entry
        {
            let mut entries = self.entries.write().await;
            if let Some(entry) = entries.get_mut(&hash) {
                let age = now.saturating_sub(entry.last_accessed);
                entry.last_accessed = now;

                // Try decode from disk
                if let Some(buf) = self.decode_buffer_from_disk(&hash) {
                    // Background revalidate if >80% TTL elapsed
                    if age > self.ttl.as_secs() * 80 / 100 {
                        let this = self.clone();
                        let url_owned = url.to_owned();
                        let hash_clone = hash.clone();
                        tokio::spawn(async move {
                            let _ = this
                                .download_and_cache_buffer(&url_owned, &hash_clone, now_secs())
                                .await;
                        });
                    }
                    return Some(buf);
                }
            }
        }

        // Cache miss — full download
        self.download_and_cache_buffer(url, &hash, now).await
    }

    /// Download an image and store it on disk.
    async fn download_and_cache_buffer(
        &self,
        url: &str,
        hash: &str,
        now: u64,
    ) -> Option<slint::SharedPixelBuffer<slint::Rgba8Pixel>> {
        // Build request with User-Agent (required by Wikimedia and others) + conditional headers
        let mut req = self
            .client
            .get(url)
            .header(
                "User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            )
            .header("Accept-Encoding", "identity");
        {
            let entries = self.entries.read().await;
            if let Some(entry) = entries.get(hash)
                && let Some(ref etag) = entry.etag
            {
                req = req.header("If-None-Match", etag.as_str());
            }
        }

        let response = match req.send().await {
            Ok(r) => r,
            Err(e) => {
                tracing::debug!(url, error = %e, "Image download failed");
                return self.decode_buffer_from_disk(hash);
            }
        };

        // 304 Not Modified — cached version is still valid
        if response.status() == reqwest::StatusCode::NOT_MODIFIED {
            let mut entries = self.entries.write().await;
            if let Some(entry) = entries.get_mut(hash) {
                entry.last_accessed = now;
            }
            return self.decode_buffer_from_disk(hash);
        }

        if !response.status().is_success() {
            tracing::debug!(url, status = %response.status(), "Image download non-success");
            return None;
        }

        let etag = response
            .headers()
            .get("etag")
            .and_then(|v| v.to_str().ok())
            .map(str::to_owned);

        let bytes = match response.bytes().await {
            Ok(b) => b,
            Err(e) => {
                tracing::debug!(url, error = %e, "Failed to read image bytes");
                return None;
            }
        };

        let size = bytes.len() as u64;

        // Write to disk
        let path = self.cache_path(hash);
        if let Err(e) = std::fs::write(&path, &bytes) {
            tracing::warn!(error = %e, "Failed to write image to cache");
            // Still try to decode from memory
        }

        // Update index
        {
            let mut entries = self.entries.write().await;
            entries.insert(
                hash.to_owned(),
                CacheEntry {
                    url: url.to_owned(),
                    etag,
                    last_accessed: now,
                    size_bytes: size,
                },
            );
            self.save_index(&entries);

            // Evict if over quota
            self.evict_if_needed(&mut entries);
        }

        // Decode
        decode_buffer_bytes(&bytes)
    }

    /// Decode an image from disk cache.
    fn decode_buffer_from_disk(
        &self,
        hash: &str,
    ) -> Option<slint::SharedPixelBuffer<slint::Rgba8Pixel>> {
        let path = self.cache_path(hash);
        let bytes = std::fs::read(&path).ok()?;
        decode_buffer_bytes(&bytes)
    }

    /// Remove entries that exceed the max size quota (LRU eviction).
    fn evict_if_needed(&self, entries: &mut HashMap<String, CacheEntry>) {
        let total: u64 = entries.values().map(|e| e.size_bytes).sum();
        if total <= self.max_bytes {
            return;
        }

        // Sort by last_accessed ascending (oldest first)
        let mut sorted: Vec<(String, u64, u64)> = entries
            .iter()
            .map(|(k, v)| (k.clone(), v.last_accessed, v.size_bytes))
            .collect();
        sorted.sort_by_key(|(_, accessed, _)| *accessed);

        let mut current = total;
        for (hash, _, size) in &sorted {
            if current <= self.max_bytes {
                break;
            }
            let path = self.cache_path(hash);
            let _ = std::fs::remove_file(&path);
            entries.remove(hash);
            current -= size;
        }

        self.save_index(entries);
        tracing::info!(
            evicted = sorted.len().saturating_sub(entries.len()),
            "LRU eviction completed"
        );
    }

    /// Remove entries older than TTL.
    pub async fn cleanup_expired(&self) {
        let now = now_secs();
        let mut entries = self.entries.write().await;
        let expired: Vec<String> = entries
            .iter()
            .filter(|(_, e)| now.saturating_sub(e.last_accessed) > self.ttl.as_secs())
            .map(|(k, _)| k.clone())
            .collect();

        for hash in &expired {
            let path = self.cache_path(hash);
            let _ = tokio::fs::remove_file(&path).await;
            entries.remove(hash);
        }
        if !expired.is_empty() {
            tracing::info!(
                count = expired.len(),
                "Cleaned up expired image cache entries"
            );
            self.save_index(&entries);
        }
    }

    /// SHA256 hash of a URL, used as the cache file name.
    fn url_to_hash(url: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(url.as_bytes());
        format!("{:x}", hasher.finalize())
    }

    /// Decode inline image data from `data:image/...;base64,...` URIs
    /// or Stalker-style `s:1:/images/...` pseudo-URIs.
    /// Returns `None` if the URL is not a data/pseudo URI or decoding fails.
    fn decode_data_uri(url: &str) -> Option<slint::SharedPixelBuffer<slint::Rgba8Pixel>> {
        use base64::Engine;

        if let Some(rest) = url.strip_prefix("data:") {
            // Format: image/png;base64,<data>
            let (_mime, rest) = rest.split_once(';')?;
            let data = rest.strip_prefix("base64,")?;
            if data.is_empty() {
                return None;
            }
            let bytes = base64::engine::general_purpose::STANDARD
                .decode(data)
                .ok()?;
            return decode_buffer_bytes(&bytes);
        }

        if let Some(raw) = url.strip_prefix("s:1:/images/") {
            // Stalker portal URL-safe base64 (no padding)
            let padded = format!("{}{}", raw, &"==="[..((4 - raw.len() % 4) % 4)]);
            let bytes = base64::engine::general_purpose::URL_SAFE
                .decode(padded.as_bytes())
                .ok()?;
            return decode_buffer_bytes(&bytes);
        }

        None
    }

    /// Path to the cached file for a given hash.
    fn cache_path(&self, hash: &str) -> PathBuf {
        self.cache_dir.join(hash)
    }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

/// Decode raw image bytes into a Slint SharedPixelBuffer.
fn decode_buffer_bytes(bytes: &[u8]) -> Option<slint::SharedPixelBuffer<slint::Rgba8Pixel>> {
    let dynamic = image::load_from_memory(bytes).ok()?;
    let rgba = dynamic.to_rgba8();
    let (w, h) = (rgba.width(), rgba.height());
    let buffer =
        slint::SharedPixelBuffer::<slint::Rgba8Pixel>::clone_from_slice(rgba.as_raw(), w, h);
    Some(buffer)
}

/// Decode raw image bytes into a Slint Image.
#[cfg_attr(not(test), allow(dead_code))]
fn decode_image_bytes(bytes: &[u8]) -> Option<Image> {
    decode_buffer_bytes(bytes).map(Image::from_rgba8)
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_url_to_hash_deterministic() {
        let h1 = ImageCache::url_to_hash("https://example.com/logo.png");
        let h2 = ImageCache::url_to_hash("https://example.com/logo.png");
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64); // SHA256 hex = 64 chars
    }

    #[test]
    fn test_url_to_hash_differs_for_different_urls() {
        let h1 = ImageCache::url_to_hash("https://example.com/a.png");
        let h2 = ImageCache::url_to_hash("https://example.com/b.png");
        assert_ne!(h1, h2);
    }

    #[test]
    fn test_decode_image_bytes_png() {
        // Generate a valid 1x1 red PNG using the image crate
        let mut img = image::RgbaImage::new(1, 1);
        img.put_pixel(0, 0, image::Rgba([255, 0, 0, 255]));
        let mut buf = std::io::Cursor::new(Vec::new());
        img.write_to(&mut buf, image::ImageFormat::Png).unwrap();
        let result = decode_image_bytes(buf.get_ref());
        assert!(result.is_some());
    }

    #[test]
    fn test_decode_image_bytes_invalid_returns_none() {
        let result = decode_image_bytes(b"not an image");
        assert!(result.is_none());
    }
}
