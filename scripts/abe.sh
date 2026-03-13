#!/usr/bin/env bash
SERVICE_NAME="abe"
SERVICE_PATH="abe"
ENV_NAME="abe"
PID_NAME="abe"
HEALTH_URL="http://localhost:8010/health/"
PORT="8010"

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

start() {
    setup
    cd "$SERVICE_DIR"
    run bun run src/index.ts
}

dispatch "$@"
