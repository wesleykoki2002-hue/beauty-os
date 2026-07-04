# Athena Spec Management Hardening

## Source

- Project: athena
- Spec key: athena-spec-management-hardening
- Target function: athena-spec-upsert
- GitHub issue: https://github.com/wesleykoki2002-hue/beauty-os/issues/3
- GitHub issue number: 3

## Goal

Harden Athena spec management so specs have stable keys, versioning, summaries, content JSON, and repeatable upsert behavior.

## Requirements

- Specs must use stable spec_key values.
- Specs must support summary and content fields.
- Specs must support repeatable upserts without creating duplicates.
- Spec records must be usable by Athena Context, Dashboard, and GitHub loop tools.
- The implementation must preserve existing spec data.

## Acceptance Criteria

- athena-spec-upsert can create a new spec.
- athena-spec-upsert can update an existing spec by spec_key.
- Athena Dashboard can count specs correctly.
- Athena Context can retrieve spec records cleanly.
- No duplicate spec records are created for the same spec_key.

## Definition of Done

- Spec schema is hardened.
- athena-spec-upsert works for create and update.
- Test result is saved.
- Build step is marked completed.
- GitHub issue, branch, commit, PR, merge, issue close, branch deletion, and full loop summary are completed.