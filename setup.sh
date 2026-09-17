#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_root="${ASK_HORMOZI_HOME:-${HOME}/.local/share/ask-hormozi}"
bin_dir="${HOME}/.local/bin"
skip_skill=false

usage() {
  printf '%s\n' \
    "Usage: ./setup.sh [options]" \
    "" \
    "Installs the CLI and skill, then indexes the bundled Markdown corpus." \
    "It does not download video, audio, captions, or transcripts." \
    "" \
    "Options:" \
    "  --skip-skill    Do not install the Codex and Claude skill folders." \
    "  -h, --help      Show this help."
}

while (($#)); do
  case "$1" in
    --skip-skill)
      skip_skill=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "error: Python 3.10+ is required." >&2
  exit 1
fi
if [[ ! -d "$project_root/corpus/segments" ]] && \
  [[ ! -d "$project_root/corpus/episodes" ]]; then
  printf '%s\n' \
    "error: the bundled corpus is missing corpus Markdown." \
    "Download a complete release archive or clone the repository again." >&2
  exit 1
fi

mkdir -p "$install_root" "$bin_dir"
python3 -m venv "$install_root/venv"
"$install_root/venv/bin/python" -m pip install --quiet --upgrade pip
"$install_root/venv/bin/python" -m pip install --quiet --upgrade "$project_root"
ln -sfn "$install_root/venv/bin/ask-hormozi" "$bin_dir/ask-hormozi"

export PATH="$bin_dir:$PATH"

# The search engine this package drives is QMD by Tobi Lütke (@tobilu/qmd on
# npm): `qmd collection add`, `qmd search --json`, `qmd context add`. It is a
# Node package, so installing it needs Node 22+ and npm.
if ! command -v qmd >/dev/null 2>&1; then
  if ! command -v npm >/dev/null 2>&1; then
    printf '%s\n' \
      "error: qmd is not installed and npm was not found, so it cannot be installed." \
      "Install Node.js 22 or newer from https://nodejs.org, then run ./setup.sh again." >&2
    exit 1
  fi
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [[ "$node_major" -lt 22 ]]; then
    printf '%s\n' \
      "error: qmd needs Node.js 22 or newer (found $(node --version 2>/dev/null || echo none))." \
      "Upgrade Node.js from https://nodejs.org, then run ./setup.sh again." >&2
    exit 1
  fi
  npm install -g @tobilu/qmd
fi

if ! command -v qmd >/dev/null 2>&1; then
  printf '%s\n' \
    "error: qmd installation finished but qmd is not on PATH." \
    "See https://github.com/tobi/qmd for manual installation." >&2
  exit 1
fi

if [[ "$skip_skill" == false ]]; then
  for skill_root in "$HOME/.codex/skills" "$HOME/.claude/skills"; do
    mkdir -p "$skill_root/ask-hormozi"
    cp -R "$project_root/skills/ask-hormozi/." "$skill_root/ask-hormozi/"
  done
fi

"$install_root/venv/bin/ask-hormozi" configure \
  --data-dir "$project_root/corpus"
"$install_root/venv/bin/ask-hormozi" index \
  --data-dir "$project_root/corpus"

printf '%s\n' \
  "" \
  "Ask Hormozi is installed and indexed." \
  "CLI: $bin_dir/ask-hormozi" \
  "Bundled corpus: $project_root/corpus" \
  "Try: ask-hormozi search \"How should I price and position my offer?\""
