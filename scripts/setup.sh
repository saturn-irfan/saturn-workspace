#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")/.." && pwd)"

SERVICES=(mars shuttle chat jupiter saturn-backend saturn-fe abe area51)

REMOTES=(
    "mars|https://github.com/Saturn-Fintech/mars.git"
    "shuttle|https://github.com/Saturn-Fintech/shuttle.git"
    "chat|https://github.com/Saturn-Fintech/chat.git"
    "jupiter|https://github.com/Saturn-Fintech/jupiter.git"
    "saturn-backend|https://github.com/Saturn-Fintech/saturn-backend.git"
    "saturn-fe|https://github.com/Saturn-Fintech/saturn-fe.git"
    "abe|https://github.com/Saturn-Fintech/abe.git"
    "area51|https://github.com/Saturn-Fintech/area51.git"
)

get_remote() {
    local svc="$1"
    for entry in "${REMOTES[@]}"; do
        local name="${entry%%|*}"
        local url="${entry#*|}"
        [ "$name" = "$svc" ] && echo "$url" && return
    done
}

echo "Saturn Workspace Setup"
echo "======================"
echo ""

# ============================================================================
# 1. Clone repos into code/
# ============================================================================

mkdir -p "$WORKSPACE/code"

echo "Cloning service repos into code/..."
echo ""

PIDS=()
SVC_NAMES=()

for svc in "${SERVICES[@]}"; do
    target="$WORKSPACE/code/$svc"
    if [ -d "$target/.git" ]; then
        echo "  [~] $svc already exists, skipping"
        continue
    fi

    remote=$(get_remote "$svc")
    (
        git clone "$remote" "$target" --quiet
        echo "  [+] $svc"
    ) &
    PIDS+=($!)
    SVC_NAMES+=("$svc")
done

FAILED=()
for i in "${!PIDS[@]}"; do
    if ! wait "${PIDS[$i]}"; then
        FAILED+=("${SVC_NAMES[$i]}")
        echo "  [✗] ${SVC_NAMES[$i]} clone failed"
    fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "ERROR: Failed to clone: ${FAILED[*]}"
    echo "Check your GitHub access and try again."
    exit 1
fi

echo ""

# ============================================================================
# 2. Create envs/ and .logs/ directories
# ============================================================================

mkdir -p "$WORKSPACE/envs"
mkdir -p "$WORKSPACE/.logs"

echo "Done!"
echo ""
echo "Next steps:"
echo "  1. Add env files to envs/ for each service (see envs/examples/common.env.example for format)"
echo "     Required files: common.env mars.env shuttle.env chat.env jupiter.env"
echo "                     saturn-backend.env saturn-fe.env abe.env area51.env"
echo "  2. make start         — start all services"
echo "  3. make status        — verify services are healthy"
echo ""
echo "See CLAUDE.md or architecture/SYSTEM.md for full documentation."
