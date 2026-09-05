#!/usr/bin/env bash
# audio_to_markdown.sh -- run the full pipeline on a new audio file:
# transcribe (timestamped) -> diarize -> transliterate (Roman script,
# casual) -> format as a clean speaker-labeled Markdown transcript.
#
# Usage:
#   audio_to_markdown.sh <audio_file> [--num-speakers N] [--mode mixedcode|hindi] [--style casual|formal] [-y|--yes]
#
# Defaults: 2 speakers, mixedcode mode, casual transliteration style.
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
#
# Not done here, deliberately (v1, see tools/hindi_translation/README.md
# / the homelab issues/ tracker for the follow-up): no idempotency --
# every run redoes every step from scratch, even if some outputs already
# exist. Fails fast on the first error rather than continuing with a
# broken input.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCRIPTS_ROOT="${TRANSCRIPTS_ROOT:-$HOME/transcripts/with_timestamps}"

NUM_SPEAKERS=2
MODE="mixedcode"
STYLE="casual"
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
  echo "Options:        num_speakers=$NUM_SPEAKERS mode=$MODE style=$STYLE"
  echo "Steps:"
  echo "  0. Convert to WAV (if needed)"
  echo "  1. Transcribe (timestamped)"
  echo "  2. Diarize (num_speakers=$NUM_SPEAKERS)"
  echo "  3. Transliterate (Roman script, style=$STYLE)"
  echo "  4. Format as Markdown"
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

  AUDIO_TO_MARKDOWN_CHILD=1 nohup "$0" "$AUDIO_FILE" \
    --num-speakers "$NUM_SPEAKERS" --mode "$MODE" --style "$STYLE" --yes \
    > "$LOG_FILE" 2>&1 &
  disown
  echo "Started -- PID $!"
  exit 0
fi

echo "=== audio_to_markdown: $STEM ==="
echo "Output folder: $OUT_DIR"
echo "Options: num_speakers=$NUM_SPEAKERS mode=$MODE style=$STYLE"
echo

cd "$SCRIPT_DIR"
source hf-env/bin/activate

# Step 0: convert to WAV if needed -- librosa/soundfile reliability
# issues with non-WAV formats, see RUNBOOK.md step 1.
EXT="${AUDIO_FILE##*.}"
EXT_LOWER="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"
if [[ "$EXT_LOWER" != "wav" ]]; then
  echo "--- Step 0/4: converting to WAV ---"
  WAV_FILE="$OUT_DIR/$STEM.wav"
  ffmpeg -y -i "$AUDIO_FILE" -ar 16000 -ac 1 "$WAV_FILE" -loglevel error
else
  WAV_FILE="$AUDIO_FILE"
fi

# Step 1: transcribe (timestamps are hinglish_transcribe.py's default)
echo "--- Step 1/4: transcribing ---"
TRANSCRIPT_TXT="$OUT_DIR/$STEM.transcribed-timestamped.txt"
PROFILE_TXT="$OUT_DIR/$STEM.transcribed-timestamped.profile.txt"
python3 hinglish_transcribe.py "$WAV_FILE" --mode "$MODE" \
  -o "$TRANSCRIPT_TXT" --profile --profile-output "$PROFILE_TXT"
SEGMENTS_JSON="${TRANSCRIPT_TXT%.txt}.segments.json"

# Step 2: diarize
echo "--- Step 2/4: diarizing (num_speakers=$NUM_SPEAKERS) ---"
DIARIZED_TXT="$OUT_DIR/$STEM.diarized-pyannote.txt"
python3 diarize.py "$WAV_FILE" "$SEGMENTS_JSON" \
  --num-speakers "$NUM_SPEAKERS" -o "$DIARIZED_TXT"

# Step 3: transliterate (rule-based + schwa-deletion/diacritic-folding
# cleanup, both bundled into --style casual)
echo "--- Step 3/4: transliterating (style=$STYLE) ---"
TRANSLIT_TXT="$OUT_DIR/$STEM.diarized-pyannote.transliterated-rule_$STYLE.txt"
python3 transliterate.py "$DIARIZED_TXT" --style "$STYLE" -o "$TRANSLIT_TXT"

# Step 4: final markdown formatting
echo "--- Step 4/4: formatting markdown ---"
FINAL_MD="$OUT_DIR/$STEM.md"
python3 format_markdown.py "$TRANSLIT_TXT" -o "$FINAL_MD"

echo
echo "=== Done ==="
echo "Final markdown: $FINAL_MD"
echo "All artifacts:  $OUT_DIR/"
