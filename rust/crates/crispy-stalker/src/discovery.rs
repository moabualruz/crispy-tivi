//! Portal URL discovery — probes multiple known paths to find the portal.

use reqwest::Client;
use tracing::debug;

use crate::error::StalkerError;

/// Known portal path suffixes to try, in priority order.
const PORTAL_PATHS: &[&str] = &[
    "/stalker_portal/c/",
    "/c/",
    "/portal.php",
    "/server/load.php",
    "/stalker_portal/server/load.php",
];

/// Probe a base URL to discover the Stalker portal endpoint.
///
/// Tries each known path suffix and returns the first one that responds
/// with HTTP 200. The returned URL is the full portal URL including the
/// path suffix, ready for API requests.
pub async fn discover_portal(client: &Client, base_url: &str) -> Result<String, StalkerError> {
    let base = base_url.trim_end_matches('/');

    for path in PORTAL_PATHS {
        let url = format!("{base}{path}");
        debug!(url = %url, "probing portal path");

        match client.get(&url).send().await {
            Ok(resp) if resp.status().is_success() || resp.status().is_redirection() => {
                debug!(url = %url, status = %resp.status(), "portal found");
                return Ok(url);
            }
            Ok(resp) => {
                debug!(
                    url = %url,
                    status = %resp.status(),
                    "portal path returned non-success"
                );
            }
            Err(e) => {
                debug!(url = %url, error = %e, "portal path probe failed");
            }
        }
    }

    Err(StalkerError::PortalNotFound(base.into()))
}

/// All known portal paths (exposed for testing).
pub fn known_paths() -> &'static [&'static str] {
    PORTAL_PATHS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_paths_includes_standard_entries() {
        let paths = known_paths();
        assert!(paths.contains(&"/c/"));
        assert!(paths.contains(&"/stalker_portal/c/"));
        assert!(paths.contains(&"/server/load.php"));
    }
}
