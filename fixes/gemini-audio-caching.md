# Gemini Audio Caching — Meeting Note Generation

**Status:** Planned — not yet implemented
**Date:** 2026-02-22
**Goal:** Cache audio in Gemini once per meeting, reuse across all 4-5 parallel chains

---

## The Problem

The same GCS audio file is processed independently by each chain — same audio, same tokens, billed 4-5 times.

```
meeting_analysis_chain      ──┐
fact_extraction_chain       ──┤──► all receive same GCS URI
risk_profile_analysis_chain ──┤    all process full audio independently
vulnerability_assessment    ──┘
```

For a 65-min meeting (~97,500 audio tokens):
- **Current:** 5 × 97,500 = **487,500 audio tokens** billed
- **With cache:** 97,500 cache creation + 4 × 9,750 (10% rate) = **~136,500 tokens** billed
- **~72% cost reduction** on audio tokens

---

## Key Design Decision

Cache **audio only** — not the system prompt.

Each chain has a different system prompt (meeting analysis, fact extraction, risk profile, vulnerability). By caching only the audio, all chains can reuse the same cache with their own system prompt — cache invalidation is never triggered by prompt changes.

```python
# Cache = audio only
CachedContent.create(contents=[audio_part])

# Each chain call = cached audio + chain-specific system prompt
generate_content(cached_content=cache_name, system_instruction=CHAIN_SYSTEM_PROMPT)
```

---

## What Changes

```
prepare_files.py     ← create cache here after GCS upload (one place)
PreparedFiles        ← add cache_name field
MRFState             ← add gemini_cache_name field
Gemini client        ← add create_audio_cache() + agenerate_cached()
each chain           ← use agenerate_cached() when cache_name available
graph.py (cleanup)   ← delete cache after graph completes (optional, TTL handles it)
```

---

## Implementation Details

### 1. Gemini Client — Two New Methods

**`create_audio_cache(gcs_uri, ttl_hours=1) → str`**
```python
cached_content = client.caching.create(
    model=self.model_name,
    contents=[
        types.Content(
            role="user",
            parts=[types.Part.from_uri(file_uri=gcs_uri, mime_type=mime_type)]
        )
    ],
    ttl=datetime.timedelta(hours=ttl_hours),
)
return cached_content.name  # e.g. "cachedContents/abc123"
```

**`agenerate_cached(cache_name, system_prompt, user_prompt, ...) → dict`**
```python
config = types.GenerateContentConfig(
    cached_content=cache_name,         # audio already cached
    system_instruction=system_prompt,  # chain-specific, not cached
    ...
)
response = await client.aio.models.generate_content(
    model=self.model_name,
    contents=[types.Content(role="user", parts=[Part.from_text(user_prompt)])],
    config=config,
)
```

---

### 2. `prepare_files.py` — Create Cache After GCS Upload

```
Current:  s3_to_gcs_async(s3_url) → gcs_uri
New:      s3_to_gcs_async(s3_url) → gcs_uri
          gemini.create_audio_cache(gcs_uri) → cache_name
          PreparedFiles(gcs_uri=..., cache_name=...)
```

Cache is created **once** here. All chains reuse it.

---

### 3. `MRFState` — Add Cache Field

```python
gemini_cache_name: str   # set after prepare_files, passed to all chains
```

---

### 4. Each Chain — Prefer Cache, Fallback to Direct

```python
if cache_name:
    result = await gemini.agenerate_cached(
        cache_name=cache_name,
        system_prompt_text=SYSTEM_PROMPT,
        user_prompt_text=user_prompt,
    )
else:
    result = await gemini.agenerate(       # fallback if cache creation failed
        system_prompt_text=SYSTEM_PROMPT,
        user_prompt_text=user_prompt,
        gemini_file=gcs_uri,
    )
```

---

### 5. Cleanup

Option A — explicit delete at graph end:
```python
if state.get("gemini_cache_name"):
    gemini.delete_cache(state["gemini_cache_name"])
```

Option B — let TTL expire (1 hour). Simpler, fine for meeting note workloads.

---

## Constraints

| Constraint | Detail |
|---|---|
| Min tokens to cache | 32,768 — short meetings (<20 min) fall back to existing flow |
| Cache scope | Per model — all chains must use same Gemini model version |
| Chunked meetings | Each chunk needs its own cache; pass list of cache names via state |
| TTL | 1 hour — covers retries from quality check failures |
| Caching API | Vertex AI `client.caching.create()` — not LiteLLM (direct SDK) |

---

## Files to Change

| File | Change |
|---|---|
| `external/llm/gemini/client.py` | Add `create_audio_cache()` and `agenerate_cached()` |
| `internal/workflows/meeting/meeting_note/utils/prepare_files.py` | Create cache after GCS upload |
| `internal/workflows/meeting/meeting_note/states/states.py` | Add `gemini_cache_name` to `MRFState` |
| `internal/workflows/meeting/meeting_note/chains/meeting_analysis.py` | Use `agenerate_cached()` |
| `internal/workflows/meeting/meeting_note/chains/fact_extraction.py` | Use `agenerate_cached()` |
| `internal/workflows/meeting/meeting_note/chains/risk_profile_analysis.py` | Use `agenerate_cached()` |
| `internal/workflows/meeting/meeting_note/chains/vulnerability_assessment.py` | Use `agenerate_cached()` |
| `internal/workflows/meeting/meeting_note/chains/non_client_fact_extraction.py` | Use `agenerate_cached()` |
| `internal/workflows/meeting/meeting_note_v2/graph.py` | Optional cleanup node |

---

## What Doesn't Change

- GCS upload flow — cache is created on top of existing GCS URI, no new upload logic
- Each chain's system prompt — stays unique per chain, not cached
- Text fallback chains (`*_text`) — use LiteLLM, unaffected
- Diarization eval — separate flow, separate caching opportunity (documented separately)
