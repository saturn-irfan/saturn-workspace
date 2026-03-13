#!/usr/bin/env bash
SERVICE_NAME="shuttle"
SERVICE_PATH="shuttle"
ENV_NAME="shuttle"
PID_NAME="shuttle"
HEALTH_URL="http://localhost:8002/health/"
PORT="8002"

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

install() {
    cd "$SERVICE_DIR"
    make build 2>&1 | sed 's/^/    /'
    echo "  [✓] shuttle built"
}

start() {
    setup
    install
    run ./bin/shuttle
}

dispatch "$@"
