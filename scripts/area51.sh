#!/usr/bin/env bash
SERVICE_NAME="area51"
SERVICE_PATH="area51"
ENV_NAME="area51"
PID_NAME="area51"
HEALTH_URL=""
PORT="5173"

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

install() {
    # Vite reads VITE_* vars from files on disk
    mkdir -p "$CODE_ROOT/area51/apps/platform"
    cp "$ENV_FILE" "$CODE_ROOT/area51/apps/platform/.env"

    cd "$SERVICE_DIR"
    pnpm install 2>&1 | sed 's/^/    /'
    echo "  [✓] area51 deps installed"
}

start() {
    setup
    install
    run pnpm dev -- --port 5173
}

dispatch "$@"
