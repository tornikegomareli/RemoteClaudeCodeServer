use std::path::PathBuf;
use std::time::Duration;

pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub auth_timeout: Duration,
    pub remote_url: Option<String>,
    pub repo_paths: Vec<PathBuf>,
}

impl Default for ServerConfig {
    fn default() -> Self {
        let repo_paths = std::env::var("REPO_PATHS")
            .unwrap_or_default()
            .split(',')
            .filter(|s| !s.is_empty())
            .map(|s| PathBuf::from(s.trim()))
            .collect();

        Self {
            host: "127.0.0.1".to_string(),
            port: 9001,
            auth_timeout: Duration::from_secs(5),
            remote_url: std::env::var("REMOTE_URL").ok(),
            repo_paths,
        }
    }
}

impl ServerConfig {
    pub fn bind_address(&self) -> String {
        format!("{}:{}", self.host, self.port)
    }

    pub fn websocket_url(&self) -> String {
        format!("ws://{}/ws", self.bind_address())
    }
}
