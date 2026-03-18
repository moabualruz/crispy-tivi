//! Image cache eviction policy for CrispyTivi.
//!
//! Provides LRU-based eviction configuration and candidate
//! selection for the two-tier image cache (in-memory + disk).
//! The policy itself is pure logic — no file I/O here. Callers
//! supply current usage figures and receive eviction decisions.

use std::time::SystemTime;

// ── CacheEntry ───────────────────────────────────────────

/// Metadata for a single cached image.
#[derive(Debug, Clone)]
pub struct CacheEntry {
    /// Unique key (typically the image URL).
    pub key: String,
    /// Size of the cached image in bytes.
    pub size_bytes: u64,
    /// Last time this entry was accessed.
    pub last_accessed: SystemTime,
    /// Cache tier.
    pub tier: CacheTier,
}

/// Which tier the cached image lives in.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CacheTier {
    /// In-memory cache — fast, small capacity.
    Memory,
    /// Disk cache — slower, larger capacity.
    Disk,
}

// ── ImageCachePolicy ─────────────────────────────────────

/// LRU eviction policy configuration for the image cache.
///
/// Call [`should_evict`](Self::should_evict) to check if the
/// cache is over budget, then
/// [`get_eviction_candidates`](Self::get_eviction_candidates)
/// to get the oldest-accessed entries to remove.
#[derive(Debug, Clone)]
pub struct ImageCachePolicy {
    /// Maximum total cache size in bytes.
    pub max_cache_bytes: u64,
    /// Pressure threshold: start evicting at this fraction.
    /// E.g. `0.9` means evict when at 90 % of `max_cache_bytes`.
    pub evict_at_fraction: f64,
}

impl ImageCachePolicy {
    /// Create a policy with the given byte cap.
    /// Eviction is triggered at 90 % of `max_cache_bytes`.
    pub fn new(max_cache_bytes: u64) -> Self {
        Self {
            max_cache_bytes,
            evict_at_fraction: 0.9,
        }
    }

    /// Returns `true` when `current_bytes` exceeds the eviction
    /// threshold.
    pub fn should_evict(&self, current_bytes: u64) -> bool {
        let threshold = (self.max_cache_bytes as f64 * self.evict_at_fraction) as u64;
        current_bytes >= threshold
    }

    /// Return the `count` least-recently-accessed entries from
    /// `entries`. Entries are sorted oldest-accessed first.
    ///
    /// Callers should evict these entries until
    /// `should_evict` returns `false`.
    pub fn get_eviction_candidates<'a>(
        &self,
        entries: &'a mut [CacheEntry],
        count: usize,
    ) -> Vec<&'a CacheEntry> {
        // Sort by last_accessed ascending (oldest first).
        entries.sort_by(|a, b| {
            a.last_accessed
                .partial_cmp(&b.last_accessed)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        entries.iter().take(count).collect()
    }

    /// Progressive release strategy under memory pressure.
    ///
    /// Returns the tier to clear first (Memory), then Disk.
    /// Callers call this in sequence until pressure is relieved.
    ///
    /// - Stage 1 (`current_bytes` ≥ eviction threshold): evict Memory
    ///   tier candidates.
    /// - Stage 2 (`current_bytes` ≥ 95 % of max): evict Disk tier too.
    /// - Stage 3 (`current_bytes` ≥ max): clear entire cache.
    pub fn pressure_stage(&self, current_bytes: u64) -> PressureStage {
        let pct = current_bytes as f64 / self.max_cache_bytes as f64;
        if pct >= 1.0 {
            PressureStage::ClearAll
        } else if pct >= 0.95 {
            PressureStage::EvictDisk
        } else if pct >= self.evict_at_fraction {
            PressureStage::EvictMemory
        } else {
            PressureStage::None
        }
    }
}

impl Default for ImageCachePolicy {
    fn default() -> Self {
        // 256 MiB default cache budget.
        Self::new(256 * 1024 * 1024)
    }
}

// ── PressureStage ────────────────────────────────────────

/// Memory-pressure release stage.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PressureStage {
    /// No pressure — cache is within budget.
    None,
    /// Evict in-memory tier entries.
    EvictMemory,
    /// Evict both in-memory and disk tier entries.
    EvictDisk,
    /// Release the entire cache immediately.
    ClearAll,
}

// ── Tests ─────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, SystemTime};

    fn make_entry(key: &str, size: u64, age_secs: u64) -> CacheEntry {
        CacheEntry {
            key: key.to_string(),
            size_bytes: size,
            last_accessed: SystemTime::now()
                .checked_sub(Duration::from_secs(age_secs))
                .unwrap_or(SystemTime::UNIX_EPOCH),
            tier: CacheTier::Disk,
        }
    }

    #[test]
    fn test_should_evict_below_threshold() {
        let policy = ImageCachePolicy::new(100);
        assert!(!policy.should_evict(89));
    }

    #[test]
    fn test_should_evict_at_threshold() {
        let policy = ImageCachePolicy::new(100);
        // 90 % of 100 = 90
        assert!(policy.should_evict(90));
    }

    #[test]
    fn test_should_evict_above_threshold() {
        let policy = ImageCachePolicy::new(100);
        assert!(policy.should_evict(99));
    }

    #[test]
    fn test_get_eviction_candidates_oldest_first() {
        let policy = ImageCachePolicy::new(1000);
        let mut entries = vec![
            make_entry("new", 100, 10),  // accessed 10 s ago
            make_entry("mid", 100, 50),  // accessed 50 s ago
            make_entry("old", 100, 200), // accessed 200 s ago
        ];
        let candidates = policy.get_eviction_candidates(&mut entries, 2);
        assert_eq!(candidates.len(), 2);
        // oldest first
        assert_eq!(candidates[0].key, "old");
        assert_eq!(candidates[1].key, "mid");
    }

    #[test]
    fn test_get_eviction_candidates_count_capped() {
        let policy = ImageCachePolicy::new(1000);
        let mut entries = vec![make_entry("a", 100, 5)];
        let candidates = policy.get_eviction_candidates(&mut entries, 10);
        assert_eq!(candidates.len(), 1);
    }

    #[test]
    fn test_pressure_stage_none() {
        let policy = ImageCachePolicy::new(1000);
        assert_eq!(policy.pressure_stage(500), PressureStage::None);
    }

    #[test]
    fn test_pressure_stage_evict_memory() {
        let policy = ImageCachePolicy::new(1000);
        // 90 % of 1000 = 900
        assert_eq!(policy.pressure_stage(920), PressureStage::EvictMemory);
    }

    #[test]
    fn test_pressure_stage_evict_disk() {
        let policy = ImageCachePolicy::new(1000);
        // 95 % of 1000 = 950
        assert_eq!(policy.pressure_stage(960), PressureStage::EvictDisk);
    }

    #[test]
    fn test_pressure_stage_clear_all() {
        let policy = ImageCachePolicy::new(1000);
        assert_eq!(policy.pressure_stage(1000), PressureStage::ClearAll);
        assert_eq!(policy.pressure_stage(1100), PressureStage::ClearAll);
    }

    #[test]
    fn test_default_policy_budget() {
        let policy = ImageCachePolicy::default();
        // Default is 256 MiB.
        assert_eq!(policy.max_cache_bytes, 256 * 1024 * 1024);
    }

    #[test]
    fn test_cache_tier_variants() {
        assert_ne!(CacheTier::Memory, CacheTier::Disk);
    }
}
