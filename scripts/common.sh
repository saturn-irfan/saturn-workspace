#!/usr/bin/env bash
# Shared logic for all service scripts.
# Each script sets config vars then sources this file.
#
# Required vars (set before sourcing):
#   SERVICE_NAME  — display name (e.g. "mars")
#   SERVICE_PATH  — path relative to CODE_ROOT (e.g. "mars", "saturn-backend/backend")
#   ENV_NAME      — env file name without extension (e.g. "mars", "saturn-backend")
#   PID_NAME      — PID/log file base name (e.g. "mars", "jupiter-api")
#   HEALTH_URL    — health check URL (empty string = skip health check)
#   PORT          — service port (empty string = skip port kill fallback)

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPTS_DIR/.." && pwd)"
CODE_ROOT="${CODE_ROOT:-$WORKSPACE/code}"
SERVICE_DIR="$CODE_ROOT/$SERVICE_PATH"
ENV_FILE="$WORKSPACE/envs/$ENV_NAME.env"
LOG_DIR="$WORKSPACE/.logs"
PID_FILE="$LOG_DIR/$PID_NAME.pid"
LOG_FILE="$LOG_DIR/$PID_NAME.log"

get_pid() {
    [ -f "$PID_FILE" ] && cat "$PID_FILE" || echo ""
}

setup() {
    mkdir -p "$LOG_DIR"
    set -a; set +u; source "$ENV_FILE"; set -u; set +a
    local common_env="$WORKSPACE/envs/common.env"
    if [ -f "$common_env" ]; then
        set -a; set +u; source "$common_env"; set -u; set +a
    fi
}

is_running() {
    local pid
    pid=$(get_pid)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

run() {
    local branch
    branch=$(cd "$SERVICE_DIR" && git branch --show-current 2>/dev/null || echo "?")
    if is_running; then
        echo "  [~] $SERVICE_NAME (PID: $(get_pid)) already running, restarting..."
        stop
    fi
    nohup "$@" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "  [+] $SERVICE_NAME (PID: $(get_pid)) started ($branch)"
}

stop() {
    local pid
    pid=$(get_pid)

    if [ -z "$pid" ]; then
        echo "  [ ] $SERVICE_NAME not running"
        return
    fi

    # 1. SIGTERM
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        for i in $(seq 1 10); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 1
        done
    fi

    # 2. SIGKILL if still alive
    if kill -0 "$pid" 2>/dev/null; then
        echo "  [!] $SERVICE_NAME (PID: $pid) didn't stop, force killing..."
        kill -9 "$pid" 2>/dev/null
        sleep 1
    fi

    # 3. Kill by port if still bound
    if [ -n "${PORT:-}" ]; then
        local port_pid
        port_pid=$(lsof -ti :"$PORT" 2>/dev/null || true)
        if [ -n "$port_pid" ]; then
            echo "  [!] $SERVICE_NAME port $PORT still in use (PID: $port_pid), killing..."
            kill -9 $port_pid 2>/dev/null
            sleep 1
        fi
    fi

    rm -f "$PID_FILE"

    if kill -0 "$pid" 2>/dev/null; then
        echo "  [✗] $SERVICE_NAME (PID: $pid) failed to stop"
    else
        echo "  [-] $SERVICE_NAME (PID: $pid) stopped"
    fi
}

status() {
    local pid branch
    pid=$(get_pid)
    branch=$(cd "$SERVICE_DIR" && git branch --show-current 2>/dev/null || echo "?")
    if [ -z "$pid" ]; then
        echo "  [ ] $SERVICE_NAME not started ($branch)"
    elif ! kill -0 "$pid" 2>/dev/null; then
        echo "  [✗] $SERVICE_NAME (PID: $pid) dead ($branch)"
    elif [ -z "$HEALTH_URL" ]; then
        echo "  [✓] $SERVICE_NAME (PID: $pid) running ($branch)"
    elif curl -sf --max-time 2 "$HEALTH_URL" > /dev/null 2>&1; then
        echo "  [✓] $SERVICE_NAME (PID: $pid) healthy ($branch)"
    else
        echo "  [!] $SERVICE_NAME (PID: $pid) not healthy ($branch)"
    fi
}

logs() {
    tail -f "$LOG_FILE"
}

errors() {
    tail -n 50 "$LOG_FILE"
}

# Default install — no-op. Scripts override if they have deps/build steps.
install() { :; }

dispatch() {
    case "${1:-}" in
        start)   start ;;
        stop)    stop ;;
        status)  status ;;
        logs)    logs ;;
        errors)  errors ;;
        install) install ;;
        *)       echo "Usage: $0 {start|stop|status|logs|errors|install}" ;;
    esac
}
