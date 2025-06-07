use std::time::Duration;

pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub auth_timeout: Duration,
    pub remote_url: Option<String>,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            host: "127.0.0.1".to_string(),
            port: 9001,
            auth_timeout: Duration::from_secs(5),
            remote_url: std::env::var("REMOTE_URL").ok(),
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