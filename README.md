# edge-expo-ansible

[![Lint](https://github.com/spectronauts/edge-expo-ansible/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/spectronauts/edge-expo-ansible/actions/workflows/lint.yml)

edge-expo-ansible is Ansible automation for SpectroCloud Palette Agent installation.

The edge-expo-ansible repository automates SpectroCloud Agent Mode host installation based on the official guide:

- https://docs.spectrocloud.com/deployment-modes/agent-mode/install-agent-host/

It supports:

- Central management mode
- Local management mode
- Rocky Linux FIPS pre-configuration (SELinux policy + cgroup v2 flow)

## Quick Start

Use this checklist for a first run.

1. Install Ansible on the local host.

```bash
./bootstrap/install-ansible.sh
```

On Linux, this bootstrap step also writes `/etc/sudoers.d/<current-user>` with a `NOPASSWD` sudo rule for the invoking non-root user.

2. Set secrets in group_vars/secrets.yml.

```yaml
---
palette_registration_token: "<your-registration-token>"
palette_api_key: "<optional-api-key>"
```

3. Set runtime mode and endpoint in group_vars/all.yml.

```yaml
---
palette_management_mode: central  # or local
palette_instance_type: saas       # or private
palette_endpoint: api.spectrocloud.com
palette_use_fips: false
```

4. Run a syntax check.

```bash
ansible-playbook --syntax-check playbooks/install_palette_agent.yml
```

5. Run the installer playbook.

```bash
ansible-playbook playbooks/install_palette_agent.yml
```

Important: this runs on localhost, modifies system packages/files, and may reboot the machine.

## High-level behavior

The automation is localhost-only. Ansible runs on the same machine that will become the edge host.

The playbook performs these phases:

1. Ensure Python 3 exists on the host (for Ansible modules).
2. Install Agent Mode prerequisites (jq, zstd, rsync, conntrack, iptables, rsyslog, etc.) using apt or dnf.
3. Build user-data from templates.
4. Download the correct installer artifact based on mode and FIPS settings.
5. Run installation flow:
   - Central mode: executes installer script with USERDATA and waits for reboot if enabled.
   - Local mode: downloads and extracts airgap tarball to /, writes /var/lib/spectro/userdata, reboots.
6. Optionally apply Rocky FIPS-specific SELinux/cgroup/firewalld tasks when configured.

## Repository layout

- bootstrap/install-ansible.sh
  - Installs Ansible on the local machine before running the playbook.
- playbooks/install_palette_agent.yml
  - Main automation playbook.
- playbooks/templates/user-data-central.yml.j2
  - User-data template for central mode.
- playbooks/templates/user-data-local.yml.j2
  - User-data template for local mode.
- inventory/hosts.yml
  - Localhost inventory using local connection.
- group_vars/all.yml
  - Non-secret defaults and behavior flags.
- group_vars/secrets.yml
  - Secret values used by the playbook.

## What you need before running

## 1) Host prerequisites

- Linux host supported by your SpectroCloud deployment target.
- Sudo/root access on the host.
- Internet or mirror/proxy access for package/artifact downloads (unless fully pre-staged).
- For central mode: valid Palette registration token.
- For private/dedicated Palette or local mode without fixed version: Palette API key (optional if you set explicit version).

## 2) Control prerequisites

- Bash shell available.
- Ansible available locally (use bootstrap script below).

Install Ansible:

```bash
./bootstrap/install-ansible.sh
```

On Linux, the bootstrap script also creates `/etc/sudoers.d/<current-user>` with a `NOPASSWD` sudo rule for the invoking non-root user.

## 3) Required files to edit

- group_vars/secrets.yml
- group_vars/all.yml

The inventory already targets localhost, so no host entry changes are needed unless you customize inventory grouping.

## Configuration details

## Required variables

In group_vars/secrets.yml:

```yaml
---
palette_registration_token: ""
palette_api_key: ""
```

Set values according to your mode:

- Central mode:
  - Required: palette_registration_token
- Local mode:
  - Required: palette_agent_version OR palette_api_key

## Core behavior variables (group_vars/all.yml)

- palette_management_mode
  - central or local
- palette_instance_type
  - saas or private
- palette_endpoint
  - Example: api.spectrocloud.com
- palette_use_fips
  - true uses FIPS artifacts and Rocky FIPS logic when applicable
- palette_wait_for_reboot
  - true waits for reboot/return during central install

## Mode and version resolution logic

- Central + saas:
  - Downloads latest installer script from GitHub release latest.
- Central + private:
  - Uses palette_agent_version if set, otherwise queries Palette stylus endpoint using palette_api_key.
- Local mode:
  - Uses palette_agent_version if set, otherwise queries Palette stylus endpoint using palette_api_key.
  - Downloads architecture-specific airgap tarball and extracts to /.

## Proxy and registry settings

- palette_http_proxy / palette_https_proxy
  - Injected into download/query tasks as lower and upper case proxy env vars.
- palette_external_registries
  - Optional list for external registry credentials in rendered user-data.
- palette_registry_mapping_rules
  - Optional dictionary for registry mapping in user-data.
- palette_site_extra / palette_stylus_extra / palette_userdata_extra_initramfs
  - Optional extension points to inject additional supported configuration.

## FIPS and Rocky-specific options

When palette_use_fips is true and distribution is Rocky:

- Enables rsync SELinux boolean.
- Builds and installs the rsync SELinux policy module.
- Ensures cgroup v2 is enabled, updating grub and rebooting if required.
- Optional firewalld rules for Cilium when palette_configure_cilium_firewalld is true.

## How to run

## 1) Dry syntax check

```bash
ansible-playbook --syntax-check playbooks/install_palette_agent.yml
```

## 2) Execute

```bash
ansible-playbook playbooks/install_palette_agent.yml
```

Because this config is localhost-only, use caution: it modifies the current machine and can reboot it.

## 3) Optional verbose run

```bash
ansible-playbook -vvv playbooks/install_palette_agent.yml
```

## Post-run validation

- Central mode:
  - Confirm edge host is registered and healthy in Palette.
- Local mode:
  - Confirm host/cluster status in Local UI.

These UI validations are manual and intentionally not automated in the playbook.

## Lint and quality checks

Run locally:

```bash
ansible-lint playbooks/install_palette_agent.yml
yamllint playbooks/install_palette_agent.yml group_vars/all.yml group_vars/secrets.yml inventory/hosts.yml
```

## Release process

Releases are not created on every push. They are created when you push a
SemVer tag (`v*.*.*` or `*.*.*`) or when you manually run the `Release`
workflow.

Create and push a release tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

You can also use a tag without the `v` prefix, for example `1.0.0`.

The release workflow validates lint checks and then creates a GitHub Release
with autogenerated notes.

## Troubleshooting quick notes

- Missing token/API key:
  - The playbook has assertion checks and fails early.
- Download failures:
  - Verify proxy settings and outbound access to GitHub/Palette endpoint.
- Reboot disconnect behavior:
  - Expected during install. Keep palette_wait_for_reboot true to allow reconnect wait logic.
- Local mode artifact mismatch:
  - Confirm architecture and version are valid for selected artifact type (FIPS vs non-FIPS).

## Safety notes

- This automation installs packages, writes system files, and may reboot the host.
- Do not run on an unintended workstation.
- Validate mode, endpoint, and credentials before execution.