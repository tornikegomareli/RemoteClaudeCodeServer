use log::info;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio::sync::RwLock;

use crate::auth::AuthManager;
use crate::config::ServerConfig;
use crate::connection::ConnectionHandler;
use crate::types::ServerState;

pub struct WebSocketServer {
    config: ServerConfig,
    auth_manager: AuthManager,
}

impl WebSocketServer {
    pub fn new(config: ServerConfig) -> Self {
        let auth_manager = AuthManager::new();
        
        Self {
            config,
            auth_manager,
        }
    }

    pub async fn run(&self) -> Result<(), Box<dyn std::error::Error>> {
        info!("WebSocket server starting on: {}", self.config.websocket_url());
        self.auth_manager.display_auth_info();

        let listener = TcpListener::bind(&self.config.bind_address()).await?;

        let state = ServerState {
            auth_uuid: self.auth_manager.get_uuid().to_string(),
            connected_client: Arc::new(RwLock::new(None)),
        };

        info!("Server is ready. Waiting for client connection...");
        info!("Client must authenticate with UUID: {}", self.auth_manager.get_uuid());

        while let Ok((stream, addr)) = listener.accept().await {
            let state = state.clone();
            let handler = ConnectionHandler::new(self.config.clone());
            tokio::spawn(async move {
                handler.handle_connection(stream, addr, state).await;
            });
        }

        Ok(())
    }
}

// Implementing Clone for ServerConfig to use it in the server
impl Clone for ServerConfig {
    fn clone(&self) -> Self {
        Self {
            host: self.host.clone(),
            port: self.port,
            auth_timeout: self.auth_timeout,
        }
    }
}