use futures_util::{SinkExt, StreamExt};
use log::error;
use std::net::SocketAddr;
use tokio::net::TcpStream;
use tokio::time::timeout;
use tokio_tungstenite::{accept_async, tungstenite::Message};
use serde_json::json;
use colored::Colorize;

use crate::auth::AuthManager;
use crate::config::ServerConfig;
use crate::types::{AuthMethod, AuthStatus, ClientInfo, ServerState};
use crate::ui::TerminalUI;

pub struct ConnectionHandler {
    config: ServerConfig,
}

impl ConnectionHandler {
    pub fn new(config: ServerConfig) -> Self {
        Self { config }
    }

    pub async fn handle_connection(
        &self,
        stream: TcpStream,
        addr: SocketAddr,
        state: ServerState,
    ) {
        TerminalUI::print_client_connected(&addr.to_string());

        let ws_stream = match accept_async(stream).await {
            Ok(ws) => ws,
            Err(e) => {
                error!("WebSocket handshake failed for {}: {}", addr, e);
                return;
            }
        };

        let (mut ws_sender, mut ws_receiver) = ws_stream.split();

        let auth_result = timeout(self.config.auth_timeout, ws_receiver.next()).await;

        match auth_result {
            Ok(Some(Ok(Message::Text(auth_message)))) => {
                let auth_message = auth_message.trim();
                
                // Try to parse as JSON first (for reconnection token)
                let auth_method = if let Ok(json_value) = serde_json::from_str::<serde_json::Value>(auth_message) {
                    if let Some(token) = json_value.get("token").and_then(|v| v.as_str()) {
                        AuthMethod::ReconnectionToken(token.to_string())
                    } else {
                        AuthMethod::InitialUuid(auth_message.to_string())
                    }
                } else {
                    // Plain UUID for backward compatibility
                    AuthMethod::InitialUuid(auth_message.to_string())
                };

                self.handle_auth(auth_method, addr, state, ws_sender, ws_receiver).await;
            }
            Ok(_) => {
                self.handle_auth_failure(
                    &mut ws_sender,
                    addr,
                    AuthStatus::Failed,
                    "invalid authentication message",
                )
                .await;
            }
            Err(_) => {
                self.handle_auth_failure(&mut ws_sender, addr, AuthStatus::Timeout, "timeout")
                    .await;
            }
        }
    }

    async fn handle_auth(
        &self,
        auth_method: AuthMethod,
        addr: SocketAddr,
        state: ServerState,
        mut ws_sender: futures_util::stream::SplitSink<
            tokio_tungstenite::WebSocketStream<TcpStream>,
            Message,
        >,
        ws_receiver: futures_util::stream::SplitStream<
            tokio_tungstenite::WebSocketStream<TcpStream>,
        >,
    ) {
        match auth_method {
            AuthMethod::InitialUuid(uuid) => {
                if uuid == state.auth_uuid {
                    // Check if another client is connected
                    let can_connect = {
                        let connected = state.connected_client.read().await;
                        connected.is_none()
                    };

                    if !can_connect {
                        self.handle_auth_failure(
                            &mut ws_sender,
                            addr,
                            AuthStatus::Failed,
                            "another client is already connected",
                        )
                        .await;
                        return;
                    }

                    // Generate tokens and client info
                    let client_id = AuthManager::generate_client_id();
                    let reconnection_token = AuthManager::generate_reconnection_token();
                    
                    let client_info = ClientInfo {
                        addr,
                        client_id: client_id.clone(),
                        reconnection_token: reconnection_token.clone(),
                    };

                    // Store client info and token
                    {
                        let mut connected = state.connected_client.write().await;
                        *connected = Some(client_info);
                    }
                    {
                        let mut tokens = state.reconnection_tokens.write().await;
                        tokens.insert(reconnection_token.clone(), client_id.clone());
                    }

                    TerminalUI::print_client_authenticated(&addr.to_string());

                    // Send success with reconnection token
                    let response = json!({
                        "status": "AUTH_SUCCESS",
                        "reconnection_token": reconnection_token,
                        "client_id": client_id
                    });

                    if let Err(e) = ws_sender.send(Message::Text(response.to_string())).await {
                        error!("Failed to send auth success message: {}", e);
                        return;
                    }

                    self.handle_authenticated_client(ws_sender, ws_receiver, addr, state, client_id)
                        .await;
                } else {
                    self.handle_auth_failure(
                        &mut ws_sender,
                        addr,
                        AuthStatus::Failed,
                        "invalid UUID",
                    )
                    .await;
                }
            }
            AuthMethod::ReconnectionToken(token) => {
                // Validate token
                let client_id = {
                    let tokens = state.reconnection_tokens.read().await;
                    tokens.get(&token).cloned()
                };

                if let Some(client_id) = client_id {
                    // Check if another client is connected
                    let can_reconnect = {
                        let connected = state.connected_client.read().await;
                        connected.is_none() || 
                        (connected.as_ref().map(|c| &c.client_id) == Some(&client_id))
                    };

                    if !can_reconnect {
                        self.handle_auth_failure(
                            &mut ws_sender,
                            addr,
                            AuthStatus::Failed,
                            "another client is already connected",
                        )
                        .await;
                        return;
                    }

                    // Update client info
                    let client_info = ClientInfo {
                        addr,
                        client_id: client_id.clone(),
                        reconnection_token: token,
                    };

                    {
                        let mut connected = state.connected_client.write().await;
                        *connected = Some(client_info);
                    }

                    TerminalUI::print_client_authenticated(&format!("{} (reconnected)", addr));

                    // Send success
                    let response = json!({
                        "status": "AUTH_SUCCESS",
                        "client_id": client_id
                    });

                    if let Err(e) = ws_sender.send(Message::Text(response.to_string())).await {
                        error!("Failed to send auth success message: {}", e);
                        return;
                    }

                    self.handle_authenticated_client(ws_sender, ws_receiver, addr, state, client_id)
                        .await;
                } else {
                    self.handle_auth_failure(
                        &mut ws_sender,
                        addr,
                        AuthStatus::Failed,
                        "invalid reconnection token",
                    )
                    .await;
                }
            }
        }
    }

    async fn handle_auth_failure(
        &self,
        ws_sender: &mut futures_util::stream::SplitSink<
            tokio_tungstenite::WebSocketStream<TcpStream>,
            Message,
        >,
        addr: SocketAddr,
        status: AuthStatus,
        reason: &str,
    ) {
        TerminalUI::print_client_rejected(&addr.to_string(), reason);
        let _ = ws_sender
            .send(Message::Text(status.as_str().to_string()))
            .await;
        let _ = ws_sender.close().await;
    }

    async fn handle_authenticated_client(
        &self,
        mut ws_sender: futures_util::stream::SplitSink<
            tokio_tungstenite::WebSocketStream<TcpStream>,
            Message,
        >,
        mut ws_receiver: futures_util::stream::SplitStream<
            tokio_tungstenite::WebSocketStream<TcpStream>,
        >,
        addr: SocketAddr,
        state: ServerState,
        client_id: String,
    ) {
        while let Some(msg) = ws_receiver.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    TerminalUI::print_message_received(&addr.to_string(), &text);

                    if let Err(e) = ws_sender.send(Message::Text(text.clone())).await {
                        error!("Failed to echo message: {}", e);
                        break;
                    }
                }
                Ok(Message::Close(_)) => {
                    TerminalUI::print_client_disconnected(&addr.to_string());
                    break;
                }
                Err(e) => {
                    error!("Error receiving message: {}", e);
                    break;
                }
                _ => {}
            }
        }

        // Clear connection but keep token valid
        {
            let mut connected = state.connected_client.write().await;
            *connected = None;
        }

        TerminalUI::print_client_disconnected(&addr.to_string());
        
        // Don't shutdown - allow reconnection
        println!("\n{}", "🔄 Server remains active. Client can reconnect using their token.".bright_yellow());
    }
}