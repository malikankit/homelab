---
title: "Build a web service for the transcription/transliteration/diarization pipeline"
status: open
created: 2026-09-04
updated: 2026-09-04
tags: [hinglish-transcribe, web-service, tailscale, future, planning-only]
---

## Context

Right now, running a new audio file through the pipeline
(`hinglish_transcribe.py` → `diarize.py` → `transliterate.py`) means
manually SSHing/running each script from the CLI, tracking output
files by hand in `~/transcripts/with_timestamps/`, and reading raw
`.txt`/`.json` files to see results. See `tools/hindi_translation/RUNBOOK.md`
for the current manual process.

The natural next step, once the underlying pipeline is solid and
trusted, is a small self-hosted web app wrapping it — but this is
**explicitly not to be built yet**. Captured here so the shape of it is
written down and can be planned properly later, rather than designed
under time pressure once someone actually wants it.

## What it should do (rough shape, not a spec)

- **Upload an audio file** through a web UI, instead of `scp`-ing it
  to geekom and running scripts by hand.
- **Make choices before running**: which pipeline steps to run
  (transcribe only? + diarize? + transliterate, and which style?),
  num-speakers hint, mode (mixedcode/hindi), etc. — the same flags
  each script already exposes on the CLI, surfaced as UI controls
  instead.
- **Visualize the pipeline actually running** — not just a spinner.
  Given how long transcription takes (~84s of processing per minute of
  audio, CPU-only, so over 2 hours for a 99-minute file per the
  `RUNBOOK.md` numbers), real progress feedback matters a lot here —
  which chunk it's on, elapsed/estimated-remaining time, not just
  "processing...".
- **Download outputs** once done — the transcript, the diarized
  version, the transliterated version, the raw JSON files — instead of
  needing shell access to `~/transcripts/`.
- **An archive/history view** — scroll through past runs (what file,
  what options were chosen, when, how long it took) and reopen any of
  them, rather than only ever seeing the most recent run.
- **A nice inline "conversation" view for reading output** — not just
  a wall of text. Given `diarize.py`'s output format is already
  `[MM:SS–MM:SS] SPEAKER_XX: text`, this maps naturally to a chat-like
  UI (speaker-labeled bubbles/turns) rather than plain text dumped to
  a page.
- **Speaker notes** — let the person reading a diarized conversation
  annotate it (e.g. rename `SPEAKER_00` → an actual name once they
  recognize who it is, or leave a note on a specific turn). Ties into
  the already-noted "generic labels for now, real names later" choice
  in `diarize.py`'s design notes.

## Deployment shape (consistent with existing conventions in this repo)

- **Exposed over Tailscale only**, same pattern as Forgejo/Dockge/
  everything else in `services/` — `tailscale serve` fronting whatever
  the app's own web server is, no raw port on a real interface, no
  public exposure. See `HOMELAB.md` and `geekom/service_map.html` for
  the existing pattern to follow.
- Likely lives under `services/` (new `services/<name>/`) rather than
  under `tools/hindi_translation/`, matching how this repo separates
  "a script you run" (`tools/`) from "a running service" (`services/`)
  — though the actual pipeline scripts themselves would presumably
  still live in or be imported from `tools/hindi_translation/`.
- Needs its own state/storage convention for the "archive of past
  runs" — probably following the same "outside-repo state" pattern
  already used for Forgejo/CouchDB-if-it-ever-happens (state on disk,
  not committed to git, per `services/*/README.md`'s existing
  convention).

## Explicitly out of scope for now

- No design decisions locked in here — framework, exact UI, job queue
  vs. simple synchronous requests, auth (Tailscale identity alone vs.
  something more), none of it decided.
- Not started. This file exists so the requirements aren't lost between
  now and whenever there's bandwidth to actually plan it properly —
  treat it as a parking lot, not a spec to start implementing from.
