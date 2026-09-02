#!/usr/bin/env python3
"""
Transcribe Hindi / Hindi-English (Hinglish) audio using the Trelis/tara
Whisper model (https://huggingface.co/Trelis/tara).

Usage:
    python3 hinglish_transcribe.py <audio_file> [override_model_path]
    python3 hinglish_transcribe.py <audio_file> --mode hindi

If no override model path is given, uses ~/models/tara -- downloading it
from Hugging Face via git+SSH first (with your explicit confirmation and
a disk-space check) if it isn't there yet.
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

DEFAULT_MODEL_DIR = Path.home() / "models" / "tara"
HF_SSH_REMOTE = "git@hf.co:Trelis/tara"

# Tara is a ~2B-parameter Whisper-large-v3-architecture model in BF16
# safetensors (~2 bytes/param) -- the model card doesn't list an exact
# repo size, so this is an estimate for the disk-space check below, not
# a precise figure.
ESTIMATED_MODEL_SIZE_BYTES = int(4.0 * 1_000_000_000)

CHUNK_SECONDS = 30
SAMPLE_RATE = 16_000


def check_disk_space_or_abort(target_dir: Path, estimated_bytes: int) -> None:
    check_path = target_dir
    while not check_path.exists():
        check_path = check_path.parent
    _total, _used, free = shutil.disk_usage(check_path)
    pct = (estimated_bytes / free * 100) if free else float("inf")
    print(f"Model download needs an estimated {estimated_bytes / 1e9:.1f} GB (rough estimate, not exact).")
    print(f"Free space at {check_path}: {free / 1e9:.1f} GB -- this download would use ~{pct:.1f}% of it.")
    if pct > 90:
        print("WARNING: that would use over 90% of currently free disk space.")
    answer = input("Proceed with download? [y/N] ").strip().lower()
    if answer != "y":
        sys.exit("Aborted -- no model downloaded.")


def download_model(model_dir: Path) -> None:
    if shutil.which("git") is None:
        sys.exit("ERROR: git not found on PATH -- can't download the model.")
    if shutil.which("git-lfs") is None:
        print("WARNING: git-lfs not found on PATH -- large model files may not")
        print("download correctly. Install it first (e.g. `brew install git-lfs`")
        print("or `sudo apt install git-lfs`), then run `git lfs install` once.")
        answer = input("Continue anyway? [y/N] ").strip().lower()
        if answer != "y":
            sys.exit("Aborted.")

    model_dir.parent.mkdir(parents=True, exist_ok=True)
    print(f"Cloning {HF_SSH_REMOTE} into {model_dir} ...")
    subprocess.run(["git", "clone", HF_SSH_REMOTE, str(model_dir)], check=True)


def ensure_model(model_dir: Path, is_override: bool) -> None:
    if model_dir.exists() and any(model_dir.iterdir()):
        return

    if is_override:
        sys.exit(f"ERROR: override model path does not exist or is empty: {model_dir}")

    print(f"Default model not found at {model_dir}.")
    answer = input(f"Download {HF_SSH_REMOTE} from Hugging Face now? [y/N] ").strip().lower()
    if answer != "y":
        sys.exit("Aborted -- no model available.")

    check_disk_space_or_abort(model_dir, ESTIMATED_MODEL_SIZE_BYTES)
    download_model(model_dir)


def load_model(model_dir: Path):
    import torch
    from transformers import WhisperForConditionalGeneration, WhisperProcessor

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.bfloat16 if device == "cuda" else torch.float32

    processor = WhisperProcessor.from_pretrained(str(model_dir))
    model = WhisperForConditionalGeneration.from_pretrained(
        str(model_dir), torch_dtype=dtype
    ).to(device)
    return processor, model, device, dtype


def transcribe(
    audio_path: Path, processor, model, device, dtype, mode: str, max_minutes: float | None = None
) -> str:
    import librosa

    tk = processor.tokenizer
    hi = tk.convert_tokens_to_ids("<|hi|>")
    mc = tk.convert_tokens_to_ids("<|mixedcode|>")
    trn = tk.convert_tokens_to_ids("<|transcribe|>")
    nts = tk.convert_tokens_to_ids("<|notimestamps|>")

    if mode == "mixedcode":
        forced_decoder_ids = [(1, hi), (2, mc), (3, trn), (4, nts)]
    else:
        forced_decoder_ids = [(1, hi), (2, trn), (3, nts)]

    # duration=... (seconds) stops librosa decoding past that point, rather
    # than loading the whole file and truncating afterward -- matters for
    # long files when you only want e.g. the first 3 minutes.
    load_kwargs = {"sr": SAMPLE_RATE, "mono": True}
    if max_minutes is not None:
        load_kwargs["duration"] = max_minutes * 60
    audio, _ = librosa.load(str(audio_path), **load_kwargs)
    chunk_samples = CHUNK_SECONDS * SAMPLE_RATE

    pieces = []
    for start in range(0, len(audio), chunk_samples):
        chunk = audio[start : start + chunk_samples]
        if len(chunk) == 0:
            continue
        feats = processor(
            chunk, sampling_rate=SAMPLE_RATE, return_tensors="pt"
        ).input_features.to(device, dtype)
        out = model.generate(
            input_features=feats,
            forced_decoder_ids=forced_decoder_ids,
            max_new_tokens=444,
        )
        pieces.append(tk.decode(out[0], skip_special_tokens=True).strip())

    return " ".join(p for p in pieces if p)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("filename", help="Path to the audio file to transcribe.")
    parser.add_argument(
        "override_model",
        nargs="?",
        default=None,
        help="Path to a local model directory to use instead of the default (~/models/tara).",
    )
    parser.add_argument(
        "--mode",
        choices=["mixedcode", "hindi"],
        default="mixedcode",
        help="mixedcode = Hinglish output, English stays in Latin script (default). "
        "hindi = pure Hindi, Devanagari only.",
    )
    parser.add_argument(
        "--minutes",
        type=float,
        default=None,
        help="Only transcribe the first N minutes of the file (fractional allowed, e.g. 1.5). "
        "Default: transcribe the whole file.",
    )
    args = parser.parse_args()

    audio_path = Path(args.filename).expanduser()
    if not audio_path.exists():
        sys.exit(f"ERROR: audio file not found: {audio_path}")

    if args.override_model:
        model_dir = Path(args.override_model).expanduser()
        is_override = True
    else:
        model_dir = DEFAULT_MODEL_DIR
        is_override = False

    ensure_model(model_dir, is_override)

    processor, model, device, dtype = load_model(model_dir)
    transcript = transcribe(
        audio_path, processor, model, device, dtype, args.mode, max_minutes=args.minutes
    )
    print(transcript)


if __name__ == "__main__":
    main()
