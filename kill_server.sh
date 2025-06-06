#!/bin/bash

echo "Looking for remoteclaudecode-server processes..."

# Find and kill all remoteclaudecode-server processes
pids=$(ps aux | grep -E "[r]emoteclaudecode-server|[c]argo.*run" | awk '{print $2}')

if [ -z "$pids" ]; then
    echo "No server processes found."
else
    echo "Found processes: $pids"
    echo "Killing processes..."
    echo $pids | xargs kill -9
    echo "Done!"
fi

# Also kill anything on port 9001
echo "Checking port 9001..."
lsof -ti :9001 | xargs kill -9 2>/dev/null || echo "Port 9001 is clear"

echo "Server cleanup complete!"