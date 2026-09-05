#!/usr/bin/env python3
"""
Reformat a diarized/transliterated transcript into a clean Markdown file:
each timestamp/speaker line becomes a bold, level-3 heading with a blank
line before and after it.

Usage:
    python3 format_markdown.py <input_txt> -o <output_md>

Turns:
    [00:00-00:30] SPEAKER_00:
    <text>

Into:
    ### **[00:00-00:30] SPEAKER_00:**

    <text>

Design choice: both a heading (###) AND bold on the same line, per
explicit request -- redundant for pure visual hierarchy (a heading is
already visually distinct), but bold also makes the line stand out when
skimming raw markdown source (e.g. a plain-text viewer that doesn't
render heading styling), so both are kept rather than picking one.
"""
import argparse
import re
import sys
from pathlib import Path

TIMESTAMP_LINE = re.compile(r"^\[.*$", re.MULTILINE)


def format_markdown(text: str) -> str:
    def to_heading(match: "re.Match") -> str:
        return f"\n### **{match.group(0).rstrip()}**\n\n"

    formatted = TIMESTAMP_LINE.sub(to_heading, text)
    # The substitution can introduce runs of 3+ blank lines around
    # existing spacing already in the source -- collapse back to a
    # single blank line between blocks.
    formatted = re.sub(r"\n{3,}", "\n\n", formatted)
    return formatted.strip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input_file", help="Path to the diarized/transliterated transcript text file.")
    parser.add_argument("-o", "--output", required=True, help="Path to write the formatted Markdown file.")
    args = parser.parse_args()

    input_path = Path(args.input_file).expanduser()
    if not input_path.exists():
        sys.exit(f"ERROR: input file not found: {input_path}")

    text = input_path.read_text(encoding="utf-8")
    formatted = format_markdown(text)

    output_path = Path(args.output).expanduser()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(formatted, encoding="utf-8")
    print(f"Formatted markdown written to {output_path}")


if __name__ == "__main__":
    main()
