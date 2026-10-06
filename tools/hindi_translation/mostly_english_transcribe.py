#!/usr/bin/env python3
"""
Transcribe English-dominant audio (occasional code-switching into Hindi/
Hinglish is fine, but English is the dominant language) using base
openai/whisper-large-v3-turbo -- a general-purpose multilingual Whisper
model, not Tara (see hinglish_transcribe.py), which is fine-tuned
specifically for Hindi-dominant code-mixed speech and forces a Hindi-
biased decoding prompt unsuitable for mostly-English audio. See
../../issues/english-dominant-audio-transcription-model.md for why this
script exists as a separate path rather than a flag on
hinglish_transcribe.py.

Usage:
    python3 mostly_english_transcribe.py <audio_file>

Downloads openai/whisper-large-v3-turbo to ~/models/whisper-large-v3-turbo
(with your explicit confirmation and a disk-space check) on first use.
"""
import argparse
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

DEFAULT_MODEL_DIR = Path.home() / "models" / "whisper-large-v3-turbo"
DEFAULT_OUTPUT_DIR = Path.home() / "transcripts"
HF_REPO_ID = "openai/whisper-large-v3-turbo"

# whisper-large-v3-turbo's safetensors weights are ~1.6GB (fp16) -- smaller
# than Tara since it's a distilled-decoder variant of large-v3, not the
# full model.
ESTIMATED_MODEL_SIZE_BYTES = int(2.0 * 1_000_000_000)

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
    # Non-interactive (e.g. running detached under audio_to_markdown.sh):
    # never block on input() -- proceed automatically, matching the
    # isatty-gated prompting convention used throughout these tools.
    if not sys.stdin.isatty():
        return
    answer = input("Proceed with download? [y/N] ").strip().lower()
    if answer != "y":
        sys.exit("Aborted -- no model downloaded.")


def download_model(model_dir: Path) -> None:
    from huggingface_hub import snapshot_download

    model_dir.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {HF_REPO_ID} into {model_dir} ...")
    snapshot_download(
        repo_id=HF_REPO_ID,
        local_dir=str(model_dir),
        allow_patterns=["*.json", "*.safetensors", "*.txt", "merges.txt", "vocab.json", "normalizer.json"],
    )


def ensure_model(model_dir: Path) -> None:
    if model_dir.exists() and any(model_dir.iterdir()):
        return

    print(f"Model not found at {model_dir}.")
    if sys.stdin.isatty():
        answer = input(f"Download {HF_REPO_ID} from Hugging Face now? [y/N] ").strip().lower()
        if answer != "y":
            sys.exit("Aborted -- no model available.")
    else:
        # Non-interactive (e.g. running detached under audio_to_markdown.sh):
        # never block on input() -- proceed automatically.
        print(f"Non-interactive run -- downloading {HF_REPO_ID} automatically.")

    check_disk_space_or_abort(model_dir, ESTIMATED_MODEL_SIZE_BYTES)
    download_model(model_dir)


class Profiler:
    """Background CPU/RAM/GPU-memory sampler + per-chunk timing, for --profile.

    Started right before the transcription loop and stopped right after, so
    the reported rate reflects actual inference time -- not model loading or
    audio decoding.
    """

    SAMPLE_INTERVAL_SECONDS = 0.5

    def __init__(self, device: str):
        self.device = device
        self.audio_seconds = 0.0
        self.chunk_seconds: list[float] = []
        self.cpu_percent_samples: list[float] = []
        self.rss_mb_samples: list[float] = []
        self.gpu_mem_mb_samples: list[float] = []
        self._has_nvidia_smi = shutil.which("nvidia-smi") is not None
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._t0 = 0.0
        self.total_wall_seconds = 0.0

    def _sample_gpu_mem_mb(self):
        if self._has_nvidia_smi:
            try:
                out = subprocess.run(
                    ["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
                    capture_output=True,
                    text=True,
                    timeout=2,
                )
                return float(out.stdout.strip().splitlines()[0])
            except Exception:
                return None
        if self.device == "cuda":
            import torch

            return torch.cuda.memory_allocated() / 1e6
        return None

    def _sample_loop(self):
        import psutil

        proc = psutil.Process()
        proc.cpu_percent(interval=None)  # first call just primes the baseline
        while not self._stop_event.is_set():
            self.cpu_percent_samples.append(proc.cpu_percent(interval=None))
            self.rss_mb_samples.append(proc.memory_info().rss / 1e6)
            gpu_mb = self._sample_gpu_mem_mb()
            if gpu_mb is not None:
                self.gpu_mem_mb_samples.append(gpu_mb)
            self._stop_event.wait(self.SAMPLE_INTERVAL_SECONDS)

    def start(self):
        self._t0 = time.perf_counter()
        self._thread = threading.Thread(target=self._sample_loop, daemon=True)
        self._thread.start()

    def stop(self):
        self.total_wall_seconds = time.perf_counter() - self._t0
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout=2)

    def record_chunk(self, seconds: float):
        self.chunk_seconds.append(seconds)

    def report(self) -> str:
        minutes = self.audio_seconds / 60
        rate = self.total_wall_seconds / minutes if minutes else float("nan")
        lines = [
            "",
            "=== Profile ===",
            f"Audio processed: {self.audio_seconds:.1f}s ({minutes:.2f} min)",
            f"Wall time:       {self.total_wall_seconds:.1f}s",
            f"Rate:            {rate:.1f}s of processing per minute of audio",
        ]
        if self.chunk_seconds:
            avg_chunk = sum(self.chunk_seconds) / len(self.chunk_seconds)
            lines.append(
                f"Chunks:          {len(self.chunk_seconds)} "
                f"(avg {avg_chunk:.1f}s/chunk, {CHUNK_SECONDS}s audio each)"
            )
        if self.cpu_percent_samples:
            avg_cpu = sum(self.cpu_percent_samples) / len(self.cpu_percent_samples)
            lines.append(
                f"CPU (this process): avg {avg_cpu:.0f}%, peak {max(self.cpu_percent_samples):.0f}%"
            )
        if self.rss_mb_samples:
            avg_rss = sum(self.rss_mb_samples) / len(self.rss_mb_samples)
            lines.append(
                f"RAM (this process): avg {avg_rss:.0f} MB, peak {max(self.rss_mb_samples):.0f} MB"
            )
        if self.gpu_mem_mb_samples:
            avg_gpu = sum(self.gpu_mem_mb_samples) / len(self.gpu_mem_mb_samples)
            lines.append(
                f"GPU memory:      avg {avg_gpu:.0f} MB, peak {max(self.gpu_mem_mb_samples):.0f} MB"
            )
        else:
            lines.append(f"Device:          {self.device} (no GPU memory stats captured)")
        return "\n".join(lines)


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
    audio_path: Path,
    processor,
    model,
    device,
    dtype,
    max_minutes: float | None = None,
    profiler: "Profiler | None" = None,
) -> dict:
    import librosa
    import torch

    tk = processor.tokenizer
    en = tk.convert_tokens_to_ids("<|en|>")
    trn = tk.convert_tokens_to_ids("<|transcribe|>")
    nts = tk.convert_tokens_to_ids("<|notimestamps|>")

    # Same forced-decoder-prompt approach as hinglish_transcribe.py (see
    # that script's transcribe() docstring/comments for why
    # forced_decoder_ids was replaced with a decoder_input_ids prefix, and
    # why <|notimestamps|> is forced with chunk-level timestamps tracked
    # by this loop instead of relying on the model's own timestamp
    # tokens). Only the forced language token differs: <|en|> instead of
    # <|hi|>, and there's no Tara-specific <|mixedcode|> token to force --
    # base Whisper already handles occasional code-switching without
    # needing to be told to expect it.
    forced_ids = [en, trn, nts]
    decoder_start_id = model.config.decoder_start_token_id
    decoder_prompt_ids = [decoder_start_id] + forced_ids

    load_kwargs = {"sr": SAMPLE_RATE, "mono": True}
    if max_minutes is not None:
        load_kwargs["duration"] = max_minutes * 60
    audio, _ = librosa.load(str(audio_path), **load_kwargs)
    chunk_samples = CHUNK_SECONDS * SAMPLE_RATE

    if profiler is not None:
        profiler.audio_seconds = len(audio) / SAMPLE_RATE
        profiler.start()

    pieces = []
    segments = []
    for start in range(0, len(audio), chunk_samples):
        chunk = audio[start : start + chunk_samples]
        if len(chunk) == 0:
            continue
        chunk_offset_seconds = start / SAMPLE_RATE
        chunk_t0 = time.perf_counter()
        feats = processor(
            chunk, sampling_rate=SAMPLE_RATE, return_tensors="pt"
        ).input_features.to(device, dtype)
        decoder_input_ids = torch.tensor([decoder_prompt_ids], device=device)
        out = model.generate(
            input_features=feats,
            decoder_input_ids=decoder_input_ids,
            max_new_tokens=448 - len(decoder_prompt_ids),
        )
        if profiler is not None:
            profiler.record_chunk(time.perf_counter() - chunk_t0)

        text = tk.decode(out[0], skip_special_tokens=True).strip()
        pieces.append(text)
        if text:
            segments.append(
                {
                    "start": round(chunk_offset_seconds, 2),
                    "end": round(chunk_offset_seconds + len(chunk) / SAMPLE_RATE, 2),
                    "text": text,
                }
            )

    if profiler is not None:
        profiler.stop()

    return {"text": " ".join(p for p in pieces if p), "segments": segments}


def prompt_output_path(kind_label: str, default_path: Path) -> str | None:
    raw = input(f"Write {kind_label} to a file? [Y/n]: ").strip().lower()
    if raw == "n":
        return None

    raw = input(f"Save to {default_path}? [Y/n]: ").strip().lower()
    if raw == "n":
        return input("Enter full output path: ").strip()
    return str(default_path)


def prompt_for_missing_args(args: argparse.Namespace, audio_path: Path) -> None:
    if not sys.stdin.isatty():
        return

    if args.minutes is None:
        raw = input("Limit to first N minutes? (blank = whole file): ").strip()
        if raw:
            args.minutes = float(raw)

    if args.output is None:
        default_transcript = DEFAULT_OUTPUT_DIR / f"{audio_path.stem}.txt"
        args.output = prompt_output_path("the transcript", default_transcript)

    if not args.profile:
        raw = input("Enable profiling? [y/N]: ").strip().lower()
        args.profile = raw == "y"

    if args.profile and args.profile_output is None:
        default_profile = DEFAULT_OUTPUT_DIR / f"{audio_path.stem}.profile.txt"
        args.profile_output = prompt_output_path("the profile report", default_profile)


def write_text(path_str: str, content: str, label: str) -> None:
    path = Path(path_str).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"({label} also written to {path})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("filename", help="Path to the audio file to transcribe.")
    parser.add_argument(
        "--minutes",
        type=float,
        default=None,
        help="Only transcribe the first N minutes of the file (fractional allowed, e.g. 1.5). "
        "Default: transcribe the whole file.",
    )
    parser.add_argument(
        "--profile",
        action="store_true",
        help="Print a timing + CPU/RAM/GPU-memory profile after transcribing.",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Write the transcript to this file (still printed to stdout too).",
    )
    parser.add_argument(
        "--profile-output",
        default=None,
        help="Write the --profile report to this file (still printed to stdout too).",
    )
    args = parser.parse_args()

    audio_path = Path(args.filename).expanduser()
    if not audio_path.exists():
        sys.exit(f"ERROR: audio file not found: {audio_path}")

    prompt_for_missing_args(args, audio_path)

    model_dir = DEFAULT_MODEL_DIR
    ensure_model(model_dir)

    processor, model, device, dtype = load_model(model_dir)

    profiler = Profiler(device) if args.profile else None
    result = transcribe(
        audio_path,
        processor,
        model,
        device,
        dtype,
        max_minutes=args.minutes,
        profiler=profiler,
    )
    transcript = result["text"]
    print(transcript)
    if args.output:
        write_text(args.output, transcript, "Transcript")
        import json

        segments_path = Path(args.output).expanduser().with_suffix(".segments.json")
        segments_path.parent.mkdir(parents=True, exist_ok=True)
        segments_path.write_text(
            json.dumps(result["segments"], ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print(f"(Segment timestamps also written to {segments_path})")

    if profiler is not None:
        report = profiler.report()
        print(report)
        if args.profile_output:
            write_text(args.profile_output, report, "Profile")


if __name__ == "__main__":
    main()
