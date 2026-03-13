# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What's What

```
code/                     # All service repos (clean baseline, each is its own git repo)
├── jupiter               # AI brain (letter generation, compliance checks, chat)
├── saturn-fe             # Web UI (React)
├── saturn-backend        # Main API (Django)
├── mars                  # Guardian API (Go)
├── shuttle               # Permissions service (Go)
├── abe                   # Admin backend (Bun/Express)
├── chat                  # Coplanner chat API (Go) - SSE streaming, rate limiting
└── grund                 # Local dev CLI (Go)

scripts/                  # Per-service lifecycle scripts + shared logic
├── common.sh             # Shared functions (setup, run, stop, status, logs, errors)
├── mars.sh               # Mars config + start/install
├── shuttle.sh            # Shuttle config + start/install
├── chat.sh               # Chat config + start/install
├── jupiter.sh            # Jupiter config + start/install
├── saturn-backend.sh     # Saturn backend config + start/install
├── saturn-fe.sh          # Saturn FE config + start/install (copies .env to disk for Vite)
├── area51.sh             # Area51 config + start/install (copies .env to disk for Vite)
├── abe.sh                # Abe config + start/install
└── create-session        # Clone all repos into an isolated session folder

envs/                     # Centralized .env files (one per service, gitignored)
├── mars.env
├── shuttle.env
├── chat.env
├── jupiter.env
├── saturn-backend.env
├── abe.env
├── saturn-fe.env
└── area51.env

sessions/                 # Isolated workspace clones (gitignored)
└── <session-name>/
    ├── .session           # Claude session ID (for tracking/resuming conversations)
    ├── .info              # Metadata: description, status, branches, activity log, todo link
    ├── mars/              # Shallow clone of mars
    ├── shuttle/           # ...
    └── ...

.logs/                    # Runtime logs and PID files (gitignored)
├── *.log                 # Service stdout/stderr
└── *.pid                 # Running process PIDs

utils/                    # Data & utilities
└── saturn-dataset        # Datasets for training/eval

fixes/                    # Bug fix documentation
└── *.md                  # Detailed documentation of fixes, root causes, and impact

architecture/             # System architecture documentation
├── SYSTEM.md             # High-level architecture
├── DATA_FLOW.md          # Service communication patterns
├── SERVICES.md           # Detailed service docs
├── OPTIMIZATIONS.md      # Process improvement tracking
└── curl/                 # Ready-to-run curl scripts for manual API testing
    ├── login.sh          # Saturn app login (Django backend POST /api/v3/auth/login/)
    └── jupiter-coplanner.sh  # Jupiter coplanner session APIs
```

## Repository Structure

**IMPORTANT:** Each folder in `code/` is its own separate git repository with independent branches, commits, and remotes.

When working in the workspace:
- Always check which repository you're in before running git commands
- Each service maintains its own version history
- Changes in one repo don't affect others
- Navigate to the specific service directory before git operations

## Workspace Overview

Saturn Fintech workspace - AI tools for UK Financial Advisors. Contains multiple services that work together.

| Project | Language | Purpose |
|---------|----------|---------|
| jupiter | Python (uv) | AI service - LangGraph workflows for letter generation, TnC, global chat |
| saturn-fe | TypeScript (pnpm) | React frontend with Vite |
| saturn-backend | Python (pip) | Django backend with PostgreSQL |
| mars | Go | Guardian API service |
| shuttle | Go | Service with role/permission management |
| abe | TypeScript (bun) | Admin backend - S3, SES, SQS, Stream Chat |
| chat | Go | Coplanner chat API - SSE streaming, session/message mgmt, rate limiting |
| grund | Go | CLI tool for local dev orchestration |

## Core Principle: Explore Before You Change

**CRITICAL:** Before making any changes or creating implementation plans, you MUST:

1. **Explore the current architecture first**
   - Read `architecture/SYSTEM.md` for high-level system understanding
   - Read `architecture/DATA_FLOW.md` for service communication patterns
   - Read `architecture/SERVICES.md` for specific service details
   - Explore the actual codebase to understand current implementations

2. **Make decisions that keep entropy low**
   - Follow existing patterns and conventions
   - Maintain consistency with current architecture
   - Don't introduce new patterns when existing ones work
   - Consider the impact on overall system complexity

3. **Discuss changes before implementing**
   - Understand how your change fits into the existing system
   - Identify which services/components are affected
   - Consider data flow implications
   - Ask questions if the architecture is unclear

**Why this matters:**
- Saturn is a complex microservices architecture with 7 services
- Changes in one service often affect others (mars ↔ jupiter, shuttle ↔ all services)
- Maintaining consistency reduces cognitive load and technical debt
- Lower entropy = easier to understand, maintain, and scale

**Example workflow:**
```
❌ BAD: "I'll add a new API endpoint to mars for client data"
✅ GOOD:
  1. Read architecture/SERVICES.md to understand mars's current APIs
  2. Check architecture/DATA_FLOW.md for client data flow patterns
  3. Explore mars's existing client endpoints
  4. Follow the same patterns (routes → controller → service → repository)
  5. Ensure consistency with existing error handling, auth, validation
```

**When to use architecture docs:**
- Before implementing new features
- Before refactoring existing code
- Before adding new API endpoints
- Before changing service communication patterns
- When unsure about where functionality belongs

**Remember:** Understanding the system deeply before changing it is not wasted time - it's the foundation of good engineering.

---

## Global Commands

```bash
# All services
make start                    # Start all services in background
make stop                     # Stop all services (3-level: SIGTERM → SIGKILL → port kill)
make status                   # Health check all services
make logs                     # Show last 50 lines from all services (⚠️ long output — run in a subagent)

# Individual service control
make start-<svc>              # Start one service
make stop-<svc>               # Stop one service
make status-<svc>             # Check one service
make logs-<svc>               # Stream live logs (blocks terminal)
make errors-<svc>             # Show last 50 lines (non-blocking)
make clean-logs               # Remove all log files

# Sessions
make build session=<name>     # Create a new session (clone + install deps)
make start session=<name>     # Start services from a session
make stop session=<name>      # Stop session services
make sessions                 # List all sessions with status

# Git (across all repos in code/)
make pull                     # Pull latest on current branch for all repos
make pull-stage               # Switch all repos to stage and pull
```

Available service names for `<svc>`:

| Name | Service |
|------|---------|
| `mars` | Guardian API |
| `jupiter` | AI service (FastAPI) |
| `fe` | Saturn frontend (port 5174) |
| `backend` | Django backend |
| `shuttle` | Permissions service |
| `area51` | Eval UI (port 5173) |
| `abe` | Admin backend |
| `chat` | Coplanner chat API (port 8080) |

## How Scripts Work

All service logic lives in `scripts/`. The Makefile is a pure dispatcher.

Each `scripts/<service>.sh` sources `scripts/common.sh` which provides:
- `setup()` — loads env vars from `envs/<service>.env`, creates log dir
- `run <cmd>` — runs command in background, writes PID file and log file
- `stop()` — 3-level escalation: SIGTERM (10s wait) → SIGKILL → kill by port
- `status()` — checks PID + HTTP health check
- `logs()` / `errors()` — stream or tail log files
- `install()` — override per-service for deps/build (default no-op)
- `dispatch "$@"` — routes subcommands (start/stop/status/logs/errors/install)

Each script only defines: `SERVICE_NAME`, `SERVICE_PATH`, `ENV_NAME`, `PID_NAME`, `HEALTH_URL`, `PORT`, and its `install()` + `start()` functions.

**Env injection:**
- Go/Python/Bun services: env vars are sourced into the process (`set -a; source $ENV_FILE; set +a`)
- Vite services (saturn-fe, area51): also copy env file to disk since Vite reads `VITE_*` from `.env` files

**Session support:**
- `make build session=<name>` clones all repos from `code/` (local shallow clone, ~1-2s), installs deps
- `make start session=<name>` sets `CODE_ROOT` to session dir, `LOG_PREFIX` for namespaced PIDs/logs
- Sessions have `.session` (Claude session ID) and `.info` (metadata, status, activity log) files
- `scripts/create-session` accepts `--claude-id`, `--description`, `--todo` flags

**Stop escalation:**
1. Send SIGTERM, wait up to 10 seconds for graceful shutdown
2. If still alive, send SIGKILL
3. If port is still occupied, find and kill by port number

## Quick Commands by Project

### jupiter (AI Service)

```bash
cd code/jupiter
make install          # Install deps with uv
make run              # Start FastAPI server
make run-worker       # Start Celery worker
make lint             # Run ruff
make format           # Run black
make type-check       # Run mypy
uv run pytest         # Run tests
```

**Read first:** `code/jupiter/spec/PRIME.md` for architecture navigation

### saturn-fe (Frontend)

```bash
cd code/saturn-fe
pnpm install          # Install deps
pnpm dev              # Start dev server
pnpm build            # Production build
pnpm lint             # ESLint
pnpm storybook        # Component preview
```

**Note:** Dev server runs in separate terminal - no need to run lint/type-check after changes

### saturn-backend (Django)

```bash
cd code/saturn-backend/backend
python manage.py runserver      # Start server (port 8000)
python manage.py process_task   # Background task worker
python manage.py migrate        # Run migrations
```

### mars / shuttle / chat (Go Services)

```bash
cd code/mars  # or code/shuttle or code/chat
make build    # Build binary
make run      # Run server
make start    # Build + run
make lint     # golangci-lint (mars/shuttle) / go vet (chat)
```

### abe (Admin Backend)

```bash
cd code/abe
bun install           # Install deps
bun run dev           # Start dev server (hot reload)
bun run compile       # Build binary
bun run start         # Run compiled binary
```

### grund (Dev Orchestration CLI)

```bash
cd code/grund
make build            # Build binary
make install          # Install to $GOPATH/bin
make test             # Run all tests
make test-unit        # Domain tests only
make test-coverage    # Generate coverage.html
```

## Port Map

| Service | Port |
|---------|------|
| saturn-backend (Django) | 8000 |
| mars | 8001 |
| shuttle | 8002 |
| jupiter | 8003 |
| abe | 8010 |
| chat | 8080 |
| saturn-fe | 5174 |
| area51 | 5173 |

## Architecture Notes

### jupiter

- LangGraph-based AI workflows with MongoDB checkpointing
- Celery for async task processing with Redis broker
- Features: Letter Generation (prod), TnC (dev), Global Chat (dev)
- Code style: Black (88 char), Ruff, MyPy (typed defs required)
- See `code/jupiter/spec/SYSTEM_OVERVIEW.md` for vertical slice architecture

### saturn-fe

- React 18 + TypeScript + Vite + Tailwind
- Component library with Radix UI primitives
- React Query for data fetching
- Module pattern: orchestrator component (<150 lines) + child components
- Design tokens: `text-title`, `text-description-primary`, `bg-bg-secondary`, etc.

### chat (Coplanner Chat API)

- Go 1.24 + Fiber v2 HTTP framework
- SSE (Server-Sent Events) for real-time AI query streaming
- PostgreSQL (GORM) for sessions/messages, Redis for caching/rate-limiting
- SQS to dispatch queries to Jupiter, S3 for document uploads
- FCA-compliant audit logs with 7-year retention (month-partitioned)
- Pattern: routes → controller → service → repository

### Go Services (mars, shuttle, chat)

- Standard Go project structure with `internal/`, `cmd/`
- Make-based builds
- golangci-lint for linting (mars/shuttle), go vet (chat)

## Cross-Project Dependencies

```text
saturn-fe ─────► mars ──────► saturn-backend (Django)
     │              │
     ├─────► chat ──┼──► jupiter (AI workflows, via SQS)
     │              │            │
     └─────► jupiter             ▼
                         External: MongoDB, Redis, SQS, S3, OpenAI/Anthropic
```

## Project-Specific CLAUDE.md Files

Individual projects have their own detailed CLAUDE.md with specific patterns:

- `code/jupiter/CLAUDE.md` - Code style, spec navigation
- `code/saturn-fe/CLAUDE.md` - Component patterns, design system usage
- `code/grund/CLAUDE.md` - DDD structure, test commands, documentation layout

---

## Bug Fix Documentation (fixes/)

The `fixes/` folder contains detailed documentation of significant bug fixes across the Saturn workspace.

**Purpose:**
- Track root causes and solutions for critical bugs
- Document what changed, why it changed, and the impact
- Maintain institutional knowledge about past issues
- Help prevent similar bugs in the future

**Structure:**
Each fix document should include:
- **Issue:** Clear description of the bug
- **Root Cause:** Why the bug occurred
- **Solution:** How it was fixed
- **Files Changed:** List of modified files
- **Impact:** What improved after the fix
- **PR Status:** Current state of the fix (draft, review, merged, released)
- **Testing:** How to verify the fix works
- **Related:** PR links, branch names, commit hashes

**When to create a fix document:**
- Bugs that affected production or user experience
- Issues that required changes across multiple files
- Fixes that future engineers should understand
- Problems that could reoccur if not documented

**Example:** `fixes/date-hallucination.md` - Documents AI date hallucination fix in jupiter's meeting note workflows

---

## Credentials

- **Saturn app**: irfan@heysaturn.com / 123123

## Auth / Login

- **Login endpoint**: `POST http://localhost:8000/api/v3/auth/login/` (Django backend)
- **Payload**: `{ "username": "<email>", "password": "<password>" }`
- **Response**: `access` + `refresh` JWT tokens, `expires_in` (seconds), user details
- **Note**: Login is handled by Django backend (port 8000), not shuttle directly. Shuttle (port 8002) handles token verification and permissions after login.
- **curl script**: `architecture/curl/login.sh`

---

## Recurring Tasks

### [Tuesday] Update Architecture Documentation

**Last completed:** 2026-02-17 | **Next:** 2026-02-24

Update `architecture/` folder with current system state. Read SYSTEM.md, DATA_FLOW.md, SERVICES.md.

### [Wednesday] Explore grund as Makefile replacement

**Before starting:** Ask the human if they want to spend time on this task. Check if grund can replace the workspace Makefile.
