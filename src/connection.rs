use chrono::Local;
use futures_util::{SinkExt, StreamExt};
use log::{error, info, warn};
use std::net::SocketAddr;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::time::timeout;
use tokio_tungstenite::{accept_async, tungstenite::Message};

use crate::config::ServerConfig;
use crate::types::{AuthStatus, ServerState};

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
        info!(
            "[{}] New connection attempt from: {}",
            Local::now().format("%Y-%m-%d %H:%M:%S"),
            addr
        );

        // Check if another client is already connected
        {
            let connected = state.connected_client.read().await;
            if connected.is_some() {
                warn!(
                    "[{}] Rejecting connection from {} - another client is already connected",
                    Local::now().format("%Y-%m-%d %H:%M:%S"),
                    addr
                );
                return;
            }
        }

        let ws_stream = match accept_async(stream).await {
            Ok(ws) => ws,
            Err(e) => {
                error!("WebSocket handshake failed for {}: {}", addr, e);
                return;
            }
        };

        let (mut ws_sender, mut ws_receiver) = ws_stream.split();

        // Wait for authentication message with timeout
        info!(
            "[{}] Waiting for authentication from {}",
            Local::now().format("%Y-%m-%d %H:%M:%S"),
            addr
        );

        let auth_result = timeout(self.config.auth_timeout, ws_receiver.next()).await;

        match auth_result {
            Ok(Some(Ok(Message::Text(received_uuid)))) => {
                if state.auth_uuid == received_uuid.trim() {
                    info!(
                        "[{}] Client {} authenticated successfully",
                        Local::now().format("%Y-%m-%d %H:%M:%S"),
                        addr
                    );

                    // Mark this client as connected
                    {
                        let mut connected = state.connected_client.write().await;
                        *connected = Some(addr);
                    }

                    // Send success message
                    if let Err(e) = ws_sender
                        .send(Message::Text(AuthStatus::Success.as_str().to_string()))
                        .await
                    {
                        error!("Failed to send auth success message: {}", e);
                        return;
                    }

                    // Handle authenticated connection
                    self.handle_authenticated_client(ws_sender, ws_receiver, addr, state)
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
        warn!(
            "[{}] Client {} authentication failed - {}",
            Local::now().format("%Y-%m-%d %H:%M:%S"),
            addr,
            reason
        );
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
    ) {
        info!(
            "[{}] Client {} is now connected and authenticated",
            Local::now().format("%Y-%m-%d %H:%M:%S"),
            addr
        );

        // Echo loop for authenticated client
        while let Some(msg) = ws_receiver.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    info!(
                        "[{}] Client {} sent: {}",
                        Local::now().format("%Y-%m-%d %H:%M:%S"),
                        addr,
                        text
                    );

                    if let Err(e) = ws_sender.send(Message::Text(text.clone())).await {
                        error!("Failed to echo message: {}", e);
                        break;
                    }
                }
                Ok(Message::Close(_)) => {
                    info!(
                        "[{}] Client {} disconnecting",
                        Local::now().format("%Y-%m-%d %H:%M:%S"),
                        addr
                    );
                    break;
                }
                Err(e) => {
                    error!("Error receiving message: {}", e);
                    break;
                }
                _ => {}
            }
        }

        // Clean up connection state
        {
            let mut connected = state.connected_client.write().await;
            *connected = None;
        }

        info!(
            "[{}] Client {} disconnected. Server shutting down...",
            Local::now().format("%Y-%m-%d %H:%M:%S"),
            addr
        );

        // Gracefully shutdown the server
        tokio::time::sleep(Duration::from_millis(100)).await;
        std::process::exit(0);
    }
}