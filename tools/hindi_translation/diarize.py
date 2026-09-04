#!/usr/bin/env python3
"""
Diarize a transcript (label who spoke when) by combining pyannote.audio's
speaker-diarization output with an existing timestamped transcript from
hinglish_transcribe.py.

Usage:
    python3 diarize.py <audio_file> <segments_json>
    python3 diarize.py <audio_file> <segments_json> --num-speakers 2

Requires a *timestamped* transcript (a `.segments.json` file, as produced
by hinglish_transcribe.py's current default). The plain `.txt`-only
outputs from before timestamps were added can't be diarized this way --
without per-chunk timing there's no way to know which spoken text
corresponds to which point in the audio, so there's nothing to align a
speaker label to. See
ai-learning/suspended-contexts/2026-09-03-hinglish-transliteration-diarization.md
for the history of why timestamps were added in the first place.

===============================================================================
NOTES: design choices made here
===============================================================================

1. GRANULARITY: chunk-level, not word-level
   ------------------------------------------
   hinglish_transcribe.py's own timestamps are chunk-level (each ~30s ASR
   call), not per-word or per-sentence -- an earlier attempt to get
   sub-chunk timestamps directly from Whisper's own timestamp tokens
   didn't pan out (see hinglish_transcribe.py's transcribe() docstring
   for why: the model only ever emitted one opening timestamp token per
   chunk, never a matching close, likely because its timestamp logic
   expects Whisper's own internal long-audio chunking, which this
   project bypasses by pre-chunking manually). That caps what this
   script can do too: a diarization turn can only be aligned to whichever
   ASR chunk(s) it overlaps, not to a specific sentence or word within a
   chunk. Getting finer than this would need forced word-alignment (e.g.
   a wav2vec2 CTC aligner) layered on top -- a real option later, not
   attempted here.

2. SPEAKER ASSIGNMENT PER CHUNK: majority overlap, flagged when ambiguous
   ------------------------------------------------------------------------
   For each ASR chunk, pyannote's diarization turns that overlap the
   chunk's [start, end) window are collected, and the chunk is labeled
   with whichever speaker accounts for the most overlapping seconds --
   not just "whoever spoke first" in that window. Chunks where a
   secondary speaker covers a non-trivial share of the window
   (SECONDARY_SPEAKER_FLAG_THRESHOLD, default 20%) are flagged in the
   output rather than silently picked one way, since that's exactly the
   case most likely to be wrong (a chunk spanning a real turn-change).

3. SPEAKER COUNT: auto-detect by default, override available
   ------------------------------------------------------------
   pyannote/speaker-diarization-3.1 can estimate the number of speakers
   on its own, or be told an exact count via `num_speakers=`. Left as
   auto-detect by default (speaker count isn't always known in advance
   for a general-purpose run of this script), with `--num-speakers N` as
   an explicit override -- worth using when you already know it's e.g. a
   2-person call, since auto-detection can occasionally over/under-count.

4. AUTH: relies on the ambient `hf auth login` session, no token in code
   -------------------------------------------------------------------------
   pyannote.audio downloads its model via huggingface_hub, which
   automatically uses the locally cached CLI login token
   (~/.cache/huggingface/token) when no explicit token is passed in code
   -- verified working for this account (already accepted the model's
   gated terms, confirmed via a lightweight `model_info()` call) before
   writing this script. No token handling needed here at all.

5. LABELS: raw SPEAKER_00/SPEAKER_01 for now, not real names
   --------------------------------------------------------------
   pyannote's own generic labels are used as-is. Mapping them to actual
   names (once you know who's SPEAKER_00 vs SPEAKER_01 from a first read)
   is a natural, cheap follow-up -- not built into this first pass, to
   keep scope tight.

===============================================================================
UNTESTED as of writing (2026-09-04) -- not yet run against real audio.
The pyannote.audio API usage below (Annotation.crop() clipping semantics,
itertracks() shape) is based on its documented behavior, not verified
live. Given this project has twice now hit real API-shape surprises
(transformers' batch_decode return shape, Whisper's timestamp-token
behavior), treat this the same way: verify before trusting a real run.
===============================================================================
"""
import argparse
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

DEFAULT_OUTPUT_DIR = Path.home() / "transcripts"
PYANNOTE_MODEL = "pyannote/speaker-diarization-3.1"

# pyannote's own model card doesn't list an exact combined size for the
# segmentation + embedding models this pipeline downloads -- rough
# estimate for the disk-space check below, not a precise figure (this
# pipeline is much smaller than an ASR model like Tara; low hundreds of MB
# is the expected ballpark, not multiple GB).
ESTIMATED_MODEL_SIZE_BYTES = int(500 * 1_000_000)

SECONDARY_SPEAKER_FLAG_THRESHOLD = 0.20


def check_disk_space_or_abort(target_dir: Path, estimated_bytes: int) -> None:
    check_path = target_dir
    while not check_path.exists():
        check_path = check_path.parent
    _total, _used, free = shutil.disk_usage(check_path)
    pct = (estimated_bytes / free * 100) if free else float("inf")
    print(f"Diarization model download needs an estimated {estimated_bytes / 1e6:.0f} MB (rough estimate, not exact).")
    print(f"Free space at {check_path}: {free / 1e9:.1f} GB -- this download would use ~{pct:.2f}% of it.")
    if pct > 90:
        print("WARNING: that would use over 90% of currently free disk space.")
        answer = input("Proceed with download? [y/N] ").strip().lower()
        if answer != "y":
            sys.exit("Aborted -- no model downloaded.")


def run_diarization(audio_path: Path, num_speakers: int | None):
    from pyannote.audio import Pipeline
    import torch

    pipeline = Pipeline.from_pretrained(PYANNOTE_MODEL)
    if torch.cuda.is_available():
        pipeline.to(torch.device("cuda"))

    kwargs = {}
    if num_speakers is not None:
        kwargs["num_speakers"] = num_speakers
    return pipeline(str(audio_path), **kwargs)


def merge_with_segments(diarization, segments: list[dict]) -> list[dict]:
    """For each ASR chunk (start/end/text from hinglish_transcribe.py's
    segments.json), find the dominant diarized speaker within that window
    by summed overlap duration. See choice #2 in the module docstring.
    """
    from pyannote.core import Segment

    merged = []
    for seg in segments:
        window = Segment(seg["start"], seg["end"])
        # mode="intersection" (pyannote's default) clips each returned
        # track to the cropping window, so turn.duration after crop is
        # already the overlap duration -- no manual intersection needed.
        cropped = diarization.crop(window, mode="intersection")

        durations: dict[str, float] = {}
        for turn, _, speaker in cropped.itertracks(yield_label=True):
            durations[speaker] = durations.get(speaker, 0.0) + turn.duration

        if not durations:
            speaker = "UNKNOWN"
            flagged = False
        else:
            total = sum(durations.values())
            speaker = max(durations, key=durations.get)
            secondary_share = 1 - (durations[speaker] / total) if total else 0.0
            flagged = secondary_share > SECONDARY_SPEAKER_FLAG_THRESHOLD

        merged.append(
            {
                "start": seg["start"],
                "end": seg["end"],
                "speaker": speaker,
                "flagged_multi_speaker": flagged,
                "text": seg["text"],
            }
        )
    return merged


def raw_diarization_turns(diarization) -> list[dict]:
    """The unmerged diarization output -- every turn pyannote found,
    independent of ASR chunk boundaries. Written alongside the merged
    output for debugging or a future finer-grained merge pass.
    """
    return [
        {"start": round(turn.start, 2), "end": round(turn.end, 2), "speaker": speaker}
        for turn, _, speaker in diarization.itertracks(yield_label=True)
    ]


def format_seconds(s: float) -> str:
    m, sec = divmod(int(s), 60)
    return f"{m:02d}:{sec:02d}"


def format_merged_transcript(merged: list[dict]) -> str:
    lines = []
    for chunk in merged:
        flag = "  [multiple speakers in this window]" if chunk["flagged_multi_speaker"] else ""
        lines.append(
            f"[{format_seconds(chunk['start'])}–{format_seconds(chunk['end'])}] "
            f"{chunk['speaker']}:{flag}\n{chunk['text']}\n"
        )
    return "\n".join(lines)


def prompt_output_path(kind_label: str, default_path: Path) -> str | None:
    raw = input(f"Write {kind_label} to a file? [Y/n]: ").strip().lower()
    if raw == "n":
        return None
    raw = input(f"Save to {default_path}? [Y/n]: ").strip().lower()
    if raw == "n":
        return input("Enter full output path: ").strip()
    return str(default_path)


def build_output_stem(segments_path: Path) -> str:
    """Strip trailing .segments.json (or .json) to recover the shared
    stem, matching CLAUDE.md's descriptive-output-filename convention.
    """
    name = segments_path.name
    for suffix in (".segments.json", ".json"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return segments_path.stem


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("audio_file", help="Path to the original audio file (any format librosa/soundfile can read).")
    parser.add_argument("segments_json", help="Path to the .segments.json produced by hinglish_transcribe.py.")
    parser.add_argument(
        "--num-speakers",
        type=int,
        default=None,
        help="Exact speaker count, if known (e.g. 2 for a two-person call). Default: pyannote auto-detects.",
    )
    parser.add_argument("-o", "--output", default=None, help="Write the merged, speaker-labeled transcript to this file.")
    args = parser.parse_args()

    audio_path = Path(args.audio_file).expanduser()
    if not audio_path.exists():
        sys.exit(f"ERROR: audio file not found: {audio_path}")

    segments_path = Path(args.segments_json).expanduser()
    if not segments_path.exists():
        sys.exit(f"ERROR: segments file not found: {segments_path}")

    segments = json.loads(segments_path.read_text(encoding="utf-8"))
    if not segments:
        sys.exit(
            f"ERROR: {segments_path} has no segments -- this looks like it came from a "
            "non-timestamped run. Diarization needs per-chunk timing; re-run "
            "hinglish_transcribe.py (timestamps are the default now) and use its "
            ".segments.json output instead."
        )

    if sys.stdin.isatty() and args.output is None:
        default_name = f"{build_output_stem(segments_path)}.diarized-pyannote.{datetime.now().strftime('%Y%m%d-%H%M%S')}.md"
        args.output = prompt_output_path("the diarized transcript", DEFAULT_OUTPUT_DIR / default_name)

    check_disk_space_or_abort(Path.home() / ".cache" / "huggingface", ESTIMATED_MODEL_SIZE_BYTES)

    print(f"Running diarization on {audio_path} ...")
    diarization = run_diarization(audio_path, args.num_speakers)

    merged = merge_with_segments(diarization, segments)
    output_text = format_merged_transcript(merged)
    print(output_text)

    if args.output:
        out_path = Path(args.output).expanduser()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output_text, encoding="utf-8")
        print(f"(Diarized transcript also written to {out_path})")

        raw_path = out_path.with_suffix(".raw.json")
        raw_path.write_text(
            json.dumps(raw_diarization_turns(diarization), ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print(f"(Raw diarization turns also written to {raw_path})")


if __name__ == "__main__":
    main()
