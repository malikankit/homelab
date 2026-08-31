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
```

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

Output is printed to stdout — redirect to a file if you want it saved:
`python3 hinglish_transcribe.py clip.wav > clip.txt`

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
