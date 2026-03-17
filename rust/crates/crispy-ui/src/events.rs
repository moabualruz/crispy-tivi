/// Minimal stub for events types shared between cache and the event pipeline.
/// The full events module is being built in parallel; this stub satisfies the
/// cache module's compile-time dependency.

/// UI-facing representation of a live channel.
#[derive(Debug, Clone, Default)]
pub struct ChannelInfo {
    pub id: String,
    pub name: String,
    pub logo_url: String,
    pub stream_url: String,
    pub group: String,
    pub number: i32,
    pub is_favorite: bool,
    pub source_id: String,
}

/// UI-facing representation of a VOD item.
#[derive(Debug, Clone, Default)]
pub struct VodInfo {
    pub id: String,
    pub name: String,
    pub stream_url: String,
    pub item_type: String,
    pub poster_url: String,
    pub category: String,
    pub year: i32,
    pub rating: String,
    pub source_id: String,
    pub series_id: String,
    pub season_number: i32,
    pub episode_number: i32,
}

/// UI-facing representation of a source (playlist).
#[derive(Debug, Clone, Default)]
pub struct SourceInfo {
    pub id: String,
    pub name: String,
    pub source_type: String,
    pub channel_count: i64,
    pub vod_count: i64,
    pub last_sync_status: String,
}

/// Top-level navigation screens.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub enum Screen {
    #[default]
    Home,
    Live,
    Movies,
    Series,
    Library,
    Search,
    Settings,
    Onboarding,
}
