#!/usr/bin/env bash

set -euo pipefail

OS="$(uname -s)"

ensure_linux_sudoers_nopasswd() {
  local target_user sudoers_file tmp_file

  if [ "$OS" != "Linux" ]; then
    return 0
  fi

  target_user="${SUDO_USER:-${USER:-}}"
  if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
    return 0
  fi

  sudoers_file="/etc/sudoers.d/$target_user"
  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' RETURN

  printf '%s\n' "$target_user ALL=(ALL) NOPASSWD:ALL" >"$tmp_file"

  if command -v visudo >/dev/null 2>&1; then
    visudo -cf "$tmp_file"
  fi

  sudo install -o root -g root -m 0440 "$tmp_file" "$sudoers_file"
}

install_with_pipx() {
  if command -v pipx >/dev/null 2>&1; then
    pipx install --include-deps ansible-core
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -m pip install --user ansible-core
    return 0
  fi

  return 1
}

ensure_linux_sudoers_nopasswd

if command -v ansible-playbook >/dev/null 2>&1; then
  ansible-playbook --version
  exit 0
fi

case "$OS" in
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      brew install ansible
    elif ! install_with_pipx; then
      echo "Unable to install Ansible automatically on macOS. Install Homebrew or pipx, then rerun this script." >&2
      exit 1
    fi
    ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ansible
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y ansible-core
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y ansible-core
    elif ! install_with_pipx; then
      echo "Unable to install Ansible automatically on Linux. Install ansible-core with your package manager or pipx, then rerun this script." >&2
      exit 1
    fi
    ;;
  *)
    echo "Unsupported operating system: $OS" >&2
    exit 1
    ;;
esac

ansible-playbook --version