# Remote WebSocket Setup Guide

## Server Setup

### 1. Build and Run the Server
```bash
cargo build --release
RUST_LOG=info cargo run
```

### 2. Server will display:
- Authentication UUID
- QR code for easy mobile scanning
- WebSocket endpoint: `ws://localhost:9001/ws`

### 3. Expose Server for Remote Access

#### Option A: Using ngrok (Recommended for testing)
1. Install ngrok: `brew install ngrok` (macOS)
2. Run ngrok: `ngrok http 9001`
3. Copy the public URL (e.g., `wss://abc123.ngrok.io`)
4. Replace `localhost:9001` with `abc123.ngrok.io` in iOS app

#### Option B: Port Forwarding
1. Configure your router to forward port 9001 to your machine
2. Use your public IP: `ws://YOUR_PUBLIC_IP:9001/ws`

#### Option C: Deploy to Cloud
Deploy the server to a cloud provider with a public IP

## iOS App Setup

### 1. Configure Connection
1. Open the iOS app
2. Tap the gear icon (⚙️)
3. Enter:
   - **WebSocket URL**: Your server URL (e.g., `wss://abc123.ngrok.io/ws`)
   - **Authentication UUID**: The UUID shown by the server
4. Tap "Save"

### 2. Connect
1. Tap "Connect" button
2. The app will authenticate automatically
3. Status indicator:
   - 🔴 Red: Disconnected
   - 🟠 Orange: Connected, authenticating
   - 🟢 Green: Authenticated and ready

## Security Notes

- The server enforces single-client policy
- Only one client can connect at a time
- Server auto-shuts down when client disconnects
- UUID changes each time the server starts

## Testing

1. Start the server and note the UUID
2. Configure the iOS app with the server URL and UUID
3. Connect from the iOS app
4. Send test messages - they should echo back
5. Disconnect - server will shut down automatically