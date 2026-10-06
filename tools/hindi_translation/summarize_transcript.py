#!/usr/bin/env python3
"""
Generate a topic outline from a diarized/transliterated Markdown transcript
(the .md output of audio_to_markdown.sh), using a local LLM via llama.cpp.

For each topic discussed, the outline gives the timestamp range it spans,
lifted from the transcript's own "### **[MM:SS-MM:SS] SPEAKER_XX:**"
headings -- the model is asked to cite real headings from the input, not
invent timestamps.

Usage:
    python3 summarize_transcript.py <transcript.md> [-o output.md]
    python3 summarize_transcript.py <transcript.md> --n-predict 4096

Requires a built llama.cpp (tools/hindi_translation/RUNBOOK.md or the repo
issue tracker has the install notes) and a GGUF model -- defaults to
Qwen2.5-7B-Instruct-Q4_K_M in ~/models/llm-gguf/, override with --model.
"""
import argparse
import subprocess
import sys
import time
from pathlib import Path

DEFAULT_LLAMA_CLI = Path.home() / "code" / "llama.cpp" / "build" / "bin" / "llama-cli"
DEFAULT_MODEL = Path.home() / "models" / "llm-gguf" / "Qwen2.5-7B-Instruct-Q4_K_M.gguf"
DEFAULT_CTX_SIZE = 32768

SYSTEM_PROMPT = (
    "You are an assistant that outlines conversation transcripts. The "
    "transcript is Hinglish (mixed Hindi/English, transliterated to Roman "
    "script) and is broken into headings of the form "
    "'[MM:SS-MM:SS] SPEAKER_XX:' followed by that speaker's text. "
    "Read the whole transcript and produce a topic outline: for each "
    "distinct topic discussed, give the timestamp range it spans (using "
    "the transcript's own timestamps, not invented ones) and a one- or "
    "two-sentence summary of what was discussed. Order topics "
    "chronologically. Output as a Markdown bullet list, one bullet per "
    "topic, format: '- **[start-end]** Summary.'"
)


def build_output_filename(input_path: Path) -> Path:
    stem = input_path.name
    if stem.endswith(".md"):
        stem = stem[: -len(".md")]
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    return input_path.parent / f"{stem}.topic_outline-qwen2.5_7b.{timestamp}.md"


def run_llama(
    llama_cli: Path,
    model: Path,
    transcript_text: str,
    ctx_size: int,
    n_predict: int,
) -> str:
    prompt_file = Path("/tmp") / "summarize_transcript_prompt.txt"
    # Written to /tmp deliberately transient -- not a project artifact,
    # overwritten on every run.
    prompt_file.write_text(transcript_text, encoding="utf-8")

    cmd = [
        str(llama_cli),
        "-m", str(model),
        "-c", str(ctx_size),
        "-n", str(n_predict),
        "--temp", "0.2",
        "-st",
        "--no-display-prompt",
        "--no-warmup",
        "-sys", SYSTEM_PROMPT,
        "-f", str(prompt_file),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"ERROR: llama-cli failed (exit {result.returncode}):\n{result.stderr}")
    return clean_llama_output(result.stdout)


def clean_llama_output(raw: str) -> str:
    """Strip llama-cli's interactive-console noise (banner, spinner, echoed
    input, timing footer) that leaks into stdout even in -st single-turn
    mode -- keep only the model's actual outline, i.e. lines from the
    first '- **[' bullet through the last one."""
    lines = raw.splitlines()
    start = next((i for i, line in enumerate(lines) if line.lstrip().startswith("- **[")), None)
    if start is None:
        sys.exit(f"ERROR: no outline bullets found in llama-cli output:\n{raw}")
    end = len(lines)
    for i in range(len(lines) - 1, start - 1, -1):
        if lines[i].lstrip().startswith("- **["):
            end = i + 1
            break
    return "\n".join(lines[start:end]).strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input_file", help="Path to the transcript Markdown file.")
    parser.add_argument("-o", "--output", help="Path to write the topic outline. Default: descriptive name next to input.")
    parser.add_argument("--model", default=str(DEFAULT_MODEL), help=f"Path to the GGUF model (default: {DEFAULT_MODEL}).")
    parser.add_argument("--llama-cli", default=str(DEFAULT_LLAMA_CLI), help=f"Path to the llama-cli binary (default: {DEFAULT_LLAMA_CLI}).")
    parser.add_argument("--ctx-size", type=int, default=DEFAULT_CTX_SIZE, help=f"Context window size (default: {DEFAULT_CTX_SIZE}).")
    parser.add_argument("--n-predict", type=int, default=2048, help="Max tokens to generate (default: 2048).")
    args = parser.parse_args()

    input_path = Path(args.input_file).expanduser()
    if not input_path.exists():
        sys.exit(f"ERROR: input file not found: {input_path}")

    model_path = Path(args.model).expanduser()
    if not model_path.exists():
        sys.exit(f"ERROR: model not found: {model_path}")

    llama_cli_path = Path(args.llama_cli).expanduser()
    if not llama_cli_path.exists():
        sys.exit(f"ERROR: llama-cli binary not found: {llama_cli_path}")

    transcript_text = input_path.read_text(encoding="utf-8")

    print(f"Running {model_path.name} on {input_path.name} ({len(transcript_text)} chars)...")
    outline = run_llama(llama_cli_path, model_path, transcript_text, args.ctx_size, args.n_predict)

    output_path = Path(args.output).expanduser() if args.output else build_output_filename(input_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(outline + "\n", encoding="utf-8")
    print(f"Topic outline written to {output_path}")


if __name__ == "__main__":
    main()
