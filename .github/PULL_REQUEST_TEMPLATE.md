<!--
  Auto Release reads the FIRST LINE of the merge commit subject for
  bump markers. Use one of [minor], [major], [skip release] in the
  subject if you want anything other than a default patch bump.
  Documenting markers in this body is fine — only the subject is matched.
-->

## What

<!-- One- or two-line summary of the change. -->

## Why

<!-- The problem or motivation. Link any related issue with `Fixes #123`. -->

## Verification

How was this change tested? Tick what applies; explain anything custom.

- [ ] `ansible-lint` passes locally
- [ ] `yamllint` passes locally
- [ ] `ansible-playbook --syntax-check` passes locally
- [ ] `ansible-playbook tests/render-templates.yml` passes locally
- [ ] Ran the full playbook against a real edge host (note OS / FIPS / connection)
- [ ] N/A — change is docs-only or CI-only

## Release impact

What kind of bump should this PR's merge commit produce?

- [ ] **patch** — default; bug fix, doc, CI, or internal cleanup
- [ ] **`[minor]`** — new variable, new task, additive behavior — no break
- [ ] **`[major]`** — breaking change to playbook contract, variable names, or required behavior on existing hosts
- [ ] **`[skip release]`** — no release for this PR

If `[major]`, list the breaking changes operators need to know about.

## Notes for the reviewer

<!--
  Tradeoffs, follow-ups, things deliberately left out, anything that
  would surprise the reviewer if they read only the diff.
-->
