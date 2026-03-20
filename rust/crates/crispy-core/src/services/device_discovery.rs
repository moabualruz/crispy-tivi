//! Device discovery service (Epoch 10.2).
//!
//! Scans the local network for castable devices via mDNS service records:
//! - Google Cast: `_googlecast._tcp`
//! - AirPlay:     `_airplay._tcp`
//! - DLNA/UPnP:   `_upnp._tcp` / SSDP M-SEARCH
//!
//! Actual network I/O is injected via the [`DiscoveryBackend`] trait so
//! that unit tests can run without touching the network.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use thiserror::Error;

// ── Error ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Error)]
pub enum DiscoveryError {
    #[error("discovery backend error: {0}")]
    Backend(String),
    #[error("scan already in progress")]
    ScanInProgress,
}

// ── Domain types ──────────────────────────────────────────────────────────────

/// Protocol type reported by mDNS / SSDP.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum DeviceProtocol {
    GoogleCast,
    AirPlay,
    Dlna,
}

impl DeviceProtocol {
    /// mDNS service name for this protocol.
    pub fn mdns_service(&self) -> &'static str {
        match self {
            DeviceProtocol::GoogleCast => "_googlecast._tcp",
            DeviceProtocol::AirPlay => "_airplay._tcp",
            DeviceProtocol::Dlna => "_upnp._tcp",
        }
    }
}

/// A discovered device on the local network.
#[derive(Debug, Clone, PartialEq)]
pub struct DiscoveredDevice {
    /// Stable unique identifier (mDNS instance name or UDN).
    pub id: String,
    /// Human-readable display name.
    pub name: String,
    /// IP address of the device.
    pub host: String,
    /// TCP port for the control endpoint.
    pub port: u16,
    /// Which protocol this device speaks.
    pub protocol: DeviceProtocol,
    /// Optional TXT record key/value pairs (e.g. Cast model name).
    pub txt: HashMap<String, String>,
    /// When this record was last seen during a scan.
    pub last_seen: Instant,
}

// ── Backend trait ─────────────────────────────────────────────────────────────

/// Abstraction over mDNS + SSDP I/O so the service is testable.
pub trait DiscoveryBackend: Send + Sync {
    /// Browse one mDNS service type and return all discovered records.
    fn browse_mdns(
        &self,
        service_type: &str,
        timeout: Duration,
    ) -> Result<Vec<DiscoveredDevice>, DiscoveryError>;
}

// ── Noop backend ──────────────────────────────────────────────────────────────

/// No-op backend that always returns an empty list.
/// Used when no real mDNS library is available (e.g. WASM).
#[derive(Debug, Default)]
pub struct NoopDiscoveryBackend;

impl DiscoveryBackend for NoopDiscoveryBackend {
    fn browse_mdns(
        &self,
        _service_type: &str,
        _timeout: Duration,
    ) -> Result<Vec<DiscoveredDevice>, DiscoveryError> {
        Ok(vec![])
    }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Manages the device registry and drives periodic scans.
pub struct DeviceDiscoveryService {
    backend: Arc<dyn DiscoveryBackend>,
    /// Known devices indexed by their `id`.
    devices: Arc<Mutex<HashMap<String, DiscoveredDevice>>>,
    /// How long to keep a device that hasn't been seen again.
    ttl: Duration,
    /// Protocols to scan.
    protocols: Vec<DeviceProtocol>,
    /// Per-protocol browse timeout.
    scan_timeout: Duration,
    /// `true` while a scan is executing.
    scanning: Arc<Mutex<bool>>,
}

impl DeviceDiscoveryService {
    /// Create with a custom backend and TTL.
    pub fn new(backend: Arc<dyn DiscoveryBackend>, ttl: Duration) -> Self {
        Self {
            backend,
            devices: Arc::new(Mutex::new(HashMap::new())),
            ttl,
            protocols: vec![
                DeviceProtocol::GoogleCast,
                DeviceProtocol::AirPlay,
                DeviceProtocol::Dlna,
            ],
            scan_timeout: Duration::from_secs(3),
            scanning: Arc::new(Mutex::new(false)),
        }
    }

    /// Create with the no-op backend (safe default).
    pub fn noop() -> Self {
        Self::new(Arc::new(NoopDiscoveryBackend), Duration::from_secs(60))
    }

    /// Set per-protocol mDNS browse timeout.
    pub fn with_scan_timeout(mut self, t: Duration) -> Self {
        self.scan_timeout = t;
        self
    }

    /// Perform a synchronous scan of all configured protocols.
    ///
    /// Results are merged into the internal device registry.
    /// Devices not seen within `ttl` are evicted.
    pub fn scan(&self) -> Result<Vec<DiscoveredDevice>, DiscoveryError> {
        {
            let mut scanning = self.scanning.lock().unwrap_or_else(|e| e.into_inner());
            if *scanning {
                return Err(DiscoveryError::ScanInProgress);
            }
            *scanning = true;
        }
        let _guard = ScanGuard(Arc::clone(&self.scanning));

        let mut found: HashMap<String, DiscoveredDevice> = HashMap::new();
        for protocol in &self.protocols {
            let records = self
                .backend
                .browse_mdns(protocol.mdns_service(), self.scan_timeout)?;
            for dev in records {
                found.insert(dev.id.clone(), dev);
            }
        }

        // Merge into registry; evict stale entries.
        let now = Instant::now();
        let mut devices = self.devices.lock().unwrap_or_else(|e| e.into_inner());
        for (id, dev) in found {
            devices.insert(id, dev);
        }
        devices.retain(|_, dev| now.duration_since(dev.last_seen) < self.ttl);

        Ok(devices.values().cloned().collect())
    }

    /// Return a snapshot of the current device registry without scanning.
    pub fn known_devices(&self) -> Vec<DiscoveredDevice> {
        self.devices
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .values()
            .cloned()
            .collect()
    }

    /// Evict all devices with a specific protocol (e.g. after service disabled).
    pub fn evict_protocol(&self, protocol: DeviceProtocol) {
        let mut devices = self.devices.lock().unwrap_or_else(|e| e.into_inner());
        devices.retain(|_, dev| dev.protocol != protocol);
    }

    /// Clear the entire registry.
    pub fn clear(&self) {
        self.devices
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clear();
    }
}

/// RAII guard that clears the `scanning` flag on drop.
struct ScanGuard(Arc<Mutex<bool>>);

impl Drop for ScanGuard {
    fn drop(&mut self) {
        *self.0.lock().unwrap_or_else(|e| e.into_inner()) = false;
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn make_device(id: &str, protocol: DeviceProtocol) -> DiscoveredDevice {
        DiscoveredDevice {
            id: id.to_string(),
            name: format!("Device {id}"),
            host: "192.168.1.100".to_string(),
            port: 8009,
            protocol,
            txt: HashMap::new(),
            last_seen: Instant::now(),
        }
    }

    // ── Stub backend ──────────────────────────────────────────────────────────

    struct StubBackend {
        records: Vec<DiscoveredDevice>,
    }

    impl DiscoveryBackend for StubBackend {
        fn browse_mdns(
            &self,
            _service_type: &str,
            _timeout: Duration,
        ) -> Result<Vec<DiscoveredDevice>, DiscoveryError> {
            Ok(self.records.clone())
        }
    }

    struct ErrorBackend;

    impl DiscoveryBackend for ErrorBackend {
        fn browse_mdns(
            &self,
            _service_type: &str,
            _timeout: Duration,
        ) -> Result<Vec<DiscoveredDevice>, DiscoveryError> {
            Err(DiscoveryError::Backend("simulated failure".into()))
        }
    }

    // ── DeviceProtocol ────────────────────────────────────────────────────────

    #[test]
    fn test_device_protocol_mdns_service_google_cast() {
        assert_eq!(
            DeviceProtocol::GoogleCast.mdns_service(),
            "_googlecast._tcp"
        );
    }

    #[test]
    fn test_device_protocol_mdns_service_airplay() {
        assert_eq!(DeviceProtocol::AirPlay.mdns_service(), "_airplay._tcp");
    }

    #[test]
    fn test_device_protocol_mdns_service_dlna() {
        assert_eq!(DeviceProtocol::Dlna.mdns_service(), "_upnp._tcp");
    }

    #[test]
    fn test_device_protocol_equality() {
        assert_eq!(DeviceProtocol::GoogleCast, DeviceProtocol::GoogleCast);
        assert_ne!(DeviceProtocol::GoogleCast, DeviceProtocol::AirPlay);
    }

    // ── NoopDiscoveryBackend ──────────────────────────────────────────────────

    #[test]
    fn test_noop_backend_returns_empty() {
        let b = NoopDiscoveryBackend;
        let result = b
            .browse_mdns("_googlecast._tcp", Duration::from_millis(10))
            .unwrap();
        assert!(result.is_empty());
    }

    // ── DeviceDiscoveryService ────────────────────────────────────────────────

    #[test]
    fn test_scan_returns_discovered_devices() {
        let dev = make_device("cast-001", DeviceProtocol::GoogleCast);
        let svc = DeviceDiscoveryService::new(
            Arc::new(StubBackend {
                records: vec![dev.clone()],
            }),
            Duration::from_secs(60),
        );
        let result = svc.scan().unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].id, "cast-001");
    }

    #[test]
    fn test_scan_merges_multiple_protocols() {
        let cast = make_device("cast-001", DeviceProtocol::GoogleCast);
        let airplay = make_device("ap-001", DeviceProtocol::AirPlay);
        let svc = DeviceDiscoveryService::new(
            Arc::new(StubBackend {
                records: vec![cast, airplay],
            }),
            Duration::from_secs(60),
        );
        let result = svc.scan().unwrap();
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_scan_deduplicates_same_id() {
        let dev1 = make_device("cast-001", DeviceProtocol::GoogleCast);
        let dev2 = make_device("cast-001", DeviceProtocol::GoogleCast);
        let svc = DeviceDiscoveryService::new(
            Arc::new(StubBackend {
                records: vec![dev1, dev2],
            }),
            Duration::from_secs(60),
        );
        let result = svc.scan().unwrap();
        assert_eq!(result.len(), 1);
    }

    #[test]
    fn test_known_devices_empty_before_scan() {
        let svc = DeviceDiscoveryService::noop();
        assert!(svc.known_devices().is_empty());
    }

    #[test]
    fn test_known_devices_populated_after_scan() {
        let dev = make_device("cast-001", DeviceProtocol::GoogleCast);
        let svc = DeviceDiscoveryService::new(
            Arc::new(StubBackend { records: vec![dev] }),
            Duration::from_secs(60),
        );
        svc.scan().unwrap();
        assert_eq!(svc.known_devices().len(), 1);
    }

    #[test]
    fn test_evict_protocol_removes_matching() {
        let cast = make_device("cast-001", DeviceProtocol::GoogleCast);
        let airplay = make_device("ap-001", DeviceProtocol::AirPlay);
        let svc = DeviceDiscoveryService::new(
            Arc::new(StubBackend {
                records: vec![cast, airplay],
            }),
            Duration::from_secs(60),
        );
        svc.scan().unwrap();
        svc.evict_protocol(DeviceProtocol::GoogleCast);
        let remaining = svc.known_devices();
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].protocol, DeviceProtocol::AirPlay);
    }

    #[test]
    fn test_clear_removes_all_devices() {
        let dev = make_device("cast-001", DeviceProtocol::GoogleCast);
        let svc = DeviceDiscoveryService::new(
            Arc::new(StubBackend { records: vec![dev] }),
            Duration::from_secs(60),
        );
        svc.scan().unwrap();
        svc.clear();
        assert!(svc.known_devices().is_empty());
    }

    #[test]
    fn test_scan_propagates_backend_error() {
        let svc = DeviceDiscoveryService::new(Arc::new(ErrorBackend), Duration::from_secs(60));
        assert!(matches!(svc.scan(), Err(DiscoveryError::Backend(_))));
    }

    #[test]
    fn test_noop_service_scan_returns_empty() {
        let svc = DeviceDiscoveryService::noop();
        let result = svc.scan().unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn test_ttl_evicts_stale_device() {
        // Device with last_seen 2 minutes ago should be evicted.
        let mut dev = make_device("cast-old", DeviceProtocol::GoogleCast);
        dev.last_seen = Instant::now() - Duration::from_secs(120);

        // Stub returns the stale device; TTL is 60s so it should be evicted.
        let svc = DeviceDiscoveryService::new(
            Arc::new(StubBackend { records: vec![dev] }),
            Duration::from_secs(60),
        );
        // Force the stale device into the registry directly.
        {
            let mut guard = svc.devices.lock().unwrap();
            let stale = make_device("cast-old", DeviceProtocol::GoogleCast);
            let mut stale = stale;
            stale.last_seen = Instant::now() - Duration::from_secs(120);
            guard.insert("cast-old".to_string(), stale);
        }
        // A fresh scan with an empty backend will evict the stale entry.
        let svc2 = DeviceDiscoveryService::new(
            Arc::new(StubBackend { records: vec![] }),
            Duration::from_secs(60),
        );
        {
            let mut guard = svc2.devices.lock().unwrap();
            let mut stale = make_device("cast-old", DeviceProtocol::GoogleCast);
            stale.last_seen = Instant::now() - Duration::from_secs(120);
            guard.insert("cast-old".to_string(), stale);
        }
        let result = svc2.scan().unwrap();
        assert!(result.is_empty(), "stale device should have been evicted");
    }

    #[test]
    fn test_with_scan_timeout_builder() {
        let svc = DeviceDiscoveryService::noop().with_scan_timeout(Duration::from_millis(500));
        assert_eq!(svc.scan_timeout, Duration::from_millis(500));
    }

    #[test]
    fn test_discovered_device_fields() {
        let mut txt = HashMap::new();
        txt.insert("md".to_string(), "Chromecast".to_string());
        let dev = DiscoveredDevice {
            id: "id1".to_string(),
            name: "Living Room TV".to_string(),
            host: "10.0.0.1".to_string(),
            port: 8009,
            protocol: DeviceProtocol::GoogleCast,
            txt,
            last_seen: Instant::now(),
        };
        assert_eq!(dev.port, 8009);
        assert_eq!(dev.txt.get("md").unwrap(), "Chromecast");
    }
}
