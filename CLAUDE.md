# Instructions for Claude working in this repo

- **Keep `geekom/service_map.html` current.** It's a living diagram of
  the Docker services running on geekom and how each is reached
  (tailscale serve, Caddy, direct ports). Whenever a service is added,
  removed, or its exposure changes (new port, new proxy hop, etc.),
  update this diagram in the same batch of work — don't treat it as a
  one-time snapshot. **Keep this local-only — do not publish it (or any
  other diagram/doc from this repo) as a Claude Artifact.** View it by
  opening the file directly.

- **Interactive CLI tools under `tools/`** (e.g. `tools/hindi_translation/`)
  should follow the UX pattern established there: prompt interactively
  for missing options (input/output paths, mode flags) when run in a
  real terminal (`sys.stdin.isatty()`), but skip all prompting and just
  use flag defaults for scripted/piped/non-interactive runs — never block
  a non-interactive invocation waiting on `input()`.

- **Default output filenames for these tools should be descriptive, not
  generic.** Encode the pipeline stage(s) applied and the method/style
  used, plus a timestamp of that step, so a file's name alone tells you
  its provenance once several processing steps have been chained
  together (e.g. transcribe → transliterate → diarize). Pattern:
  `<original-stem>.<stage>-<method>.<YYYYMMDD-HHMMSS>.<ext>`, chaining
  additional `.<stage>-<method>` segments as more steps get applied —
  see `tools/hindi_translation/transliterate.py`'s
  `build_output_filename()` for a working example.
