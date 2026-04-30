# edge-expo-ansible

[![Lint](https://github.com/spectronauts/edge-expo-ansible/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/spectronauts/edge-expo-ansible/actions/workflows/lint.yml)

Ansible automation that prepares a host as a SpectroCloud Palette **edge host**, registered against Palette SaaS in **central agent mode**.

The default inventory targets `localhost` with `ansible_connection: local`, so the typical workflow is: copy this repo onto the edge host, fill in your token + project, and run the playbook on that host.

## Scope

This repository is intentionally narrow:

- Central agent mode only (no local-management appliance flow)
- Palette SaaS endpoint only (no private API key flow)
- Optional Rocky Linux + FIPS hardening (SELinux module + cgroup v2)
- Optional firewalld configuration for Cilium

If you need a different mode, this is not the right repo.

## Requirements

| | |
|---|---|
| Controller | `ansible-core` >= 2.14 (CI tests with Python 3.12) |
| Target OS | Debian/Ubuntu (apt) **or** RedHat-family — Rocky, RHEL, AlmaLinux (dnf) |
| Target privilege | `root`, or a user with passwordless `sudo` |
| Target Python | Python 3 — installed automatically if missing |
| Network | Outbound HTTPS to `github.com` (installer) and your Palette SaaS endpoint |

The repo uses bare module names (`apt`, `dnf`, `shell`, ...) for compatibility with older Ansible versions, and `.ansible-lint` skips `fqcn[action-core]` for that reason. Keep new tasks consistent with that style.

## Quick Start

> Run these on the edge host itself. The default inventory uses `ansible_connection: local`.

**1. Install Ansible**

```bash
./bootstrap/install-ansible.sh
```

The script installs `ansible-core` via the OS package manager (apt / dnf / yum / brew) or falls back to `pipx`. On Linux, when invoked by a non-root user, it also creates `/etc/sudoers.d/<your-user>` with a `NOPASSWD: ALL` rule so subsequent `become: true` tasks don't prompt.

**2. Set your registration token** in `group_vars/secrets.yml`:

```yaml
---
palette_registration_token: "<your-registration-token>"
```

Get this token from the Palette UI: **Tenant Settings → Registration Token** (or **Project → Registration Token** depending on your tenant layout).

**3. Set your project and endpoint** in `group_vars/all.yml`:

```yaml
palette_project_name: "my-edge-project"     # required
palette_endpoint: api.spectrocloud.com      # default; change for non-default tenants
palette_use_fips: false                     # set true for Rocky FIPS hosts
palette_reboot_after_install: true          # leave true unless using local connection
```

**4. Syntax-check the playbook**

```bash
ansible-playbook --syntax-check -i inventory/hosts.yml playbooks/install_palette_agent.yml
```

**5. Run it**

```bash
ansible-playbook -i inventory/hosts.yml playbooks/install_palette_agent.yml
```

The run takes a few minutes plus a reboot. After it returns, verify the host appears as **Healthy** in the Palette UI under **Clusters → Edge Hosts**.

## What the Playbook Does

| Phase | What happens | Tag |
|---|---|---|
| 1. Bootstrap | Installs Python 3 on the target via raw module | `bootstrap` |
| 2. Validate | Asserts token + project + management mode are present and well-formed | `always` |
| 3. Packages | Refreshes apt/dnf cache and installs prerequisites (`jq`, `zstd`, `rsync`, `conntrack`, `iptables`, `rsyslog`, ...) | `packages`, `prereqs` |
| 4. SELinux *(optional)* | Rocky+FIPS only: enables `rsync_full_access`, compiles a `rsync_dac_override` SELinux module, ensures cgroup v2 in grub, reboots if grub changed, asserts cgroup v2 came up | `selinux` |
| 5. Firewalld *(optional)* | RedHat-family only, when `palette_configure_cilium_firewalld: true`: opens Kubernetes / Cilium ports, ESP, masquerade, reloads only on change | `firewall` |
| 6. Render | Templates the central-mode `user-data` to `{{ palette_install_workdir }}/user-data` (mode `0600`) | `install` |
| 7. Install | Downloads the SaaS installer from `github.com/spectrocloud/agent-mode/releases/latest`, runs it with `USERDATA` set, captures output to `/var/log/palette-agent-install.log`. Idempotent: skipped if `spectro-palette-agent-bootstrap.service` already exists. On failure, a rescue block prints the install log + recent journal | `install` |
| 8. Reboot | Reboots so registration stages can run. Skipped when `ansible_connection: local` (manual reboot required). | `install`, `reboot` |
| 9. Services | Enables the seven `spectro-palette-agent-*` units, starts the network/bootstrap/reconcile services, disables `spectro-palette-tui.service` | `services` |
| 10. Validate | Asserts the agent services produced journal entries; prints next-step summary | `validation` |

## Configuration Reference

### `group_vars/secrets.yml`

| Variable | Required | Description |
|---|---|---|
| `palette_registration_token` | yes | Edge registration token from the Palette UI. Whitespace is rejected. |

### `group_vars/all.yml`

| Variable | Default | Description |
|---|---|---|
| `palette_management_mode` | `central` | Locked. Only `central` is supported. |
| `palette_endpoint` | `api.spectrocloud.com` | Palette SaaS endpoint. `https://` and trailing paths are stripped automatically. |
| `palette_project_name` | `""` | **Required.** Palette project name to register the host into. |
| `palette_use_fips` | `false` | Use the FIPS installer variant and apply Rocky FIPS prep. |
| `palette_vip_skip` | `false` | Skip VIP setup in the rendered user-data (Stylus `disableTui`/`vip` config). |
| `palette_install_workdir` | `/opt/palette-agent` | Where `user-data` and the installer script are written on the target. |
| `palette_installer_checksum` | `""` | Optional `sha256:abc123...` checksum verified against the downloaded installer. Empty = skip verification. |
| `palette_reboot_after_install` | `true` | Reboot after install. Recommended `true`; ignored on `ansible_connection: local`. |
| `palette_reboot_timeout` | `1800` | Max seconds to wait for a reboot to complete. |
| `palette_http_proxy` / `palette_https_proxy` | `""` | Injected as `HTTP_PROXY`/`HTTPS_PROXY` env into `get_url` and the installer. |
| `palette_external_registries` | `[]` | Registry credentials merged into the rendered user-data. |
| `palette_registry_mapping_rules` | `{}` | Registry mapping rules merged into the rendered user-data. |
| `palette_site_extra` / `palette_stylus_extra` | `{}` | Extra map merged into the `site` / `stylus` sections of user-data. |
| `palette_configure_cilium_firewalld` | `false` | Open Kubernetes + Cilium ports in firewalld. RedHat-family only. |
| `palette_cilium_firewalld_zone` | `public` | firewalld zone used by the rule additions above. |
| `palette_disable_tui` | `true` | Suppress the Palette TUI on this edge host. When `true`, masks `spectro-palette-tui.service`, drops a systemd preset pinning it disabled, and renders `stylus.disableTui: true` into user-data so cluster deploy can't re-enable it. Set `false` if you want the TUI available. |

## Selective Runs

Tasks are tagged so you can re-run a single phase or skip one:

```bash
# Just refresh prerequisite packages
ansible-playbook -i inventory/hosts.yml playbooks/install_palette_agent.yml --tags packages

# Re-run only the post-install validation
ansible-playbook -i inventory/hosts.yml playbooks/install_palette_agent.yml --tags validation

# Skip the post-install reboot
ansible-playbook -i inventory/hosts.yml playbooks/install_palette_agent.yml --skip-tags reboot
```

Available tags: `bootstrap`, `prereqs`, `packages`, `selinux`, `firewall`, `install`, `reboot`, `services`, `validation`.

`always`-tagged tasks (assertions, fact lookups, the installed-state stat) run regardless of `--tags`, so partial runs don't fail with undefined variables.

## Idempotency

Re-running the playbook on a host that's already provisioned is safe:

- The installer is gated by a `stat` on `/etc/systemd/system/spectro-palette-agent-bootstrap.service`. If present, download + execute + post-install reboot are skipped.
- firewalld rule additions detect `ALREADY_ENABLED` in stderr and report `not changed`. `firewall-cmd --reload` only fires when at least one rule actually changed.
- SELinux boolean / module / grub edits each check current state before mutating.

To force a reinstall, remove the bootstrap unit file (`rm /etc/systemd/system/spectro-palette-agent-bootstrap.service`) before re-running.

## Troubleshooting

**Installer fails:** the rescue block prints the tail of `/var/log/palette-agent-install.log` and `journalctl -n 200`. Read those first.

**Host doesn't appear in Palette UI:** check the agent services on the target.

```bash
systemctl status spectro-palette-agent-bootstrap.service
journalctl -u spectro-palette-agent-bootstrap.service -n 200 --no-pager
```

**Behind a proxy:** set `palette_http_proxy` / `palette_https_proxy` in `group_vars/all.yml`. They're injected into the installer download and execution.

**Local connection skips reboot:** by design, to avoid rebooting your workstation. Reboot the edge host manually after the run for the boot-time registration stages to execute.

## Repository Layout

```
edge-expo-ansible/
├── ansible.cfg                                     # inventory path, pipelining
├── bootstrap/install-ansible.sh                    # installs ansible-core
├── group_vars/
│   ├── all.yml                                     # non-secret config
│   └── secrets.yml                                 # registration token
├── inventory/hosts.yml                             # localhost inventory
└── playbooks/
    ├── install_palette_agent.yml                   # main playbook
    └── templates/user-data-central.yml.j2          # rendered to user-data
```

## Lint

```bash
ansible-lint playbooks/install_palette_agent.yml
yamllint playbooks/install_palette_agent.yml group_vars/ inventory/
shellcheck bootstrap/install-ansible.sh
```

CI runs all three on every push and pull request to `main`.

## Safety Notes

- This automation modifies system packages, systemd units, SELinux policy, firewalld rules, and `/etc/default/grub`. Run it only on hosts you intend to dedicate to Palette edge use.
- The bootstrap script grants `NOPASSWD: ALL` sudo to the invoking user. Do not run on a shared workstation.
- The registration token is sensitive. Do not commit a populated `group_vars/secrets.yml` to a public repo.
