## Quickstart (Proxmox-only)

This repo currently supports **Proxmox VE** only.

### 1) Bootstrap configuration (interactive)

```bash
cd /path/to/repo
bash scripts/preflight.sh
bash scripts/bootstrap.sh
```

This generates:

- `inventory/hosts.yml`
- `group_vars/all/main.yml`
- `.keys/moltbot_ansible` (SSH keypair)
- optionally `group_vars/all/vault.yml` (if you enable NetBird/Tailscale)

### 2) (Optional) Add VPN secrets

If you enabled NetBird or Tailscale during bootstrap:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

### 3) Install Ansible dependencies

```bash
ansible-galaxy collection install -r requirements.yml
```

### 4) Deploy

Without vault:

```bash
ansible-playbook playbooks/site.yml
```

With vault:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

### 5) Post-install

MoltBot provider onboarding is usually interactive (QR codes/tokens).
SSH to the container and run the onboarding command printed by Ansible (typically `clawdbot ...` during the rename transition).

