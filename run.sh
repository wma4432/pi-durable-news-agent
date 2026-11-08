#!/usr/bin/env bash
# Wrapper so the repo runs on this WSL box without zsh and with Node 24.
#
#   ./run.sh api tokens        # one-time: write the bearer tokens into .env
#   ./run.sh combos dev        # free + offline: faux model, fixture news, UI on :4851
#   ./run.sh combos local      # the real thing (needs OPENROUTER_API_KEY in .env)
#   ./run.sh net down local    # stop everything
#
# Two local deviations from the README, both deliberate:
#   1. The justfile hardcodes `set shell := ["zsh", ...]`; zsh is not installed and
#      needs sudo. `--shell bash` overrides it — the recipes are POSIX-compatible.
#   2. Node 24 comes from nvm, which is not active in a non-login shell.
set -euo pipefail
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use 24 >/dev/null 2>&1 || { echo "Node 24 missing: nvm install 24" >&2; exit 1; }
export PATH="$HOME/.local/bin:$PATH"
cd "$(dirname "$0")"
exec just --shell bash --shell-arg -cu "$@"
