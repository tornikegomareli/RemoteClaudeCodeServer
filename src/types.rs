use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone)]
pub struct ServerState {
    pub auth_uuid: String,
    pub connected_client: Arc<RwLock<Option<SocketAddr>>>,
}

pub enum AuthStatus {
    Success,
    Failed,
    Timeout,
}

impl AuthStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            AuthStatus::Success => "AUTH_SUCCESS",
            AuthStatus::Failed => "AUTH_FAILED",
            AuthStatus::Timeout => "AUTH_TIMEOUT",
        }
    }
}