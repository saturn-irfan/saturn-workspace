#!/usr/bin/env bash
SERVICE_NAME="chat"
SERVICE_PATH="chat"
ENV_NAME="chat"
PID_NAME="chat"
HEALTH_URL="http://localhost:8080/health/live/"
PORT="8080"

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

install() {
    cd "$SERVICE_DIR"
    make build 2>&1 | sed 's/^/    /'
    echo "  [✓] chat built"
}

start() {
    setup
    install
    run ./bin/chat
}

dispatch "$@"
