#!/usr/bin/env bash
# audio_to_markdown.sh -- run the full pipeline on a new audio file:
# transcribe (timestamped) -> diarize -> transliterate (Roman script,
# casual) -> format as a clean speaker-labeled Markdown transcript.
#
# Usage:
#   audio_to_markdown.sh <audio_file> [--num-speakers N] [--mode mixedcode|hindi] [--style casual|formal] [-y|--yes]
#   audio_to_markdown.sh <audio_file> --english [--num-speakers N] [-y|--yes]
#
# Defaults: 2 speakers, mixedcode mode, casual transliteration style.
#
# --english switches to mostly_english_transcribe.py (base
# whisper-large-v3-turbo, forces <|en|> instead of Tara's <|hi|>/<|mc|>)
# for English-dominant audio with only occasional Hindi/Hinglish -- see
# ../../issues/english-dominant-audio-transcription-model.md for why
# Tara is a poor fit for that direction. Also skips the transliteration
# step entirely (nothing to romanize -- output is already English) and
# ignores --mode/--style, which are Hinglish-pipeline-specific.
#
# Shows the plan (steps, options, a rough time estimate from the audio's
# own duration) and asks for confirmation before doing anything, unless
# -y/--yes is given or stdin isn't a terminal (e.g. called from a script
# or the future web service -- matches the isatty-gated prompting
# convention already used in hinglish_transcribe.py/transliterate.py).
# Once confirmed, re-launches itself detached (nohup + disown) and
# exits immediately -- safe to close the terminal/SSH session, the
# pipeline keeps running. Check progress with:
#   tail -f ~/transcripts/with_timestamps/<audio-stem>/<audio-stem>.run.log
# or just re-run this same command later / check the web UI once built
# -- it only checks the filesystem for the final .md, no job tracking.
#
# All intermediate artifacts (raw transcript, segments.json, profile,
# diarized text + raw turns, transliterated text, final markdown) are
# kept together in one per-recording folder:
#   ~/transcripts/with_timestamps/<audio-stem>/
# <audio-stem> has spaces replaced with dashes, even if the original
# filename had them -- easier to `ls`/tab-complete, no quoting needed.
# A text-only copy (no .wav) of that folder is also placed at:
#   ~/code/files-from-mac/transcript-outputs/with_timestamps/<audio-stem>/
#
# Not done here, deliberately (v1, see tools/hindi_translation/README.md
# / the homelab issues/ tracker for the follow-up): no idempotency --
# every run redoes every step from scratch, even if some outputs already
# exist. Fails fast on the first error rather than continuing with a
# broken input.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCRIPTS_ROOT="${TRANSCRIPTS_ROOT:-$HOME/transcripts/with_timestamps}"
# Text-only copy of every run's outputs, kept alongside the original
# source audio on the Mac-synced side -- so the Mac has the readable
# artifacts without the multi-hundred-MB .wav duplicated everywhere.
COPY_ROOT="${COPY_ROOT:-$HOME/code/files-from-mac/transcript-outputs/with_timestamps}"

NUM_SPEAKERS=2
MODE="mixedcode"
STYLE="casual"
ENGLISH=0
ASSUME_YES=0
AUDIO_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --num-speakers)
      NUM_SPEAKERS="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --style)
      STYLE="$2"
      shift 2
      ;;
    --english)
      ENGLISH=1
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      if [[ -z "$AUDIO_FILE" ]]; then
        AUDIO_FILE="$1"
        shift
      else
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$AUDIO_FILE" ]]; then
  echo "Usage: audio_to_markdown <audio_file> [--num-speakers N] [--mode mixedcode|hindi] [--style casual|formal]" >&2
  exit 1
fi
if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "ERROR: audio file not found: $AUDIO_FILE" >&2
  exit 1
fi

AUDIO_FILE="$(readlink -f "$AUDIO_FILE")"
STEM="$(basename "$AUDIO_FILE")"
STEM="${STEM%.*}"
# Spaces in a stem make every downstream path need quoting and are a
# pain to `ls`/tab-complete through -- replace with dashes once, here,
# so every artifact this run produces (folder + every output filename,
# since they're all built from $STEM) is clean from the start.
STEM="${STEM// /-}"

OUT_DIR="$TRANSCRIPTS_ROOT/$STEM"
mkdir -p "$OUT_DIR"
LOG_FILE="$OUT_DIR/$STEM.run.log"

# Everything above this point is cheap (arg parsing, mkdir) -- safe to
# redo in both the parent (for display) and the detached child. Skip
# the confirm-and-detach dance entirely when we ARE the detached child
# (recognized by an env var the parent sets right before re-exec).
if [[ "${AUDIO_TO_MARKDOWN_CHILD:-0}" != "1" ]]; then
  DURATION_SECONDS="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO_FILE" 2>/dev/null || true)"
  if [[ -n "$DURATION_SECONDS" ]]; then
    DURATION_MIN_DISPLAY="$(awk "BEGIN{printf \"%.1f\", $DURATION_SECONDS/60}")"
    # Rough estimate only: ~2x the audio's own duration, based on the one
    # real benchmark so far (a 99-minute file: ~1.4x for transcription +
    # ~0.7x for diarization, transliteration/formatting negligible).
    # Actual time varies with audio content, CPU load, etc.
    EST_MINUTES="$(awk "BEGIN{printf \"%.0f\", $DURATION_SECONDS/60*2}")"
  else
    DURATION_MIN_DISPLAY="unknown"
    EST_MINUTES="unknown"
  fi

  echo "=== audio_to_markdown: plan ==="
  echo "Audio file:     $AUDIO_FILE"
  echo "Audio duration: ${DURATION_MIN_DISPLAY} min"
  echo "Output folder:  $OUT_DIR"
  echo "Steps:"
  if [[ "$ENGLISH" == "1" ]]; then
    echo "Options:        english mode, num_speakers=$NUM_SPEAKERS"
    echo "  0. Convert to WAV (if needed)"
    echo "  1. Transcribe (English, whisper-large-v3-turbo)"
    echo "  2. Diarize (num_speakers=$NUM_SPEAKERS)"
    echo "  3. Format as Markdown"
  else
    echo "Options:        num_speakers=$NUM_SPEAKERS mode=$MODE style=$STYLE"
    echo "  0. Convert to WAV (if needed)"
    echo "  1. Transcribe (timestamped)"
    echo "  2. Diarize (num_speakers=$NUM_SPEAKERS)"
    echo "  3. Transliterate (Roman script, style=$STYLE)"
    echo "  4. Format as Markdown"
  fi
  echo "Rough time estimate: ~${EST_MINUTES} min total (CPU-only, no GPU on this machine -- see RUNBOOK.md; this is a rough guess from one benchmark, not a guarantee)."
  echo

  if [[ "$ASSUME_YES" != "1" && -t 0 ]]; then
    read -r -p "Proceed? [y/N] " REPLY
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
      echo "Aborted -- nothing was run."
      exit 1
    fi
  fi

  echo "Starting in the background -- safe to close this terminal now."
  echo "Watch progress: tail -f \"$LOG_FILE\""
  echo "Or just check back later (re-run this command, or the web UI once built) -- it looks for the finished .md, no live tracking needed."

  ENGLISH_FLAG=()
  if [[ "$ENGLISH" == "1" ]]; then
    ENGLISH_FLAG=(--english)
  fi
  AUDIO_TO_MARKDOWN_CHILD=1 nohup "$0" "$AUDIO_FILE" \
    --num-speakers "$NUM_SPEAKERS" --mode "$MODE" --style "$STYLE" "${ENGLISH_FLAG[@]}" --yes \
    > "$LOG_FILE" 2>&1 &
  disown
  echo "Started -- PID $!"
  exit 0
fi

echo "=== audio_to_markdown: $STEM ==="
echo "Output folder: $OUT_DIR"
if [[ "$ENGLISH" == "1" ]]; then
  echo "Options: english mode, num_speakers=$NUM_SPEAKERS"
  TOTAL_STEPS=3
else
  echo "Options: num_speakers=$NUM_SPEAKERS mode=$MODE style=$STYLE"
  TOTAL_STEPS=4
fi
echo

cd "$SCRIPT_DIR"
source hf-env/bin/activate

# Step 0: convert to WAV if needed -- librosa/soundfile reliability
# issues with non-WAV formats, see RUNBOOK.md step 1.
EXT="${AUDIO_FILE##*.}"
EXT_LOWER="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"
if [[ "$EXT_LOWER" != "wav" ]]; then
  echo "--- Step 0/$TOTAL_STEPS: converting to WAV ---"
  WAV_FILE="$OUT_DIR/$STEM.wav"
  ffmpeg -y -i "$AUDIO_FILE" -ar 16000 -ac 1 "$WAV_FILE" -loglevel error
else
  WAV_FILE="$AUDIO_FILE"
fi

# Step 1: transcribe (timestamps are the default in both transcribe scripts)
echo "--- Step 1/$TOTAL_STEPS: transcribing ---"
TRANSCRIPT_TXT="$OUT_DIR/$STEM.transcribed-timestamped.txt"
PROFILE_TXT="$OUT_DIR/$STEM.transcribed-timestamped.profile.txt"
if [[ "$ENGLISH" == "1" ]]; then
  python3 mostly_english_transcribe.py "$WAV_FILE" \
    -o "$TRANSCRIPT_TXT" --profile --profile-output "$PROFILE_TXT"
else
  python3 hinglish_transcribe.py "$WAV_FILE" --mode "$MODE" \
    -o "$TRANSCRIPT_TXT" --profile --profile-output "$PROFILE_TXT"
fi
SEGMENTS_JSON="${TRANSCRIPT_TXT%.txt}.segments.json"

# Step 2: diarize
echo "--- Step 2/$TOTAL_STEPS: diarizing (num_speakers=$NUM_SPEAKERS) ---"
DIARIZED_TXT="$OUT_DIR/$STEM.diarized-pyannote.txt"
python3 diarize.py "$WAV_FILE" "$SEGMENTS_JSON" \
  --num-speakers "$NUM_SPEAKERS" -o "$DIARIZED_TXT"

if [[ "$ENGLISH" == "1" ]]; then
  # No transliteration step -- output is already English, nothing to
  # romanize (see the --english note at the top of this script).
  FORMAT_INPUT="$DIARIZED_TXT"
else
  # Step 3: transliterate (rule-based + schwa-deletion/diacritic-folding
  # cleanup, both bundled into --style casual)
  echo "--- Step 3/$TOTAL_STEPS: transliterating (style=$STYLE) ---"
  TRANSLIT_TXT="$OUT_DIR/$STEM.diarized-pyannote.transliterated-rule_$STYLE.txt"
  python3 transliterate.py "$DIARIZED_TXT" --style "$STYLE" -o "$TRANSLIT_TXT"
  FORMAT_INPUT="$TRANSLIT_TXT"
fi

# Final step: markdown formatting
echo "--- Step $TOTAL_STEPS/$TOTAL_STEPS: formatting markdown ---"
FINAL_MD="$OUT_DIR/$STEM.md"
python3 format_markdown.py "$FORMAT_INPUT" -o "$FINAL_MD"

echo
echo "--- Copying text outputs to $COPY_ROOT/$STEM/ ---"
COPY_DIR="$COPY_ROOT/$STEM"
mkdir -p "$COPY_DIR"
find "$OUT_DIR" -maxdepth 1 -type f \( -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.log" \) \
  -exec cp -p {} "$COPY_DIR/" \;

echo
echo "=== Done ==="
echo "Final markdown: $FINAL_MD"
echo "All artifacts:  $OUT_DIR/"
echo "Text copy:      $COPY_DIR/"
