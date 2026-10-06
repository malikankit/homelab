---
title: "Transcription model choice for English-dominant (occasionally-Hinglish) audio"
status: open
created: 2026-09-29
updated: 2026-09-29
tags: [hinglish-transcribe, transcription, planning-only]
---

## Context

The current `audio_to_markdown` pipeline (see
`../tools/hindi_translation/RUNBOOK.md`) was built and tested against
Hindi-dominant code-mixed audio, using `Trelis/tara` via
`hinglish_transcribe.py`. That script unconditionally forces the
`<|hi|>` language token (and `<|mc|>` in the default `mixedcode` mode)
in the decoder prompt, regardless of what's actually being said.

User has recordings that are the *inverse* mix — roughly 95% English,
5% Hinglish. Tara's forced Hindi-language decoding bias is a poor fit
for that: it risks mistranscribing or Hindi-influencing the transcription
of ordinary English speech, not just missing the occasional Hindi
phrase.

## Recommended direction (not yet tried)

Use a general-purpose multilingual Whisper model instead of Tara for
this audio — e.g. `openai/whisper-large-v3` or the faster
`whisper-large-v3-turbo` — with English as the primary forced/detected
language. Base Whisper already handles occasional code-switching
reasonably well without needing to be fine-tuned to *expect* it as the
dominant pattern.

Diarization, transliteration, and topic-outline steps (3-6 in the
RUNBOOK) would all still apply unchanged to this model's output — only
the transcription step's model/prompt-forcing would differ. Likely
shape: either a `--language en` style flag on `hinglish_transcribe.py`
that swaps the forced decoder tokens accordingly, or a separate small
script/model path specifically for this direction, if the two diverge
enough to not share code cleanly.

## Open questions

- Does forcing `<|en|>` fully solve it, or does the occasional Hinglish
  phrase need `<|mc|>`-equivalent handling too (base Whisper doesn't
  have that token — it's Tara-specific)?
- Is there a way to reuse `hinglish_transcribe.py`'s existing chunking/
  timestamp-loop logic against a different base model, or does this
  need its own script?
- Worth a quick one-chunk test on a real English-dominant recording
  before committing to a full script change.

## Not yet done

Nothing installed or tested. Comes up when the user has an actual
English-dominant recording to process — no urgency until then.
