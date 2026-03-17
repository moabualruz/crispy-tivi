//! DataProvider abstraction — enables same UI to work with local or remote data.
//!
//! - `LocalProvider` wraps `CrispyService` for native desktop/mobile (direct fn calls)
//! - `RemoteProvider` will connect via WebSocket for WASM/browser (Phase 6 implementation)

use crispy_server::CrispyService;
use crispy_server::models::{Channel, Source, SourceStats, VodItem};

/// Trait abstracting data access for the UI layer.
///
/// Native apps use `LocalProvider` (direct `CrispyService` calls).
/// WASM apps will use `RemoteProvider` (WebSocket to crispy-server).
pub(crate) trait DataProvider {
    fn get_sources(&self) -> Vec<Source>;
    fn get_source_stats(&self) -> Vec<SourceStats>;
    fn save_source(&self, source: &Source) -> anyhow::Result<()>;
    fn delete_source(&self, id: &str) -> anyhow::Result<()>;

    fn get_channels(&self, source_ids: &[String]) -> Vec<Channel>;
    fn get_channels_by_ids(&self, ids: &[String]) -> Vec<Channel>;

    fn get_vod(
        &self,
        source_ids: &[String],
        item_type: Option<&str>,
        query: Option<&str>,
    ) -> Vec<VodItem>;

    fn get_setting(&self, key: &str) -> Option<String>;
    fn set_setting(&self, key: &str, value: &str) -> anyhow::Result<()>;

    fn get_favorites(&self, profile_id: &str) -> Vec<String>;
    fn add_favorite(&self, profile_id: &str, channel_id: &str) -> anyhow::Result<()>;
    fn remove_favorite(&self, profile_id: &str, channel_id: &str) -> anyhow::Result<()>;
}

/// Local data provider — wraps CrispyService for native apps.
#[derive(Clone)]
pub(crate) struct LocalProvider {
    svc: CrispyService,
}

impl LocalProvider {
    pub(crate) fn new(svc: CrispyService) -> Self {
        Self { svc }
    }

    #[allow(dead_code)]
    pub(crate) fn service(&self) -> &CrispyService {
        &self.svc
    }
}

impl DataProvider for LocalProvider {
    fn get_sources(&self) -> Vec<Source> {
        self.svc.get_sources().unwrap_or_default()
    }

    fn get_source_stats(&self) -> Vec<SourceStats> {
        self.svc.get_source_stats().unwrap_or_default()
    }

    fn save_source(&self, source: &Source) -> anyhow::Result<()> {
        self.svc.save_source(source)?;
        Ok(())
    }

    fn delete_source(&self, id: &str) -> anyhow::Result<()> {
        self.svc.delete_source(id)?;
        Ok(())
    }

    fn get_channels(&self, source_ids: &[String]) -> Vec<Channel> {
        self.svc
            .get_channels_by_sources(source_ids)
            .unwrap_or_default()
    }

    fn get_channels_by_ids(&self, ids: &[String]) -> Vec<Channel> {
        self.svc.get_channels_by_ids(ids).unwrap_or_default()
    }

    fn get_vod(
        &self,
        source_ids: &[String],
        item_type: Option<&str>,
        query: Option<&str>,
    ) -> Vec<VodItem> {
        self.svc
            .get_filtered_vod(source_ids, item_type, None, query, "name")
            .unwrap_or_default()
    }

    fn get_setting(&self, key: &str) -> Option<String> {
        self.svc.get_setting(key).ok().flatten()
    }

    fn set_setting(&self, key: &str, value: &str) -> anyhow::Result<()> {
        self.svc.set_setting(key, value)?;
        Ok(())
    }

    fn get_favorites(&self, profile_id: &str) -> Vec<String> {
        self.svc.get_favorites(profile_id).unwrap_or_default()
    }

    fn add_favorite(&self, profile_id: &str, channel_id: &str) -> anyhow::Result<()> {
        self.svc.add_favorite(profile_id, channel_id)?;
        Ok(())
    }

    fn remove_favorite(&self, profile_id: &str, channel_id: &str) -> anyhow::Result<()> {
        self.svc.remove_favorite(profile_id, channel_id)?;
        Ok(())
    }
}

/// Remote data provider — WebSocket client for WASM/browser.
/// Placeholder for Phase 6 full implementation.
#[cfg(target_arch = "wasm32")]
pub(crate) struct RemoteProvider {
    // Will hold WebSocket connection to crispy-server
    _server_url: String,
}

#[cfg(target_arch = "wasm32")]
impl RemoteProvider {
    pub(crate) fn new(server_url: &str) -> Self {
        Self {
            _server_url: server_url.to_string(),
        }
    }
}
