# hindi_translation

Transcribes Hindi / Hindi-English (Hinglish) audio to text using
[Trelis/tara](https://huggingface.co/Trelis/tara), a ~2B-parameter
Whisper-large-v3-architecture ASR model.

## Setup

```bash
cd tools/hindi_translation
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

```bash
python3 hinglish_transcribe.py <audio_file> [override_model_path]
python3 hinglish_transcribe.py <audio_file> --mode hindi
python3 hinglish_transcribe.py <audio_file> --minutes 3
python3 hinglish_transcribe.py <audio_file> --profile
python3 hinglish_transcribe.py <audio_file> --minutes 3 -o out.txt --profile --profile-output profile.txt
```

**Interactive prompts**: run it in a terminal with `--minutes`/`--output`/
`--profile`/`--profile-output` left unset, and it'll ask for each of
those one at a time. Any of them given as a flag is used as-is and not
re-asked. Piped/scripted runs (not a terminal) skip prompting entirely,
using flag defaults.

For the transcript and profile-report files specifically, the prompt
flow is: ask whether to write one at all → if yes, offer the default
path under `~/transcripts/` (`<audio-file-stem>.txt` /
`<audio-file-stem>.profile.txt`) → accept it, or type a full custom
path instead. `~/transcripts/` is created automatically if it doesn't
exist yet.

- `audio_file` — required. Any format `librosa`/`soundfile` can read
  (wav, mp3, flac, m4a, ...). Automatically resampled to 16 kHz mono
  and chunked into ≤30-second segments (Tara's per-call limit), with
  the transcript stitched back together.
- `override_model_path` — optional. A local directory containing a
  Tara-compatible model (processor + weights) to use instead of the
  default. Must already exist — the auto-download flow only applies to
  the default model.
- `--mode {mixedcode,hindi}` — default `mixedcode` (Hinglish: English
  words stay in Latin script, matching the script's name). `hindi`
  forces pure Devanagari output.
- `--minutes N` — optional, only transcribe the first N minutes of the
  file (fractional allowed, e.g. `--minutes 1.5`). Useful for a quick
  test on a long file — decoding stops at that point rather than
  loading/transcribing the whole thing first.
- `--profile` — optional, prints a timing + resource report after the
  transcript: seconds of processing per minute of audio, per-chunk
  timing, and CPU/RAM (this process) sampled every 0.5s during
  inference — plus GPU memory if `nvidia-smi` is on `PATH` or a CUDA
  device is active. Only covers the actual transcription loop, not
  model loading or audio decoding, so the rate reflects inference
  speed specifically — see the example output further below.
- `-o, --output FILE` — optional, write the transcript to `FILE`
  (still printed to stdout too — nothing is suppressed).
- `--profile-output FILE` — optional, write the `--profile` report to
  `FILE` (also still printed to stdout).

Example `--profile` output (illustrative numbers, not a real benchmark):

```
=== Profile ===
Audio processed: 180.0s (3.00 min)
Wall time:       42.1s
Rate:            14.0s of processing per minute of audio
Chunks:          6 (avg 7.0s/chunk, 30s audio each)
CPU (this process): avg 340%, peak 410%
RAM (this process): avg 4210 MB, peak 4550 MB
Device:          cpu (no GPU memory stats captured)
```

## Default model

If no override is given, the script looks for the model at
`~/models/tara` (this repo's convention — see the parent `~/models/`
directory for any other locally-downloaded models). If it's not there:

1. Asks for explicit confirmation before downloading anything.
2. Checks free disk space at that location and shows what percentage
   the download would consume (model size is an *estimate* — ~4 GB,
   since the model card doesn't list an exact repo size) — asks for
   confirmation again if this looks risky.
3. Clones the model via git+SSH: `git@hf.co:Trelis/tara` — this uses
   your existing SSH key already configured for Hugging Face access
   (see `~/.ssh/config`), same as any other git-over-SSH remote in this
   repo. Requires `git-lfs` to actually pull the large weight files
   (`git lfs install` once, if you haven't already) — the script warns
   if `git-lfs` isn't found on `PATH` but lets you continue anyway.

## Notes

- GPU (`cuda`) is used automatically if available (`torch.bfloat16`);
  falls back to CPU (`torch.float32`) otherwise — no flag needed.
- The two modes come from the model's own special tokens
  (`<|mixedcode|>` vs. plain `<|hi|>` + `<|transcribe|>`) — see the
  [model card](https://huggingface.co/Trelis/tara) for how these work
  under the hood.
