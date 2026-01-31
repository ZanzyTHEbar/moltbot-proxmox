#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/lib/log.sh"

info "Running preflight checks..."

# Core tools
need_cmd bash
need_cmd ssh
need_cmd ssh-keygen
need_any_cmd curl wget
need_cmd ansible
need_cmd ansible-playbook
need_cmd ansible-galaxy
need_cmd yq

# UX dependency
if ! command -v gum >/dev/null 2>&1; then
  warn "Missing optional-but-required-for-bootstrap UX tool: gum"
  warn "Install gum, then re-run bootstrap."
  echo
  echo "Install hints:"
  echo "- macOS (brew):   brew install gum"
  echo "- Arch (pacman):  sudo pacman -S gum"
  echo "- Debian/Ubuntu:  try: sudo apt-get install -y gum  (if available for your distro)"
  echo "- Otherwise: see Charmbracelet gum releases/docs"
  echo
  die "gum is required for scripts/bootstrap.sh"
fi

if ! yq --version 2>/dev/null | grep -qiE 'mikefarah|version v4'; then
  warn "Your yq does not look like mikefarah/yq v4."
  warn "This repo assumes yq v4 syntax."
  echo
  warn "Install hints:"
  warn "- macOS (brew):   brew install yq"
  warn "- Arch (pacman):  sudo pacman -S yq"
  warn "- Debian/Ubuntu:  sudo apt-get install -y yq  (may be v3 on some distros)"
  warn "- Alternative: download mikefarah/yq v4 binary"
  echo
fi

ok "All required dependencies are present."
echo
echo "Next:"
echo "  bash scripts/bootstrap.sh"

