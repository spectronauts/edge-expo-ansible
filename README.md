# edge-expo-ansible

[![Lint](https://github.com/spectronauts/edge-expo-ansible/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/spectronauts/edge-expo-ansible/actions/workflows/lint.yml)

Ansible automation for SpectroCloud Palette edge host registration in SaaS central agent mode.

This repository is intentionally constrained:

- Central mode only
- Palette SaaS endpoint flow only
- No local-management flow
- No private Palette API key flow

## Quick Start

1. Install Ansible on the target host.

```bash
./bootstrap/install-ansible.sh
```

On Linux, this bootstrap step also writes `/etc/sudoers.d/<current-user>` with a `NOPASSWD` sudo rule for the invoking non-root user.

2. Set your registration token in `group_vars/secrets.yml`.

```yaml
---
palette_registration_token: "<your-registration-token>"
```

3. Set your endpoint and options in `group_vars/all.yml`.

```yaml
---
palette_management_mode: central
palette_endpoint: api.spectrocloud.com
palette_use_fips: false
```

4. Run a syntax check.

```bash
ansible-playbook --syntax-check -i inventory/hosts.yml playbooks/install_palette_agent.yml
```

5. Execute the playbook.

```bash
ansible-playbook -i inventory/hosts.yml playbooks/install_palette_agent.yml
```

## Behavior

The playbook runs against the local host by default and does the following:

1. Ensures Python 3 exists.
2. Installs prerequisites (`jq`, `zstd`, `rsync`, `conntrack`, `iptables`, `rsyslog`, and related packages).
3. Renders central registration user-data to `{{ palette_install_workdir }}/user-data`.
4. Downloads the latest SaaS central agent installer script from SpectroCloud agent-mode releases.
5. Runs the installer with `USERDATA` pointing to the rendered registration config.
6. Applies optional Rocky + FIPS host preparation when enabled.

Important:

- This modifies system packages/files.
- Run only on intended edge hosts.
- This repository does not contain local-management appliance extraction logic.

## Repository Layout

- `bootstrap/install-ansible.sh`: Installs Ansible locally.
- `playbooks/install_palette_agent.yml`: Main SaaS central agent mode playbook.
- `playbooks/templates/user-data-central.yml.j2`: Central registration user-data template.
- `inventory/hosts.yml`: Localhost inventory.
- `group_vars/all.yml`: Non-secret settings.
- `group_vars/secrets.yml`: Secret token values.

## Configuration

In `group_vars/secrets.yml`:

```yaml
---
palette_registration_token: ""
```

In `group_vars/all.yml`:

- `palette_management_mode`: fixed to `central`
- `palette_endpoint`: Palette SaaS endpoint host
- `palette_use_fips`: enable FIPS installer variant and Rocky FIPS helper tasks
- `palette_http_proxy` / `palette_https_proxy`: optional proxy env injection
- `palette_external_registries`: optional registry credentials injected into user-data
- `palette_registry_mapping_rules`: optional registry mapping rules injected into user-data
- `palette_site_extra` / `palette_stylus_extra`: optional extension maps merged into user-data

## Validation

Post-run, validate the edge host appears healthy in Palette.

## Lint

```bash
ansible-lint playbooks/install_palette_agent.yml
yamllint playbooks/install_palette_agent.yml group_vars/all.yml group_vars/secrets.yml inventory/hosts.yml
```

## Safety Notes

- This automation changes host configuration.
- Use a dedicated edge host.
- Do not run on an unintended workstation.
