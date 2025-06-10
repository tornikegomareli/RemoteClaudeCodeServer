# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build and Run
```bash
# Standard run with ngrok (recommended)
./run.sh

# Build only
cargo build

# Build release version
cargo build --release

# Run without ngrok
cargo run

# Run with logging
RUST_LOG=info cargo run
RUST_LOG=debug cargo run  # More verbose

# Kill stuck server
./kill_server.sh
```

### Development Tools
```bash
# Format code
cargo fmt

# Check code without building
cargo check

# Run clippy linter
cargo clippy

# Watch for changes and rebuild
cargo install cargo-watch  # Install once
cargo watch -x run        # Auto-rebuild on changes

# Run with specific features
cargo run --features "your-feature"
```

## Architecture Overview

### Core Components and Flow
The server implements a WebSocket-based authentication system with reconnection support:

```
main.rs → WebSocketServer::new() → TCP listener (9001) → spawn ConnectionHandler → Auth → Echo
```

### State Management
- **`ServerState`**: Shared server state using `Arc<RwLock<T>>` for thread safety
  - `auth_uuid`: Server's authentication UUID (regenerated each run)
  - `connected_client`: Enforces single-client policy
  - `reconnection_tokens`: HashMap mapping tokens to client IDs

### Authentication System
Two-tier authentication with 5-second timeout:

1. **Initial Connection**: Client sends UUID → Server validates → Returns:
   ```json
   {
     "status": "AUTH_SUCCESS",
     "reconnection_token": "uuid-v4",
     "client_id": "client_12345"
   }
   ```

2. **Reconnection**: Client sends token as JSON:
   ```json
   {"token": "previous-reconnection-token"}
   ```
   Server validates token → Allows connection without UUID

### Message Flow
- Authentication attempts JSON parsing first (for tokens), falls back to plain UUID
- After auth: Echo server (receives text, echoes back)
- Graceful handling of Close frames and connection errors
- Client disconnect preserves tokens but clears `connected_client`

### Key Design Decisions
- Single-client policy: Only one active connection allowed
- Server persists after disconnect (no auto-shutdown)
- Tokens survive disconnection but not server restart
- Lock ordering prevents deadlocks: always acquire locks in same order
- WebSocket endpoint at `/ws` (not enforced in current implementation)

## Configuration

### Environment Setup
Create `.env` file:
```
NGROK_AUTHTOKEN=your_token_here
```

### Server Configuration
- Default bind: `127.0.0.1:9001`
- Auth timeout: 5 seconds
- Environment variable: `REMOTE_URL` (set by run.sh for ngrok URL)

### QR Code Format
When using ngrok, QR code contains JSON:
```json
{
  "uuid": "auth-uuid-here",
  "url": "wss://xxx.ngrok.io/ws"
}
```

## Code Style Guidelines
- **NO verbose or obvious comments**
- Keep code clean and self-documenting
- Use descriptive variable and function names
- Prefer small, focused functions
- Use Rust idioms and best practices

## iOS Client Integration
The TestingWebSocketClient app expects:
- QR code with JSON format (UUID + URL)
- AUTH_SUCCESS response with reconnection token
- Token-based reconnection support
- Plain text echo messages after authentication

## Important Implementation Notes
- WebSocket handshake errors are handled gracefully
- Client ID format: `client_` + random 5-digit number
- Reconnection tokens: UUID v4 format
- All shared state uses `Arc<RwLock<T>>` for concurrent access
- Server uses Tokio async runtime with futures for WebSocket handling
- UI updates use colored terminal output with emojis for clarity
