# Saturn Services Documentation

**Last updated:** 2026-02-27

Detailed information about each service — responsibilities, tech stack, configuration, and integration points.

## Port Map

| Service | Port | Notes |
|---------|------|-------|
| saturn-backend | 8000 | Django `runserver` default |
| mars | 8001 | Guardian API |
| shuttle | 8002 | Auth + proxy gateway |
| jupiter | 8003 | FastAPI AI service |
| abe | 8010 | Admin backend |
| chat | 8080 | Coplanner chat API |
| area51 | 5173 | Eval UI |
| saturn-fe | 5174 | React frontend |

---

## 1. saturn-fe (Frontend Application)

### Overview
React-based web application providing the UI for financial advisors to manage clients, generate letters, create meeting notes, chat with AI, view analytics, and access compliance tools.

### Technology Stack
- **Framework:** React 18.3 + TypeScript 5.6
- **Build Tool:** Vite 6
- **Routing:** React Router 7.1
- **State Management:** React Query 3.39 (server state), Zustand 5 (client state)
- **Styling:** Tailwind CSS 3.4
- **UI Components:** Radix UI primitives
- **Rich Text:** TipTap 3
- **Charts:** Recharts 2.8
- **Collaborative Editing:** Yjs 13.6
- **Animations:** Framer Motion 11.13
- **Validation:** Zod 3.24
- **AI Monitoring:** Langfuse 3.38

### Project Structure
```
src/
├── api/               # 35+ service files, 34+ React Query hooks
├── components/        # 87+ reusable UI components
├── modules/           # 17+ feature-specific modules
├── pages/             # 19+ route page components
├── stores/            # 13 Zustand stores
├── routes/            # Routing configuration
├── hooks/             # 24+ custom React hooks
├── types/             # 26 TypeScript type definitions
└── utils/             # Utility functions
```

### Feature Modules
1. **MRF** (Meeting Record Flow) — v1 and v2
2. **Suitability Letters** — Multi-step AI letter generation
3. **LOA** (Letter of Authority) — Case management with plan extraction
4. **Guardian Suite** — Client care + compliance observations
5. **Client Management** — Profiles, contacts, investments
6. **Native Analytics** — Extensible dashboard with charts/tables (NEW)
7. **Tasks** — Kanban board with task details
8. **Coplanner** — AI chat integration (real API, replacing mocks)
9. **Settings** — Profile, integrations, user management, delegations
10. **TnC** — Training & Competency tracking
11. **Fact Find** — Client questionnaire
12. **Inbox** — Notifications
13. **Labs** — Email agent, document extraction
14. **Wiki** — Knowledge base (Prismic CMS)
15. **What's New** — Product changelog

### Development Commands
```bash
cd code/saturn-fe
pnpm install          # Install dependencies
pnpm dev              # Start dev server (port 5174)
pnpm build            # Production build
pnpm lint             # ESLint
pnpm storybook        # Component preview
```

---

## 2. shuttle (Authentication & Proxy Gateway)

### Overview
Central authentication, authorization, and multi-tenant user management service. Also serves as the API proxy gateway routing frontend requests to backend services with proper auth context.

### Technology Stack
- **Language:** Go 1.21+
- **Framework:** Fiber v2
- **Database:** PostgreSQL (GORM)
- **Cache:** Redis
- **Auth:** JWT (golang-jwt), Auth0 (M2M + RWA)
- **Observability:** Datadog APM, Sentry

### Core Responsibilities
1. User authentication (login, OTP, MFA, password reset)
2. JWT token management (access/refresh)
3. Tenant management (multi-tenant support)
4. ReBAC (Relationship-Based Access Control)
5. User delegations and role management
6. S2S token generation for inter-service auth
7. API proxy gateway with authorization
8. SSE streaming support (240s timeout for jupiter)

### Proxy Gateway Chain
```
Request → Gateway → IPWhitelist → ValidateAccessToken → GetAuthzToken → Proxy
```

Routes to: mars, jupiter, chat

### Configuration
```yaml
Port: 8002
Database: PostgreSQL (SSL required, pool 5-20)
Redis: Port 6379
JWT: AccessTokenTTL 1hr, RefreshTokenTTL 7d
Auth0: M2M + RWA client
New: CHATAL_URL (chat service URL for proxy routing)
```

### Development Commands
```bash
cd code/shuttle
make build && make run    # Build and run (port 8002)
make lint                 # golangci-lint v2
```

---

## 3. mars (Guardian API Service)

### Overview
Core AI-powered letter generation, meeting management, analytics, and labs feature service. Primary API for financial advisors accessed via shuttle proxy.

### Technology Stack
- **Language:** Go 1.21+
- **Framework:** Fiber v2
- **Database:** PostgreSQL (GORM)
- **Message Queue:** AWS SQS
- **Cache:** Redis
- **Observability:** Datadog APM, StatsD, Sentry

### Core Responsibilities
1. Letter generation workflows (OCR → extraction → generation)
2. Meeting notes with collaborative editing (YJS)
3. Client profile and contact management
4. Analytics dashboard (Metabase JWT integration)
5. Context search API (@mentions, S2S with RBAC)
6. Labs features (cases, workflows, email pipeline)
7. Investment tracking and recommendations
8. Observations and TnC settings
9. Inbox/notifications
10. Feature waitlist management

### New: S2S Enrichment
Mars now calls Shuttle for RBAC enrichment on internal endpoints. Accepts service secrets from both Jupiter and Chat services.

### New: Labs Module
Migrated from saturn-backend — includes cases, workflows, orchestrations, communications (Outlook email), and triage system with new JSONB-typed models.

### Configuration
```yaml
Port: 8001
Database: PostgreSQL (SSL required)
AWS: SQS queues, S3 storage, SNS notifications
Redis: Caching
New: SHUTTLE_URL (required — for S2S enrichment)
```

### Development Commands
```bash
cd code/mars
make build && make run    # Build and run (port 8001)
make lint                 # golangci-lint
```

---

## 4. jupiter (AI Workflow Service)

### Overview
AI orchestration service using LangGraph for complex workflows. Handles letter generation, TnC evaluation, meeting note processing, coplanner queries, and chat with LLM calls routed through LiteLLM.

### Technology Stack
- **Language:** Python 3.11+
- **Framework:** FastAPI 0.115 + Uvicorn
- **AI:** LangGraph 0.5, LangChain 0.3, LiteLLM
- **Task Queue:** Celery 5.3 with Redis broker
- **Database:** MongoDB (exclusive to Jupiter)
- **LLMs:** OpenAI (GPT-5, GPT-5.1, GPT-4.1), Anthropic (Claude Sonnet 4.6), Google (Gemini 2.5 Pro)
- **Observability:** Langfuse, Datadog APM

### Workflows

| Workflow | Status | LLM Route | Key Change |
|----------|--------|-----------|------------|
| Letter Generation | Production | Various | + evaluation pass (GPT-4.1) |
| Meeting Notes v1/v2 | Production | Various | + date context fix |
| Client Perspective | Production | GPT-5.1 → GPT-5 Azure | Upgraded + A/B eval (247 cases) |
| Follow-up Email | Production | Claude Sonnet 4.6 Bedrock → Direct → GPT-5 | Upgraded + Bedrock |
| TnC | Development | GPT-5 Azure → GPT-5 (reasoning: high) | Stable |
| Global Chat | Development | Various | RAG + tool architecture |
| Coplanner | Development | Various | HTTP dispatch from chat |
| Speaker ID | Experimental | Gemini 2.5 Pro | - |

### LLM Temperature Constraint
GPT-5 and GPT-5.1 models **require temperature=1.0** — no other values supported.

### API Endpoints
```
GET    /health                        - Health check
POST   /letter/trigger                - Trigger letter generation
GET    /letter/{id}/extracted-data    - Get workflow state
POST   /letter/resume                 - Resume after human verification
POST   /tnc/trigger                   - Trigger TnC evaluation
POST   /chat/message                  - Global chat (SSE streaming)
POST   /internal/coplanner/query      - Coplanner query (from chat, S2S)
POST   /internal/coplanner/ramble     - Audio transcription (from chat, S2S)
POST   /eval/diarization             - Start diarization eval (from abe)
GET    /eval/diarization/{id}        - Get eval results (from abe)
```

### Configuration
```yaml
Port: 8003
Database: MongoDB (pool 5-20)
Redis: Celery broker + result backend
LLMs: OpenAI, Anthropic, Google (via LiteLLM)
AWS: SQS (inbox/completion queues), S3 (file storage), Bedrock (Claude)
Observability: Langfuse + Datadog
```

### Development Commands
```bash
cd code/jupiter
make install          # Install deps with uv
make run              # Start FastAPI server (port 8003)
make run-worker       # Start Celery worker
make lint             # Ruff
make format           # Black
make type-check       # MyPy
uv run pytest         # Run tests
```

---

## 5. saturn-backend (Main Django Backend)

### Overview
Main business logic and client management service. Handles accounts, CRM integrations, calendar sync, tasks, LOA, fact-find, email agent, and background task processing.

### Technology Stack
- **Language:** Python 3.11+
- **Framework:** Django 5 + Django REST Framework
- **Database:** PostgreSQL
- **Task Queue:** Celery with Redis broker
- **Cache:** Redis

### Django Apps (40+)
**Core:** server, auth, management, common
**Business:** firm, employee, client, assignments
**Engagement:** letter, letterv3, document, meeting, email
**Features:** flows, fact_find, planning, mrf, compliance.tnc
**Integrations:** integrations, integrationsv2, integrationsv2.calendar
**Utilities:** darklaunch_features, proxy, analytics, task, cache
**Labs:** doc_extraction_loa, notification, notification_framework

### Recent Changes
- New meeting types (feature flagged: `mrf_new_types_enabled`)
- Custom Intelliflo app_id per firm
- Microsoft OAuth multi-user fix
- Feature flag improvements (flag_map pattern)

### Background Tasks (Celery Beat)
```
refresh-expiring-oauth-tokens    - Every 55 minutes
renew-expiring-subscriptions     - Every 4 hours
cleanup-orphaned-subscriptions   - Daily at 2 AM
auto-schedule-bots-for-pending   - Daily at 5 AM
cleanup-orphaned-bots            - Sunday at 3 AM
deactivate-expired-trials        - Every 6 hours
reconcile-autobot-status         - Daily at 3 AM
```

### Development Commands
```bash
cd code/saturn-backend/backend
python manage.py runserver          # Start server (port 8000)
python manage.py process_task       # Background task worker
python manage.py migrate            # Run migrations
```

---

## 6. chat (Coplanner Chat API)

### Overview
Real-time coplanner chat service with SSE streaming, audio transcription, and AI query processing. Communicates with Jupiter via HTTP and uses Redis Pub/Sub for async results.

### Technology Stack
- **Language:** Go 1.24
- **Framework:** Fiber v2
- **Database:** PostgreSQL (GORM, cursor-based pagination)
- **Cache:** Redis (session state, Pub/Sub)
- **Streaming:** SSE (Server-Sent Events)
- **Audit:** FCA-compliant, 7-year retention, month-partitioned

### Core Models
```go
CoplannerSession {
    FirmID, UserID, ClientID    uuid.UUID
    Title                        string
    Status                       string  // ACTIVE, ARCHIVED
    LastActivityAt               time.Time
    MessageCount                 int
    Metadata                     JSONB
}

CoplannerMessage {
    SessionID, RequestID         uuid.UUID
    Role                         string  // USER, ASSISTANT
    Content                      string
    ContentType                  string  // TEXT, CODE, DOCUMENT
    Status                       string  // COMPLETED, PENDING, ERROR
    PageContext, Mentions         JSONB
    TokenCount, ProcessingTimeMs int
    ModelUsed                    string
}
```

### Key Features
- HTTP dispatch to Jupiter (replaced SQS — lower latency)
- S2S enrichment via Shuttle for RBAC
- ALB-aware graceful shutdown with load shedding
- Active stream tracking with atomic counters
- Context search via Mars S2S

### Configuration
```yaml
Port: 8080
Database: PostgreSQL
Redis: Session state + Pub/Sub
JupiterBaseURL: HTTP endpoint for AI dispatch
MarsBaseURL: Context search + enrichment
ShuttleBaseURL: S2S auth enrichment
ServiceSecret: Inter-service auth key
```

### Development Commands
```bash
cd code/chat
make build && make run    # Build and run (port 8080)
```

---

## 7. abe (Admin Backend Service)

### Overview
Backend API for Saturn administration, tenant management, RBAC, and evaluation tools. Provides admin interface for managing tenants, users, permissions, and running AI evaluations.

### Technology Stack
- **Runtime:** Bun
- **Language:** TypeScript
- **Framework:** Express.js
- **Database:** MongoDB (Mongoose)
- **AWS:** S3, SES, SQS

### Core Responsibilities
1. Tenant CRUD and multi-tenant management
2. Admin user management with RBAC
3. User delegations with expiration
4. Letter configuration management
5. Feature flag management
6. Meeting data access (via Mars S2S)
7. Diarization evaluation (via Jupiter) — in development
8. User login functionality

### New: Meeting & Eval APIs (in development)
```
GET    /meetings/                    - List meetings (via Mars S2S)
GET    /meetings/:id                 - Get meeting (via Mars S2S)
POST   /eval/diarization             - Start diarization eval (via Jupiter)
GET    /eval/diarization/:meetingId  - Get eval results (via Jupiter)
```

### Configuration
```yaml
Port: 8010
Database: MongoDB
AWS: S3, SES, SQS
Services:
  shuttle: SHUTTLE_URL
  mars: MARS_URL (with service secret)
  jupiter: JUPITER_URL (new)
```

### Development Commands
```bash
cd code/abe
bun install           # Install deps
bun run dev           # Start dev server (port 8010)
```

---

## 8. grund (Dev Orchestration CLI)

### Overview
Local microservice development orchestration tool. Automates service startup with complete dependency chains in correct order. Now with lifecycle hooks and repository sync.

### Technology Stack
- **Language:** Go 1.21+
- **Runtime:** Docker & Docker Compose v2+
- **CLI:** Cobra
- **Architecture:** Domain-Driven Design (DDD)
- **Version:** v0.5.0

### CLI Commands
```bash
# Daily operations
grund up <service...>             # Start services with dependencies
grund down                        # Stop all services
grund status                      # Show running services
grund logs [service...]           # View logs
grund restart <service>           # Restart service
grund reset [--volumes]           # Stop and cleanup
grund sync                        # Clone/pull all service repos (NEW v0.5.0)

# Configuration
grund init                        # Interactive setup wizard
grund service init                # Initialize new service
grund service add <type>          # Add infrastructure
grund config show [service]       # Display config
grund secrets list <service>      # Show required secrets
```

### New: Lifecycle Hooks (v0.4.0)
```yaml
# In services.yaml
services:
  chat:
    hooks:
      - stage: post_infrastructure    # pre_up, post_infrastructure, post_up, pre_down, post_down
        target: host                  # host or container
        command: "create-session-table.sh"
        continue_on_error: false
        timeout: 30
```

### New: `grund sync` (v0.5.0)
- Clone all missing service repos (shallow clone)
- Pull existing repos (`git pull --ff-only`)
- `--no-pull` flag to skip pulls
- Table output showing status per service

### Development Commands
```bash
cd code/grund
make build            # Build binary
make install          # Install to $GOPATH/bin
make test             # Run all tests
make test-unit        # Domain tests only
make test-coverage    # Generate coverage.html
```

---

## Service Summary Table

| Service | Language | Framework | Port | Database | Queue | Purpose |
|---------|----------|-----------|------|----------|-------|---------|
| saturn-fe | TypeScript | React 18 + Vite | 5174 | - | - | Web UI |
| shuttle | Go | Fiber v2 | 8002 | PostgreSQL | - | Auth + Proxy Gateway |
| mars | Go | Fiber v2 | 8001 | PostgreSQL | SQS | Letters, Meetings, Analytics |
| jupiter | Python | FastAPI | 8003 | MongoDB | Redis (Celery) | AI Workflows |
| saturn-backend | Python | Django 5 | 8000 | PostgreSQL | Redis (Celery) | Main Business Logic |
| chat | Go 1.24 | Fiber v2 | 8080 | PostgreSQL | Redis (Pub/Sub) | Coplanner Chat |
| abe | TypeScript | Bun + Express | 8010 | MongoDB | SQS | Admin Backend |
| grund | Go | Cobra CLI | - | - | - | Dev Orchestration |
