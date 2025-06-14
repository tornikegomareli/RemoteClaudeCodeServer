use crate::repository::Repository;
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone)]
pub struct ServerState {
    pub auth_uuid: String,
    pub connected_client: Arc<RwLock<Option<ClientInfo>>>,
    pub reconnection_tokens: Arc<RwLock<HashMap<String, String>>>, // token -> client_id
    pub repositories: Arc<RwLock<Vec<Repository>>>,
    pub selected_repository: Arc<RwLock<Option<Repository>>>,
}

#[derive(Clone)]
pub struct ClientInfo {
    pub addr: SocketAddr,
    pub client_id: String,
    pub reconnection_token: String,
}

pub enum AuthStatus {
    Success(String), // Contains reconnection token
    Failed,
    Timeout,
}

impl AuthStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            AuthStatus::Success(_) => "AUTH_SUCCESS",
            AuthStatus::Failed => "AUTH_FAILED",
            AuthStatus::Timeout => "AUTH_TIMEOUT",
        }
    }
}

pub enum AuthMethod {
    InitialUuid(String),
    ReconnectionToken(String),
}
