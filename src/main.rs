use remoteclaudecode_server::{config::ServerConfig, WebSocketServer};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Load .env file
    dotenv::dotenv().ok();

    let config = ServerConfig::default();
    let server = WebSocketServer::new(config);

    server.run().await?;

    Ok(())
}
