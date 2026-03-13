#!/usr/bin/env bash
SERVICE_NAME="jupiter"
SERVICE_PATH="jupiter"
ENV_NAME="jupiter"
PID_NAME="jupiter-api"
HEALTH_URL="http://localhost:8003/health/"
PORT="8003"

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

start() {
    setup
    cd "$SERVICE_DIR"
    run uv run python src/main.py
}

dispatch "$@"
