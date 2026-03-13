# Documentation Update Process Optimizations

**Last updated:** 2026-02-17

This document tracks optimizations and improvements to the **Tuesday architecture documentation update process** - making the scheduled task faster, more efficient, and producing better documentation.

---

## Current Process Overview

**What we do every Tuesday:**
1. Launch 5 explore agents in parallel to examine all repositories
2. Wait for all agents to complete (~90-120 seconds total)
3. Synthesize findings from all agent reports
4. Create/update 4 documentation files (SYSTEM.md, DATA_FLOW.md, SERVICES.md, this file)
5. Update README.md with latest changes

**Time breakdown (2026-02-17):**
- Agent exploration: ~95-113 seconds (parallel execution)
- Documentation writing: ~10-15 seconds (4 files)
- Total: ~105-128 seconds (under 2 minutes)

---

## Optimizations Applied Today (2026-02-17)

### ✅ 1. Parallel Agent Execution
**What:** Launched all 5 explore agents simultaneously instead of sequentially

**Impact:**
- Before: ~450 seconds (5 agents × 90s each, sequential)
- After: ~113 seconds (longest agent duration)
- **Improvement: 75% faster** (4x speedup)

**Implementation:**
```xml
<function_calls>
  <invoke name="Task"><!-- jupiter --></invoke>
  <invoke name="Task"><!-- saturn-fe --></invoke>
  <invoke name="Task"><!-- saturn-backend --></invoke>
  <invoke name="Task"><!-- mars + shuttle --></invoke>
  <invoke name="Task"><!-- abe + grund --></invoke>
</function_calls>
```

**Lesson learned:** Always launch independent exploration tasks in parallel to maximize efficiency.

---

### ✅ 2. Grouped Related Services
**What:** Combined related Go services into single agent tasks (mars+shuttle, abe+grund)

**Impact:**
- Reduced from 7 potential agents to 5 agents
- Agent can understand relationships between similar services better
- Less context switching when synthesizing findings

**Why it works:**
- mars + shuttle: Both Go services with similar architecture, shuttle is the auth gateway for mars
- abe + grund: Both supporting services (admin backend + dev CLI)

**Lesson learned:** Group related services when they share similar tech stacks or have tight integration.

---

### ✅ 3. Used Haiku Model for Exploration
**What:** Specified `model: haiku` for all explore agents instead of default sonnet

**Impact:**
- Faster exploration (haiku is optimized for speed)
- Lower cost per exploration
- Still comprehensive findings (haiku is sufficient for code exploration)

**Lesson learned:** Use haiku for straightforward exploration tasks, reserve sonnet for complex synthesis.

---

## Optimization Opportunities (Not Yet Applied)

### 🎯 1. Incremental Updates Instead of Full Rewrites
**Current:** Completely rewrite all documentation files every Tuesday
**Opportunity:** Only update sections that have changes

**How to implement:**
1. Store git commit hashes for each repo in README.md
2. On Tuesday, check which repos have new commits since last update
3. Only re-explore repos with changes
4. Update only affected sections in documentation

**Expected impact:**
- Reduce exploration time by 60-80% when only 1-2 repos have changes
- From ~2 minutes to ~30-60 seconds for minor updates

**Trade-off:** More complex logic, might miss cross-service impacts

---

### 🎯 2. Agent Result Caching
**Current:** Fresh exploration every Tuesday, even if no changes
**Opportunity:** Cache agent results and reuse if repo hasn't changed

**How to implement:**
1. Hash the latest git commit of each repo
2. Store agent results with commit hash in `architecture/.cache/`
3. If commit hash matches, use cached results
4. Only re-run agents for repos with new commits

**Expected impact:**
- Near-instant updates (5-10 seconds) when no code changes
- Significant reduction in LLM API costs

**Trade-off:** Need cache invalidation strategy, storage overhead

---

### 🎯 3. Automated Change Detection
**Current:** Manually review all agent findings
**Opportunity:** Automatically highlight what changed since last update

**How to implement:**
1. Diff previous documentation with new findings
2. Generate "What's New" section automatically
3. Highlight new features, API endpoints, models

**Expected impact:**
- Faster synthesis (no need to manually compare)
- Better changelog for README.md

---

### 🎯 4. Template-Based Documentation Generation
**Current:** Write documentation from scratch each time
**Opportunity:** Use templates with placeholder sections

**How to implement:**
1. Create Jinja2 templates for each .md file
2. Extract structured data from agent findings
3. Render templates with data

**Expected impact:**
- Consistent formatting across updates
- Faster writing (5 seconds instead of 15)
- Easier to maintain documentation structure

---

### 🎯 5. Focused Exploration Prompts
**Current:** General "explore everything" prompts
**Opportunity:** Give agents specific areas to focus on

**How to implement:**
- Agent 1 (jupiter): Focus on new workflows, AI features
- Agent 2 (saturn-fe): Focus on new routes, components, modules
- Agent 3 (saturn-backend): Focus on new Django apps, models
- Agent 4 (mars+shuttle): Focus on new API endpoints, auth changes
- Agent 5 (abe+grund): Focus on new admin features, CLI commands

**Expected impact:**
- More relevant findings (less noise)
- Faster exploration (agents don't explore unchanged areas)

---

### 🎯 6. Parallel Documentation Writing
**Current:** Write 4 files sequentially with Edit/Write tools
**Opportunity:** Generate all 4 file contents in parallel, then write

**How to implement:**
1. After synthesis, plan all 4 file updates
2. Generate content for all files in parallel
3. Write all files in single function_calls block

**Expected impact:**
- Slightly faster writing (marginal improvement)

**Trade-off:** More complex error handling if one file fails

---

### 🎯 7. Weekly Diff Report
**Current:** No comparison with previous week
**Opportunity:** Generate automated "What Changed This Week" report

**How to implement:**
1. Store previous week's agent findings
2. Diff current findings with previous
3. Generate markdown report of changes

**Expected impact:**
- Better visibility into what's new
- Easier to spot trends (which services changing most)
- Useful for stakeholder updates

---

## Process Improvement Ideas

### 💡 1. Add Validation Step
**Idea:** After generating docs, run validation checks

**Checks:**
- All services mentioned in SYSTEM.md exist in SERVICES.md
- All data flows reference valid services
- No broken internal links
- Code blocks have proper syntax

**Impact:** Higher documentation quality, catch errors early

---

### 💡 2. Generate Architecture Diagrams
**Idea:** Automatically generate visual diagrams from documentation

**How:**
- Use Mermaid.js for service diagrams
- Use PlantUML for sequence diagrams
- Embed in SYSTEM.md and DATA_FLOW.md

**Impact:** Better visualization, easier to understand architecture

---

### 💡 3. Track Documentation Metrics
**Idea:** Measure documentation quality over time

**Metrics to track:**
- Time to complete update
- Number of agent tool uses
- Documentation size (word count)
- Services explored vs. services with changes
- Cost per update (LLM API costs)

**Impact:** Data-driven optimization decisions

---

## Optimization Tracking Table

| Optimization | Priority | Effort | Impact | Status | Next Update |
|--------------|----------|--------|--------|--------|-------------|
| Parallel agent execution | ✅ High | Low | 75% faster | **Applied** | - |
| Grouped related services | ✅ High | Low | Less context | **Applied** | - |
| Used Haiku model | ✅ Medium | Low | Faster + cheaper | **Applied** | - |
| Incremental updates | 🎯 High | Medium | 60-80% faster | Planned | 2026-02-24 |
| Agent result caching | 🎯 High | Medium | Near-instant | Planned | 2026-03-03 |
| Automated change detection | 🎯 Medium | Low | Faster synthesis | Planned | 2026-03-03 |
| Template-based generation | 🎯 Low | Medium | Consistent format | Future | TBD |
| Focused exploration | 🎯 Medium | Low | Less noise | Planned | 2026-02-24 |
| Weekly diff report | 💡 Low | Medium | Better visibility | Future | TBD |
| Add validation step | 💡 Medium | Low | Higher quality | Future | TBD |

---

## Lessons Learned

### 2026-02-27 Update

**What worked well:**
- Parallel agent execution (5 agents, haiku model) — comprehensive results
- Sonnet model for frontend API mapping — needed deeper analysis for 35+ service files
- Feature-based documentation structure (user preference) — much more useful than service-based
- Documented frontend-facing APIs grouped by feature with route + flag info

**What could be improved:**
- Frontend API exploration took longest (~170s for sonnet, ~260s for route mapping)
- Could pre-cache the API service file list for faster targeted reads
- DATA_FLOW.md restructured as feature-based API reference — better for developers

**Process:**
- 5 explore agents (haiku): jupiter, saturn-fe, mars+shuttle, chat+abe+grund, saturn-backend
- 2 explore agents (sonnet): frontend API mapping, frontend routes+modules
- Total agents: 7
- Files updated: SYSTEM.md, DATA_FLOW.md, SERVICES.md, OPTIMIZATIONS.md

**Key changes documented:**
- Chat service fully documented (coplanner with SSE, HTTP replacing SQS)
- S2S enrichment pattern (mars, chat → shuttle for RBAC)
- Jupiter LLM routing updates (GPT-5.1, Claude Sonnet 4.6, GPT-4.1 eval pass)
- Native Analytics module (saturn-fe + mars Metabase JWT)
- Labs migration to mars
- Grund v0.4.0 hooks + v0.5.0 sync

---

### 2026-02-17

**What worked well:**
- ✅ Parallel agent execution was a huge win (4x speedup)
- ✅ Grouping related services reduced complexity
- ✅ Haiku model was sufficient for exploration
- ✅ Clear prompts produced comprehensive findings

**What could be improved:**
- 🔧 Agents explored too broadly - some findings weren't relevant to architecture
- 🔧 Manual synthesis took longer than expected (reading 5 agent reports)
- 🔧 Documentation writing could be more structured (used templates)

**Action items for next Tuesday (2026-02-24):**
1. Implement git commit hash tracking in README.md
2. Only re-explore repos with changes since last Tuesday
3. Give agents more focused prompts (new features, API changes only)
4. Consider caching agent results for unchanged repos

---

## How to Update This File

After each Tuesday documentation update:

1. **Record the process:**
   - Time taken for each step
   - Number of agents used
   - What worked, what didn't

2. **Add new optimizations:**
   - If you discovered a better way to do something, add it to "Optimizations Applied"
   - Update the tracking table

3. **Track opportunities:**
   - If you thought "this could be faster", add to "Optimization Opportunities"
   - Estimate priority, effort, and impact

4. **Update lessons learned:**
   - What was different this week?
   - What should we try next week?

5. **Measure progress:**
   - Compare total time to previous weeks
   - Track cost savings from optimizations

---

## Future Vision

**Goal:** Fully automated Tuesday updates in under 30 seconds

**Ideal workflow:**
1. Cron job triggers at 9 AM Tuesday
2. Check git commits since last Tuesday
3. Only explore changed repos (cached results for unchanged)
4. Generate incremental diffs
5. Update only changed sections
6. Commit and push to repo
7. Send Slack notification with "What's New" summary

**Estimated impact:**
- From ~2 minutes manual work to 30 seconds automated
- Consistent, reliable updates every Tuesday
- No human intervention needed

---

## Cost Tracking

### 2026-02-17 Update Costs
- **Agent exploration:** 5 agents × ~65,000 tokens each = ~325,000 tokens
- **Model:** Haiku ($0.25/1M input, $1.25/1M output)
- **Estimated cost:** ~$0.25-0.40 per update

**Optimization opportunity:** With caching, could reduce to ~$0.05-0.10 per update (80% savings)
