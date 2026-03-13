# Saturn System Architecture

**Last updated:** 2026-02-27

## Overview

Saturn Fintech is a SAAS platform providing AI-powered tools for UK Financial Advisors. The system is built as a microservices architecture with 8 core services working together to deliver letter generation, meeting management, compliance checking, coplanner chat, analytics, and client management capabilities.

## Service Ecosystem

```
┌─────────────────────────────────────────────────────────────────┐
│                         saturn-fe (React)                        │
│                    Frontend Application Layer                    │
└────────────┬──────────────────┬─────────────────┬──────────────┘
             │                  │                  │
             ▼                  ▼                  ▼
┌────────────────────┐ ┌───────────────┐ ┌────────────────────┐
│  shuttle (Go)      │ │  mars (Go)    │ │  chat (Go)         │
│  Authentication &  │◄┤  Guardian API │ │  Coplanner Chat    │
│  Authorization     │ │  Letters &    │ │  SSE Streaming     │
│  Proxy Gateway     │ │  Meetings     │ │  Audio Transcribe  │
└────────┬───────────┘ └──────┬────────┘ └────────┬───────────┘
         │                    │                    │
         │    ┌───────────────┴────────────────────┘
         │    │         S2S Enrichment
         │    ▼
         │  ┌────────────────────────┐
         │  │   jupiter (Python)     │
         │  │   AI Workflows         │
         │  │   LangGraph Engine     │
         │  │   LLM Routing          │
         │  └────────────────────────┘
         │                │
         ▼                ▼
┌────────────────────┐ ┌────────────────────────┐
│ saturn-backend     │ │   abe (Bun/Express)    │
│ (Django)           │ │   Admin Backend        │
│ Main Business      │ │   Tenant Management    │
│ Logic              │ │   Eval & Meetings      │
└────────────────────┘ └────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────────┐
│                    Shared Infrastructure                        │
│  PostgreSQL | MongoDB | Redis | AWS (S3, SQS, SNS, SES)       │
└────────────────────────────────────────────────────────────────┘
```

## Core Services

### 1. **saturn-fe** (Frontend)
- **Language:** TypeScript (React 18 + Vite)
- **Purpose:** Web UI for financial advisors
- **Key Tech:** React Query, Zustand, Tailwind, Radix UI, TipTap, Recharts
- **Port:** 5174 (dev)

**Key Features:**
- Multi-layout routing with feature flags
- 87+ reusable UI components
- 17+ feature modules (MRF, LOA, Suitability Letters, Guardian, TNC, Analytics, Tasks)
- Environment-based routing (labs/beta/production)
- Native Analytics dashboard with extensible section types
- Coplanner integration with real API (replacing mocks)

### 2. **shuttle** (Authentication & Proxy Gateway)
- **Language:** Go (Fiber v2)
- **Purpose:** Central auth, authz, proxy gateway, and multi-tenant management
- **Key Tech:** JWT, Auth0, PostgreSQL, Redis, Datadog APM
- **Port:** 8002

**Key Responsibilities:**
- User authentication (login, OTP, MFA, password reset)
- JWT token management (access/refresh)
- ReBAC (Relationship-Based Access Control)
- User delegations and role management
- API proxy gateway with authorization (routes to mars, jupiter, chat)
- S2S token generation for inter-service auth
- SSE streaming support with extended timeouts (240s for jupiter)

### 3. **mars** (Guardian API)
- **Language:** Go (Fiber v2)
- **Purpose:** Core letter generation, meeting management, analytics, and labs features
- **Key Tech:** PostgreSQL, SQS, Redis, Datadog, StatsD
- **Port:** 8001

**Key Responsibilities:**
- Letter generation workflows (OCR → extraction → generation → DOCX)
- Meeting notes with collaborative editing (YJS)
- Client profile and contact management
- Analytics dashboard API (Metabase JWT integration)
- Context search API for @mentions (S2S with RBAC)
- Labs features (cases, workflows, orchestrations, email pipeline)
- Investment tracking and recommendations
- TnC (Terms & Conditions) generation

### 4. **jupiter** (AI Service)
- **Language:** Python (FastAPI + LangGraph)
- **Purpose:** AI orchestration and LLM workflows
- **Key Tech:** LangGraph 0.5, LangChain 0.3, Celery, MongoDB, Redis, LiteLLM
- **Port:** 8003

**Key Features:**
- **Letter Generation** (Production): 6-node LangGraph pipeline + final evaluation pass
- **TnC** (In Development): Batch processing with parallel question evaluation
- **Global Chat** (In Development): Orchestrator-Agent design with RAG
- **Meeting Notes** (Production): Multi-chain workflow with speaker diarization + date context
- **Client Perspective** (Production): GPT-5.1 with A/B evaluation framework
- **Follow-up Email** (Production): Claude Sonnet 4.6 via AWS Bedrock
- **Speaker ID** (Experimental): Gemini 2.5 Pro
- **Coplanner** (In Development): Query and transcription dispatch for chat service

**Current LLM Routing:**
- Client Perspective: GPT-5.1 (temperature=1.0 required) → GPT-5 Azure fallback
- Follow-up Email: Claude Sonnet 4.6 Bedrock → Claude Sonnet 4.6 Direct → GPT-5 reasoning
- TnC: GPT-5 Azure → GPT-5 (reasoning_effort: high)
- Letter Evaluation: GPT-4.1 (temperature=0.3)

### 5. **saturn-backend** (Main Backend)
- **Language:** Python (Django 5)
- **Purpose:** Main business logic and client management
- **Key Tech:** Django REST Framework, PostgreSQL, Celery, Redis
- **Port:** 8000

**Key Responsibilities:**
- Client and account management (40+ Django apps)
- Letter templates and publishing (v1 + v3 AI-powered)
- Fact-finding questionnaires
- CRM integrations (Intelliflo, Xplan, Plannr, Curo)
- Calendar sync (Microsoft, Google)
- Background task processing
- Feature flags and dark launch
- New meeting types (feature flagged)
- Email agent with Gmail Watch + Google Cloud Pub/Sub

### 6. **chat** (Coplanner Chat API)
- **Language:** Go 1.24 (Fiber v2)
- **Purpose:** Real-time coplanner chat with AI query streaming
- **Key Tech:** PostgreSQL (GORM), Redis (Pub/Sub), SSE
- **Port:** 8080

**Key Features:**
- SSE streaming for AI query responses
- Audio transcription streaming
- Session and message management with cursor-based pagination
- Document upload support
- Context search (@mentions) via Mars S2S
- HTTP dispatch to Jupiter (replaced SQS for lower latency)
- S2S enrichment via Shuttle for RBAC
- ALB-aware graceful shutdown with load shedding
- FCA-compliant audit logs (7-year retention, month-partitioned)

### 7. **abe** (Admin Backend)
- **Language:** TypeScript (Bun + Express)
- **Purpose:** Admin operations, tenant management, and evaluation tools
- **Key Tech:** MongoDB, AWS (S3, SES, SQS), Stream Chat
- **Port:** 8010

**Key Responsibilities:**
- Tenant CRUD and multi-tenant management
- Admin user management with RBAC
- User delegations with expiration
- Letter configuration management
- AWS integration (S3 uploads, SES email, SQS messaging)
- Meeting data access (via Mars S2S)
- Diarization evaluation (via Jupiter) - in development
- User login functionality

### 8. **grund** (Dev Orchestration CLI)
- **Language:** Go (CLI tool)
- **Purpose:** Local development orchestration
- **Key Tech:** Docker, Docker Compose v2+, Cobra CLI
- **Version:** v0.5.0

**Key Features:**
- Automatic dependency resolution (transitive + topological sort)
- Infrastructure support (Postgres, MongoDB, Redis, LocalStack)
- Environment variable interpolation
- Health check monitoring
- Service lifecycle management
- **Lifecycle hooks** (v0.4.0): pre_up, post_infrastructure, post_up, pre_down, post_down
- **`grund sync`** (v0.5.0): Auto-clone and pull service repositories

## Technology Stack Summary

| Service | Language | Framework | Database | Message Queue | Cache |
|---------|----------|-----------|----------|---------------|-------|
| saturn-fe | TypeScript | React 18 + Vite | - | - | - |
| shuttle | Go | Fiber v2 | PostgreSQL | - | Redis |
| mars | Go | Fiber v2 | PostgreSQL | AWS SQS | Redis |
| jupiter | Python | FastAPI | MongoDB | Redis (Celery) | Redis |
| saturn-backend | Python | Django 5 + DRF | PostgreSQL | Redis (Celery) | Redis |
| chat | Go 1.24 | Fiber v2 | PostgreSQL | Redis (Pub/Sub) | Redis |
| abe | TypeScript | Bun + Express | MongoDB | AWS SQS | - |
| grund | Go | Cobra CLI | - | - | - |

## Infrastructure Dependencies

### Databases
- **PostgreSQL:** shuttle, mars, saturn-backend, chat (client data, users, letters, sessions)
- **MongoDB:** jupiter (AI checkpoints, vectors, RAG), abe (admin data)
- **Redis:** All services (caching, sessions, Celery broker, Pub/Sub)

### AWS Services
- **S3:** File storage (letters, documents, firm assets, audio files)
- **SQS:** Async messaging between services (Jupiter ↔ Mars, Saturn-backend ↔ Mars)
- **SNS:** Pub/sub notifications
- **SES:** Email sending (abe)

### External Services
- **OpenAI:** GPT-5, GPT-5.1, GPT-4.1 via jupiter (LiteLLM routing)
- **Anthropic:** Claude Sonnet 4.6 via jupiter (direct + AWS Bedrock)
- **Google Gemini:** Gemini 2.5 Pro for speaker ID (jupiter)
- **Auth0:** User authentication (shuttle)
- **Datadog:** APM tracing (jupiter, mars, shuttle)
- **Langfuse:** LLM observability (jupiter, saturn-fe)
- **Sentry:** Error tracking (all services)
- **Reducto.ai:** OCR/document extraction (jupiter)
- **AssemblyAI/Deepgram:** Speech-to-text (jupiter)
- **Metabase:** Analytics dashboards (mars JWT integration)
- **Mixpanel:** User event tracking (saturn-fe)
- **Hotjar:** User behavior analytics (saturn-fe)

## Deployment Architecture

### Production Environments
- **Production:** secure.saturnos.com, api.cronos.heysaturn.com
- **Staging:** beta.heysaturn.com, api.cronos-stage.heysaturn.com
- **Labs:** labs.heysaturn.com, api.cronos-dev.heysaturn.com

### Service Communication
- **Frontend → Services:** Via shuttle proxy gateway (with auth + SSE support)
- **Service → Service:** Direct HTTP with S2S enrichment via shuttle
- **Chat → Jupiter:** HTTP POST (replaced SQS for lower latency)
- **Async Processing:** SQS queues for long-running operations (Mars ↔ Jupiter)
- **Real-time:** SSE streaming (chat, global chat), Redis Pub/Sub (chat results)

## Observability

### Logging
- JSON logging across all services
- Winston (abe), Python logging (jupiter, saturn-backend), Go logging (mars, shuttle, chat)

### Tracing
- Datadog APM: jupiter, mars, shuttle
- Request ID propagation
- OpenTelemetry support

### Monitoring
- Sentry: Error tracking
- Langfuse: LLM call tracing (jupiter, saturn-fe)
- Mixpanel: User event tracking
- Hotjar: User behavior analytics
- Metabase: Analytics dashboards

### Metrics
- StatsD metrics (mars)
- Custom health check endpoints (all services)

## Security

### Authentication Flow
1. User login via shuttle (JWT tokens)
2. Access token (short-lived) + Refresh token (long-lived)
3. Token validation on each request
4. Service-to-service auth via shared secrets (X-Service-Auth header)

### S2S Enrichment Pattern (New)
1. Service receives request with X-Service-Auth + X-User-ID headers
2. Service validates service secret
3. Calls Shuttle `/internal/auth/enrich` for user context
4. Enriched user data (roles, tenants, permissions) set in request context
5. RBAC enforcement on downstream handlers

### Authorization
- ReBAC (Relationship-Based Access Control) via shuttle
- Role-based permissions (ADVISOR, DIRECTOR, COMPLIANCE, etc.)
- User delegations with expiration
- Multi-tenant isolation
- Policy-based authorization in mars (loaded from config/authorization)

### Data Security
- Soft delete pattern (deleted flag)
- Tenant-scoped queries
- Audit logging on main entities
- FCA-compliant audit logs in chat (7-year retention)
- Encrypted secrets management

## Development Tools

### Local Development
- **grund CLI:** Service orchestration with dependency resolution + lifecycle hooks
- **Docker Compose:** Infrastructure management
- **Makefile:** Global commands (start, stop, logs)
- **Hot reload:** Vite (frontend), Uvicorn (jupiter), Django runserver

### Code Quality
- **TypeScript:** ESLint + Prettier
- **Python:** Black, Ruff, MyPy
- **Go:** golangci-lint (mars, shuttle), go vet (chat)
- Pre-commit hooks across all repos

### Testing
- **Frontend:** Vitest, React Testing Library
- **Backend:** pytest (Python), go test (Go)
- **E2E:** Evaluation framework in jupiter
- **AI Evals:** A/B evaluation framework (247 test cases for client perspective)

## Scaling Strategy

### Horizontal Scaling
- Stateless service design
- Load balancing via ALB
- Celery workers (jupiter, saturn-backend)
- Redis pub/sub for distributed systems
- ALB-aware graceful shutdown (chat)

### Performance Optimization
- React Query caching (frontend)
- MongoDB connection pooling (jupiter)
- PostgreSQL connection pooling (all Go/Django services)
- Redis caching layer
- Lazy loading and code splitting
- Cursor-based pagination (chat)

### Reliability
- Auto-retry with exponential backoff (Celery)
- LLM fallback routing (LiteLLM with multi-deployment)
- Circuit breaker patterns
- Graceful shutdown handlers
- Load shedding during deployment (chat)
- Health checks for service discovery

## Recent Architectural Changes (Feb 2026)

### New Features
- Native Analytics dashboard (saturn-fe + mars Metabase integration)
- Coplanner chat service (chat) with SSE streaming and audio transcription
- Letter evaluation pass - final quality gate (jupiter)
- Client Perspective upgrade to GPT-5.1 with A/B eval framework (jupiter)
- Follow-up email upgrade to Claude Sonnet 4.6 via Bedrock (jupiter)
- Labs feature migration to mars (cases, workflows, orchestrations, email)
- Tasks module with kanban view (saturn-fe)
- LOA module matured (saturn-fe)
- Meeting & Eval admin APIs (abe)
- `grund sync` command for repo management (grund v0.5.0)
- Lifecycle hooks for service setup/teardown (grund v0.4.0)
- New meeting types with feature flags (saturn-backend)

### Architecture Improvements
- S2S enrichment pattern via Shuttle (mars, chat → shuttle for RBAC)
- Chat replaced SQS with HTTP for Jupiter dispatch (lower latency)
- SSE streaming support through shuttle proxy gateway
- ALB-aware graceful shutdown with load shedding (chat)
- Context search API for @mentions with RBAC (mars internal)
- Date hallucination fix in meeting note workflows (jupiter)
- GPT-5/5.1 temperature constraint handling (must be 1.0)

### Infrastructure Updates
- AWS Bedrock integration for Claude models (jupiter)
- Redis Pub/Sub for chat result delivery
- Metabase JWT signing for analytics (mars)
- Extended proxy timeouts (240s for jupiter via shuttle)
- golangci-lint v2 and pre-commit hooks (shuttle)
