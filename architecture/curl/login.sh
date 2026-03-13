#!/usr/bin/env bash
# Saturn — Auth
# Backend: http://localhost:8000
# Shuttle: http://localhost:8002

# ─── Login (Django Backend) ───────────────────────────────────────────────────

curl -s -X POST "http://localhost:8000/api/v3/auth/login/" \
  -H "Content-Type: application/json" \
  -H "X-TIME: $(date -u +%Y-%m-%dT%H:%M:%S+00:00)" \
  -d '{
    "username": "irfan@heysaturn.com",
    "password": "123123"
  }' | jq .

# ─── Login (Shuttle) ──────────────────────────────────────────────────────────
# tenant_id: 7eb044c4-0d3d-4343-b2d6-75ee1f7fd2ee (irfan@heysaturn.com)

curl -s -X POST "http://localhost:8002/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "irfan@heysaturn.com",
    "password": "123123",
    "tenant_id": "7eb044c4-0d3d-4343-b2d6-75ee1f7fd2ee"
  }' | jq .
