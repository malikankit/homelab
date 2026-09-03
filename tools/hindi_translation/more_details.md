# hinglish_transcribe.py — transliteration, diarization, and data-handling notes

Written 2026-09-03, follow-up to `details.md`.

## Did Claude "see" the transcript content?

Yes, honestly. When `tail -c 3000` ran on the output file to confirm the
run finished, that snippet (including the actual Hindi/Hinglish text)
became part of the tool output fed back into context to generate the next
response — same as any other tool output in the conversation, then part
of it was quoted back in a reply. That content passed through Anthropic's
infrastructure as part of processing the conversation, the same way any
file read via `Read` or `cat`/`tail` via `Bash` does — there's no
private/local-only file access; anything read becomes part of what's sent
to the model.

On retention: Claude Code / API conversations are governed by Anthropic's
standard API data-handling policies (not used to train models by
default). No visibility into exact server-side retention windows beyond
that — worth checking Anthropic's actual data usage docs directly for a
definitive policy answer rather than relying on inference here.

## Gating reads of files outside the repo

A `PreToolUse` hook (fires *before* a tool call executes, can allow/ask/
deny) matched on the `Read` tool is the clean case: the hook receives
`tool_input.file_path`, checks whether the resolved path falls outside
`/home/am/code/homelab`, and returns an "ask" or "deny" decision if so.
That would have caught every read of `~/transcripts/`, `~/models/tara/`,
`~/code/files-from-mac/` this session — all outside this repo.

`Bash` is the harder case — the tool takes a free-form shell command, not
a structured path, so a hook can only heuristically grep the command
string for out-of-repo paths (`cat`, `tail`, a Python script's arguments,
etc.). Not airtight, but useful as a nudge/log, not a hard gate.

**Status: proposed, not yet built.** Decision pending on whether to build
the `Read`-tool version (reliable) now.

## Transliteration choice — confirmed

Pragmatic/natural, not pedantic. **`ai4bharat/IndicXlit`** (AI4Bharat's ML
transliteration model) — trained on how people actually type Hindi in
Roman script casually ("kaise ho", "kiran") rather than producing formal
diacritic-marked output ("kaise hō", "kiraṇ"). Not the rule-based
IAST/ITRANS scheme (`indic-transliteration` library), which is more
pedantic/formal.

## Would speaker-awareness be easier to build into the ASR model itself
while it "listens"?

Architectural answer, not incidental. Whisper (and Tara, same
architecture) works like this: raw audio → log-mel spectrogram → a
transformer **encoder** turns that into a sequence of audio-feature
vectors → a transformer **decoder** autoregressively predicts text
tokens, attending back into those audio features. It was trained purely
on `(audio, text)` pairs with a next-token-prediction loss — nothing in
that training signal ever told it "this stretch of audio is a different
voice than that stretch." Even though the encoder's internal
representations almost certainly *do* carry some acoustic signal
correlated with voice (pitch, timbre), nothing in the model's objective
preserves or exposes that as usable output — there's no speaker head, no
such labels in training data.

Diarization models (`pyannote.audio` and similar) are a completely
different training paradigm: speaker-embedding networks (e.g.
ECAPA-TDNN/x-vector style) trained via speaker-verification objectives on
datasets explicitly labeled with speaker identity, producing an embedding
per short audio window, then clustering those embeddings to assign
speaker labels. Purpose-built for exactly this, the way Whisper is
purpose-built for transcription — different objective, different
architecture family.

Worth knowing: this is an active research area — there are emerging
**joint** ASR+diarization models (e.g. "speaker-attributed ASR," NVIDIA's
Sortformer/Canary line, "serialized output training" approaches) that try
to do both in one pass. Tara isn't one of those. The most popular
*practical* off-the-shelf combo today is **WhisperX** — an existing
open-source wrapper chaining Whisper-style ASR + forced word-alignment +
`pyannote` diarization into one pipeline. Leaning toward keeping the
existing Tara-based ASR (specifically tuned for Hinglish, already
quality-verified) and bolting `pyannote` diarization on separately,
rather than swapping to WhisperX's generic multilingual Whisper.

## Glossary

- **Transcription** — audio → text, same language, same script (what
  Tara does).
- **Translation** — converting *meaning* from one language to another
  (not what's wanted here — Hindi should stay Hindi, just in a different
  script).
- **Transliteration** — converting *script*, not meaning or language
  (Devanagari हिंदी → Roman "hindi") — Ask 1.
- **Diarization** — labeling *who* spoke *when* in an audio stream,
  independent of what was said — Ask 2.
- **(Forced) alignment** — mapping transcript text to precise timestamps
  in the audio (the missing piece that lets diarization and transcription
  be merged — relevant to the timestamp fix in Ask 2's step 2).
- **ASR** — Automatic Speech Recognition, the umbrella term for
  "transcription via a model" (what Tara/Whisper are).

## Models to download for the final version

1. **Transliteration**: [`ai4bharat/IndicXlit`](https://huggingface.co/ai4bharat)
   (Hindi→Roman, natural/pragmatic rendering) — small model, no gating.
2. **Diarization**: [`pyannote/speaker-diarization-3.1`](https://huggingface.co/pyannote/speaker-diarization-3.1)
   — gated on Hugging Face, needs accepting terms on the model page once
   + an HF token (same auth pattern as Tara's own download).

Both are separate from Tara and from each other — Tara stays exactly
as-is for the actual transcription; these two run as post-processing/
parallel passes and get merged with the existing script's output.

**Status: not yet implemented.** Order: transliteration first (quick,
low-risk), diarization as a second step once that's confirmed working.
