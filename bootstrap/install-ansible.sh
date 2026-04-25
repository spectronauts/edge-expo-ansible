#!/usr/bin/env bash

set -euo pipefail

if command -v ansible-playbook >/dev/null 2>&1; then
  ansible-playbook --version
  exit 0
fi

OS="$(uname -s)"

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