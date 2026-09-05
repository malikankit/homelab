---
title: "Local LLM for Hinglish→English translation and summarization"
status: open
created: 2026-09-05
updated: 2026-09-05
tags: [hinglish-transcribe, translation, summarization, llm, planning-only]
---

## Context

Three related asks: (a) translate a Hinglish transcript to English,
optionally inline below each timestamped section; (b) summarize the
Hinglish transcript directly; (c) summarize the English translation.
Not urgent — logged for later, current focus is the `audio_to_markdown`
wrapper script.

## (a) Translation — two real options

**Try first, costs nothing**: Tara's tokenizer still has Whisper's
native `<|translate|>` task token (verified: id 50359, distinct from
the unknown-token id — confirmed present, not confirmed *good*). Same
model, same script, just swap `<|transcribe|>` for `<|translate|>` in
the forced decoder prompt. Real risk: Trelis's fine-tuning targeted
transcription specifically, not translation — could have degraded that
capability (a form of catastrophic forgetting). Untested either way,
worth a quick one-chunk test before trusting it for a full file.

**Fallback**: a small local instruction-tuned LLM prompted to
translate. Dedicated MT models (IndicTrans2, NLLB-200) expect *pure*
Hindi, not the actual Hinglish/code-mixed input here — likely to
perform poorly outside their training distribution. A general LLM
handles code-mixed/informal text more gracefully, and can also cover
(b) and (c) below from the same model via different prompts.

## (b) and (c) — summarization

Real finding along the way: the already-downloaded `Qwen3.8-27B-FP8`
models (see `issues/reclaim-disk-space-duplicated-models.md`) are
almost certainly **not usable on this machine at all** — FP8
quantization is GPU-specific with no efficient CPU path. Probably why
they've sat unused/duplicated rather than a deliberate unused choice.

**What's actually relevant to run here**: a small model in **GGUF
format via `llama.cpp`** — a different, CPU-optimized inference stack
from the `transformers`/`torch` path used so far for Tara/pyannote.
Candidates:
- **Qwen2.5 7B Instruct (GGUF, Q4_K_M)** — top pick, genuinely strong
  on multilingual/code-mixed text specifically.
- **Llama 3.2 3B Instruct (GGUF)** — smaller/faster fallback if 7B is
  too slow on this CPU.
- **Phi-3.5-mini (3.8B, GGUF)** — fast, weaker specifically on Hindi
  than Qwen.

## Recommended order, when this gets picked up

1. Test Tara's `<|translate|>` on a single chunk — cheap, might
   already solve (a).
2. If insufficient, install `llama.cpp` + Qwen2.5 7B GGUF — covers (a)
   as fallback, plus (b) and (c), from one model.

## Not yet done

Nothing installed, nothing tested. Parked behind the `audio_to_markdown`
wrapper script work.
