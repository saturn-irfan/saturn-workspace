🔍 RCA: Medical Condition Hallucination in Meeting Notes

**Issue**: Gemini 2.5 Pro hallucinated "cerebral palsy" in the Flanagan meeting notes. The transcript only said "mentally and physically disabled."

**Root cause**: Gemini processed raw audio and inferred a specific diagnosis from context (disabled granddaughter + Vulnerable Person's Trust + means-tested benefits → statistically most likely condition). The thinking trace shows zero deliberation — "cerebral palsy" appears from the first token.

**Chain**: Gemini audio extraction (hallucinated) → fact consolidator GPT-4.1 (preserved it — "don't change any details") → final meeting note → chat assistant referenced it

**Fix**: Adding explicit medical guardrail to all meeting note prompts: "For health conditions and disabilities, use ONLY the exact words spoken. Never infer or name a specific condition."

**Langfuse**: session `7cb58ec3-dc68-4b70-bef8-3b0adedb1fea`, observation `e84538f4640f9552`

**Also**: Starting gradual migration to shared prompt snippets to prevent this class of issue — cross-cutting rules (style, terminology, medical) will be defined once and included everywhere.
