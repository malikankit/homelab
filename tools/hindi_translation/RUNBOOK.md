# Runbook: processing a new audio file

## Quick path (use this)

```bash
audio_to_markdown "/path/to/recording.m4a"          # defaults: 2 speakers, mixedcode, casual
python3 summarize_transcript.py "<stem>.md"         # topic outline with timestamps
```

`audio_to_markdown` is a chezmoi-managed alias (geekom only — see
`../../chezmoi/dot_zshrc.tmpl`) for `audio_to_markdown.sh`. It shows a
plan (duration, options, rough time estimate) and asks to confirm, then
detaches into the background — safe to close the terminal. Output lands
in `~/transcripts/with_timestamps/<audio-stem>/`, final transcript at
`<stem>.md`. Everything below explains what that wrapper does
internally, step by step, and *why* it's built this way — useful when
something breaks, or when deciding whether this pipeline is even the
right tool for a given recording (see the "When this pipeline is the
wrong choice" section at the end).

## 0. One-time setup (already done on geekom, here for reference)

```bash
cd tools/hindi_translation
source hf-env/bin/activate
```

The venv (`hf-env/`) already has everything installed: `transformers`,
`torch`, `librosa`, `soundfile`, `psutil`, `indic-transliteration`,
`pyannote.audio`. If it's missing something, `pip install -r requirements.txt`.

**Also needed once**: `ffmpeg` on `PATH` (`sudo apt-get install -y ffmpeg`
if missing — `librosa` needs it for non-WAV formats like `.m4a`), and
`hf auth login` for diarization's gated-model access (see step 3).
Separately, for the topic-outline step: `llama.cpp` built at
`~/code/llama.cpp/build/bin/` and the `Qwen2.5-7B-Instruct-Q4_K_M.gguf`
model (~4.4GB) in `~/models/llm-gguf/` — see step 6 for why this is a
completely separate stack from everything above.

## 1. Convert to WAV first if it isn't already

`.m4a` and other non-WAV formats have had reliability issues with
`librosa`'s native decoding (see
`../../ai-learning/learning-while-doing/debugging-a-breaking-ml-library-upgrade.md`).
Pre-converting sidesteps it entirely:

```bash
ffmpeg -y -i "input.m4a" -ar 16000 -ac 1 "input.wav"
```

**Why 16kHz mono**: that's what Whisper-architecture models (Tara
included) expect as input — anything else gets resampled internally
anyway, so doing it once up front avoids redundant resampling work.

## 2. Transcribe (with timestamps — the current default)

```bash
python3 hinglish_transcribe.py "input.wav" \
  -o ~/transcripts/with_timestamps/input.transcribed-timestamped.txt \
  --profile \
  --profile-output ~/transcripts/with_timestamps/input.transcribed-timestamped.profile.txt
```

**Why Tara specifically** (`Trelis/tara`, a Whisper-large-v3-architecture
model fine-tuned on Hindi/Hinglish): base Whisper handles Hindi and
English fine individually, but Tara was fine-tuned specifically for
*code-mixed* speech — the actual pattern in these recordings (Hindi and
English inside the same sentence, not just the same conversation). This
matters a lot for the "when is this pipeline wrong" question below.

**Why the model forces `<|hi|>` (and `<|mc|>` in mixedcode mode) rather
than auto-detecting language**: auto-detection on code-mixed audio was
unreliable during testing — Whisper's language detector picks one
language per chunk from a short audio prefix, which doesn't work well
when the chunk itself mixes languages. Forcing the language/mode tokens
that Tara was actually fine-tuned against gave much more consistent
output. The cost of this choice is exactly what the "English-heavy
audio" section below describes.

**Why timestamps come from the script's own loop, not the model's
native timestamp tokens**: tested directly — even with
`return_timestamps=True`, the model only ever emitted a single opening
`<|0.00|>` token per chunk and never a closing one. Not usable for
segment boundaries. Instead, `<|notimestamps|>` is forced and the
script tracks `chunk_offset_seconds` itself from its own fixed 30-second
chunking loop. This also writes a `.segments.json` automatically
alongside `-o` — chunk-level (30s) timestamps, needed for diarization in
step 4. **Don't skip `-o`** if you plan to diarize later.

**Why 30-second chunks specifically, and why that's a real constraint,
not just a default**: Whisper's architecture pads or truncates every
chunk to exactly 30 seconds internally regardless of the actual input
length — so making chunks smaller doesn't proportionally reduce compute
cost, it just produces more 30-second-cost chunks. This is the reason
diarization granularity is capped at 30s windows (see step 3) — a
known, accepted limitation, not something easily tuned away.

**Timing expectation**: CPU-only on geekom, roughly **84 seconds of
processing per minute of audio** (a ~99-minute file takes about
2h20m). No GPU on this machine. `--profile` gives you exact numbers
for whatever you actually ran.

**Other useful flags**: `--mode hindi` (pure Devanagari instead of the
default Hinglish `mixedcode`), `--minutes N` (only transcribe the
first N minutes — good for a quick test on a long file before
committing to the full run).

**Run it in the background** for anything over a few minutes of audio
— `audio_to_markdown` already does this for you; only relevant if
you're running this script standalone.

## 3. Diarize (optional — needs step 2's `.segments.json`)

Diarization requires the **timestamped** output specifically — plain
non-timestamped transcripts can't be diarized (no per-chunk timing to
align speaker turns against). See
`../../ai-learning/learning-while-doing/diarization-plus-asr-two-blind-models.md`
for why these are two completely independent models stitched together
by timestamp, not one feeding the other — pyannote never sees the
transcript text, Tara never sees speaker identity.

**One-time prerequisite**: accept the gated model terms on Hugging
Face for **both**:
- https://huggingface.co/pyannote/speaker-diarization-3.1
- https://huggingface.co/pyannote/speaker-diarization-community-1
  (a newer pyannote.audio version pulled this in as an internal
  dependency of the 3.1 pipeline — easy to miss, only surfaces as a
  `GatedRepoError` on first real run)

Then confirm you're logged in (`hf auth whoami`) — no separate access
token needed, the script uses the ambient CLI login automatically.

```bash
python3 diarize.py "input.wav" \
  ~/transcripts/with_timestamps/input.transcribed-timestamped.segments.json \
  --num-speakers 2 \
  -o ~/transcripts/with_timestamps/input.diarized-pyannote.txt
```

**Why `--num-speakers 2` as the default** (in both this script and the
wrapper): pyannote's own clustering step decides total speaker count
when not told — tested on a real ~99-minute two-person file, it
over-counted to 4 speakers. Since the actual recordings this pipeline
is built for are 1:1 conversations, hardcoding the known count sidesteps
that failure mode entirely rather than trying to tune clustering
thresholds. Override with a different number for group recordings.

**Why `exclusive_speaker_diarization` rather than the raw
`speaker_diarization`**: pyannote's own naming — the "exclusive" variant
is non-overlapping and explicitly meant for downstream ASR alignment,
which is exactly what this merge step does (raw output can have
overlapping speaker turns, which don't map cleanly onto a single ASR
chunk).

**Why a 20% secondary-speaker threshold for flagging**
(`SECONDARY_SPEAKER_FLAG_THRESHOLD` in `diarize.py`): a somewhat
arbitrary but reasonable line — below it, treat the majority speaker's
label as reliable; above it, the chunk likely contains a real
back-and-forth that a single speaker label can't represent well, worth
a manual check against the `.raw.json`. This flagging rate turned out
high (48-62.5%) on fast-paced conversational audio — a direct
consequence of the 30-second chunk-size constraint from step 2, not a
diarization bug. No architecture change has been made to address this;
logged as an open, deferred question rather than solved.

**Output format**: `[MM:SS–MM:SS] SPEAKER_XX: <chunk text>`, with a
`[multiple speakers in this window]` flag as described above.

**Timing expectation**: much lighter/faster than transcription —
diarization models are smaller than the ASR model. Still, run it in
the background for long files, same as step 2.

## 4. Transliterate (optional — Roman script instead of Devanagari)

Works on **any** transcript output (timestamped or not, diarized or
not — this step doesn't care about timing, it's pure text-to-text):

```bash
python3 transliterate.py "input.transcribed-timestamped.txt" \
  --style casual \
  -o ~/transcripts/with_timestamps/input.transliterated-rule_casual.txt
```

**Why rule-based (IAST transliteration + cleanup rules) rather than a
dedicated ML transliteration model**: the obvious ML choice,
AI4Bharat's IndicXlit, depends on the unmaintained `fairseq` package,
which has real installation problems on this machine (tmpfs quota
errors during install, among others) — full history in
`../../ai-learning/suspended-contexts/2026-09-03-hinglish-transliteration-diarization.md`.
`--method ml` is a documented stub in the script, not implemented.
Rule-based transliteration on top of standard IAST romanization proved
good enough for casual reading without that dependency.

**Why `--style casual` strips diacritics *and* deletes the word-final
schwa, in that specific order**: IAST is a scholarly Sanskrit-derived
romanization scheme that doesn't elide the inherent vowel ("a") that
Hindi speakers actually drop in casual speech ("hona" is said/written
casually as "hona", not the IAST-correct "honā" collapsed differently).
Schwa deletion has to run **before** diacritic-stripping specifically —
tried the reverse order first, and it broke real words ("tha" → "th",
"diya" → "diy") because an explicit long vowel (ā) and the plain
inherent schwa are still distinct Unicode characters before stripping,
but identical afterward. `--style formal` keeps the raw IAST diacritics
instead, if that ever matters for a different downstream use.

Fast — seconds, not minutes. No need to background it.

## 5. Format as Markdown

```bash
python3 format_markdown.py "input.diarized-pyannote.transliterated-rule_casual.txt" \
  -o "input.md"
```

Turns each `[MM:SS-MM:SS] SPEAKER_XX:` line into a `### **[...]**`
heading with blank lines around it — both a heading *and* bold on the
same line deliberately (redundant for visual hierarchy in a rendered
viewer, but the bold also makes the line stand out in a plain-text
viewer that doesn't render heading styles).

## 6. Topic outline (optional — separate model/stack entirely)

```bash
python3 summarize_transcript.py "input.md"
```

Produces a chronological Markdown bullet list, one bullet per topic,
citing the transcript's own timestamp ranges (not invented ones) — e.g.
`- **[02:00–03:30]** Summary: ...`.

**Why this is a completely separate stack** (`llama.cpp` + a GGUF model,
not `transformers`/`torch` like everything above): this machine is
CPU-only with 10GB RAM. Models already on hand
(`Qwen3.8-27B-FP8`, see `../../issues/reclaim-disk-space-duplicated-models.md`)
turned out to be FP8-quantized — a GPU-specific format with no
efficient CPU inference path, effectively unusable here. `llama.cpp` +
GGUF quantization is the actually-relevant CPU-inference stack for
general-purpose LLM tasks like this on this hardware.

**Why Qwen2.5-7B-Instruct specifically** (over Llama 3.2 3B or
Phi-3.5-mini, the other candidates considered): genuinely stronger on
multilingual/code-mixed text specifically, which matters here since the
input is Hinglish. Llama 3.2 3B is the fallback if 7B proves too slow;
Phi-3.5-mini is fast but weaker on Hindi specifically. Q4_K_M
quantization (~4.4GB) is llama.cpp's commonly-recommended
quality/size tradeoff point, not a specially-tuned choice.

**Why the whole transcript goes in as one prompt rather than chunking
it**: at ~78KB / ~20-25K tokens for a ~97-minute call, it fits inside
Qwen2.5's 32K context window with room to spare for the output — no
need for a map-reduce summarization approach at this transcript length.
That would become necessary for much longer recordings.

**Timing expectation**: CPU-only, dominated by prompt processing
(prefill) rather than generation — roughly ~21 minutes for a ~78KB
transcript in testing (prefill ~26 tok/s, generation only ~1.4 tok/s).
Slower than transcription+diarization combined for a file that size.

**A fixed bug worth knowing about**: `llama-cli`'s interactive-console
framing (ASCII-art banner, loading spinner, echoed input, occasional
`�` from UTF-8 split across streamed tokens) leaks into stdout even
in `-st` single-turn mode. `summarize_transcript.py`'s
`clean_llama_output()` strips everything outside the first/last
`- **[` bullet lines to work around it — if a future `llama.cpp` version
changes this framing, that filter may need adjusting.

## When this pipeline is the wrong choice

**Recordings that are mostly English with only occasional Hindi/Hinglish**
(e.g. ~95% English, ~5% Hinglish) are a poor fit for this pipeline as-is.
The reason is in step 2 above: `hinglish_transcribe.py` unconditionally
forces the `<|hi|>` (Hindi) language token — and in `mixedcode` mode,
also `<|mc|>` — regardless of what's actually being said. Tara was
fine-tuned for code-mixed *Hindi-dominant* speech; forcing that same
decoding bias onto audio that's overwhelmingly English risks
mistranscription or a Hindi-influenced rendering of ordinary English
speech, not just missing the occasional Hindi word.

**Better fit for English-dominant, occasionally-code-switched audio**:
a general-purpose multilingual Whisper model (e.g. `openai/whisper-large-v3`
or the faster `whisper-large-v3-turbo`) with English selected as the
primary language (or language auto-detection left on, since a short
prefix of mostly-English audio should detect correctly). Base Whisper
already handles occasional code-switching reasonably — it just isn't
fine-tuned to *expect* it as the dominant pattern the way Tara is.
Diarization, transliteration, and topic-outline steps 3-6 would all
still apply unchanged; only the transcription model/prompt-forcing in
step 2 would need to differ.

Not yet built — this pipeline was designed and tested specifically
against Hindi-dominant code-mixed audio. Logged as
`../../issues/english-dominant-audio-transcription-model.md` for when a
recording like this actually needs processing.

## File organization convention

`~/transcripts/` has two subfolders:
- `without_timestamps/` — outputs from before timestamps were added to
  `hinglish_transcribe.py` (2026-09-03 and earlier). Historical only;
  new runs shouldn't add anything here.
- `with_timestamps/` — everything going forward, one subfolder per
  recording stem (`audio_to_markdown`'s convention). Filenames follow
  `CLAUDE.md`'s convention: `<original-stem>.<stage>-<method>.<timestamp>.<ext>`,
  chaining stages as more processing gets applied
  (`transcribed-timestamped` → `diarized-pyannote` →
  `transliterated-rule_casual` → `topic_outline-qwen2.5_7b`, etc.).

## Known gotchas (see `../../issues/` for full context on each)

- **`pip install` hitting `Disk quota exceeded`**: not a real quota —
  `/tmp` is a small RAM-backed `tmpfs` on this machine. Redirect:
  `TMPDIR=<a real-disk scratch dir> pip install ...`. See
  `issues/reclaim-disk-space-duplicated-models.md` and the
  fairseq/tmpfs history in the ai-learning suspended-contexts note
  linked above.
- **Running two heavy scripts at once**: this machine only has 10GB RAM;
  transcription alone uses ~7.5GB, and the Qwen2.5-7B GGUF run uses
  ~8.2GB. Don't run any two of transcription/diarization/summarization
  concurrently, or either can fail/thrash — finish one before starting
  the next, especially for long files.
- **`ffmpeg` missing**: `librosa` needs it for non-WAV input; install
  once (`sudo apt-get install -y ffmpeg`), or just pre-convert to WAV
  yourself (step 1) to avoid the dependency entirely.
- **`cmake` missing** (only relevant if rebuilding `llama.cpp`): needs
  `sudo apt-get install -y cmake`, run in a real interactive terminal —
  `sudo` can't authenticate through a non-interactive session.
