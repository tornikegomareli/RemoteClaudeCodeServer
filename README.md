# RemoteClaudeCode Server

WebSocket server with UUID authentication for remote iOS client connection.

## Prerequisites

1. **Rust** - [Install from rustup.rs](https://rustup.rs/)
2. **ngrok** - [Download from ngrok.com](https://ngrok.com/download)

## Quick Start

1. **Clone and setup:**
```bash
git clone <repo-url>
cd RemoteClaudeCodeServer
cp .env.example .env
```

2. **Add your ngrok token to `.env`:**
   - Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken
   - Edit `.env` and replace `your_ngrok_authtoken_here` with your actual token

3. **Run everything:**
```bash
./run.sh
```

That's it! The script will:
- Configure ngrok with your token
- Start ngrok tunnel and get the public URL
- Start the WebSocket server with a QR code containing both UUID and URL
- Display all connection info

## What You'll See

The server displays:
- 🔐 Authentication UUID (changes each run)
- 📱 QR code containing BOTH UUID and URL
- 📡 Local and remote connection URLs
- ✨ All connection info in one place

## iOS App Connection

### Quick Connect (Recommended)
1. Open your iOS app
2. Tap the ⚙️ settings icon
3. Tap "Scan QR Code"
4. Point at the QR code in terminal
5. Tap "Connect" - that's it!

The QR code automatically provides both the UUID and ngrok URL.

## Manual Commands

If you prefer to run things separately:

```bash
# Terminal 1: Run server
cargo run

# Terminal 2: Start ngrok
ngrok http 9001
```

## Troubleshooting

- **Port already in use**: The script automatically kills processes on port 9001
- **Server won't stop**: Use `Ctrl+C` (not `Ctrl+Z`)
- **Kill stuck server**: `./kill_server.sh`