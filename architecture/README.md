# Saturn Architecture

This folder contains architecture documentation for the Saturn ecosystem.

**Last updated:** 2026-02-17 (Tuesday)

## Contents

- `SYSTEM.md` - High-level system architecture and service relationships
- `DATA_FLOW.md` - Data flow between services
- `SERVICES.md` - Individual service responsibilities and APIs
- `OPTIMIZATIONS.md` - Optimizations for the Tuesday documentation update process

## Update Schedule

This documentation is refreshed every **Tuesday** by exploring all repositories and capturing the current state of the system.

## What's New (2026-02-17)

### Services Explored
- ✅ jupiter (AI Service) - Letter generation, TnC, Global Chat, Meeting Notes
- ✅ saturn-fe (Frontend) - React app with 87 components, 17 feature modules
- ✅ saturn-backend (Django) - 40+ Django apps for client/account management
- ✅ mars (Go) - Guardian API for letters and meetings
- ✅ shuttle (Go) - Authentication, authorization, ReBAC
- ✅ abe (Bun/Express) - Admin backend with tenant management
- ✅ grund (Go CLI) - Dev orchestration tool with dependency resolution

### Key Findings
- **New Features:** Global Chat with RAG, Citation checking, Meeting note v2, User delegations
- **Architecture Improvements:** ReBAC implementation, Proxy gateway, Resource context service
- **Infrastructure:** Datadog APM integrated, OpenTelemetry setup, Public ALB for shuttle
- **Optimizations:** Multiple opportunities identified in OPTIMIZATIONS.md

### Service Communication Pattern
```
saturn-fe → shuttle (auth/proxy) → mars/jupiter/saturn-backend
                ↓                          ↓
           PostgreSQL                  MongoDB + Redis + SQS
```

## How to Use This Documentation

1. **SYSTEM.md** - Start here for high-level overview and service ecosystem
2. **DATA_FLOW.md** - Understand how data moves between services (auth, letters, meetings)
3. **SERVICES.md** - Deep dive into each service (APIs, models, config)
4. **OPTIMIZATIONS.md** - Performance improvements and opportunities

## Contributing

When making significant architectural changes:
1. Update the relevant .md file
2. Add optimization opportunities to OPTIMIZATIONS.md
3. Update this README with the date and changes
4. Run `grep -r "FIXME\|TODO" code/` to identify known issues
