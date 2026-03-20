//! Watch position sync service (Epoch 10.8).
//!
//! Persists watch position on pause, stop, and every 30 seconds during
//! playback. Also pushes the current position to all connected cast devices.
//!
//! The DB write path uses `CrispyService::save_watch_history`. Cast device
//! push is injected via [`PositionPushBackend`] so the service is testable.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use thiserror::Error;

// ── Error ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Error)]
pub enum WatchSyncError {
    #[error("no active session to sync")]
    NoSession,
    #[error("push error: {0}")]
    Push(String),
    #[error("storage error: {0}")]
    Storage(String),
}

// ── Domain types ──────────────────────────────────────────────────────────────

/// Trigger that caused a position write.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SyncTrigger {
    /// Periodic heartbeat (every 30 s during playback).
    Heartbeat,
    /// User paused.
    Paused,
    /// Playback stopped (end of stream or user action).
    Stopped,
    /// App is being closed.
    AppExit,
}

/// A watch position record to be persisted and pushed.
#[derive(Debug, Clone)]
pub struct WatchPosition {
    /// Unique identifier for the media item (channel id, vod id, etc.).
    pub media_id: String,
    /// Human-readable title.
    pub title: String,
    /// Playback URL.
    pub stream_url: String,
    /// Current playback position in milliseconds.
    pub position_ms: i64,
    /// Total duration in milliseconds (0 if unknown / live stream).
    pub duration_ms: i64,
    /// Profile id that owns this session.
    pub profile_id: String,
}

// ── Storage trait ─────────────────────────────────────────────────────────────

/// Abstraction over the history persistence layer.
pub trait PositionStorage: Send + Sync {
    fn save(&self, pos: &WatchPosition) -> Result<(), WatchSyncError>;
}

// ── Push backend trait ────────────────────────────────────────────────────────

/// Abstraction over sending the position to connected cast devices.
pub trait PositionPushBackend: Send + Sync {
    /// Push position to all active cast sessions (fire-and-forget acceptable).
    fn push(&self, pos: &WatchPosition) -> Result<(), WatchSyncError>;
}

// ── Noop impls ────────────────────────────────────────────────────────────────

#[derive(Debug, Default)]
pub struct NoopPositionStorage;

impl PositionStorage for NoopPositionStorage {
    fn save(&self, _pos: &WatchPosition) -> Result<(), WatchSyncError> {
        Ok(())
    }
}

#[derive(Debug, Default)]
pub struct NoopPositionPushBackend;

impl PositionPushBackend for NoopPositionPushBackend {
    fn push(&self, _pos: &WatchPosition) -> Result<(), WatchSyncError> {
        Ok(())
    }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Manages watch-position persistence and cross-device sync.
pub struct WatchPositionSyncService {
    storage: Arc<dyn PositionStorage>,
    push: Arc<dyn PositionPushBackend>,
    /// Heartbeat interval (default 30 s).
    heartbeat_interval: Duration,
    /// Current session.
    session: Arc<Mutex<Option<WatchPosition>>>,
    /// When the last heartbeat write occurred.
    last_heartbeat: Arc<Mutex<Option<Instant>>>,
    /// Total number of syncs performed (for testing/metrics).
    sync_count: Arc<Mutex<u64>>,
}

impl WatchPositionSyncService {
    pub fn new(storage: Arc<dyn PositionStorage>, push: Arc<dyn PositionPushBackend>) -> Self {
        Self {
            storage,
            push,
            heartbeat_interval: Duration::from_secs(30),
            session: Arc::new(Mutex::new(None)),
            last_heartbeat: Arc::new(Mutex::new(None)),
            sync_count: Arc::new(Mutex::new(0)),
        }
    }

    pub fn noop() -> Self {
        Self::new(
            Arc::new(NoopPositionStorage),
            Arc::new(NoopPositionPushBackend),
        )
    }

    /// Override heartbeat interval (for testing).
    pub fn with_heartbeat_interval(mut self, interval: Duration) -> Self {
        self.heartbeat_interval = interval;
        self
    }

    /// Start a new playback session.
    pub fn start_session(&self, pos: WatchPosition) {
        *self.session.lock().unwrap_or_else(|e| e.into_inner()) = Some(pos);
        *self
            .last_heartbeat
            .lock()
            .unwrap_or_else(|e| e.into_inner()) = Some(Instant::now());
    }

    /// Update the position in the active session (does NOT write to storage).
    pub fn update_position(&self, position_ms: i64) -> Result<(), WatchSyncError> {
        let mut guard = self.session.lock().unwrap_or_else(|e| e.into_inner());
        let session = guard.as_mut().ok_or(WatchSyncError::NoSession)?;
        session.position_ms = position_ms;
        Ok(())
    }

    /// Called on a regular tick (e.g. every second from the player).
    /// Writes to storage and pushes if the heartbeat interval has elapsed.
    pub fn tick(&self, position_ms: i64) -> Result<(), WatchSyncError> {
        self.update_position(position_ms)?;

        let should_heartbeat = {
            let last = self
                .last_heartbeat
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            last.is_none_or(|t| t.elapsed() >= self.heartbeat_interval)
        };

        if should_heartbeat {
            self.do_sync(SyncTrigger::Heartbeat)?;
        }
        Ok(())
    }

    /// Notify the service of a pause event.
    pub fn on_pause(&self, position_ms: i64) -> Result<(), WatchSyncError> {
        self.update_position(position_ms)?;
        self.do_sync(SyncTrigger::Paused)
    }

    /// Notify the service of a stop event. Clears the session.
    pub fn on_stop(&self, position_ms: i64) -> Result<(), WatchSyncError> {
        self.update_position(position_ms)?;
        let result = self.do_sync(SyncTrigger::Stopped);
        // Clear session after final write regardless of push result.
        *self.session.lock().unwrap_or_else(|e| e.into_inner()) = None;
        *self
            .last_heartbeat
            .lock()
            .unwrap_or_else(|e| e.into_inner()) = None;
        result
    }

    /// Flush all sessions on app exit.
    pub fn on_app_exit(&self) -> Result<(), WatchSyncError> {
        let has_session = self
            .session
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .is_some();
        if has_session {
            self.do_sync(SyncTrigger::AppExit)?;
        }
        Ok(())
    }

    /// Return the current session snapshot (if any).
    pub fn current_session(&self) -> Option<WatchPosition> {
        self.session
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
    }

    /// Total number of successful syncs (for observability).
    pub fn sync_count(&self) -> u64 {
        *self.sync_count.lock().unwrap_or_else(|e| e.into_inner())
    }

    // ── Internals ────────────────────────────────────────────────────────────

    fn do_sync(&self, _trigger: SyncTrigger) -> Result<(), WatchSyncError> {
        let pos = {
            self.session
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .clone()
                .ok_or(WatchSyncError::NoSession)?
        };

        // Persist to storage.
        self.storage.save(&pos)?;

        // Push to connected devices (best-effort; log but don't fail on push error).
        let _ = self.push.push(&pos);

        // Update heartbeat timestamp.
        *self
            .last_heartbeat
            .lock()
            .unwrap_or_else(|e| e.into_inner()) = Some(Instant::now());

        // Increment counter.
        let mut count = self.sync_count.lock().unwrap_or_else(|e| e.into_inner());
        *count += 1;
        Ok(())
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn make_position(id: &str, pos_ms: i64) -> WatchPosition {
        WatchPosition {
            media_id: id.to_string(),
            title: "Test Channel".to_string(),
            stream_url: "http://example.com/stream.m3u8".to_string(),
            position_ms: pos_ms,
            duration_ms: 0,
            profile_id: "profile-1".to_string(),
        }
    }

    // ── Recording storage ─────────────────────────────────────────────────────

    #[derive(Default, Clone)]
    struct RecordingStorage {
        calls: Arc<Mutex<Vec<WatchPosition>>>,
    }

    impl PositionStorage for RecordingStorage {
        fn save(&self, pos: &WatchPosition) -> Result<(), WatchSyncError> {
            self.calls
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(pos.clone());
            Ok(())
        }
    }

    #[derive(Default, Clone)]
    struct RecordingPush {
        calls: Arc<Mutex<Vec<WatchPosition>>>,
    }

    impl PositionPushBackend for RecordingPush {
        fn push(&self, pos: &WatchPosition) -> Result<(), WatchSyncError> {
            self.calls
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(pos.clone());
            Ok(())
        }
    }

    struct FailStorage;

    impl PositionStorage for FailStorage {
        fn save(&self, _pos: &WatchPosition) -> Result<(), WatchSyncError> {
            Err(WatchSyncError::Storage("disk full".into()))
        }
    }

    // ── start_session ─────────────────────────────────────────────────────────

    #[test]
    fn test_no_session_initially() {
        let svc = WatchPositionSyncService::noop();
        assert!(svc.current_session().is_none());
    }

    #[test]
    fn test_start_session_stores_session() {
        let svc = WatchPositionSyncService::noop();
        svc.start_session(make_position("ch-1", 0));
        assert_eq!(svc.current_session().unwrap().media_id, "ch-1");
    }

    // ── update_position ───────────────────────────────────────────────────────

    #[test]
    fn test_update_position_changes_position() {
        let svc = WatchPositionSyncService::noop();
        svc.start_session(make_position("ch-1", 0));
        svc.update_position(5000).unwrap();
        assert_eq!(svc.current_session().unwrap().position_ms, 5000);
    }

    #[test]
    fn test_update_position_fails_without_session() {
        let svc = WatchPositionSyncService::noop();
        assert!(matches!(
            svc.update_position(1000),
            Err(WatchSyncError::NoSession)
        ));
    }

    // ── on_pause ──────────────────────────────────────────────────────────────

    #[test]
    fn test_on_pause_writes_to_storage() {
        let storage = Arc::new(RecordingStorage::default());
        let svc = WatchPositionSyncService::new(
            Arc::clone(&storage) as Arc<dyn PositionStorage>,
            Arc::new(NoopPositionPushBackend),
        );
        svc.start_session(make_position("ch-1", 0));
        svc.on_pause(10_000).unwrap();
        let calls = storage.calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].position_ms, 10_000);
    }

    #[test]
    fn test_on_pause_pushes_to_cast() {
        let push = Arc::new(RecordingPush::default());
        let svc = WatchPositionSyncService::new(
            Arc::new(NoopPositionStorage),
            Arc::clone(&push) as Arc<dyn PositionPushBackend>,
        );
        svc.start_session(make_position("ch-1", 0));
        svc.on_pause(5_000).unwrap();
        let calls = push.calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].position_ms, 5_000);
    }

    // ── on_stop ───────────────────────────────────────────────────────────────

    #[test]
    fn test_on_stop_writes_and_clears_session() {
        let storage = Arc::new(RecordingStorage::default());
        let svc = WatchPositionSyncService::new(
            Arc::clone(&storage) as Arc<dyn PositionStorage>,
            Arc::new(NoopPositionPushBackend),
        );
        svc.start_session(make_position("ch-1", 0));
        svc.on_stop(20_000).unwrap();
        // Session cleared.
        assert!(svc.current_session().is_none());
        // Write occurred.
        let calls = storage.calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].position_ms, 20_000);
    }

    // ── tick / heartbeat ──────────────────────────────────────────────────────

    #[test]
    fn test_tick_heartbeat_writes_after_interval() {
        let storage = Arc::new(RecordingStorage::default());
        let svc = WatchPositionSyncService::new(
            Arc::clone(&storage) as Arc<dyn PositionStorage>,
            Arc::new(NoopPositionPushBackend),
        )
        // Force immediate heartbeat.
        .with_heartbeat_interval(Duration::from_millis(0));

        svc.start_session(make_position("ch-1", 0));
        svc.tick(1_000).unwrap();
        svc.tick(2_000).unwrap();

        let calls = storage.calls.lock().unwrap();
        assert!(calls.len() >= 2);
    }

    #[test]
    fn test_tick_no_heartbeat_before_interval() {
        let storage = Arc::new(RecordingStorage::default());
        let svc = WatchPositionSyncService::new(
            Arc::clone(&storage) as Arc<dyn PositionStorage>,
            Arc::new(NoopPositionPushBackend),
        )
        // Interval far in future — no heartbeat fires after session start.
        .with_heartbeat_interval(Duration::from_secs(999));

        svc.start_session(make_position("ch-1", 0));
        // Both ticks are well within the 999s interval — no writes expected.
        svc.tick(1_000).unwrap();
        svc.tick(2_000).unwrap();

        let calls = storage.calls.lock().unwrap();
        assert_eq!(
            calls.len(),
            0,
            "no heartbeat should fire within 999s interval"
        );
    }

    // ── on_app_exit ───────────────────────────────────────────────────────────

    #[test]
    fn test_on_app_exit_flushes_session() {
        let storage = Arc::new(RecordingStorage::default());
        let svc = WatchPositionSyncService::new(
            Arc::clone(&storage) as Arc<dyn PositionStorage>,
            Arc::new(NoopPositionPushBackend),
        );
        svc.start_session(make_position("ch-1", 5_000));
        svc.on_app_exit().unwrap();
        let calls = storage.calls.lock().unwrap();
        assert_eq!(calls.len(), 1);
    }

    #[test]
    fn test_on_app_exit_no_session_is_ok() {
        let svc = WatchPositionSyncService::noop();
        // Should not error when no session active.
        svc.on_app_exit().unwrap();
    }

    // ── sync_count ────────────────────────────────────────────────────────────

    #[test]
    fn test_sync_count_increments() {
        let svc = WatchPositionSyncService::noop();
        svc.start_session(make_position("ch-1", 0));
        svc.on_pause(1_000).unwrap();
        svc.on_pause(2_000).unwrap();
        assert_eq!(svc.sync_count(), 2);
    }

    // ── storage error propagation ─────────────────────────────────────────────

    #[test]
    fn test_storage_error_propagates() {
        let svc =
            WatchPositionSyncService::new(Arc::new(FailStorage), Arc::new(NoopPositionPushBackend));
        svc.start_session(make_position("ch-1", 0));
        assert!(matches!(
            svc.on_pause(1_000),
            Err(WatchSyncError::Storage(_))
        ));
    }

    // ── WatchPosition fields ──────────────────────────────────────────────────

    #[test]
    fn test_watch_position_fields() {
        let pos = make_position("vod-001", 30_000);
        assert_eq!(pos.media_id, "vod-001");
        assert_eq!(pos.position_ms, 30_000);
        assert_eq!(pos.profile_id, "profile-1");
    }
}
