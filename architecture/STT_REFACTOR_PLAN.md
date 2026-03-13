# STT Services Refactor — Direct httpx Implementation

## Why

Current STT services wrap 3 different SDKs with `asyncio.to_thread`. Problems:
- Deepgram/ElevenLabs SDKs create new httpx clients per instance (no connection reuse)
- SDK retry logic (Deepgram/ElevenLabs) delays our round-robin fallback
- `asyncio.to_thread` blocks a thread from the pool for minutes (AssemblyAI polling)
- AssemblyAI SDK's `speech_model` field is deprecated — must switch to `speech_models` array
- ElevenLabs downloads files unnecessarily — API supports `cloud_storage_url` directly
- 3 SDKs = 3 mental models, 3 dependency upgrade risks

## Architecture

```
external/stt/
  speech_to_txt.py          # Dispatcher (minor changes)
  services/
    assembly_ai.py           # Direct httpx → AssemblyAI REST API
    deepgram.py              # Direct httpx → Deepgram REST API
    elevenlabs.py            # Direct httpx → ElevenLabs REST API
```

No base class. No shared abstractions. Each service is fully self-contained (~60-80 lines).

### Class Structure

Each service is a lightweight class holding config + a module-level singleton httpx client:

```python
_client: httpx.AsyncClient | None = None

def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            base_url=_BASE_URL,
            headers={"authorization": api_key},
            timeout=httpx.Timeout(30, connect=10),
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
        )
    return _client

class AssemblyAIService:
    def __init__(self, model: str): ...
    async def transcribe(self, file_url, keywords=None, expected_speakers=None) -> list[dict]: ...
    def _build_payload(self, file_url, keywords, expected_speakers) -> dict: ...
    async def _poll(self, transcript_id) -> dict: ...
    def _parse_words(self, data) -> list[dict]: ...
```

### Dispatcher Changes

```python
# speech_to_txt.py
_PROVIDERS = {
    "assemblyai": AssemblyAIService,
    "deepgram":   DeepgramService,
    "elevenlabs": ElevenLabsService,
}

def _create_service(provider_model: str) -> tuple[str, Callable]:
    provider, model = provider_model.split("/", 1)
    if provider not in _PROVIDERS:
        raise ValueError(f"Unknown STT provider: '{provider}'")
    return provider_model, _PROVIDERS[provider](model).transcribe
```

No other changes to `speech_to_txt.py`. Retry loop, metrics, `Transcript` model all stay the same.

---

## Service Implementations

### 1. AssemblyAI

**Base URL:** `https://api.assemblyai.com`
**Auth:** `Authorization: {api_key}` (raw key, no prefix)
**Flow:** Async (POST → poll GET every 3s until terminal status)

#### Request — POST /v2/transcript

```json
{
  "audio_url": "https://...",
  "speech_models": ["universal"],
  "punctuate": true,
  "format_text": true,
  "speaker_labels": true,
  "language_code": "en_uk",
  "filter_profanity": false,
  "speakers_expected": 2,
  "custom_spelling": [
    {"from": ["SIP"], "to": "SIPP"},
    {"from": ["SAAS", "SAS", "SASS"], "to": "SSAS"},
    {"from": ["isa"], "to": "ISA"},
    {"from": ["isas"], "to": "ISAs"}
  ],
  "keyterms_prompt": ["term1", "term2"],
  "word_boost": ["term1", "term2"],
  "boost_param": "high"
}
```

**Keyword handling:**
- If model is in `_MODEL_MAP` (slam-1, universal): use `keyterms_prompt`
- Otherwise: use `word_boost` + `boost_param: "high"`

**IMPORTANT:** `speech_model` (singular) is DEPRECATED. Use `speech_models` (array).

#### Polling — GET /v2/transcript/{id}

**Statuses:**
| Status | Action |
|--------|--------|
| `queued` | Continue polling |
| `processing` | Continue polling |
| `completed` | Extract words, return |
| `error` | Raise exception with `data["error"]` |

**Poll interval:** 3 seconds (fixed, no backoff needed — server does the work)

#### Response Word Schema

```json
{"text": "Hello", "start": 250, "end": 650, "confidence": 0.98, "speaker": "A"}
```

Timestamps are in **milliseconds**. Speaker labels are strings (A, B, C...).

**Parse to our schema:**
```python
{"word": w["text"], "start": w["start"], "end": w["end"], "speaker": w.get("speaker"), "speaker_name": None}
```

No timestamp conversion needed (already in ms).

#### Timeouts

| Scope | Value | How |
|-------|-------|-----|
| Per HTTP request | 30s | `httpx.Timeout(30, connect=10)` on client |
| Total transcription | 240s (fast models) / 600s (others) | `asyncio.wait_for()` wrapping `_poll()` |

**Fast models:** `slam-1`, `universal`

#### Error Handling

| HTTP Status | Meaning | Action |
|-------------|---------|--------|
| 200 | Success (check `status` field in body) | Parse response |
| 400 | Bad request | Raise (non-retryable) |
| 401 | Invalid API key | Raise (non-retryable) |
| 404 | Transcript not found | Raise |
| 429 | Rate limited | Raise → outer loop falls back to next service |
| 500/503/504 | Server error | Raise → outer loop retries |

#### Rate Limits

- 20,000 requests per 5-minute window
- Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`

#### Valid Model Values

| Value | Model |
|-------|-------|
| `"best"` | Universal-3-Pro (highest accuracy) |
| `"universal"` | Universal-2 (broad coverage, 99 languages) |
| `"slam-1"` | Slam-1 (customizable, beta) |

---

### 2. Deepgram

**Base URL:** `https://api.deepgram.com`
**Auth:** `Authorization: Token {api_key}`
**Flow:** Synchronous (single POST returns transcript)

#### Request — POST /v1/listen

**Options go as QUERY PARAMETERS, not body.**
**Body is JSON `{"url": "..."}` for URL transcription or raw bytes for file upload.**

```
POST /v1/listen?model=nova-2-finance&language=en-GB&diarize=true&punctuate=true
    &profanity_filter=false&smart_format=true&paragraphs=true&utterances=true
    &replace=SIP:SIPP&replace=SAAS:SSAS&replace=SAS:SSAS&replace=SASS:SSAS
    &replace=isa:ISA&replace=isas:ISAs
Content-Type: application/json
Authorization: Token {api_key}

{"url": "https://..."}
```

**Query params (httpx format — list of tuples for repeated params):**
```python
params = [
    ("model", self.model),
    ("language", "en-GB"),
    ("diarize", "true"),
    ("punctuate", "true"),
    ("profanity_filter", "false"),
    ("smart_format", "true"),
    ("paragraphs", "true"),
    ("utterances", "true"),
    ("replace", "SIP:SIPP"),
    ("replace", "SAAS:SSAS"),
    ("replace", "SAS:SSAS"),
    ("replace", "SASS:SSAS"),
    ("replace", "isa:ISA"),
    ("replace", "isas:ISAs"),
]
if keywords:
    params.extend(("keywords", kw) for kw in keywords)
if expected_speakers is not None:
    params.append(("diarize_speakers", str(expected_speakers)))
```

#### Response Word Schema

```json
{"word": "the", "start": 0.08, "end": 0.24, "confidence": 0.99, "speaker": 0, "punctuated_word": "The"}
```

Timestamps are in **seconds** (float). Speaker is **integer** (0, 1, 2...).

**Parse to our schema:**
```python
{"word": w["word"], "start": int(w["start"] * 1000), "end": int(w["end"] * 1000), "speaker": str(w["speaker"]), "speaker_name": None}
```

Convert seconds → ms, speaker int → string.

#### Timeouts

| Scope | Value | How |
|-------|-------|-----|
| Full request | 600s | `httpx.Timeout(600, connect=10)` per-request override |

Server-side max: 10 minutes (nova models), 20 minutes (whisper).

#### Error Handling

| HTTP Status | Meaning | Action |
|-------------|---------|--------|
| 200 | Success | Parse response |
| 400 | Bad request / bad audio | Raise |
| 401 | Invalid API key | Raise |
| 402 | Insufficient balance | Raise |
| 413 | File too large (>2GB) | Raise |
| 429 | Concurrent limit exceeded | Raise → outer loop falls back |
| 500/502/504 | Server error / timeout | Raise → outer loop retries |

Response includes `dg-request-id` header for debugging.

Error body format:
```json
{"err_code": "INVALID_AUTH", "err_msg": "Invalid credentials.", "request_id": "..."}
```

#### Rate Limits

Concurrency-based (not per-minute):
- Pay-as-you-go: 150 concurrent
- Growth: 225 concurrent
- No rate limit headers documented

#### Valid Model Values

| Model | Use Case |
|-------|----------|
| `nova-2` / `nova-2-general` | General purpose |
| `nova-2-finance` | Financial content |
| `nova-2-meeting` | Meetings |
| `nova-2-medical` | Medical |
| `nova-3` / `nova-3-general` | Latest (no keywords/replace support) |

---

### 3. ElevenLabs

**Base URL:** `https://api.elevenlabs.io`
**Auth:** `xi-api-key: {api_key}`
**Flow:** Synchronous (single POST returns transcript)

#### Request — POST /v1/speech-to-text

**Multipart form data. Booleans must be strings ("true"/"false").**

**KEY FINDING:** API supports `cloud_storage_url` — no need to download files first!

```python
data = {
    "model_id": self.model,
    "cloud_storage_url": file_url,       # Pass URL directly — no download needed!
    "language_code": "eng",
    "tag_audio_events": "true",
    "diarize": "true",
}
if expected_speakers is not None:
    data["num_speakers"] = str(expected_speakers)
if keywords:
    # ElevenLabs supports keyterms (max 100, each <50 chars, <=5 words)
    for kw in keywords:
        data.setdefault("keyterms", []).append(kw)
```

**For local files (no URL):**
```python
files = {"file": ("audio.mp3", file_bytes, "audio/mpeg")}
```

**Note:** `keyterms` is supported — up to 100 terms. Current code logs a warning and ignores keywords. We can now support them.

#### Response Word Schema

```json
{"text": "Hello", "start": 0.0, "end": 0.45, "type": "word", "speaker_id": "speaker_0", "logprob": -0.123}
```

Timestamps are in **seconds** (float). Speaker is string (`speaker_0`, `speaker_1`...).

**Word types:**
| Type | Meaning |
|------|---------|
| `word` | Spoken word |
| `spacing` | Whitespace between words (FILTER THESE OUT) |
| `audio_event` | Non-speech sounds like `(laughter)` |

**Parse to our schema:**
```python
[
    {"word": w["text"], "start": int(w["start"] * 1000), "end": int(w["end"] * 1000),
     "speaker": w.get("speaker_id"), "speaker_name": None}
    for w in data.get("words", [])
    if w.get("type") != "spacing"
]
```

Convert seconds → ms, filter spacing tokens.

#### Timeouts

| Scope | Value | How |
|-------|-------|-----|
| Full request | 600s | `httpx.Timeout(600, connect=10)` per-request override |

Server processes at 20-50x realtime. 1hr audio ≈ 1-3 minutes.
Max file: 3GB (upload), 2GB (URL). Max duration: 10 hours.

#### Error Handling

| HTTP Status | Meaning | Action |
|-------------|---------|--------|
| 200 | Success | Parse response |
| 400/422 | Validation error | Raise |
| 401 | Invalid API key | Raise |
| 402 | Insufficient credits | Raise |
| 429 | Rate/concurrency limit | Raise → outer loop falls back |
| 500/503 | Server error | Raise → outer loop retries |

Error body format:
```json
{"detail": {"type": "...", "code": "...", "message": "...", "status": "...", "request_id": "..."}}
```

429 subtypes: `rate_limit_exceeded`, `concurrent_limit_exceeded`

#### Rate Limits

Concurrency-based:
| Plan | STT Concurrency |
|------|----------------|
| Free | 8 |
| Starter | 12 |
| Pro | 40 |
| Scale | 60 |

No rate limit headers documented.

#### Valid Model Values

| Model | Status |
|-------|--------|
| `scribe_v1` | Legacy (still works) |
| `scribe_v2` | Current (90+ languages, entity detection, keyterms) |

---

## httpx Client Management

One long-lived `httpx.AsyncClient` per provider (module-level singleton):

```python
_client: httpx.AsyncClient | None = None

def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            base_url=BASE_URL,
            headers={...},
            timeout=httpx.Timeout(30, connect=10),
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
        )
    return _client
```

**Why singleton:** Jupiter handles ~2000 meetings/day. Per-request clients waste TLS handshakes.
**Why per-provider:** Each has different base URL, auth header format.
**Lifecycle:** Lives for process lifetime. No explicit cleanup needed.

### Connection Limits

| Setting | Value | Why |
|---------|-------|-----|
| `max_connections` | 20 | Natural backpressure per provider |
| `max_keepalive_connections` | 10 | Warm connections for next request |
| `connect` timeout | 10s | Fast fail on unreachable provider |
| `read` timeout | 30s (AssemblyAI polls), 600s override (Deepgram/ElevenLabs) | Match server-side limits |

---

## Error Handling Strategy

**Principle: fail fast, let outer loop handle.**

```
Service raises → speech_to_txt catches → tries next service in round-robin
```

No retry logic inside services. No try/catch around business logic. Only the HTTP call itself can throw.

### Error Categories

| Category | Status Codes | Retryable by outer loop? |
|----------|-------------|--------------------------|
| Client error (bad request) | 400, 413, 422 | No — same request will fail again |
| Auth error | 401, 403 | No — config issue |
| Rate limited | 429 | Yes — next service might work |
| Payment | 402 | No — account issue |
| Server error | 500, 502, 503, 504 | Yes — transient |

### Implementation

```python
async def transcribe(self, ...):
    client = _get_client()
    response = await client.post(...)
    response.raise_for_status()  # Raises httpx.HTTPStatusError for 4xx/5xx
    ...
```

`httpx.HTTPStatusError` propagates up to `speech_to_txt.py` which catches `Exception` and falls back.

---

## Observability

### Existing Metrics (keep as-is in speech_to_txt.py)
- `stt_metrics.track_request(service_name)`
- `stt_metrics.track_request_success(service_name)`
- `stt_metrics.track_request_failed(service_name, error_type)`
- `stt_metrics.track_latency(service_name, latency_ms)`

### New Logging (add inside services)
- Log poll count for AssemblyAI: `logger.info(f"AssemblyAI polling completed after {poll_count} polls")`
- Log HTTP status on error: `logger.error(f"AssemblyAI returned {response.status_code}: {response.text}")`
- Log `audio_duration` from AssemblyAI response for cost tracking
- Log `dg-request-id` from Deepgram response headers for debugging
- Log `transcription_id` from ElevenLabs response for debugging

### Langfuse Integration

Jupiter already uses Langfuse extensively via `@observe` decorator (see `gemini/client.py` for the pattern).
STT services currently have NO Langfuse tracing — adding it gives visibility into every transcription.

**Pattern:** `@observe(as_type="generation")` + `update_current_generation()` — treat STT as a generation.
Same pattern as `gemini/client.py`. Langfuse's built-in cost tracking, model comparison, and usage dashboards all work.

#### Dispatcher level — `speech_to_txt.py`

```python
from langfuse import observe

@observe(name="stt.transcribe")
async def speech_to_txt(file_url, keywords=None, ...):
    # Existing retry loop — each attempt shows as child span
    ...
```

This creates a parent trace for the entire transcription job, including retries/fallbacks.

#### Service level — each provider (as_type="generation")

Treat STT like an LLM generation. Map audio duration → input tokens, word count → output tokens.
Same pattern as `gemini/client.py` uses `@observe(as_type="generation")`.

```python
from langfuse import observe, get_client

class AssemblyAIService:
    @observe(name="stt.assemblyai", as_type="generation")
    async def transcribe(self, file_url, keywords=None, expected_speakers=None):
        langfuse = get_client()

        # Log input
        langfuse.update_current_generation(
            model=f"assemblyai/{self.model}",
            input={"file_url": file_url, "keywords": keywords},
            model_parameters={"expected_speakers": expected_speakers},
        )

        # ... transcription logic ...

        # Log output + usage
        langfuse.update_current_generation(
            output={"word_count": len(words)},
            usage_details={
                "input": int(data.get("audio_duration", 0)),  # audio seconds (like input tokens)
                "output": len(words),                           # words produced (like output tokens)
            },
            metadata={
                "model_used": data.get("speech_model_used"),
                "poll_count": poll_count,
            },
        )
        return words
```

```python
class DeepgramService:
    @observe(name="stt.deepgram", as_type="generation")
    async def transcribe(self, file_url, keywords=None, expected_speakers=None):
        langfuse = get_client()
        langfuse.update_current_generation(
            model=f"deepgram/{self.model}",
            input={"file_url": file_url, "keywords": keywords},
            model_parameters={"expected_speakers": expected_speakers},
        )

        # ... transcription logic ...

        langfuse.update_current_generation(
            output={"word_count": len(words)},
            usage_details={
                "input": int(data["metadata"]["duration"]),
                "output": len(words),
            },
            metadata={
                "dg_request_id": response.headers.get("dg-request-id"),
            },
        )
        return words
```

```python
class ElevenLabsService:
    @observe(name="stt.elevenlabs", as_type="generation")
    async def transcribe(self, file_url, keywords=None, expected_speakers=None):
        langfuse = get_client()
        langfuse.update_current_generation(
            model=f"elevenlabs/{self.model}",
            input={"file_url": file_url, "keywords": keywords},
            model_parameters={"expected_speakers": expected_speakers},
        )

        # ... transcription logic ...

        langfuse.update_current_generation(
            output={"word_count": len(words)},
            usage_details={
                "output": len(words),
                # ElevenLabs doesn't return audio duration
            },
            metadata={
                "transcription_id": data.get("transcription_id"),
                "language_code": data.get("language_code"),
                "language_probability": data.get("language_probability"),
            },
        )
        return words
```

#### LLM ↔ STT concept mapping

| LLM concept | STT equivalent |
|-------------|---------------|
| `model` | `assemblyai/universal`, `deepgram/nova-2-finance`, `elevenlabs/scribe_v1` |
| Input tokens | Audio duration (seconds) |
| Output tokens | Word count |
| Input content | `{file_url, keywords}` |
| Output content | `{word_count}` |
| Model parameters | `{expected_speakers}` |

#### Cost tracking in Langfuse

Configure custom pricing per model in Langfuse dashboard:
- `assemblyai/universal` = $0.15/hr → Langfuse auto-calculates from `input` (audio seconds)
- `assemblyai/best` = $0.21/hr
- `deepgram/nova-2-finance` = $0.0043/min

#### What shows up in Langfuse dashboard

```
stt.transcribe (parent trace)
  ├── stt.assemblyai [generation] (attempt 1 — failed, shows error)
  ├── stt.deepgram [generation] (attempt 2 — success)
  │     model: deepgram/nova-2-finance
  │     usage: {input: 3600, output: 45000}
  │     cost: $0.26 (auto-calculated)
```

- Every transcription as a **generation** with model, usage, cost
- Langfuse model comparison: compare accuracy/cost across providers
- Fallback chains visible (which provider was tried, which succeeded)
- Cost dashboards auto-populated from usage_details
- Filter by provider, model, date range in Langfuse UI

#### Usage data from API responses

| Provider | Audio duration field | Available? |
|----------|---------------------|-----------|
| AssemblyAI | `data["audio_duration"]` | Yes (seconds) |
| Deepgram | `data["metadata"]["duration"]` | Yes (seconds) |
| ElevenLabs | Not returned | No — configure in Langfuse via file metadata if needed |

---

## Breaking Changes to Address

| Current Code | Problem | Fix |
|-------------|---------|-----|
| `speech_model` field (AssemblyAI) | Deprecated | Use `speech_models` array |
| ElevenLabs `_download_file()` | Unnecessary — API supports URLs | Use `cloud_storage_url` form field |
| ElevenLabs keyword warning | Keywords were unsupported | Now supported via `keyterms` param |
| Deepgram `transcribe()` return | Returns tuple (bug) | Already fixed — returns words list |
| `base.py` Word model | Unused | Already removed constants, keep file only if `_download_file` needed |

---

## Files to Change

| File | Action |
|------|--------|
| `services/assembly_ai.py` | Rewrite — drop SDK, use httpx |
| `services/deepgram.py` | Rewrite — drop SDK, use httpx |
| `services/elevenlabs.py` | Rewrite — drop SDK, use httpx |
| `services/base.py` | Delete — no base class needed, `_download_file` no longer needed |
| `speech_to_txt.py` | Minor update — new `_create_service` with `_PROVIDERS` dict |

### Dependencies to Remove (from pyproject.toml)

| Package | Replaced By |
|---------|-------------|
| `assemblyai` | `httpx` (already a dependency) |
| `deepgram-sdk` | `httpx` |
| `elevenlabs` | `httpx` |

**Note:** Only remove if these SDKs aren't used elsewhere in Jupiter. Check before removing.

---

## Implementation Order

1. **AssemblyAI** — most complex (polling), validates our httpx pattern
2. **Deepgram** — simplest (single POST with query params)
3. **ElevenLabs** — medium (multipart form, `cloud_storage_url` change)
4. **speech_to_txt.py** — update `_create_service`
5. **Test** — run existing test suite + manual ramble test
6. **Cleanup** — delete `base.py`, check SDK usage elsewhere, remove unused deps
