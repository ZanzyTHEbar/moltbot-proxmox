# MoltBot on Proxmox LXC (Ansible)

This directory contains an Ansible project that will:

- Create an **unprivileged LXC** on Proxmox by running the Proxmox community-script **`ct/docker.sh`** (via SSH to your Proxmox host, unattended)
- Bootstrap SSH access into the container (inject your public key)
- Apply a **security baseline** (ssh hardening, UFW, optional fail2ban, unattended upgrades)
- Install **Docker** (for sandboxed execution) with an extra guardrail to prevent published container ports from being reachable from the LAN
- Install MoltBot (or fall back to `clawdbot` if that’s what the CLI provides)

References:
- Proxmox install strategy is inspired by the “hardened installer” approach in [`moltbot/clawdbot-ansible`](https://github.com/moltbot/clawdbot-ansible).
- MoltBot docs hub: [`docs.molt.bot`](https://docs.molt.bot/) and architecture overview: [`docs.molt.bot/concepts/architecture`](https://docs.molt.bot/concepts/architecture).
- Core repo/org: [`moltbot/moltbot`](https://github.com/moltbot/moltbot), [`moltbot`](https://github.com/moltbot).

## Prereqs (your workstation)

- Ansible installed locally
- SSH access working to Proxmox as root (or a user allowed to run `pct`): `ssh root@<proxmox-host>`

Install required Ansible collections:

```bash
cd /path/to/this/repo
ansible-galaxy collection install -r requirements.yml
```

## Quickstart (recommended UX)

Run the bootstrap helper:

```bash
cd /path/to/this/repo
bash scripts/preflight.sh
bash scripts/bootstrap.sh
```

Then follow the printed instructions.

Also see: `QUICKSTART.md`.

## Configure (manual)

Copy examples:

- `inventory/hosts.example.yml` → `inventory/hosts.yml`
- `group_vars/all/main.example.yml` → `group_vars/all/main.yml`
- `group_vars/all/vault.example.yml` → `group_vars/all/vault.yml` (optional, then encrypt)

Edit `group_vars/all/main.yml` and set:

- **`pve_node`**: Proxmox node name
- **`pve_vmid`**: container ID
- **`pve_template_storage`** / **`pve_container_storage`**: storages
- **`pve_disk_gb`**: container disk size
- **`bootstrap_admin_pubkeys`**: at least one SSH public key string
- **`bootstrap_admin_private_key_file`**: private key path Ansible should use to SSH into the CT

By default this repo is **LAN-only**, with NetBird/Tailscale optional.

## Run

```bash
cd /path/to/this/repo
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## NetBird (preferred VPN)

Set `netbird_setup_key` in `group_vars/all/vault.yml` and encrypt it:

```bash
cd /path/to/this/repo
ansible-vault encrypt group_vars/all/vault.yml
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## What happens / security model

- **LAN-only**: UFW defaults to deny incoming and allows **SSH only from `admin_allow_cidrs`**.
- **Root login + password auth are disabled** in SSH.
- MoltBot is installed, but the systemd service is **disabled by default** because provider onboarding/login is typically interactive (QR codes, tokens).

After the playbook finishes:

1. SSH in (LAN or VPN): `ssh -i .keys/moltbot_ansible moltadmin@<ct-ip>`
2. Run onboarding/provider login (interactive), for example:
   - `moltbot onboard --install-daemon`
   - or `moltbot configure` then `moltbot providers login`
3. Re-run the playbook with `moltbot_enable_service: true` if you want the gateway to auto-start via systemd.

