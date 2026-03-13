#!/usr/bin/env bash
# Jupiter — Coplanner Session APIs
# Base: http://localhost:8003
# Auth: X-Service-Auth header (SERVICE_SECRET from jupiter .env)

AUTH="c6cebcba5fe1f7ef547f68d26ca3f1dfa98c6452bbbe4269f8f40f6bddc4426c"
BASE="http://localhost:8003/internal/coplanner"

# ─── Query ────────────────────────────────────────────────────────────────────

# Send a coplanner query (fire-and-forget, 202 Accepted)
# Results stream via Redis Pub/Sub on the channel field
curl -s -X POST "$BASE/query" \
  -H "X-Service-Auth: $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "req-001",
    "session_id": "session-001",
    "message_id": "msg-001",
    "query": "What are the FCA rules around pension transfer suitability?",
    "firm_id": "firm-001",
    "user_id": "user-001",
    "channel": "coplanner:tokens:req-001",
    "mentions": [],
    "attachments": []
  }'

# ─── Sessions — List ──────────────────────────────────────────────────────────

# List all sessions (sorted by updated_at desc, no message content)
curl -s "$BASE/sessions" \
  -H "X-Service-Auth: $AUTH"

# Filter by firm
curl -s "$BASE/sessions?firm_id=firm-001" \
  -H "X-Service-Auth: $AUTH"

# Filter by user
curl -s "$BASE/sessions?user_id=user-001" \
  -H "X-Service-Auth: $AUTH"

# Filter by firm + user
curl -s "$BASE/sessions?firm_id=firm-001&user_id=user-001" \
  -H "X-Service-Auth: $AUTH"

# Paginate (limit + offset)
curl -s "$BASE/sessions?limit=10&offset=20" \
  -H "X-Service-Auth: $AUTH"

# ─── Sessions — Get ───────────────────────────────────────────────────────────

# Get full session (all messages + parts)
curl -s "$BASE/sessions/session-001" \
  -H "X-Service-Auth: $AUTH"

# Get conversation history only (role + parts pairs, used for graph injection)
curl -s "$BASE/sessions/session-001/history" \
  -H "X-Service-Auth: $AUTH"

# ─── Sessions — Delete ────────────────────────────────────────────────────────

# Delete a session
curl -s -X DELETE "$BASE/sessions/session-001" \
  -H "X-Service-Auth: $AUTH"

# ─── Health ───────────────────────────────────────────────────────────────────

curl -s "http://localhost:8003/health" \
  -H "X-Service-Auth: $AUTH"
