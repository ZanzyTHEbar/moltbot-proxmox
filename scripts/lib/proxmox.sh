#!/usr/bin/env bash
set -euo pipefail

ssh_probe() {
  # ssh_probe <host> <user> <cmd>
  local host="$1"
  local user="$2"
  local cmd="$3"
  ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new "${user}@${host}" "$cmd"
}

detect_nodes() {
  local host="$1"
  local user="$2"
  local raw=""
  raw="$(ssh_probe "$host" "$user" "pvesh get /nodes --output-format json 2>/dev/null || true" || true)"
  if [ -z "$raw" ]; then
    return 0
  fi
  # Minimal extraction without jq: find lines like node:<name>
  printf '%s' "$raw" | tr '{},\"' '\n' | sed -n 's/^node: //p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u
}

detect_storages() {
  local host="$1"
  local user="$2"
  ssh_probe "$host" "$user" "pvesm status | awk 'NR>1 {print \$1\" (\"\$2\")\"}' 2>/dev/null || true" || true
}

detect_bridges() {
  local host="$1"
  local user="$2"
  ssh_probe "$host" "$user" "ip -br link show type bridge 2>/dev/null | awk '{print \$1}'" || true
}

