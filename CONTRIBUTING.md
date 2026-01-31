## Contributing

Thanks for contributing.

### Ground rules

- Don’t commit secrets.
  - Never commit `group_vars/all/vault.yml`, `inventory/hosts.yml`, or `.keys/`.
  - Keep production IPs/hostnames out of examples.
- Keep changes Proxmox-only for now.
- Prefer small, reviewable diffs.

### Development workflow

1) Run preflight + bootstrap (local)

```bash
bash scripts/preflight.sh
bash scripts/bootstrap.sh --dry-run
```

2) Validate Ansible playbooks parse

```bash
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/resources.yml --syntax-check
```

### Style

- Shell scripts: `set -euo pipefail`, keep functions in `scripts/lib/`, keep `scripts/bootstrap.sh` thin.
- YAML: don’t hand-generate; use `yq` where appropriate.

