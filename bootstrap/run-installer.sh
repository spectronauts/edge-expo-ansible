#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ALL_VARS_FILE="$REPO_ROOT/group_vars/all.yml"
SECRETS_FILE="$REPO_ROOT/group_vars/secrets.yml"
INVENTORY_FILE="$REPO_ROOT/inventory/hosts.yml"
PLAYBOOK_FILE="$REPO_ROOT/playbooks/install_palette_agent.yml"

color_blue='\033[1;34m'
color_green='\033[1;32m'
color_yellow='\033[1;33m'
color_red='\033[1;31m'
color_reset='\033[0m'

print_header() {
  echo
  printf '%b%s%b\n' "$color_blue" "== $1 ==" "$color_reset"
}

print_info() {
  printf '%b%s%b\n' "$color_green" "$1" "$color_reset"
}

print_warn() {
  printf '%b%s%b\n' "$color_yellow" "$1" "$color_reset"
}

print_error() {
  printf '%b%s%b\n' "$color_red" "$1" "$color_reset" >&2
}

prompt_label() {
  echo >&2
  printf '%b%s%b\n' "$color_blue" "$1" "$color_reset" >&2
}

yaml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

prompt_required() {
  local prompt="$1"
  local value=""
  while true; do
    prompt_label "$prompt"
    read -r -p ">" value
    value="$(trim_whitespace "$value")"
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return 0
    fi
    print_warn "This value is required."
  done
}

prompt_required_secret() {
  local prompt="$1"
  local value=""
  while true; do
    prompt_label "$prompt"
    read -r -s -p ">" value
    echo
    value="$(trim_whitespace "$value")"
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return 0
    fi
    print_warn "This value is required."
  done
}

prompt_with_default() {
  local prompt="$1"
  local default_value="$2"
  local value=""
  prompt_label "$prompt"
  read -r -p ">[$default_value] " value
  value="$(trim_whitespace "$value")"
  if [ -z "$value" ]; then
    value="$default_value"
  fi
  printf '%s' "$value"
}

prompt_yes_no() {
  local prompt="$1"
  local default_value="$2"
  local value=""
  local normalized_default=""

  normalized_default="$(printf '%s' "$default_value" | \
    tr '[:upper:]' '[:lower:]')"

  while true; do
    prompt_label "$prompt"
    read -r -p ">[$normalized_default] " value
    value="$(trim_whitespace "$value")"
    value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"

    if [ -z "$value" ]; then
      value="$normalized_default"
    fi

    case "$value" in
      y|yes|true)
        printf '%s' "true"
        return 0
        ;;
      n|no|false)
        printf '%s' "false"
        return 0
        ;;
      *)
        print_warn "Please answer yes or no."
        ;;
    esac
  done
}

require_integer() {
  local value="$1"
  local label="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    print_error "$label must be an integer."
    exit 1
  fi
}

require_trimmed_value() {
  local value="$1"
  local label="$2"
  local trimmed_value=""

  trimmed_value="$(trim_whitespace "$value")"
  if [ "$value" != "$trimmed_value" ]; then
    print_error "$label contains leading or trailing whitespace."
    exit 1
  fi
}

normalize_endpoint_host() {
  local endpoint="$1"
  endpoint="${endpoint#http://}"
  endpoint="${endpoint#https://}"
  endpoint="${endpoint%%/*}"
  printf '%s' "$endpoint"
}

write_vars_files() {
  local endpoint_host="$1"
  local project_name="$2"
  local use_fips="$3"
  local vip_skip="$4"
  local http_proxy="$5"
  local https_proxy="$6"
  local install_workdir="$7"
  local reboot_after_install="$8"
  local reboot_timeout="$9"
  local registration_token="${10}"

  local backup_suffix=".bak.$(date +%Y%m%d%H%M%S)"

  cp "$ALL_VARS_FILE" "$ALL_VARS_FILE$backup_suffix"
  cp "$SECRETS_FILE" "$SECRETS_FILE$backup_suffix"

  cat >"$ALL_VARS_FILE" <<EOF
---
# This repository only supports Palette SaaS central agent mode installs.
palette_management_mode: central
palette_endpoint: "$(yaml_escape "$endpoint_host")"
palette_project_name: "$(yaml_escape "$project_name")"
palette_use_fips: $use_fips
palette_vip_skip: $vip_skip

palette_http_proxy: "$(yaml_escape "$http_proxy")"
palette_https_proxy: "$(yaml_escape "$https_proxy")"
palette_install_workdir: "$(yaml_escape "$install_workdir")"
palette_reboot_after_install: $reboot_after_install
palette_reboot_timeout: $reboot_timeout

palette_external_registries: []
palette_registry_mapping_rules: {}

palette_site_extra: {}
palette_stylus_extra: {}

palette_configure_cilium_firewalld: false
palette_cilium_firewalld_zone: public
EOF

  cat >"$SECRETS_FILE" <<EOF
---
palette_registration_token: "$(yaml_escape "$registration_token")"
EOF

  if ! grep -Fqx \
      "palette_registration_token: \"$(yaml_escape \"$registration_token\")\"" \
      "$SECRETS_FILE"; then
    print_error "Failed to write registration token exactly as provided."
    exit 1
  fi
}

run_playbook_flow() {
  print_header "Bootstrapping Ansible"
  "$REPO_ROOT/bootstrap/install-ansible.sh"

  print_header "Syntax Check"
  ansible-playbook --syntax-check -i "$INVENTORY_FILE" "$PLAYBOOK_FILE"

  print_header "Running Installer Playbook"
  ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE"
}

print_header "Palette Edge Host Guided Installer"
print_info "This wizard will:"
echo "- Collect install values"
echo "- Write group_vars/all.yml and group_vars/secrets.yml"
echo "- Bootstrap Ansible"
echo "- Run syntax check"
echo "- Execute the install playbook"

registration_token="$(prompt_required "Palette registration token")"
registration_token_no_ws="$(printf '%s' "$registration_token" | \
  tr -d '[:space:]')"
if [ "$registration_token" != "$registration_token_no_ws" ]; then
  print_warn "Whitespace was removed from the registration token input."
fi
registration_token="$registration_token_no_ws"
project_name="$(prompt_required "Palette project name")"
endpoint_input="$(prompt_with_default "Palette endpoint host" \
  "api.spectrocloud.com")"
use_fips="$(prompt_yes_no "Use FIPS installer" "no")"
vip_skip="$(prompt_yes_no "Skip VIP configuration" "no")"
http_proxy="$(prompt_with_default "HTTP proxy (optional)" "")"
https_proxy="$(prompt_with_default "HTTPS proxy (optional)" "$http_proxy")"
install_workdir="$(prompt_with_default "Installer work directory" \
  "/opt/palette-agent")"
reboot_after_install="$(prompt_yes_no "Reboot host after install" "yes")"
reboot_timeout="$(prompt_with_default "Reboot timeout in seconds" "1800")"

require_integer "$reboot_timeout" "Reboot timeout"
require_trimmed_value "$registration_token" "Palette registration token"
require_trimmed_value "$project_name" "Palette project name"

endpoint_host="$(normalize_endpoint_host "$endpoint_input")"
if [ -z "$endpoint_host" ]; then
  print_error "Endpoint host cannot be empty after normalization."
  exit 1
fi

print_header "Configuration Summary"
echo "project_name: $project_name"
echo "endpoint: $endpoint_host"
echo "use_fips: $use_fips"
echo "vip_skip: $vip_skip"
echo "http_proxy: ${http_proxy:-<empty>}"
echo "https_proxy: ${https_proxy:-<empty>}"
echo "install_workdir: $install_workdir"
echo "reboot_after_install: $reboot_after_install"
echo "reboot_timeout: $reboot_timeout"
echo "token: $registration_token"

confirm="$(prompt_yes_no "Proceed with these values" "yes")"
if [ "$confirm" != "true" ]; then
  print_warn "Aborted by user."
  exit 0
fi

print_header "Writing Configuration"
write_vars_files \
  "$endpoint_host" \
  "$project_name" \
  "$use_fips" \
  "$vip_skip" \
  "$http_proxy" \
  "$https_proxy" \
  "$install_workdir" \
  "$reboot_after_install" \
  "$reboot_timeout" \
  "$registration_token"

print_info "Updated group vars files and created timestamped backups."

run_playbook_flow

if grep -q "ansible_connection: local" "$INVENTORY_FILE"; then
  echo
  print_warn "Inventory uses local connection; reboot may require " \
    "manual action depending on host policy."
fi

echo
print_info "Completed guided installation flow."