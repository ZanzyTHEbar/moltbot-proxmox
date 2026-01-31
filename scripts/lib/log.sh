#!/usr/bin/env bash
set -euo pipefail

_log_ts() { date +"%H:%M:%S"; }

info() { printf "[%s] [INFO] %s\n" "$(_log_ts)" "$*"; }
warn() { printf "[%s] [WARN] %s\n" "$(_log_ts)" "$*" >&2; }
err()  { printf "[%s] [ERR ] %s\n" "$(_log_ts)" "$*" >&2; }
ok()   { printf "[%s] [ OK ] %s\n" "$(_log_ts)" "$*"; }

die() {
  err "$*"
  exit 1
}

need_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || die "Missing required command: $c"
}

need_any_cmd() {
  # need_any_cmd curl wget
  local found="n"
  local c=""
  for c in "$@"; do
    if command -v "$c" >/dev/null 2>&1; then
      found="y"
      break
    fi
  done
  [ "$found" = "y" ] || die "Missing required command (need one of): $*"
}

