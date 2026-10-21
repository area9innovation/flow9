#!/bin/bash
# Launches Claude Code in this checkout. The Metamind Web Agent runs routines
# through this script, so it must stay at the repo root under this name.

# bin/flowc1 needs Java 21+. Where no Java runs, as on a box whose mise sets no
# global version, take mise's Temurin 21; it must be set before mise activates.
java -version >/dev/null 2>&1 || export MISE_JAVA_VERSION=temurin-21

# Activate mise when present, so a box-managed toolchain is on PATH.
if command -v mise &>/dev/null; then
  eval "$(mise activate bash)"
elif [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi

# flowc1, flowcpp and the build scripts live in bin/.
_ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="$_ROOT/bin:$PATH"

printf '\033]0;Claude Code\007'

# Effort is the thinking-token band. AI_EFFORT= (empty) defers to the CLI's
# own setting; a routine sets it per run.
: "${AI_EFFORT=high}"
_EFFORT_ARGS=()
[ -n "$AI_EFFORT" ] && _EFFORT_ARGS=(--effort "$AI_EFFORT")

claude --dangerously-skip-permissions "${_EFFORT_ARGS[@]}" "$@"
