# Security Policy

## Reporting a Vulnerability

If you've found a security issue in this repository's playbook, templates, or bootstrap scripts, please **report it privately** instead of opening a public issue.

Use GitHub's private vulnerability reporting form:

> Repository → **Security** tab → **Report a vulnerability**

Include:

- A clear description of the issue and the impact
- Steps to reproduce, or a proof-of-concept if you have one
- The branch or commit you observed it on
- Any suggested mitigation, if you have one

You will get an acknowledgement within a reasonable window. Coordinated disclosure timing will be agreed before any public write-up.

## Scope

In scope:

- Code in this repository — the Ansible playbook, Jinja templates, bootstrap scripts, GitHub Actions workflows
- Anything this code does on a target host that an operator wouldn't reasonably expect from running the documented commands

Out of scope:

- Behavior of upstream products this repository does not own
- Vulnerabilities in third-party dependencies (Ansible, GitHub Actions actions). Report those upstream; if the impact is uniquely amplified by how this repo uses them, that part is in scope.
- Issues that require a malicious operator who already has root or `NOPASSWD` sudo on the target host

## Hardening Notes for Operators

If you run this code, treat the following as security-relevant:

- The bootstrap script grants `NOPASSWD: ALL` sudo to the invoking user. Run only on hosts you intend to dedicate to the agent role.
- The playbook downloads an installer from GitHub releases at run time. Set `palette_installer_checksum` in `group_vars/all.yml` so the download is verified before execution.
- Keep `group_vars/secrets.yml` out of source control (it is gitignored by default; do not remove that entry).
