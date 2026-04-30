#!/usr/bin/env bash

set -euo pipefail

OS="$(uname -s)"

remove_linux_sudoers_nopasswd() {
  local target_user sudoers_file

  if [ "$OS" != "Linux" ]; then
    return 0
  fi

  target_user="${SUDO_USER:-${USER:-}}"
  if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
    return 0
  fi

  sudoers_file="/etc/sudoers.d/$target_user"
  if [ ! -f "$sudoers_file" ]; then
    echo "No sudoers entry at $sudoers_file; nothing to remove."
    return 0
  fi

  echo "Removing $sudoers_file"
  sudo rm -f "$sudoers_file"
}

uninstall_ansible() {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ansible-playbook not found; nothing to uninstall."
    return 0
  fi

  case "$OS" in
    Darwin)
      if command -v brew >/dev/null 2>&1 && brew list ansible >/dev/null 2>&1; then
        brew uninstall ansible
      elif command -v pipx >/dev/null 2>&1 && pipx list 2>/dev/null | grep -q ansible-core; then
        pipx uninstall ansible-core
      else
        echo "Ansible is installed but not via brew or pipx. Remove it manually."
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1 && dpkg -s ansible >/dev/null 2>&1; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y ansible
      elif command -v dnf >/dev/null 2>&1 && rpm -q ansible-core >/dev/null 2>&1; then
        sudo dnf remove -y ansible-core
      elif command -v yum >/dev/null 2>&1 && rpm -q ansible-core >/dev/null 2>&1; then
        sudo yum remove -y ansible-core
      elif command -v pipx >/dev/null 2>&1 && pipx list 2>/dev/null | grep -q ansible-core; then
        pipx uninstall ansible-core
      else
        echo "Ansible is installed but not via apt/dnf/yum/pipx. Remove it manually."
      fi
      ;;
    *)
      echo "Unsupported operating system: $OS" >&2
      exit 1
      ;;
  esac
}

usage() {
  cat <<EOF
Usage: $0 [--keep-ansible] [--keep-sudoers]

Reverses bootstrap/install-ansible.sh:
  - removes /etc/sudoers.d/<your-user> if install-ansible.sh wrote it
  - uninstalls ansible-core via the same package manager it was installed with

Flags:
  --keep-ansible   leave ansible installed; only remove the sudoers entry
  --keep-sudoers   leave the sudoers entry; only uninstall ansible
EOF
}

KEEP_ANSIBLE=0
KEEP_SUDOERS=0
for arg in "$@"; do
  case "$arg" in
    --keep-ansible) KEEP_ANSIBLE=1 ;;
    --keep-sudoers) KEEP_SUDOERS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 1 ;;
  esac
done

if [ "$KEEP_SUDOERS" -eq 0 ]; then
  remove_linux_sudoers_nopasswd
fi

if [ "$KEEP_ANSIBLE" -eq 0 ]; then
  uninstall_ansible
fi

echo "Done."
