# hinglish_transcribe.py — recent changes + script walkthrough

Written 2026-09-02, after debugging a live run against a real audio file.

## What changed just now (all in `hinglish_transcribe.py`)

Two unrelated environment/API problems surfaced when actually running this
against real audio, both from a gap between when this was written and what's
actually installed today.

### 1. `forced_decoder_ids` removed from `transformers.generate()`

Old code (from an earlier session, matching `transformers>=4.40` at the
time) forced the language/task/mixedcode tokens like this:

```python
forced_decoder_ids = [(1, hi), (2, mc), (3, trn), (4, nts)]
model.generate(input_features=feats, forced_decoder_ids=forced_decoder_ids, max_new_tokens=444)
```

But the venv (`hf-env/`) has `transformers==5.16.1` (a major-version jump),
which dropped `forced_decoder_ids` as a kwarg entirely — it errors with
`ValueError: forced_decoder_ids ... not used by the model`. The modern
equivalent is to bake those forced tokens directly into the **decoder's
starting prompt** instead of passing them as a side-channel:

```python
decoder_prompt_ids = [decoder_start_id, hi, mc, trn, nts]
decoder_input_ids = torch.tensor([decoder_prompt_ids], device=device)
model.generate(input_features=feats, decoder_input_ids=decoder_input_ids, max_new_tokens=448 - len(decoder_prompt_ids))
```

Whisper's decoder always starts with a `decoder_start_token_id` (pulled from
`model.config`), followed by whatever forced tokens you want — same 5
tokens, just handed to `generate()` as a literal prefix sequence rather than
a "force these positions" instruction.

### 2. `max_new_tokens` budget accounting changed

Under the old API, the forced tokens didn't count against `max_new_tokens`.
Under the new `decoder_input_ids` approach, they do — so `max_new_tokens=444`
+ a 5-token prompt = 449, which exceeds Whisper's hard cap of 448 total
decoder positions. Fixed by making it `448 - len(decoder_prompt_ids)`
instead of a fixed `444`.

### 3. (Earlier, not a code change) Missing model weights + missing ffmpeg

Unrelated to the script itself:

- `~/models/tara`'s `git clone` had an interrupted `git-lfs` download
  (Hugging Face's newer "Xet" storage backend doesn't play nicely with
  plain `git-lfs pull`) — re-downloaded `model.safetensors` directly via
  HTTPS and verified its SHA-256 against the LFS pointer's expected hash.
- `librosa` 1.0.0 dropped its old `ffmpeg`/`audioread` fallback, so it
  couldn't open `.m4a` files at all until `ffmpeg` was installed
  (`sudo apt-get install -y ffmpeg`). Also now pre-converting `.m4a` inputs
  to `.wav` via `ffmpeg` before running the script, to sidestep
  `soundfile`'s flaky native M4A support.

## Walkthrough of the script

**Constants (top of file)**: `DEFAULT_MODEL_DIR` (`~/models/tara`),
`DEFAULT_OUTPUT_DIR` (`~/transcripts`), the HF SSH remote for auto-download,
a rough 4GB model-size estimate for the disk check, `CHUNK_SECONDS=30`
(Tara's per-call audio limit) and `SAMPLE_RATE=16000` (what Whisper
expects).

**`check_disk_space_or_abort` / `download_model` / `ensure_model`** — the
model auto-download flow: if `~/models/tara` is empty/missing, prompt for
explicit confirmation, show what % of free disk the ~4GB estimate would
consume, warn if >90%, then `git clone` the HF repo (checking `git`/
`git-lfs` are on `PATH` first).

**`Profiler` class** — powers `--profile`. On `start()` it spins up a
daemon thread that, every 0.5s, samples this process's CPU%, RSS memory,
and GPU memory (via `nvidia-smi` if present, else
`torch.cuda.memory_allocated()` if on CUDA). `record_chunk()` is called
once per audio chunk to log its wall time. `report()` formats it all into
the human-readable block shown in the README example (audio processed,
wall time, rate in seconds/minute-of-audio, per-chunk average, CPU/RAM/GPU
stats).

**`load_model`** — picks `cuda`+`bfloat16` if a GPU is available, else
`cpu`+`float32` (geekom has no GPU, so this always runs on CPU today).
Loads the Whisper processor + model from the local model directory.

**`transcribe`** — the core loop, now fixed as above:

1. Looks up the special token IDs (`<|hi|>`, `<|mixedcode|>`,
   `<|transcribe|>`, `<|notimestamps|>`) from the tokenizer, builds the
   forced-prompt-prefix per `--mode`.
2. Loads audio via `librosa` at 16kHz mono; if `--minutes` is set,
   `duration=` stops decoding early rather than loading the whole file
   first.
3. Splits into 30-second chunks (Tara's per-call ceiling), runs
   `model.generate()` on each with that forced prefix, decodes each
   output, strips special tokens, and joins everything with spaces at the
   end.
4. Feeds the profiler timing info per chunk if `--profile` is on.

**`prompt_output_path` / `prompt_for_missing_args`** — the interactive-
prompt UX: if run in a real terminal (not piped/scripted) and a flag
wasn't given, ask for it one at a time (minutes limit, output file,
profiling on/off, profile-output file), defaulting transcript/profile
paths to `~/transcripts/<stem>.txt` / `.profile.txt`. When run
non-interactively (e.g. via a script, or Claude Code's Bash tool),
`sys.stdin.isatty()` is false, so `prompt_for_missing_args` short-circuits
immediately — nothing gets asked, flags/defaults are used as-is.

**`write_text`** — writes transcript/profile content to a file (creating
parent dirs), always alongside printing to stdout, never instead of it.

**`main`** — argparse wiring, validates the audio file exists, resolves
the model dir (override arg or default), calls `ensure_model` →
`load_model` → `transcribe`, then prints/writes the transcript and (if
enabled) the profile report.

## Scrolling in tmux (Mac laptop, no PgUp/PgDn keys)

- Outside tmux: **Fn+Up Arrow** = Page Up, **Fn+Down Arrow** = Page Down
  (no dedicated PgUp/PgDn keys on any Mac laptop keyboard).
- Inside tmux: that alone won't scroll the pane. Enter copy-mode first —
  **Ctrl+b then `[`** (tmux prefix is Ctrl+b) — then Fn+Up/Down (or arrow
  keys / `j`/`k`) to scroll, and `q` to exit copy-mode back to normal.

## First real run: results, timing, and two follow-up asks (2026-09-02/03)

Ran the fixed script against a real ~99-minute Hinglish conversation
(`kiran-ankit-31august2026.m4a` → converted to `.wav`). Full run took
2h18m wall time (8300s) on geekom's CPU (no GPU available) — 199 chunks
of 30s each, avg 776% CPU (~7.8 cores), peak RAM ~7.9GB. Rate: ~83.5s of
processing per minute of audio. Output written to
`~/transcripts/kiran-ankit-31august2026.txt` (101,781 bytes) and
`~/transcripts/kiran-ankit-31august2026.profile.txt`. Quality read as
coherent, natural Hinglish throughout (Devanagari for Hindi, Latin for
English words, matching the `mixedcode` mode default) — one stray `�`
character noticed near the very end, likely a chunk-boundary decode
artifact, nothing structural broken.

### Did Hinglish make it slower vs. plain English/Hindi?

Mostly no. The runtime is dominated by CPU-only autoregressive decoding
on a ~2B-parameter model (one token generated at a time, up to ~443
tokens per 30s chunk × 199 chunks) — a fixed cost of model size +
hardware, largely independent of language.

There's a smaller secondary effect: BPE tokenizers (this one included)
are usually trained mostly on Latin-script text, so Devanagari often
needs more subword tokens to represent the same spoken content than an
equivalent Romanized transliteration would. More tokens to generate =
more decode steps = somewhat more compute. So a hypothetical
all-Roman-script *output* would likely be a little faster, but not
dramatically — the CPU/model-size bottleneck would still dominate.

Real levers that would actually move the needle: running on a GPU
(likely 10-20x faster), or checking whether `max_new_tokens` (currently
`448 - len(decoder_prompt_ids)`, i.e. up to ~443) is overshooting actual
per-chunk content length — **parked for later per explicit request**,
not yet investigated or changed.

### Ask 1: Roman-script transliteration

Tara has no built-in "fully Romanized" mode — only `hindi` (pure
Devanagari) and `mixedcode` (Hindi in Devanagari, English stays Latin,
what was used). Getting the whole transcript into Roman script needs a
**separate post-processing pass on the text already generated** — pure
text-to-text, no audio involved, so it's fast (seconds) and independent
of the slow ASR step. Two approaches:

- **Rule-based schemes** (e.g. IAST/ITRANS via the
  `indic-transliteration` Python library) — deterministic, no model
  needed, but tends to produce formal/diacritic-heavy output (e.g.
  "kiraṇ" with a dot under the ṇ) rather than how people actually type
  Hinglish casually ("kiran").
- **ML transliteration model** (e.g. AI4Bharat's `IndicXlit`) — trained
  on how people actually romanize Hindi in casual text, gives more
  natural results ("kaise ho" not a diacritic-laden formal rendering).
  Slightly heavier (another small model download) but better quality
  for a "easier to read" goal.

Leaning toward IndicXlit given the stated goal is readability/naturalness,
not strict phonetic accuracy. Runs once on the final transcript text, so
cost is independent of which ASR run produced it.

### Ask 2: Speaker diarization + turn-based formatting

**This is entirely a post-processing step, not something Tara/Whisper
does.** Whisper-family models (Tara included, Whisper-large-v3
architecture) are pure speech-to-text with no concept of "speaker."
Diarization ("who spoke when") is a separate task, normally handled by a
dedicated model. Standard pipeline (how tools like Otter.ai work under
the hood): run ASR and diarization separately, then merge by timestamp.

1. **Diarization pass**: run a dedicated model (standard open option:
   `pyannote.audio`'s pretrained pipeline) over the raw audio →
   `(start_time, end_time, speaker_label)` segments. No transcript text
   involved, just who-when.
2. **ASR pass with timestamps kept**: the current script explicitly
   disables timestamps (`<|notimestamps|>` is one of the forced tokens).
   To merge with diarization, Tara needs to report *when* each piece of
   text was said. Would need to drop `<|notimestamps|>` so Whisper emits
   its native segment-level timestamp tokens, then convert those to
   absolute time using each chunk's offset (chunk N started at `N × 30s`).
3. **Merge**: for each transcribed segment, find which diarization
   interval it overlaps most with, tag it with that speaker.
4. **Format**: group consecutive same-speaker segments into paragraphs,
   e.g.:
   ```
   Speaker A [00:00]: Kiran didi, hi Ankit, long time no see...
   Speaker B [00:14]: Haan haan, aaj toh maine seven ka alarm...
   ```

**Caveats before building this:**
- `pyannote.audio`'s pretrained pipeline is gated on Hugging Face —
  needs accepting terms on the model page + an HF token, similar to the
  Tara download flow.
- Separate model + dependency (`pyannote.audio`), pulls in its own
  weights (likely another few-hundred-MB-to-GB download).
- Adds more CPU compute on top of the ~2h18m already spent, though
  diarization models are typically much lighter/faster than the ASR
  itself — probably minutes, not hours, for 99 minutes of audio.
- The current flat 30s chunking means a chunk could genuinely span a
  speaker change, so per-segment (not per-chunk) timestamps from step 2
  matter for accurate alignment, not just having diarization's own
  timeline.

**Status: not yet implemented.** Decision pending on scope/order —
whether to do transliteration first (quick, low-risk) and diarization as
a separate follow-up, or scope both together.
