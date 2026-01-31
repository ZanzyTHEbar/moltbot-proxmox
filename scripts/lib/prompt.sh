#!/usr/bin/env bash
set -euo pipefail

prompt_require_gum() {
  command -v gum >/dev/null 2>&1 || return 1
  return 0
}

prompt_input() {
  # prompt_input "Label" "default" -> prints string
  local label="$1"
  local def="${2:-}"
  if ! prompt_require_gum; then
    echo "gum is required for interactive prompts. Run: bash scripts/preflight.sh" >&2
    exit 1
  fi
  gum input --prompt "${label}: " --value "${def}"
}

prompt_confirm() {
  # prompt_confirm "Question" -> prints y|n
  local label="$1"
  local def="${2:-y}" # y|n
  if ! prompt_require_gum; then
    echo "gum is required for interactive prompts. Run: bash scripts/preflight.sh" >&2
    exit 1
  fi
  if [ "${def}" = "y" ]; then
    gum confirm "${label}" && printf 'y' || printf 'n'
  else
    gum confirm --default=false "${label}" && printf 'y' || printf 'n'
  fi
}

prompt_choose() {
  # prompt_choose "Label" "default" item1 item2 ... -> prints chosen item (or default if empty list)
  local label="$1"
  local def="$2"
  shift 2
  if [ "$#" -eq 0 ]; then
    printf '%s' "$def"
    return 0
  fi
  if ! prompt_require_gum; then
    echo "gum is required for interactive prompts. Run: bash scripts/preflight.sh" >&2
    exit 1
  fi
  # gum choose supports --selected for default highlight
  gum choose --header "${label}" --selected "${def}" "$@"
}

