//! Proxy list loading and geoblock confirmation.
//!
//! Translated from IPTVChecker-Python `load_proxy_list()` and
//! `test_with_proxy()`.

use tracing::{debug, warn};
use url::Url;

/// Supported proxy URL schemes.
const VALID_SCHEMES: &[&str] = &["http", "https", "socks4", "socks4a", "socks5", "socks5h"];

/// Parse a proxy list from raw text content.
///
/// Supports three formats (matching IPTVChecker-Python `load_proxy_list()`):
///
/// 1. **JSON array** — objects with `ip`, `port`, optional `protocol`/`protocols`
///    fields, or plain strings.
/// 2. **Protocol-prefixed** — `http://1.2.3.4:8080`
/// 3. **Plain text** — `1.2.3.4:8080` (defaults to `http://`)
///
/// Lines starting with `#` are treated as comments and skipped.
pub fn parse_proxy_list(content: &str) -> Vec<String> {
    let trimmed = content.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }

    // Try JSON first.
    let raw_entries = try_parse_json(trimmed).unwrap_or_else(|| parse_plain_text(trimmed));

    let mut valid = Vec::new();
    for (idx, entry) in raw_entries.iter().enumerate() {
        match validate_proxy_entry(entry) {
            Ok(normalized) => valid.push(normalized),
            Err(reason) => {
                warn!(
                    proxy_index = idx + 1,
                    entry = entry.as_str(),
                    reason = reason.as_str(),
                    "skipping invalid proxy entry"
                );
            }
        }
    }

    if !raw_entries.is_empty() {
        debug!(
            total = raw_entries.len(),
            valid = valid.len(),
            skipped = raw_entries.len() - valid.len(),
            "proxy list loaded"
        );
    }

    valid
}

/// Try to parse the content as a JSON array of proxy entries.
fn try_parse_json(content: &str) -> Option<Vec<String>> {
    let value: serde_json::Value = serde_json::from_str(content).ok()?;
    let array = value.as_array()?;

    let mut entries = Vec::new();
    for item in array {
        match item {
            serde_json::Value::String(s) => {
                entries.push(s.clone());
            }
            serde_json::Value::Object(obj) => {
                let ip = obj.get("ip").and_then(|v| v.as_str());
                let port = obj.get("port").and_then(|v| {
                    v.as_u64()
                        .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
                });

                if let (Some(ip), Some(port)) = (ip, port) {
                    // Check for `protocols` array first, then `protocol` string.
                    if let Some(protocols) = obj.get("protocols").and_then(|v| v.as_array()) {
                        for proto in protocols {
                            if let Some(p) = proto.as_str() {
                                entries.push(format!("{p}://{ip}:{port}"));
                            }
                        }
                    } else {
                        let protocol = obj
                            .get("protocol")
                            .and_then(|v| v.as_str())
                            .unwrap_or("http");
                        entries.push(format!("{protocol}://{ip}:{port}"));
                    }
                }
            }
            _ => {}
        }
    }

    Some(entries)
}

/// Parse plain-text proxy list (one entry per line, `#` comments).
fn parse_plain_text(content: &str) -> Vec<String> {
    content
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
        .map(String::from)
        .collect()
}

/// Validate and normalize a single proxy entry.
///
/// Translation of IPTVChecker-Python `validate_proxy_entry()`:
/// - Adds `http://` if no scheme present
/// - Validates scheme, hostname, and port
/// - Returns `scheme://netloc` on success
fn validate_proxy_entry(entry: &str) -> Result<String, String> {
    let candidate = entry.trim();
    if candidate.is_empty() {
        return Err("entry is empty".into());
    }

    // Extract scheme if present.
    let (original_scheme, without_scheme) = if let Some(idx) = candidate.find("://") {
        let scheme = candidate[..idx].to_lowercase();
        let rest = &candidate[idx + 3..];
        (scheme, rest.to_string())
    } else {
        ("http".to_string(), candidate.to_string())
    };

    if !VALID_SCHEMES.contains(&original_scheme.as_str()) {
        return Err(format!("unsupported proxy scheme '{original_scheme}'"));
    }

    // Parse using http:// so url crate recognizes host:port for all schemes.
    let parse_url = format!("http://{without_scheme}");
    let parsed = Url::parse(&parse_url).map_err(|e| format!("invalid proxy URL: {e}"))?;

    if parsed.host_str().is_none() {
        return Err("missing proxy host".into());
    }

    let port = parsed.port().ok_or("missing proxy port")?;
    if port == 0 {
        return Err(format!("proxy port {port} is out of range (1-65535)"));
    }

    let path = parsed.path();
    if path != "/" && !path.is_empty() && path.len() > 1 {
        return Err("proxy URL must not include a path".into());
    }

    if parsed.query().is_some() || parsed.fragment().is_some() {
        return Err("proxy URL must not include query or fragment".into());
    }

    let host = parsed.host_str().unwrap();
    Ok(format!("{original_scheme}://{host}:{port}"))
}

/// Test stream access through a specific proxy for geoblock confirmation.
///
/// Translation of IPTVChecker-Python `test_with_proxy()`:
/// - Makes a GET request through the proxy
/// - Checks for 200 status + stream content type
/// - Reads up to 500 KB to verify data flows
///
/// Returns `true` if the stream is accessible through the proxy (confirming
/// it is geoblocked from the original location).
pub async fn test_with_proxy(
    url: &str,
    proxy_url: &str,
    timeout_ms: u64,
) -> Result<bool, crate::error::CheckerError> {
    let proxy = reqwest::Proxy::all(proxy_url)
        .map_err(|e| crate::error::CheckerError::InvalidUrl(format!("bad proxy URL: {e}")))?;

    let client = reqwest::Client::builder()
        .proxy(proxy)
        .timeout(std::time::Duration::from_millis(timeout_ms))
        .connect_timeout(std::time::Duration::from_secs(5))
        .user_agent("VLC/3.0.14 LibVLC/3.0.14")
        .build()?;

    let resp = client.get(url).send().await?;
    if resp.status().as_u16() != 200 {
        return Ok(false);
    }

    let content_type = resp
        .headers()
        .get(reqwest::header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_lowercase();

    let is_stream = content_type.starts_with("video/")
        || content_type.starts_with("audio/")
        || content_type.contains("mpegurl")
        || content_type.contains("octet-stream")
        || content_type.contains("mp4");

    if !is_stream {
        return Ok(false);
    }

    // Read up to 500 KB to verify data flows.
    let bytes = resp.bytes().await?;
    Ok(!bytes.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_plain_text_proxies() {
        let content = "1.2.3.4:8080\n5.6.7.8:3128\n# comment\n\n9.10.11.12:1080";
        let result = parse_proxy_list(content);
        assert_eq!(result.len(), 3);
        assert_eq!(result[0], "http://1.2.3.4:8080");
        assert_eq!(result[1], "http://5.6.7.8:3128");
        assert_eq!(result[2], "http://9.10.11.12:1080");
    }

    #[test]
    fn parse_protocol_prefixed_proxies() {
        let content = "socks5://1.2.3.4:1080\nhttps://5.6.7.8:443";
        let result = parse_proxy_list(content);
        assert_eq!(result.len(), 2);
        assert_eq!(result[0], "socks5://1.2.3.4:1080");
        assert_eq!(result[1], "https://5.6.7.8:443");
    }

    #[test]
    fn parse_json_array_proxies() {
        let content = r#"[
            {"ip": "1.2.3.4", "port": 8080, "protocol": "http"},
            {"ip": "5.6.7.8", "port": 1080, "protocols": ["socks5", "socks4"]},
            "https://9.10.11.12:443"
        ]"#;
        let result = parse_proxy_list(content);
        assert_eq!(result.len(), 4);
        assert_eq!(result[0], "http://1.2.3.4:8080");
        assert_eq!(result[1], "socks5://5.6.7.8:1080");
        assert_eq!(result[2], "socks4://5.6.7.8:1080");
        assert_eq!(result[3], "https://9.10.11.12:443");
    }

    #[test]
    fn parse_json_default_protocol() {
        let content = r#"[{"ip": "1.2.3.4", "port": 3128}]"#;
        let result = parse_proxy_list(content);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0], "http://1.2.3.4:3128");
    }

    #[test]
    fn rejects_invalid_scheme() {
        let content = "ftp://1.2.3.4:21";
        let result = parse_proxy_list(content);
        assert!(result.is_empty());
    }

    #[test]
    fn rejects_missing_port() {
        let content = "1.2.3.4";
        let result = parse_proxy_list(content);
        assert!(result.is_empty());
    }

    #[test]
    fn empty_content_returns_empty() {
        assert!(parse_proxy_list("").is_empty());
        assert!(parse_proxy_list("   ").is_empty());
    }
}
