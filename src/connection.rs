use futures_util::{SinkExt, StreamExt};
use log::error;
use std::net::SocketAddr;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::time::timeout;
use tokio_tungstenite::{accept_async, tungstenite::Message};

use crate::config::ServerConfig;
use crate::types::{AuthStatus, ServerState};
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

        {
            let connected = state.connected_client.read().await;
            if connected.is_some() {
                TerminalUI::print_client_rejected(&addr.to_string(), "another client is already connected");
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


        let auth_result = timeout(self.config.auth_timeout, ws_receiver.next()).await;

        match auth_result {
            Ok(Some(Ok(Message::Text(received_uuid)))) => {
                if state.auth_uuid == received_uuid.trim() {
                    TerminalUI::print_client_authenticated(&addr.to_string());

                    {
                        let mut connected = state.connected_client.write().await;
                        *connected = Some(addr);
                    }

                    if let Err(e) = ws_sender
                        .send(Message::Text(AuthStatus::Success.as_str().to_string()))
                        .await
                    {
                        error!("Failed to send auth success message: {}", e);
                        return;
                    }

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

        {
            let mut connected = state.connected_client.write().await;
            *connected = None;
        }

        TerminalUI::print_client_disconnected(&addr.to_string());
        TerminalUI::print_server_shutdown();

        tokio::time::sleep(Duration::from_millis(100)).await;
        std::process::exit(0);
    }
}