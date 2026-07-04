# Athena Loop Runner Spec

## Source

- Project: athena
- Spec key: athena-loop-runner
- Target function: athena-loop-runner
- GitHub issue: https://github.com/wesleykoki2002-hue/beauty-os/issues/9
- GitHub issue number: 9

## Goal

Build Athena Loop Runner so Athena can guide or eventually automate the full engineering loop with fewer manual steps.

## Problem

Athena can complete the full GitHub engineering loop, but the process still requires many manual PowerShell commands.

The current loop is:

Spec ? Issue ? Branch ? Commit ? PR ? Sync ? Merge ? Close Issue ? Delete Branch ? Full Loop Summary

Athena Loop Runner should reduce this manual work by identifying the next missing step and returning one clear action.

## Requirements

- Accept project_key, source_type, and source_key.
- Read the target spec or build step.
- Determine the next missing loop step.
- Return one clear next action.
- Support safe dry-run behavior.
- Use athena-full-loop-summary as source of truth.
- Eventually coordinate issue create, issue link, branch create, file commit, PR create, PR sync, PR merge, issue close, branch cleanup, and full loop summary.
- Never skip safety checks for PR merge, issue close, or branch cleanup.

## Acceptance Criteria

- Athena Loop Runner can identify whether a spec has no issue, no branch, no commit, no PR, no merge, no issue close, no branch deletion, or no full loop summary.
- Athena Loop Runner returns one clear next step.
- Athena Loop Runner can use athena-full-loop-summary as its source of truth.
- Athena Dashboard can show the Loop Runner spec.
- The Loop Runner spec can complete the same full GitHub loop as previous specs.

## Definition of Done

- Spec is created.
- GitHub issue is created and linked.
- Branch is created.
- Spec documentation is committed.
- PR is created, synced, merged, and logged.
- Issue is closed.
- Branch is deleted or synced as deleted.
- Full loop summary returns completed with 10/10 steps.

## Safety Rules

Athena Loop Runner must not blindly execute destructive actions.

Required safe behavior:

- PR merge requires a synced, mergeable, clean PR unless force_merge is explicitly enabled.
- Issue close requires linked PR merged unless force_close is explicitly enabled.
- Branch cleanup requires merged PR and closed issue unless force_delete is explicitly enabled.
- Dry run must be supported for every destructive step.
- The runner should prefer recommending one next step before attempting automation.

## Long-Term Direction

Version 1 should guide the user through the next missing step.

Later versions can evolve into:

- semi-automatic loop runner
- full loop orchestration
- GitHub issue/PR state machine
- dashboard-driven engineering command center
- reusable build pipeline for Athena, Hermes, Apollo, Hanna, and BeautyDNA