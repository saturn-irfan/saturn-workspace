#!/usr/bin/env bash
SERVICE_NAME="saturn-fe"
SERVICE_PATH="saturn-fe"
ENV_NAME="saturn-fe"
PID_NAME="saturn-fe"
HEALTH_URL=""
PORT="5174"

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

install() {
    # Vite reads VITE_* vars from files on disk
    mkdir -p "$SERVICE_DIR/envs"
    cp "$ENV_FILE" "$SERVICE_DIR/envs/.env"

    cd "$SERVICE_DIR"
    pnpm install 2>&1 | sed 's/^/    /'
    echo "  [✓] saturn-fe deps installed"
}

start() {
    setup
    install
    run pnpm dev --port 5174
}

dispatch "$@"
