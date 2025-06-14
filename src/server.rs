use std::sync::Arc;
use tokio::net::TcpListener;
use tokio::sync::RwLock;

use crate::auth::AuthManager;
use crate::config::ServerConfig;
use crate::connection::ConnectionHandler;
use crate::repository::scan_repositories;
use crate::types::ServerState;
use crate::ui::TerminalUI;

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
        TerminalUI::display_startup_screen(
            self.auth_manager.get_uuid(),
            &self.config.websocket_url(),
            self.config.remote_url.as_deref(),
        );

        let listener = TcpListener::bind(&self.config.bind_address()).await?;

        let repositories = scan_repositories(&self.config.repo_paths);
        println!("📁 Found {} repositories", repositories.len());

        let state = ServerState {
            auth_uuid: self.auth_manager.get_uuid().to_string(),
            connected_client: Arc::new(RwLock::new(None)),
            reconnection_tokens: Arc::new(RwLock::new(std::collections::HashMap::new())),
            repositories: Arc::new(RwLock::new(repositories)),
            selected_repository: Arc::new(RwLock::new(None)),
        };

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

impl Clone for ServerConfig {
    fn clone(&self) -> Self {
        Self {
            host: self.host.clone(),
            port: self.port,
            auth_timeout: self.auth_timeout,
            remote_url: self.remote_url.clone(),
            repo_paths: self.repo_paths.clone(),
        }
    }
}
