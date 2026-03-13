#!/usr/bin/env bash
SERVICE_NAME="mars"
SERVICE_PATH="mars"
ENV_NAME="mars"
PID_NAME="mars"
HEALTH_URL="http://localhost:8001/health/"
PORT="8001"

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

install() {
    cd "$SERVICE_DIR"
    YJS_FILE="internal/services/doc/yjs_runner.go"
    XML_PARSER_FILE="internal/services/pipeline/xml_parser.go"
    LOCAL_YJS_PATH="$SERVICE_DIR/yjs/yjs-runner.js"
    sed -i '' "s|/yjs/yjs-runner.js|$LOCAL_YJS_PATH|g" "$YJS_FILE"
    sed -i '' "s|/yjs/yjs-runner.js|$LOCAL_YJS_PATH|g" "$XML_PARSER_FILE"
    make build 2>&1 | sed 's/^/    /'
    sed -i '' "s|$LOCAL_YJS_PATH|/yjs/yjs-runner.js|g" "$YJS_FILE"
    sed -i '' "s|$LOCAL_YJS_PATH|/yjs/yjs-runner.js|g" "$XML_PARSER_FILE"
    npm ci --only=production --prefix "$SERVICE_DIR/yjs" 2>&1 | sed 's/^/    /'
    echo "  [✓] mars built"
}

start() {
    setup
    install
    run ./bin/mars
}

dispatch "$@"
