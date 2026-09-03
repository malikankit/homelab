#!/usr/bin/env python3
"""
Transliterate a Devanagari/Hinglish transcript (e.g. output from
hinglish_transcribe.py) into Roman script.

Usage:
    python3 transliterate.py <transcript_file>
    python3 transliterate.py <transcript_file> --style formal
    python3 transliterate.py <transcript_file> --method ml   # not yet implemented

===============================================================================
NOTES: two ways to do this, and why they give different-looking results
===============================================================================

There are two fundamentally different approaches to Devanagari -> Roman
transliteration, and they trade off in opposite directions:

1. RULE-BASED (what this script actually implements)
   -----------------------------------------------
   A deterministic character/syllable mapping table (no model, no
   inference) -- every Devanagari letter and diacritic maps to a fixed
   Roman sequence. This script uses the `indic-transliteration` Python
   library's IAST scheme (International Alphabet of Sanskrit
   Transliteration), which is the standard *scholarly* transliteration
   used in academic/Sanskrit contexts.

   IAST is precise but *formal* -- it:
     - Keeps every consonant's inherent "a" vowel even where spoken
       Hindi drops it (schwa deletion isn't a thing IAST does -- it's a
       Sanskrit-derived scheme, and Sanskrit doesn't elide the schwa the
       way spoken Hindi does). E.g. आप ("you") comes out "āpa", not the
       natural "aap".
     - Uses diacritical marks for long vowels/nasalization/retroflexes
       (ā, ī, ū, ṃ, ṇ, ś, etc.) that nobody actually types when casually
       writing Hinglish.

   This script's "casual" style (the default -- see --style below) works
   around the diacritics half of that problem cheaply: run IAST, then
   *strip the combining diacritical marks* via Unicode NFKD
   decomposition. "āpa" -> "apa", "haiṃ" -> "haim". This gets rid of the
   marks nobody types, but does NOT fix the schwa-deletion or
   anusvara-as-"n"-not-"m" issues -- so output reads *close* to natural
   casual Hinglish spelling but not identical to it (expect "apa" where
   a person would write "aap", "mem" where a person would write "mein").
   Trade-off: zero setup risk, no heavy dependencies, effectively
   instant (pure text processing, no model inference) -- but capped
   accuracy against what people actually type.

2. ML-BASED (not implemented here yet -- see --method ml)
   -------------------------------------------------------
   A trained transliteration model (the identified candidate is
   AI4Bharat's IndicXlit) that's learned from real examples of how
   people actually romanize Hindi casually -- handles schwa deletion,
   natural nasalization spelling, etc. properly, because it was trained
   on real casual-Hinglish text rather than a fixed scholarly mapping
   table.

   Trade-off: better accuracy against natural spelling, but real setup
   risk in this environment -- the standard package
   (`ai4bharat-transliteration`) depends on `fairseq` (Meta's seq2seq
   toolkit, unmaintained since ~2022), which has already failed to
   install twice in this project (see
   ai-learning/suspended-contexts/2026-09-03-hinglish-transliteration-diarization.md
   for the full failure history: a PyPI packaging bug, then a `/tmp`
   tmpfs size cap hit during a duplicate CUDA download). A `TMPDIR`
   redirect fixes the second failure specifically, but general fairseq
   fragility remains a real, currently-untested risk.

Decided order (see the suspended-context note above for the full plan):
rule-based first (this script, working now) -> diarization -> re-run
transcription with timestamps -> re-transliterate/diarize on the
timestamped version -> *then* attempt ML-based as a time-boxed
comparison once the rest of the pipeline is solid.

===============================================================================
"""
import argparse
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

DEFAULT_OUTPUT_DIR = Path.home() / "transcripts"


def strip_diacritics(text: str) -> str:
    """NFKD-decompose and drop combining marks -- turns IAST's scholarly
    diacritics (ā, ī, ṃ, ṇ, ś, ...) into plain ASCII-ish Roman letters.
    Does not fix schwa-deletion or anusvara-spelling gaps -- see the
    module docstring's "casual" style notes above for exactly what this
    does and doesn't fix.
    """
    decomposed = unicodedata.normalize("NFKD", text)
    return "".join(c for c in decomposed if not unicodedata.combining(c))


def transliterate_rule_based(text: str, style: str) -> str:
    from indic_transliteration import sanscript
    from indic_transliteration.sanscript import transliterate as xlit

    iast = xlit(text, sanscript.DEVANAGARI, sanscript.IAST)
    # sanscript renders the Devanagari danda (।) as "|" under IAST --
    # swap it for a period, since "|" reads oddly as sentence punctuation
    # in Roman script.
    iast = iast.replace("|", ".")
    if style == "formal":
        return iast
    return strip_diacritics(iast)


def transliterate_ml_based(text: str) -> str:
    raise NotImplementedError(
        "ML-based transliteration (AI4Bharat IndicXlit) is not implemented "
        "yet -- it's next in the pipeline after diarization + timestamped "
        "re-transcription. See this script's module docstring, and "
        "ai-learning/suspended-contexts/2026-09-03-hinglish-transliteration-diarization.md "
        "for the fairseq install history / TMPDIR fix needed before attempting it."
    )


def prompt_output_path(kind_label: str, default_path: Path) -> str | None:
    """Same UX pattern as hinglish_transcribe.py's prompt_output_path --
    ask whether to write a file at all, then whether the suggested
    default path is fine or a custom one should be used instead."""
    raw = input(f"Write {kind_label} to a file? [Y/n]: ").strip().lower()
    if raw == "n":
        return None
    raw = input(f"Save to {default_path}? [Y/n]: ").strip().lower()
    if raw == "n":
        return input("Enter full output path: ").strip()
    return str(default_path)


def prompt_for_missing_args(args: argparse.Namespace, input_path: Path) -> None:
    """Interactive prompts for whatever wasn't already given as a flag --
    only when actually running in a terminal (skipped for scripted/piped
    use), matching hinglish_transcribe.py's convention."""
    if not sys.stdin.isatty():
        return

    if args.style is None:
        raw = input("Style -- formal (IAST, diacritics) or casual (stripped)? [F/c]: ").strip().lower()
        args.style = "formal" if raw == "f" else "casual"

    if args.output is None:
        default_name = build_output_filename(input_path, args.method, args.style)
        args.output = prompt_output_path("the transliterated text", DEFAULT_OUTPUT_DIR / default_name)


def build_output_filename(input_path: Path, method: str, style: str) -> str:
    """Descriptive output filename: original stem + pipeline stage +
    method/style used + timestamp of this step. Keeps the pipeline's
    history readable from the filename alone once diarization etc. get
    chained on top of this (see CLAUDE.md's tools/ conventions note)."""
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    method_tag = f"{method}_{style}" if method == "rule" else method
    return f"{input_path.stem}.transliterated-{method_tag}.{stamp}.txt"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("filename", help="Path to the transcript text file to transliterate.")
    parser.add_argument(
        "--method",
        choices=["rule", "ml"],
        default="rule",
        help="rule = deterministic IAST-based mapping, no heavy deps (default, working). "
        "ml = AI4Bharat IndicXlit, more natural output but not yet implemented -- see module docstring.",
    )
    parser.add_argument(
        "--style",
        choices=["formal", "casual"],
        default=None,
        help="rule method only. formal = IAST with diacritics (\"kiraṇ\"). "
        "casual = diacritics stripped (\"kiran\") -- closer to natural typed Hinglish, though "
        "not identical (schwa-deletion and anusvara spelling aren't corrected). "
        "Default: casual, or prompted interactively if run in a terminal.",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Write the transliterated text to this file (still printed to stdout too).",
    )
    args = parser.parse_args()

    input_path = Path(args.filename).expanduser()
    if not input_path.exists():
        sys.exit(f"ERROR: input file not found: {input_path}")

    prompt_for_missing_args(args, input_path)
    if args.style is None:
        args.style = "casual"

    text = input_path.read_text(encoding="utf-8")

    if args.method == "ml":
        transliterate_ml_based(text)  # always raises -- see function
        return

    result = transliterate_rule_based(text, args.style)
    print(result)

    if args.output:
        out_path = Path(args.output).expanduser()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(result, encoding="utf-8")
        print(f"(Transliterated text also written to {out_path})")


if __name__ == "__main__":
    main()
