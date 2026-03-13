# Saturn Feature Architecture & API Reference

**Last updated:** 2026-02-27

This document describes Saturn's features from the frontend perspective — what each feature does, which APIs it calls, which backend services own those APIs, and the data flow for key workflows.

## Base URL Configuration

| Target | Base URL | Port |
|--------|----------|------|
| saturn-backend | `APP_CONFIGURATION.API_BASE_URL` | 8000 |
| mars (via proxy) | `API_PROXY_BASE_URL + 'mars'` | 8001 |
| ruler (via proxy) | `API_PROXY_BASE_URL + 'ruler'` | 8001 |
| shuttle | `API_PROXY_BASE_URL` | 8002 |
| chat | via shuttle proxy | 8080 |

---

## 1. Authentication

**Owner:** shuttle (primary), saturn-backend (legacy)
**Feature Flag:** None

### Routes
| Path | Page |
|------|------|
| `/auth/login` | Login |
| `/auth/register` | Register |
| `/auth/reset-password` | Password reset |
| `/auth/forgot-password` | Forgot password |
| `/auth/verify-mfa` | MFA verification |
| `/auth/onboarding` | Post-registration onboarding |

### APIs (shuttle — primary auth)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/auth/login/` | User login → returns OTP challenge |
| POST | `/auth/verify/otp/` | Verify OTP → returns JWT tokens |
| POST | `/auth/token/refresh/` | Refresh access token |
| POST | `/auth/resend/otp/` | Resend OTP code |
| POST | `/auth/logout/` | Logout (invalidate session) |
| POST | `/auth/reset-password/request/` | Request password reset |
| POST | `/auth/reset-password/confirm/` | Confirm password reset |

### APIs (saturn-backend — legacy, still used)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `auth/login/` | Legacy login |
| POST | `auth/signup/` | Legacy signup |
| POST | `auth/token/refresh/` | Legacy token refresh |
| GET | `get_user_info/` | User info + feature flags + meeting types |

### Flow
```
User → POST /auth/login/ (shuttle)
     → OTP sent to email/phone
     → POST /auth/verify/otp/ (shuttle)
     → JWT access + refresh tokens
     → GET get_user_info/ (saturn-backend)
     → User context loaded (role, firm, feature flags)
```

---

## 2. Meeting Record Flow (MRF)

**Owner:** mars (v2), saturn-backend (v1 legacy)
**Feature Flags:** `mrf_chat`, `mrf_new_types_enabled`, `download_meeting_transcript_disabled`, `download_meeting_audio_disabled`

### Routes
| Path | Page | Flags |
|------|------|-------|
| `/mrf/past-meetings` | Meeting notes list | None |
| `/mrf/:meetingId` | Meeting selection | None |
| `/mrf/:meetingId/details` | Full MRF detail (v2) | Internal flags |

**Sub-views:** fact-review, meeting-summary, speaker-identification, speaker-selection, accept-tasks

### APIs (mars — v2 flow)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/meeting` | Create meeting note |
| GET | `/meeting/past-meeting-notes` | List past meetings |
| GET | `/meeting/config` | Meeting configuration |
| GET | `/meeting/{id}/` | Get meeting details |
| PATCH | `/meeting/{id}/` | Update meeting |
| DELETE | `/meeting/{id}/` | Delete meeting |
| POST | `/meeting/{id}/transitions/` | Trigger workflow transition |
| POST | `/meeting/upload-url` | Get S3 presigned upload URL |
| POST | `/meeting/complete-upload` | Confirm upload complete |
| GET | `/meeting/{id}/transcript/` | Get meeting transcript |
| GET | `/meeting/{id}/doc/` | Get meeting document (YJS) |
| POST | `/meeting/{id}/doc/updates/` | Apply document updates |
| POST | `/meeting/{id}/doc/sync/` | Sync collaborative edits |
| GET | `/meeting/{id}/speaker-identification/` | Get speaker ID results |
| PATCH | `/meeting/{id}/speaker-identification/` | Update speaker assignments |
| GET | `/meeting/{id}/facts/` | Get extracted facts |
| POST | `/meeting/{id}/facts/` | Add/update facts |
| GET | `/meeting/{id}/tasks/` | Get generated tasks |
| GET | `/meeting/{id}/client-perspective` | Get client perspective text |
| GET | `/meeting/{id}/follow-up-email/` | Get follow-up email draft |
| PATCH | `/meeting/{id}/follow-up-email/` | Update follow-up email |
| GET | `/meeting/{id}/finalization` | Get finalization state |
| POST | `/meeting/finalization/submit` | Submit finalized meeting |
| POST | `/meeting/{id}/finalization/client-perspective` | Submit client perspective |
| GET | `/meeting/{id}/finalization/follow-up-email` | Get finalization email |
| GET | `/meeting/{id}/current-page` | Get user's current page |
| GET | `/meeting/{id}/chat/documents` | List chat documents |
| POST | `/meeting/{id}/chat/documents/upload-url` | Upload chat document |
| POST | `/meeting/{id}/chat/` | Send chat message |
| GET | `/meeting/{id}/chat/{chatId}` | Get chat response |

### Data Flow
```
User uploads recording (saturn-fe)
    → POST /meeting (mars) → S3 upload
    → POST /meeting/{id}/transitions/ (mars)
    → mars → SQS → jupiter (Celery worker)
    → jupiter: audio chunking → STT → speaker diarization
    → jupiter: fact extraction + analysis + risk profiling (with date context)
    → jupiter: client perspective (GPT-5.1) + follow-up email (Claude Sonnet 4.6)
    → jupiter → SQS → mars (status update)
    → User reviews via /meeting/{id}/* endpoints
```

---

## 3. Suitability Letters

**Owner:** mars (new guardian flow), saturn-backend (legacy)
**Feature Flag:** `is_suitability_letter_generation_enabled`

### Routes
| Path | Page | Flags |
|------|------|-------|
| `/suitability-letters` | Letters list | `is_suitability_letter_generation_enabled` |
| `/suitability-letters/:id` | Letter detail | None |
| `/suitability-letters/:id/analysis` | AI analysis | `is_guardian` (internal) |
| `/suitability-letters/:id/generate` | Generation step | `is_guardian` (internal) |

### APIs (mars — guardian letters)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/letters/` | List letters |
| POST | `/letters/` | Create letter |
| GET | `/letters/{id}` | Get letter details |
| PATCH | `/letters/{id}` | Update letter |
| DELETE | `/letters/{id}` | Delete letter |
| POST | `/letters/{id}/sources` | Add source documents/meeting notes |
| DELETE | `/letters/{id}/sources/documents/{docId}` | Remove document source |
| DELETE | `/letters/{id}/sources/meeting-notes/{noteId}` | Remove meeting note source |
| POST | `/letters/{id}/execute` | Trigger AI generation |
| GET | `/letters/{id}/client-details` | Get extracted client data |
| PATCH | `/letters/{id}/client-details` | Update client data |
| PATCH | `/letters/{id}/financials` | Update financial data |
| PATCH | `/letters/{id}/recommendations` | Update recommendations |
| GET | `/letters/home/` | Letters home/dashboard |
| GET | `/letters/onboarding/` | Letter onboarding config |
| POST | `/letters/onboarding/` | Create onboarding |
| POST | `/letters/onboarding/{id}/logo/upload-url` | Upload firm logo |

### APIs (ruler — letter form engine)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/letters/{letterId}` | Get letter form |
| GET | `/graphs/{snapshotId}` | Get form graph state |
| PUT | `/graphs/{snapshotId}/` | Update form graph |
| GET | `/graphs/{snapshotId}/result` | Get computed result |
| POST | `/graphs/` | Create new graph |

### Data Flow
```
User creates letter (saturn-fe)
    → POST /letters/ (mars) → status: INITIALIZED
    → POST /letters/{id}/sources (mars) → attach docs + notes
    → POST /letters/{id}/execute (mars) → SQS → jupiter

jupiter LangGraph pipeline:
    1. document_processing_node (OCR via Reducto)
    2. extraction_node (LLM structured extraction)
    3. human_verification_gate (INTERRUPT → user reviews)
    4. data_transformation_node (transform + meeting notes)
    5. letter_generation_node (Jinja2 template)
    6. json_conversion_node (HTML → JSON)
    7. evaluation_pass (GPT-4.1 rule enforcement) ← NEW

    → SQS → mars → status: COMPLETED
    → User reviews letter in saturn-fe
```

---

## 4. Coplanner Chat

**Owner:** chat service, jupiter (AI processing)
**Feature Flag:** `always_on_coplanner_enabled`

### APIs (chat — via shuttle proxy)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/coplanner/sessions/query/` | Send query (SSE streaming response) |
| GET | `/coplanner/sessions/{id}` | Get session details |
| PATCH | `/coplanner/sessions/{id}` | Update session |
| DELETE | `/coplanner/sessions/{id}` | Delete session |
| GET | `/coplanner/messages/{id}` | Get message |
| GET | `/coplanner/sessions/{id}/latest-response` | Get latest AI response |
| POST | `/coplanner/documents/upload/` | Upload document to chat |
| POST | `/coplanner/transcribe/` | Transcribe audio (SSE) |
| GET | `/coplanner/context/search/` | @mention context search |

### Data Flow
```
User sends message (saturn-fe)
    → POST /coplanner/sessions/query/ (chat via shuttle proxy)
    → shuttle: validate token + proxy (SSE, 240s timeout)
    → chat: store message → HTTP POST /internal/coplanner/query (jupiter)
    → jupiter: RAG retrieval + tool execution + response generation
    → jupiter → Redis Pub/Sub → chat
    → chat → SSE stream → saturn-fe (real-time response)

Audio transcription:
    → POST /coplanner/transcribe/ (chat)
    → chat → HTTP POST /internal/coplanner/ramble (jupiter)
    → SSE transcription results streamed back

@mention context search:
    → GET /coplanner/context/search/ (chat)
    → chat → S2S enrichment via shuttle
    → chat → Mars context search API (RBAC-protected)
    → Return matching clients/entities
```

---

## 5. Clients & Contacts

**Owner:** mars (primary), saturn-backend (legacy profiles)
**Feature Flag:** None

### Routes
| Path | Page |
|------|------|
| `/clients` | Client list |
| `/clients/:clientId` | Client profile |

### APIs (mars)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/clients` | List clients |
| GET | `/clients/home` | Client home view |
| GET | `/clients/{id}` | Get client profile |
| POST | `/clients` | Create client |
| PATCH | `/clients/{id}` | Update client |
| DELETE | `/clients/{id}` | Delete client |
| PUT | `/clients/{id}/advisors/{advisorId}` | Assign advisor |
| DELETE | `/clients/{id}/advisors/{advisorId}` | Unassign advisor |
| POST | `/clients/{id}/contacts` | Add contact |
| DELETE | `/clients/{id}/contacts/{contactId}` | Remove contact |
| GET | `/contacts` | List contacts |
| GET | `/contacts/{contactId}` | Get contact |
| PATCH | `/contacts/{contactId}` | Update contact |

### APIs (mars — client profile)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `api/v1/client-profile/account/{accountId}` | Full client profile |
| GET | `api/v1/client-profile/conflicts/{accountId}` | Profile conflicts |
| POST | `api/v1/client-profile/bulk-operations` | Bulk operations |
| GET | `client-profiles/meeting-overview?client_account_id={id}` | Meeting overview |

### APIs (saturn-backend — legacy, still active)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `account/{id}/` | Get account |
| PUT | `account/{id}/` | Update account |
| GET | `contact/` | List contacts |
| POST | `contact/` | Create contact |
| GET | `client-profiles/documents/` | Client documents |
| GET | `client-profiles/meeting-facts/` | Client meeting facts |

---

## 6. Investments

**Owner:** mars
**Feature Flag:** None (within client profile)

### APIs (mars)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/investment/accounts` | List investment accounts |
| POST | `/investment/accounts` | Create investment account |
| PATCH | `/investment/accounts/{id}` | Update account |
| DELETE | `/investment/accounts/{id}` | Delete account |
| POST | `/investment/holdings` | Create holding |
| PATCH | `/investment/holdings/{id}` | Update holding |
| DELETE | `/investment/holdings/{id}` | Delete holding |
| GET | `/investment/cash-movement-recommendations` | Get recommendations |
| POST | `/investment/cash-movement-recommendations` | Create recommendation |
| PATCH | `/investment/cash-movement-recommendations/{id}` | Update recommendation |
| DELETE | `/investment/cash-movement-recommendations/{id}` | Delete recommendation |

---

## 7. Analytics Dashboard

**Owner:** mars (API + Metabase JWT), saturn-fe (native charts)
**Feature Flag:** None (role-gated: DIRECTOR only)

### Routes
| Path | Page | Access |
|------|------|--------|
| `/analytics` | Analytics dashboard | DIRECTOR role only |

### APIs (mars)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/analytics/home` | Analytics tabs + Metabase JWT |
| GET | `/analytics/:tab` | Tab configuration with permissions |
| GET | `/analytics/:tab/:section_id` | Section data |

### Section Types
- **chart** — Area charts with reference lines
- **metric-comparison** — Side-by-side horizontal bar comparisons
- **breakdown** — Stacked bars with item lists
- **table** — Paginated data tables

---

## 8. Tasks

**Owner:** saturn-backend
**Feature Flag:** None

### Routes
| Path | Page |
|------|------|
| `/tasks` | Kanban board |
| `/tasks/:taskId` | Task detail |

### APIs (saturn-backend)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `task/` | List tasks |
| GET | `task/{id}/` | Get task |
| POST | `task/` | Create task |
| PUT | `task/{id}/` | Update task |
| DELETE | `task/{id}/` | Delete task |
| PUT | `task/{id}/reorder/` | Reorder task |

---

## 9. Guardian Suite

### 9a. Client Care

**Owner:** mars
**Feature Flag:** `care_center_enabled`

| Path | Page |
|------|------|
| `/guardian/client-care` | Client care dashboard |

### 9b. Observations

**Owner:** mars
**Feature Flag:** `observations_enabled` (DIRECTOR role only)

| Path | Page |
|------|------|
| `/guardian/observations` | Observations dashboard |
| `/guardian/observations/:meetingId` | Observation detail |

### APIs (mars)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/tnc/observations/statistics` | Observation stats |
| GET | `/tnc/observations/meetings` | Meetings with observations |
| GET | `/tnc/observations/meeting/{id}` | Meeting observations |
| PATCH | `/tnc/observations/meeting/{id}` | Update observations |
| PATCH | `/tnc/observations/meeting/{id}/{obsId}` | Update single observation |
| GET | `/tnc/settings` | Observation settings |
| POST | `/tnc/settings` | Create setting |
| PATCH | `/tnc/settings/{id}` | Update setting |
| DELETE | `/tnc/settings/{id}` | Delete setting |
| GET | `/tnc/observations/meeting/{id}/report` | Observation report |
| GET | `/meeting-notes/{id}/transcript` | Meeting transcript |

---

## 10. Training & Competency (TnC)

**Owner:** saturn-backend (management), jupiter (AI evaluation)
**Feature Flag:** None

### Routes
| Path | Page |
|------|------|
| `/training-and-competency/list` | TnC records list |
| `/training-and-competency/:tncReportId` | TnC report detail |

### APIs (saturn-backend)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `compliance/tnc/meeting/` | List TnC meetings |
| GET | `compliance/tnc/{id}/` | Get TnC report |
| PATCH | `compliance/tnc/{id}/` | Update TnC report |
| GET | `compliance/tnc/meeting/{id}/status/` | Get evaluation status |
| POST | `/meeting/{id}/generate_tnc/` | Trigger TnC evaluation |

---

## 11. LOA (Letter of Authority / Plan Extraction)

**Owner:** saturn-backend
**Feature Flag:** `loa_doc_extraction_enabled`

### Routes
| Path | Page |
|------|------|
| `/loa/cases` | Cases list |
| `/loa/cases/:caseId` | Case detail |
| `/loa/cases/:caseId/processing` | Processing state |
| `/loa/cases/:caseId/plans/:planId` | Plan detail |

### APIs (saturn-backend)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/loa/cases/` | List cases |
| POST | `/loa/case/create/` | Create case |
| GET | `/loa/case/{id}/` | Get case |
| PUT | `/loa/case/{id}/` | Update case |
| DELETE | `/loa/case/{id}/` | Delete case |
| POST | `/loa/case/{id}/add-more/` | Add documents to case |
| GET | `/loa/case/{id}/plan/{planId}/` | Get plan |
| PUT | `/loa/case/{id}/plan/{planId}/` | Update plan |
| GET | `/loa/case/{id}/plan/{planId}/followup/` | Get follow-up |

---

## 12. Fact Find

**Owner:** saturn-backend
**Feature Flag:** `fact_find`

### Routes
| Path | Page |
|------|------|
| `/fact-find` | Fact find questionnaire |

### APIs (saturn-backend)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/fact-find/{id}/get-facts/` | Get facts |
| POST | `/fact-find/{id}/save-facts/` | Save facts |
| GET | `/fact-find/{id}/review-with-core/` | Review with CRM core |
| PUT | `/fact-find/{id}/push-to-core/` | Push to CRM |

---

## 13. Inbox / Notifications

**Owner:** mars
**Feature Flag:** None

### APIs (mars)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/inbox` | Get notifications |
| PATCH | `/inbox/read` | Mark as read |
| PATCH | `inbox/archive/{id}?archived={bool}` | Archive/unarchive |

---

## 14. Settings

### 14a. User Management

**Owner:** shuttle
**Feature Flag:** None

| Path | Page |
|------|------|
| `/settings/profile/all-people` | All people directory |

#### APIs (shuttle)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/users/management` | List users |
| GET | `/users/management/stats` | User statistics |
| GET | `/users/management/{userId}` | Get user |
| PUT | `/users/management/{userId}` | Update user |
| DELETE | `/users/management/{userId}` | Deactivate user |
| GET | `/users/{userId}/delegations/employees` | Available delegations |
| POST | `/users/{userId}/delegations` | Create delegation |
| DELETE | `/users/{userId}/delegations` | Delete delegation |
| POST | `/invites` | Send invites |
| GET | `/invites` | List invites |
| PATCH | `/invites/{inviteId}` | Update invite |
| DELETE | `/invites/{inviteId}` | Revoke invite |
| GET | `/tenants/roles` | List available roles |

### 14b. Onboarding

**Owner:** shuttle

#### APIs (shuttle)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/onboarding/status` | Get onboarding status |
| GET | `/onboarding/pages/{pageId}` | Get onboarding page |
| PUT | `/onboarding/pages/{pageId}` | Submit onboarding page |
| GET | `/onboarding/steps/{stepName}` | Get onboarding step |

### 14c. Firm Settings

**Owner:** saturn-backend

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/firm/retrieve/{firm_id}/` | Get firm details |
| PUT | `/firm/update/{firm_id}/` | Update firm |

### 14d. Coplanner Bot Settings

**Owner:** saturn-backend

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/integrations/recall/coplanner/{eventId}` | Add bot to meeting |
| DELETE | `/integrations/recall/coplanner/{eventId}` | Remove bot |
| POST | `/integrations/recall/add-bot-to-url` | Add bot via URL |
| GET | `settings/employee/` | Get coplanner settings |
| PATCH | `settings/employee/` | Update coplanner settings |

### 14e. Mars Settings

**Owner:** mars

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/settings/home` | Get settings tab config |

---

## 15. CRM Integrations

### 15a. Intelliflo

**Owner:** saturn-backend
**Routes:** `/settings/integrations/sync/intelliflo`

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/integrations/intelliflo/matching/advisers/` | Get adviser matches |
| POST | `/integrations/intelliflo/matching/advisers/` | Submit matches |
| POST | `/integrations/intelliflo/matching/advisers/start-matching/` | Start matching |
| GET | `/integrations/intelliflo/matching/advisers/progress/` | Matching progress |
| GET | `/integrations/intelliflo/clients/` | Get clients |
| POST | `/integrations/intelliflo/clients/` | Import clients |
| GET | `/integrations/intelliflo/clients/progress/` | Import progress |
| GET | `/integrations/intelliflo/clients/conflicts/` | Data conflicts |
| POST | `/integrations/intelliflo/clients/conflicts/` | Resolve conflicts |
| GET | `/integrations/intelliflo/sync-status/` | Sync status |
| GET | `/integrations/intelliflo/sso/authorization-url/` | SSO login URL |
| POST | `/integrations/intelliflo/sso/callback/` | SSO callback |
| POST | `/integrations/intelliflo/disconnect_tenant` | Disconnect |

### 15b. Xplan

**Owner:** saturn-backend
**Routes:** `/settings/integrations/sync/xplan`

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/xplan/config/` | Get config |
| POST | `/xplan/config/` | Save config |
| GET | `/xplan/connect/` | Start OAuth |
| POST | `/xplan/callback/` | OAuth callback |
| POST | `/xplan/disconnect/` | Disconnect |

### 15c. Plannr

**Owner:** saturn-backend
**Routes:** `/settings/integrations/sync/plannr`

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/plannr/connect/` | Start OAuth |
| POST | `/plannr/callback/` | OAuth callback |
| GET | `/plannr/accounts/` | Get accounts |
| POST | `/plannr/accounts/` | Import accounts |
| GET | `/plannr/task-status/` | Task status |
| GET | `/plannr/config/` | Get config |
| POST | `/plannr/disconnect/` | Disconnect |

### 15d. Calendar Sync (Microsoft/Google)

**Owner:** saturn-backend

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `integrations/v2/calendar/oauth/microsoft/connect/` | Start Microsoft OAuth |
| POST | `integrations/v2/calendar/oauth/microsoft/disconnect/` | Disconnect |
| POST | `integrations/v2/calendar/oauth/microsoft/sync/` | Trigger sync |
| GET | `integrations/v2/calendar/oauth/google/connect/` | Start Google OAuth |
| POST | `integrations/v2/calendar/oauth/google/disconnect/` | Disconnect |
| POST | `integrations/v2/calendar/oauth/google/sync/` | Trigger sync |
| GET | `/integrations/v2/user-status/` | Integration status |

### 15e. CRM Data Sync (Mars)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `api/v1/crm/sync/push/` | Push data to CRM |

---

## 16. Labs Features

### 16a. Email Agent

**Owner:** saturn-backend
**Feature Flag:** `labs_enabled`

| Path | Page |
|------|------|
| `/email-agent` | Email agent dashboard |

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/email-agent/watch/status/` | Gmail watch status |
| POST | `/email-agent/watch/enable/` | Enable email monitoring |
| POST | `/email-agent/watch/disable/` | Disable monitoring |
| GET | `/email-agent/settings/me/` | Get settings |
| PUT | `/email-agent/settings/me/` | Update settings |
| GET | `/email-agent/profile/me/` | Get agent profile |
| PUT | `/email-agent/profile/me/` | Update agent profile |
| GET | `/email-agent/emails/` | List emails |
| GET | `/email-agent/emails/stats/` | Email statistics |
| GET | `/email-agent/drafts/` | List AI-generated drafts |
| POST | `/email-agent/drafts/{id}/approve/` | Approve draft |
| POST | `/email-agent/drafts/{id}/reject/` | Reject draft |
| POST | `/email-agent/drafts/{id}/mark_sent/` | Mark as sent |
| GET | `/email-agent/contacts/` | List contacts |

### 16b. Document Extraction

**Feature Flag:** `labs_enabled`

| Path | Page |
|------|------|
| `/labs/doc-extraction` | Doc extraction tool |
| `/labs/doc-extraction/generate` | Generate from extraction |

---

## 17. Dashboard / Home

**Owner:** saturn-backend
**Feature Flag:** None

| Path | Page |
|------|------|
| `/` | Home dashboard |
| `/upcoming-meetings/:view` | Upcoming meetings |

### APIs (saturn-backend)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/dashboard/meetings/past-meeting-notes` | Recent meetings |
| GET | `/dashboard/meetings/upcoming-meetings` | Upcoming meetings |
| GET | `/dashboard/tasks/priority` | Priority tasks |

---

## 18. Features / Waitlist

**Owner:** mars

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/features/{featureId}` | Get feature info |
| POST | `/features/{featureId}/waitlist` | Join waitlist |

---

## Feature Flag Reference

| Flag | Feature | Access Control |
|------|---------|---------------|
| `is_suitability_letter_generation_enabled` | Suitability Letters | Route + sidebar |
| `loa_doc_extraction_enabled` | LOA / Plan Extraction | Route + sidebar |
| `care_center_enabled` | Guardian Client Care | Route + sidebar |
| `observations_enabled` | Guardian Observations | Route + sidebar + DIRECTOR role |
| `fact_find` | Fact Find | Route + client profile tab |
| `fact_find_push` | Push facts to CRM | Button visibility |
| `mrf_chat` | MRF AI chat assistant | Panel in MRF detail |
| `mrf_new_types_enabled` | New meeting types | User info API |
| `always_on_coplanner_enabled` | Coplanner chat | Feature access |
| `change_log_enabled` | What's New page | Route + sidebar |
| `labs_enabled` | Labs section | Sidebar section |
| `dedup_client_enabled` | Duplicate management | Settings sidebar |
| `is_guardian` | Guardian analysis views | Internal routing |
| `download_meeting_transcript_disabled` | Hide transcript download | Inverted flag |
| `download_meeting_audio_disabled` | Hide audio download | Inverted flag |

---

## API Ownership Summary

| Backend | Features Owned |
|---------|---------------|
| **mars** | Clients, contacts, meetings v2, letters (guardian), investments, inbox, observations, analytics, features/waitlist, settings home, CRM sync push, context search |
| **saturn-backend** | Auth (legacy), user info, dashboard, tasks, TnC, LOA, fact-find, documents, firm settings, coplanner bot, all CRM integrations, email agent, employees |
| **shuttle** | Auth (primary), user management, invites, delegations, roles, onboarding, proxy gateway |
| **chat** | Coplanner sessions, messages, queries, transcription, context search |
| **jupiter** | AI processing (not called directly by FE — accessed via mars SQS or chat HTTP) |
| **ruler** | Letter form graph engine (via proxy) |
