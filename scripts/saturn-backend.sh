#!/usr/bin/env bash
SERVICE_NAME="saturn-backend"
SERVICE_PATH="saturn-backend/backend"
ENV_NAME="saturn-backend"
PID_NAME="saturn-backend"
HEALTH_URL="http://localhost:8000/admin/login/"
PORT="8000"

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

start() {
    setup
    cd "$SERVICE_DIR"
    run python manage.py runserver
}

dispatch "$@"
