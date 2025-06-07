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

## Kill any existing processes on port 9001
echo -e "${YELLOW}Cleaning up existing processes...${NC}"
lsof -ti :9001 | xargs kill -9 2>/dev/null || true

## Start the server in background
echo -e "${GREEN}Starting RemoteClaudeCode server...${NC}"
cargo run &
SERVER_PID=$!

sleep 3

## Start ngrok
echo -e "${GREEN}Starting ngrok tunnel...${NC}"
echo -e "${BLUE}Look for the public URL in the ngrok output below${NC}"
echo -e "${BLUE}Use the wss:// version of the URL in your iOS app${NC}"
echo
ngrok http 9001

## When ngrok is closed, kill the server
kill $SERVER_PID 2>/dev/null || true

