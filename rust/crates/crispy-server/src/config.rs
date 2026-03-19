//! Server configuration.
//!
//! Loaded from environment variables with CLI-arg overrides.
//! All fields have sensible defaults so the server works
//! out-of-the-box without any configuration.

/// Top-level server configuration.
#[derive(Debug, Clone)]
pub struct ServerConfig {
    /// Port for the HTTP server (static files + health + proxy).
    pub http_port: u16,
    /// Port for the WebSocket API server.
    pub ws_port: u16,
    /// Optional directory to serve as static files (WASM build output).
    /// When `None`, the `/` route is disabled and only `/health`, `/proxy`,
    /// and `/ws` are available.
    pub static_dir: Option<String>,
    /// Path to the SQLite database file.
    pub db_path: String,
    /// Comma-separated list of allowed CORS origins.
    /// Empty string → allow any origin (dev / LAN mode).
    pub cors_origins: String,
}

impl ServerConfig {
    /// Load configuration from environment variables with sensible defaults.
    ///
    /// | Variable                | Default                                    |
    /// |-------------------------|--------------------------------------------|
    /// | `CRISPY_HTTP_PORT`      | `8080`                                     |
    /// | `CRISPY_WS_PORT`        | `8081`                                     |
    /// | `CRISPY_STATIC_DIR`     | *(unset — static serving disabled)*        |
    /// | `CRISPY_DB_PATH`        | `~/.crispytivi/data/crispy_tivi_v2.sqlite` |
    /// | `CRISPY_ALLOWED_ORIGINS`| *(empty — allow any)*                      |
    pub fn from_env() -> Self {
        Self {
            http_port: env_u16("CRISPY_HTTP_PORT", 8080),
            ws_port: env_u16("CRISPY_WS_PORT", 8081),
            static_dir: std::env::var("CRISPY_STATIC_DIR")
                .ok()
                .filter(|s| !s.is_empty()),
            db_path: std::env::var("CRISPY_DB_PATH")
                .ok()
                .filter(|s| !s.is_empty())
                .unwrap_or_else(default_db_path),
            cors_origins: std::env::var("CRISPY_ALLOWED_ORIGINS").unwrap_or_default(),
        }
    }
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            http_port: 8080,
            ws_port: 8081,
            static_dir: None,
            db_path: default_db_path(),
            cors_origins: String::new(),
        }
    }
}

// ── Helpers ─────────────────────────────────────────

fn env_u16(key: &str, default: u16) -> u16 {
    std::env::var(key)
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(default)
}

fn default_db_path() -> String {
    let home = std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .unwrap_or_else(|_| ".".to_string());
    let dir = format!("{home}/.crispytivi/data");
    let _ = std::fs::create_dir_all(&dir);
    format!("{dir}/crispy_tivi_v2.sqlite")
}

// ── Tests ────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config_has_expected_ports() {
        let cfg = ServerConfig::default();
        assert_eq!(cfg.http_port, 8080);
        assert_eq!(cfg.ws_port, 8081);
        assert!(cfg.static_dir.is_none());
        assert!(cfg.cors_origins.is_empty());
    }

    #[test]
    fn test_from_env_reads_http_port() {
        // SAFETY: single-threaded test; no other thread reads CRISPY_HTTP_PORT.
        unsafe { std::env::set_var("CRISPY_HTTP_PORT", "9090") };
        let cfg = ServerConfig::from_env();
        unsafe { std::env::remove_var("CRISPY_HTTP_PORT") };
        assert_eq!(cfg.http_port, 9090);
    }

    #[test]
    fn test_from_env_reads_ws_port() {
        // SAFETY: single-threaded test; no other thread reads CRISPY_WS_PORT.
        unsafe { std::env::set_var("CRISPY_WS_PORT", "9091") };
        let cfg = ServerConfig::from_env();
        unsafe { std::env::remove_var("CRISPY_WS_PORT") };
        assert_eq!(cfg.ws_port, 9091);
    }

    #[test]
    fn test_from_env_reads_static_dir() {
        // SAFETY: single-threaded test; no other thread reads CRISPY_STATIC_DIR.
        unsafe { std::env::set_var("CRISPY_STATIC_DIR", "/tmp/wasm") };
        let cfg = ServerConfig::from_env();
        unsafe { std::env::remove_var("CRISPY_STATIC_DIR") };
        assert_eq!(cfg.static_dir.as_deref(), Some("/tmp/wasm"));
    }

    #[test]
    fn test_from_env_static_dir_none_when_empty() {
        // SAFETY: single-threaded test; no other thread reads CRISPY_STATIC_DIR.
        unsafe { std::env::set_var("CRISPY_STATIC_DIR", "") };
        let cfg = ServerConfig::from_env();
        unsafe { std::env::remove_var("CRISPY_STATIC_DIR") };
        assert!(cfg.static_dir.is_none());
    }

    #[test]
    fn test_from_env_reads_db_path() {
        // SAFETY: single-threaded test; no other thread reads CRISPY_DB_PATH.
        unsafe { std::env::set_var("CRISPY_DB_PATH", "/tmp/test.sqlite") };
        let cfg = ServerConfig::from_env();
        unsafe { std::env::remove_var("CRISPY_DB_PATH") };
        assert_eq!(cfg.db_path, "/tmp/test.sqlite");
    }

    #[test]
    fn test_from_env_reads_cors_origins() {
        // SAFETY: single-threaded test; no other thread reads CRISPY_ALLOWED_ORIGINS.
        unsafe {
            std::env::set_var(
                "CRISPY_ALLOWED_ORIGINS",
                "http://localhost:3000,http://192.168.1.10:8080",
            )
        };
        let cfg = ServerConfig::from_env();
        unsafe { std::env::remove_var("CRISPY_ALLOWED_ORIGINS") };
        assert_eq!(
            cfg.cors_origins,
            "http://localhost:3000,http://192.168.1.10:8080"
        );
    }

    #[test]
    fn test_from_env_invalid_port_uses_default() {
        // SAFETY: single-threaded test; no other thread reads CRISPY_HTTP_PORT.
        unsafe { std::env::set_var("CRISPY_HTTP_PORT", "not_a_number") };
        let cfg = ServerConfig::from_env();
        unsafe { std::env::remove_var("CRISPY_HTTP_PORT") };
        assert_eq!(cfg.http_port, 8080);
    }
}
