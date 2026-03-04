use super::svc;
use anyhow::Result;

/// Get all VOD items in a profile's watchlist as a JSON string.
pub fn get_watchlist_items(profile_id: String) -> Result<String> {
    let items = svc()?.get_watchlist_items(&profile_id)?;
    Ok(serde_json::to_string(&items)?)
}

/// Add a VOD item to the profile's watchlist.
pub fn add_watchlist_item(profile_id: String, vod_item_id: String) -> Result<()> {
    Ok(svc()?.add_watchlist_item(&profile_id, &vod_item_id)?)
}

/// Remove a VOD item from the profile's watchlist.
pub fn remove_watchlist_item(profile_id: String, vod_item_id: String) -> Result<()> {
    Ok(svc()?.remove_watchlist_item(&profile_id, &vod_item_id)?)
}
