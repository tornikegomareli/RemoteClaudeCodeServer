use colored::*;
use crossterm::{
    execute,
    terminal::{Clear, ClearType},
};
use qrcode::{render::unicode, QrCode};
use serde_json::json;
use std::io;

pub struct TerminalUI;

impl TerminalUI {
    pub fn display_startup_screen(auth_uuid: &str, server_url: &str, remote_url: Option<&str>) {
        // Clear terminal
        let _ = execute!(io::stdout(), Clear(ClearType::All));

        // Display header
        Self::print_header();

        // Display system info
        Self::print_system_info();

        // Display server info
        Self::print_server_info(server_url, auth_uuid, remote_url);

        // Display QR code
        Self::print_qr_code(auth_uuid, remote_url);

        // Display iOS connection instructions
        Self::print_ios_instructions();

        // Display footer
        Self::print_footer();
    }

    fn print_header() {
        println!(
            "\n{}",
            "╔═══════════════════════════════════════════════════════════════════╗".bright_cyan()
        );
        println!(
            "{}",
            "║          RemoteClaudeCode Server v0.1.0                 ║".bright_cyan()
        );
        println!(
            "{}",
            "╚═══════════════════════════════════════════════════════════════════╝".bright_cyan()
        );
    }

    fn print_system_info() {
        println!("\n{}", "🔐 How This System Works:".bright_yellow().bold());
        println!("   • The server generates a unique UUID for authentication");
        println!("   • Only one client can connect at a time (single-client policy)");
        println!("   • Client must send the UUID within 5 seconds of connecting");
        println!("   • Server auto-shuts down when the client disconnects");
        println!("   • All messages are echoed back (for now - more features coming!)");
    }

    fn print_server_info(server_url: &str, auth_uuid: &str, remote_url: Option<&str>) {
        println!("\n{}", "📡 Server Information:".bright_green().bold());
        println!(
            "   {} {}",
            "Local URL:".bright_white(),
            server_url.bright_blue()
        );
        if let Some(url) = remote_url {
            println!(
                "   {} {}",
                "Remote URL:".bright_white(),
                url.bright_green()
            );
        }
        println!(
            "   {} {}",
            "Status:".bright_white(),
            "Waiting for connection...".yellow()
        );
        println!(
            "   {} {}",
            "Auth UUID:".bright_white(),
            auth_uuid.bright_magenta()
        );
    }

    fn print_qr_code(auth_uuid: &str, remote_url: Option<&str>) {
        println!("\n{}", "📱 QR Code (contains connection info):".bright_green().bold());
        
        // Create JSON with UUID and URL if available
        let qr_data = if let Some(url) = remote_url {
            json!({
                "uuid": auth_uuid,
                "url": url,
                "version": "1.0"
            }).to_string()
        } else {
            json!({
                "uuid": auth_uuid,
                "version": "1.0"
            }).to_string()
        };

        match QrCode::new(&qr_data) {
            Ok(code) => {
                let image = code
                    .render::<unicode::Dense1x2>()
                    .dark_color(unicode::Dense1x2::Light)
                    .light_color(unicode::Dense1x2::Dark)
                    .quiet_zone(false)
                    .build();

                let lines: Vec<&str> = image.lines().collect();
                for line in lines {
                    println!("   {}", line);
                }
            }
            Err(e) => {
                println!("   {}", format!("Failed to generate QR code: {}", e).red());
            }
        }
    }

    fn print_ios_instructions() {
        println!("\n{}", "📲 iOS App Connection Steps:".bright_green().bold());
        println!("   1. Open the TestingWebSocketClient app on your iOS device");
        println!(
            "   2. Tap the {} button (top right)",
            "⚙️ gear icon".bright_white()
        );
        println!("   3. Configure the connection:");
        println!(
            "      • {}: Enter the server URL",
            "WebSocket URL".bright_white()
        );
        println!(
            "        {}",
            "(use ngrok URL if connecting remotely)".dimmed()
        );
        println!(
            "      • {}: Scan QR code or paste UUID",
            "Authentication UUID".bright_white()
        );
        println!("   4. Tap {} to save settings", "\"Save\"".bright_white());
        println!(
            "   5. Tap {} button to connect",
            "\"Connect\"".bright_green()
        );
        println!("\n   {}", "Connection Status Indicators:".yellow());
        println!("   🔴 {} - Not connected", "Red".red());
        println!(
            "   🟠 {} - Connected, authenticating",
            "Orange".truecolor(255, 165, 0)
        );
        println!("   🟢 {} - Authenticated and ready", "Green".green());
    }

    fn print_footer() {
        println!("\n{}", "─".repeat(70).bright_black());
        println!("{}", "Press Ctrl+C to stop the server".dimmed());
        println!("{}", "─".repeat(70).bright_black());
        println!();
    }

    pub fn print_client_connected(addr: &str) {
        println!(
            "{} {}",
            "[CONNECTED]".bright_green().bold(),
            format!("Client connected from {}", addr).bright_white()
        );
    }

    pub fn print_client_authenticated(addr: &str) {
        println!(
            "{} {}",
            "[AUTHENTICATED]".bright_green().bold(),
            format!("Client {} successfully authenticated ✓", addr).bright_white()
        );
    }

    pub fn print_client_rejected(addr: &str, reason: &str) {
        println!(
            "{} {}",
            "[REJECTED]".bright_red().bold(),
            format!("Client {} rejected: {}", addr, reason).bright_white()
        );
    }

    pub fn print_message_received(addr: &str, message: &str) {
        println!(
            "{} {} {}",
            "[MESSAGE]".bright_blue().bold(),
            format!("From {}:", addr).bright_white(),
            message.cyan()
        );
    }

    pub fn print_client_disconnected(addr: &str) {
        println!(
            "{} {}",
            "[DISCONNECTED]".bright_yellow().bold(),
            format!("Client {} disconnected", addr).bright_white()
        );
    }

    pub fn print_server_shutdown() {
        println!("\n{}", "🛑 Server shutting down...".bright_red().bold());
    }
}
