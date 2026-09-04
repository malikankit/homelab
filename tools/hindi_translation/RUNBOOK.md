# Runbook: processing a new audio file

Step-by-step for running a new Hindi/Hinglish audio file through the
full pipeline — transcribe → transliterate → diarize. Each step is a
separate script; none of this is wired into one command yet (that's
intentional for now — see `../../issues/build-web-service-for-transcription-pipeline.md`
for the eventual plan to make this a proper app).

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

## 1. Convert to WAV first if it isn't already

`.m4a` and other non-WAV formats have had reliability issues with
`librosa`'s native decoding (see
`../../ai-learning/learning-while-doing/debugging-a-breaking-ml-library-upgrade.md`).
Pre-converting sidesteps it entirely:

```bash
ffmpeg -y -i "input.m4a" -ar 16000 -ac 1 "input.wav"
```

## 2. Transcribe (with timestamps — the current default)

```bash
python3 hinglish_transcribe.py "input.wav" \
  -o ~/transcripts/with_timestamps/input.transcribed-timestamped.txt \
  --profile \
  --profile-output ~/transcripts/with_timestamps/input.transcribed-timestamped.profile.txt
```

This also writes a `.segments.json` automatically alongside `-o`
(same base name, that suffix) — chunk-level (30s) timestamps, needed
for diarization in step 4. **Don't skip `-o`** if you plan to diarize
later; without it, there's no `.segments.json` to feed `diarize.py`.

**Timing expectation**: CPU-only on geekom, roughly **84 seconds of
processing per minute of audio** (a ~99-minute file takes about
2h20m). No GPU on this machine. `--profile` gives you exact numbers
for whatever you actually ran.

**Other useful flags**: `--mode hindi` (pure Devanagari instead of the
default Hinglish `mixedcode`), `--minutes N` (only transcribe the
first N minutes — good for a quick test on a long file before
committing to the full run).

**Run it in the background** for anything over a few minutes of audio
— it's slow and you don't want to block on it:
```bash
nohup python3 hinglish_transcribe.py "input.wav" -o ... --profile --profile-output ... \
  > /tmp/transcribe_input.log 2>&1 &
```
(Or use whatever backgrounding convention you're already using in the
session — Claude Code's own background-task tooling if you're asking
Claude to run this.)

## 3. Diarize (optional — needs step 2's `.segments.json`)

Diarization requires the **timestamped** output specifically — plain
non-timestamped transcripts can't be diarized (no per-chunk timing to
align speaker turns against). See
`../../ai-learning/learning-while-doing/diarization-plus-asr-two-blind-models.md`
for why these are two completely independent models stitched together
by timestamp, not one feeding the other.

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
  -o ~/transcripts/with_timestamps/input.diarized-pyannote.txt
```

Also writes a `.raw.json` (pyannote's unmerged speaker turns) alongside
`-o`, for debugging or a future finer-grained merge pass.

**Output format**: `[MM:SS–MM:SS] SPEAKER_XX: <chunk text>`, with a
`[multiple speakers in this window]` flag on any chunk where a
secondary speaker covers >20% of that window — worth double-checking
those against the `.raw.json` rather than trusting the label blindly.

**Timing expectation**: much lighter/faster than transcription —
diarization models are smaller than the ASR model. Still, run it in
the background for long files, same as step 2.

## 4. Transliterate (optional — Roman script instead of Devanagari)

Works on **any** transcript output (timestamped or not — this step
doesn't care about timing, it's pure text-to-text):

```bash
python3 transliterate.py "input.transcribed-timestamped.txt" \
  --style casual \
  -o ~/transcripts/with_timestamps/input.transliterated-rule_casual.txt
```

`--style casual` (default) strips IAST's scholarly diacritics for a
natural reading ("kiran" not "kiraṇ"); `--style formal` keeps them.
Rule-based only for now (`--method ml` is a documented stub — see the
script's own module docstring for why the ML route, AI4Bharat's
IndicXlit, isn't implemented yet: it depends on the unmaintained
`fairseq` package, which has real installation problems on this
machine — full history in
`../../ai-learning/suspended-contexts/2026-09-03-hinglish-transliteration-diarization.md`).

Fast — seconds, not minutes. No need to background it.

## File organization convention

`~/transcripts/` has two subfolders:
- `without_timestamps/` — outputs from before timestamps were added to
  `hinglish_transcribe.py` (2026-09-03 and earlier). Historical only;
  new runs shouldn't add anything here.
- `with_timestamps/` — everything going forward. Filenames follow
  `CLAUDE.md`'s convention: `<original-stem>.<stage>-<method>.<timestamp>.<ext>`,
  chaining stages as more processing gets applied
  (`transcribed-timestamped` → `diarized-pyannote` →
  `transliterated-rule_casual`, etc.).

## Known gotchas (see `../../issues/` for full context on each)

- **`pip install` hitting `Disk quota exceeded`**: not a real quota —
  `/tmp` is a small RAM-backed `tmpfs` on this machine. Redirect:
  `TMPDIR=<a real-disk scratch dir> pip install ...`. See
  `issues/reclaim-disk-space-duplicated-models.md` and the
  fairseq/tmpfs history in the ai-learning suspended-contexts note
  linked above.
- **Running two heavy scripts at once**: this machine only has 10GB RAM;
  transcription alone uses ~7.5GB. Don't run transcription and
  diarization concurrently, or either can fail/thrash — finish one
  before starting the next, especially for long files.
- **`ffmpeg` missing**: `librosa` needs it for non-WAV input; install
  once (`sudo apt-get install -y ffmpeg`), or just pre-convert to WAV
  yourself (step 1) to avoid the dependency entirely.
