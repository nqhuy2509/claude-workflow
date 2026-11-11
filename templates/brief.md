# Task brief for Antigravity: <task name> (<repo>)

You are implementing ONE approved task in the git worktree below. Work only inside it.

- Worktree: `<absolute worktree path>`
- Repository: `<repo name>` — read its `CLAUDE.md` / `AGENTS.md` first and follow it strictly.
- Branch: `<agy/...>` (already checked out; do NOT switch branches)

## Goal

## Context
<!-- Relevant files, existing patterns to copy, why this change is needed. -->

## What to do
1.

## Allowed paths (do not touch anything else)
- `<path/glob>`

## Shared contract (only when another session works on the other repo in parallel)
<!-- Exact API routes, DTO field names/types, enum values. Do not deviate. -->

## Rules
- Do NOT commit, push, switch branches, or delete files outside the allowed paths.
- Follow the repository conventions in `CLAUDE.md` / `AGENTS.md`. Key rules for this task:
  - <copy the 3–6 rules from CLAUDE.md that matter for this change>
- Keep changes minimal and focused on the goal; no unrelated refactors or formatting churn.
- **Commands:** you may run ONLY commands that start with one of these prefixes:
  <paste allowed-commands.txt, one per line>
  Running anything else (including `cd … &&` chains, pipes, or other tools) is auto-denied and **immediately ends
  your session**, leaving the task unfinished. If a check needs another command, skip it and say so in the report.
- Create `AGY_REPORT.md` early (Status: IN PROGRESS) and update it as you go, so a report exists even if you stop.

## Acceptance criteria
- [ ]

## Self-check commands (run them from the worktree)
```sh
```

## When finished
Create `AGY_REPORT.md` in the worktree root using EXACTLY this structure, then stop:

```md
# AGY Report
## Status
DONE | PARTIAL | BLOCKED
## Changes
- <file>: <what changed>
## Acceptance criteria
- [x] / [ ] <criterion> — <evidence>
## Self-check results
- `<command>`: PASS | FAIL | NOT RUN (<reason>)
## Open issues / questions
- <none or list>
```
