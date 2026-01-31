#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${ROOT_DIR}/scripts/lib/log.sh"
source "${ROOT_DIR}/scripts/lib/prompt.sh"
source "${ROOT_DIR}/scripts/lib/proxmox.sh"
source "${ROOT_DIR}/scripts/lib/yaml.sh"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/bootstrap.sh [--dry-run]

Options:
  -n, --dry-run   Print yq mutations that would be applied (no file changes)
  -h, --help      Show this help
EOF
      exit 0
      ;;
  esac
done

info "Bootstrapping MoltBot-on-Proxmox Ansible config in: ${ROOT_DIR}"

ts() { date +"%Y%m%d_%H%M%S"; }
backup_if_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    local b="${f}.bak.$(ts)"
    if [ "$DRY_RUN" = "1" ]; then
      info "DRY-RUN: would back up: $f -> $b"
      return 0
    fi
    cp -a "$f" "$b"
    info "Backed up: $f -> $b"
  fi
}

if [ "$DRY_RUN" = "1" ]; then
  info "DRY-RUN enabled: no files will be created/modified."
  export YAML_DRY_RUN=1
else
  mkdir -p "${ROOT_DIR}/inventory" "${ROOT_DIR}/group_vars/all" "${ROOT_DIR}/.keys"
  chmod 700 "${ROOT_DIR}/.keys"
fi

prompt_require_gum || die "gum is required. Run: bash scripts/preflight.sh"

info "This wizard will generate:"
info " - inventory/hosts.yml"
info " - group_vars/all/main.yml"
info " - group_vars/all/vault.yml (optional)"
info " - .keys/moltbot_ansible (SSH keypair)"

KEY="${ROOT_DIR}/.keys/moltbot_ansible"
if [ "$DRY_RUN" = "1" ]; then
  if [ -f "${KEY}.pub" ]; then
    PUB="$(cat "${KEY}.pub")"
    info "DRY-RUN: using existing pubkey: ${KEY}.pub"
  else
    PUB="ssh-ed25519 AAAA_DRY_RUN_PLACEHOLDER moltbot-ansible"
    warn "DRY-RUN: ${KEY}.pub not found; using placeholder pubkey in printed mutations."
    warn "DRY-RUN: would generate SSH keypair at: ${KEY} (+ .pub)"
  fi
else
  if [ ! -f "${KEY}" ]; then
    ssh-keygen -t ed25519 -a 64 -f "${KEY}" -N '' -C 'moltbot-ansible' >/dev/null
    ok "Generated SSH keypair: ${KEY} (+ .pub)"
  fi
  PUB="$(cat "${KEY}.pub")"
fi

PROXMOX_NAME="$(prompt_input "Inventory name for your Proxmox host" "proxmox1")"
PROXMOX_HOST="$(prompt_input "Proxmox SSH host/IP (ansible_host)" "192.168.1.10")"
PROXMOX_USER="$(prompt_input "Proxmox SSH user" "root")"

AUTO_DETECT="$(prompt_confirm "Auto-detect Proxmox nodes/storages/bridges via SSH?" "y")"

PVE_NODE="pve"
PVE_TEMPLATE_STORAGE="local"
PVE_CONTAINER_STORAGE="local-lvm"
PVE_BRIDGE="vmbr0"

if [ "$AUTO_DETECT" = "y" ]; then
  info "Probing Proxmox host for nodes, storages, and bridges..."

  mapfile -t NODES < <(detect_nodes "$PROXMOX_HOST" "$PROXMOX_USER" || true)
  if [ "${#NODES[@]}" -gt 0 ]; then
    PVE_NODE="$(prompt_choose "Detected Proxmox nodes (pick one)" "pve" "${NODES[@]}")"
  else
    warn "Could not auto-detect nodes; falling back to manual input."
    PVE_NODE="$(prompt_input "Proxmox node name (pve_node)" "pve")"
  fi

  mapfile -t STORAGES < <(detect_storages "$PROXMOX_HOST" "$PROXMOX_USER" || true)
  if [ "${#STORAGES[@]}" -gt 0 ]; then
    TEMPLATE_PICK="$(prompt_choose "Storages: pick one that contains templates/vztmpl" "local" "${STORAGES[@]}")"
    CONTAINER_PICK="$(prompt_choose "Storages: pick one that supports container rootfs/rootdir" "local-lvm" "${STORAGES[@]}")"
    PVE_TEMPLATE_STORAGE="${TEMPLATE_PICK%% *}"
    PVE_CONTAINER_STORAGE="${CONTAINER_PICK%% *}"
  else
    warn "Could not auto-detect storages; falling back to manual input."
    PVE_TEMPLATE_STORAGE="$(prompt_input "Template storage ID (vztmpl) (pve_template_storage)" "local")"
    PVE_CONTAINER_STORAGE="$(prompt_input "Container storage ID (rootdir) (pve_container_storage)" "local-lvm")"
  fi

  mapfile -t BRIDGES < <(detect_bridges "$PROXMOX_HOST" "$PROXMOX_USER" || true)
  if [ "${#BRIDGES[@]}" -gt 0 ]; then
    PVE_BRIDGE="$(prompt_choose "Detected Linux bridges on Proxmox" "vmbr0" "${BRIDGES[@]}")"
  else
    warn "Could not auto-detect bridges; falling back to manual input."
    PVE_BRIDGE="$(prompt_input "Network bridge (pve_bridge)" "vmbr0")"
  fi
else
  PVE_NODE="$(prompt_input "Proxmox node name (pve_node)" "pve")"
  PVE_TEMPLATE_STORAGE="$(prompt_input "Template storage ID (vztmpl) (pve_template_storage)" "local")"
  PVE_CONTAINER_STORAGE="$(prompt_input "Container storage ID (rootdir) (pve_container_storage)" "local-lvm")"
  PVE_BRIDGE="$(prompt_input "Network bridge (pve_bridge)" "vmbr0")"
fi

PVE_VMID="$(prompt_input "CTID (pve_vmid)" "1200")"
PVE_HOSTNAME="$(prompt_input "CT hostname (pve_hostname)" "moltbot")"
PVE_UNPRIV="$(prompt_confirm "Unprivileged container? (recommended)" "y")"
PVE_CORES="$(prompt_input "CPU cores (pve_cores)" "4")"
PVE_MEM="$(prompt_input "RAM MB (pve_memory_mb)" "8192")"
PVE_SWAP="$(prompt_input "Swap MB (pve_swap_mb)" "1024")"
PVE_DISK="$(prompt_input "Disk GB (pve_disk_gb)" "150")"

LAN_CIDR="$(prompt_input "LAN CIDR allowed to SSH (admin_allow_cidrs entry)" "192.168.1.0/24")"

USE_NETBIRD="$(prompt_confirm "Enable NetBird? (preferred VPN)" "n")"
USE_TAILSCALE="$(prompt_confirm "Enable Tailscale? (optional)" "n")"

info "Writing files..."

# inventory/hosts.yml (copy template + apply with yq)
INV="${ROOT_DIR}/inventory/hosts.yml"
backup_if_exists "$INV"
if [ "$DRY_RUN" = "1" ]; then
  info "DRY-RUN: would copy inventory/hosts.example.yml -> inventory/hosts.yml"
else
  cp "${ROOT_DIR}/inventory/hosts.example.yml" "$INV"
fi
export PROXMOX_NAME PROXMOX_HOST PROXMOX_USER
yaml_set_env "$INV" '.all.children.proxmox.hosts = { (strenv(PROXMOX_NAME)): { "ansible_host": strenv(PROXMOX_HOST), "ansible_user": strenv(PROXMOX_USER) } }'
ok "Wrote: inventory/hosts.yml"

# group_vars/all/main.yml (copy template + apply with yq)
MAIN="${ROOT_DIR}/group_vars/all/main.yml"
backup_if_exists "$MAIN"
if [ "$DRY_RUN" = "1" ]; then
  info "DRY-RUN: would copy group_vars/all/main.example.yml -> group_vars/all/main.yml"
else
  cp "${ROOT_DIR}/group_vars/all/main.example.yml" "$MAIN"
fi
export PVE_NODE PVE_VMID PVE_HOSTNAME PVE_UNPRIV PVE_CORES PVE_MEM PVE_SWAP PVE_TEMPLATE_STORAGE PVE_CONTAINER_STORAGE PVE_DISK PVE_BRIDGE LAN_CIDR PUB KEY
export USE_NETBIRD USE_TAILSCALE

yaml_set_env "$MAIN" '.pve_node = strenv(PVE_NODE)'
yaml_set_env "$MAIN" '.pve_vmid = (strenv(PVE_VMID) | tonumber)'
yaml_set_env "$MAIN" '.pve_hostname = strenv(PVE_HOSTNAME)'
yaml_set_env "$MAIN" '.pve_unprivileged = (strenv(PVE_UNPRIV) == "y")'
yaml_set_env "$MAIN" '.pve_cores = (strenv(PVE_CORES) | tonumber)'
yaml_set_env "$MAIN" '.pve_memory_mb = (strenv(PVE_MEM) | tonumber)'
yaml_set_env "$MAIN" '.pve_swap_mb = (strenv(PVE_SWAP) | tonumber)'
yaml_set_env "$MAIN" '.pve_template_storage = strenv(PVE_TEMPLATE_STORAGE)'
yaml_set_env "$MAIN" '.pve_container_storage = strenv(PVE_CONTAINER_STORAGE)'
yaml_set_env "$MAIN" '.pve_disk_gb = (strenv(PVE_DISK) | tonumber)'
yaml_set_env "$MAIN" '.pve_bridge = strenv(PVE_BRIDGE)'
yaml_set "$MAIN" '.pve_net_ipv4 = "dhcp"'

yaml_set "$MAIN" '.bootstrap_admin_user = "moltadmin"'
yaml_set_env "$MAIN" '.bootstrap_admin_pubkeys = [strenv(PUB)]'
yaml_set_env "$MAIN" '.bootstrap_admin_private_key_file = strenv(KEY)'

yaml_set "$MAIN" '.hardening_install_fail2ban = true'
yaml_set "$MAIN" '.hardening_install_unattended_upgrades = true'
yaml_set_env "$MAIN" '.admin_allow_cidrs = [strenv(LAN_CIDR)]'

yaml_set_env "$MAIN" '.netbird_enable = (strenv(USE_NETBIRD) == "y")'
yaml_set_env "$MAIN" '.tailscale_enable = (strenv(USE_TAILSCALE) == "y")'
ok "Wrote: group_vars/all/main.yml"

# group_vars/all/vault.yml (only if any VPN enabled)
VAULT="${ROOT_DIR}/group_vars/all/vault.yml"
if [ "$USE_NETBIRD" = "y" ] || [ "$USE_TAILSCALE" = "y" ]; then
  if [ ! -f "$VAULT" ]; then
    cp "${ROOT_DIR}/group_vars/all/vault.example.yml" "$VAULT"
    ok "Wrote: group_vars/all/vault.yml (from example)"
  else
    info "Keeping existing: group_vars/all/vault.yml"
  fi
  warn "Reminder: encrypt vault.yml before committing anything:"
  warn "  ansible-vault encrypt group_vars/all/vault.yml"
fi

ok "Done."
echo
info "Next:"
info "  bash scripts/preflight.sh"
info "  ansible-galaxy collection install -r requirements.yml"
if [ -f "$VAULT" ]; then
  info "  ansible-playbook playbooks/site.yml --ask-vault-pass"
else
  info "  ansible-playbook playbooks/site.yml"
fi
echo