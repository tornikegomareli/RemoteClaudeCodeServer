#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -f .env ]; then
  echo -e "${RED}Error: .env file not found!${NC}"
  echo -e "${YELLOW}Please copy .env.example to .env and add your ngrok authtoken${NC}"
  echo -e "${BLUE}Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
  exit 1
fi

source .env

if [ -z "$NGROK_AUTHTOKEN" ] || [ "$NGROK_AUTHTOKEN" = "your_ngrok_authtoken_here" ]; then
  echo -e "${RED}Error: NGROK_AUTHTOKEN not set in .env file!${NC}"
  echo -e "${BLUE}Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
  exit 1
fi

if ! command -v ngrok &>/dev/null; then
  echo -e "${RED}Error: ngrok is not installed!${NC}"
  echo -e "${YELLOW}Please install ngrok from: https://ngrok.com/download${NC}"
  exit 1
fi

echo -e "${YELLOW}Configuring ngrok...${NC}"
ngrok config add-authtoken $NGROK_AUTHTOKEN

echo -e "${YELLOW}Cleaning up existing processes...${NC}"
lsof -ti :9001 | xargs kill -9 2>/dev/null || true

# Start ngrok in background and capture URL
echo -e "${GREEN}Starting ngrok tunnel...${NC}"
ngrok http 9001 > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start and get URL
echo -e "${YELLOW}Waiting for ngrok to establish tunnel...${NC}"
sleep 3

# Get ngrok URL using API
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | grep -o 'https://[^"]*' | head -1)

if [ -z "$NGROK_URL" ]; then
  echo -e "${RED}Failed to get ngrok URL. Make sure ngrok is running.${NC}"
  kill $NGROK_PID 2>/dev/null
  exit 1
fi

# Convert https to wss
WS_URL="${NGROK_URL/https:/wss:}/ws"

echo -e "${GREEN}ngrok tunnel established!${NC}"
echo -e "${BLUE}Public WebSocket URL: ${WS_URL}${NC}"

# Export URL for server to use
export REMOTE_URL="$WS_URL"

# Start server with the URL
echo -e "${GREEN}Starting RemoteClaudeCode server with remote URL...${NC}"
REMOTE_URL="$WS_URL" cargo run

# Cleanup
kill $NGROK_PID 2>/dev/null || true