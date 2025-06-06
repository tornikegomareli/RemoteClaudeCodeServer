use chrono::Local;
use futures_util::{SinkExt, StreamExt};
use log::{error, info, warn};
use qrcode::{render::unicode, QrCode};
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::RwLock;
use tokio::time::timeout;
use tokio_tungstenite::{accept_async, tungstenite::Message};
use uuid::Uuid;

#[derive(Clone)]
struct ServerState {
    auth_uuid: String,
    connected_client: Arc<RwLock<Option<SocketAddr>>>,
}

#[tokio::main]
async fn main() {
    env_logger::init();

    let auth_uuid = Uuid::new_v4().to_string();
    let addr = "127.0.0.1:9001";

    info!("WebSocket server starting on: ws://{}/ws", addr);
    info!("Authentication UUID: {}", auth_uuid);
    
    // Generate and display QR code
    display_qr_code(&auth_uuid);

    let listener = TcpListener::bind(&addr).await.expect("Failed to bind");

    let state = ServerState {
        auth_uuid: auth_uuid.clone(),
        connected_client: Arc::new(RwLock::new(None)),
    };

    info!("Server is ready. Waiting for client connection...");
    info!("Client must authenticate with UUID: {}", auth_uuid);

    while let Ok((stream, addr)) = listener.accept().await {
        let state = state.clone();
        tokio::spawn(handle_connection(stream, addr, state));
    }
}

fn display_qr_code(uuid: &str) {
    match QrCode::new(uuid) {
        Ok(code) => {
            let image = code
                .render::<unicode::Dense1x2>()
                .dark_color(unicode::Dense1x2::Light)
                .light_color(unicode::Dense1x2::Dark)
                .build();
            println!("\n=== QR Code for UUID ===");
            println!("{}", image);
            println!("======================\n");
        }
        Err(e) => {
            error!("Failed to generate QR code: {}", e);
        }
    }
}

async fn handle_connection(stream: TcpStream, addr: SocketAddr, state: ServerState) {
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

    let auth_result = timeout(Duration::from_secs(5), ws_receiver.next()).await;

    match auth_result {
        Ok(Some(Ok(Message::Text(received_uuid)))) => {
            let received_uuid = received_uuid.trim();
            if received_uuid == state.auth_uuid {
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
                    .send(Message::Text("AUTH_SUCCESS".to_string()))
                    .await
                {
                    error!("Failed to send auth success message: {}", e);
                    return;
                }

                // Handle authenticated connection
                handle_authenticated_client(ws_sender, ws_receiver, addr, state).await;
            } else {
                warn!(
                    "[{}] Client {} failed authentication - invalid UUID",
                    Local::now().format("%Y-%m-%d %H:%M:%S"),
                    addr
                );
                let _ = ws_sender
                    .send(Message::Text("AUTH_FAILED".to_string()))
                    .await;
                let _ = ws_sender.close().await;
            }
        }
        Ok(_) => {
            warn!(
                "[{}] Client {} sent invalid authentication message",
                Local::now().format("%Y-%m-%d %H:%M:%S"),
                addr
            );
            let _ = ws_sender
                .send(Message::Text("AUTH_FAILED".to_string()))
                .await;
            let _ = ws_sender.close().await;
        }
        Err(_) => {
            warn!(
                "[{}] Client {} authentication timeout",
                Local::now().format("%Y-%m-%d %H:%M:%S"),
                addr
            );
            let _ = ws_sender
                .send(Message::Text("AUTH_TIMEOUT".to_string()))
                .await;
            let _ = ws_sender.close().await;
        }
    }
}

async fn handle_authenticated_client(
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