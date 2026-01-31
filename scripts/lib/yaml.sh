#!/usr/bin/env bash
set -euo pipefail

yaml_need_yq() {
  command -v yq >/dev/null 2>&1 || return 1
  return 0
}

yaml_dry_run_enabled() {
  [ "${YAML_DRY_RUN:-0}" = "1" ]
}

yaml_print_mutation() {
  # yaml_print_mutation <file> <yq_expr>
  local file="$1"
  local expr="$2"
  printf 'yq eval -i %q %q\n' "$expr" "$file"
}

yaml_set() {
  # yaml_set <file> <yq_expr>
  # Example: yaml_set inventory/hosts.yml '.a.b = "x"'
  local file="$1"
  local expr="$2"
  yaml_need_yq || { echo "Missing yq. Run: bash scripts/preflight.sh" >&2; exit 1; }
  if yaml_dry_run_enabled; then
    yaml_print_mutation "$file" "$expr"
    return 0
  fi
  yq eval -i "$expr" "$file"
}

yaml_set_env() {
  # yaml_set_env <file> <yq_expr_using_strenv>
  # Example:
  #   export X=hello
  #   yaml_set_env file.yml '.a = strenv(X)'
  local file="$1"
  local expr="$2"
  yaml_need_yq || { echo "Missing yq. Run: bash scripts/preflight.sh" >&2; exit 1; }
  if yaml_dry_run_enabled; then
    yaml_print_mutation "$file" "$expr"
    return 0
  fi
  yq eval -i "$expr" "$file"
}

