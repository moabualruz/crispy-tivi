//! Legacy bulk EPG hook.
//!
//! Bulk per-channel `get_short_epg` fetches are intentionally disabled.
//! Full-background EPG refreshes should come from XMLTV sync; on-demand
//! `get_short_epg` remains available through the facade/resolver L3 path.

use crate::models::{Channel, Source};
use crate::services::ServiceContext;

/// Legacy entrypoint retained for call-site compatibility.
///
/// Tier 2 disables bulk background `get_short_epg` fetches so channel sync
/// does not fan out into per-channel Xtream/Stalker requests.
pub fn spawn_bulk_epg_fetch(_service: ServiceContext, source: Source, channels: Vec<Channel>) {
    tracing::debug!(
        "Bulk get_short_epg disabled for source {} (type {}, {} channels)",
        source.id,
        source.source_type,
        channels.len(),
    );
}
