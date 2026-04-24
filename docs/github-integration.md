---
layout: default
title: GitHub Integration
permalink: /github-integration.html
---

# GitHub Integration — Usage Guide

Operational reference for running githubclip with the GitHub MCP provider.

## Prerequisites

```bash
gh auth status                    # must show authenticated
ls .githubclip/config.yaml         # must exist (run /githubclip-init if not)
cat .githubclip/config.yaml | head -3  # provider: github
```

## Running the Heartbeat

```bash
/heartbeat --dry-run   # preview queue without side effects
/heartbeat             # pick top issue and do work
```

Dry-run is safe to run at any time. It reads the queue and prints what would be picked — no labels, comments, or field mutations.

## How the Queue Works

githubclip fetches all GitHub Project items assigned to the configured `user_name` and filters to:
- Status: `Todo` or `In Progress` only
- No `agent-blocked` label (unless new human comments have been posted since blocking)

**Ranking order:**
1. Status (`In Progress` before `Todo`)
2. Priority (`Urgent > High > Medium > Low > None`)
3. `updated_at` descending (most recently updated wins ties)

**Expected dry-run output:**
```
Dry run — would pick:
  #42 [backend] "Fix auth bug" (In Progress, High)

Queue:
  #17 [frontend] "Update nav" (Todo, Medium)
  #9  [orchestrator] "Triage inbox" (Todo, Low)
```

## Persona Routing

Issues are routed based on their GitHub label:

| Label | Persona | Behavior |
|---|---|---|
| `backend` | Backend | Implementation, tests, APIs |
| `frontend` | Frontend | UI, components, styles |
| `ceo` | CEO | Architecture, strategy, prioritization |
| *(none)* | Orchestrator | Default — triages and routes unlabeled issues |

One persona label per issue. Orchestrator is always the fallback.

## Heartbeat Comments

Every heartbeat posts a comment on the issue:

```
## Heartbeat #N — YYYY-MM-DD HH:MM UTC (Xm Ys)

**Status:** In Progress | Completed | Blocked

### What was done
- Description of work completed

### Next steps
- What comes next

### Blockers
None

---
*githubclip · persona-name · [#N](...) · from [Heartbeat #N-1](...)*
```

The counter `N` is derived from existing comments on the issue — not stored locally. It increments safely across restarts.

## State Transitions

After work completes, the heartbeat updates Project fields and labels based on outcome:

| Outcome | Project Status | Labels |
|---|---|---|
| `completed` | `Done` | remove `agent-working` |
| `blocked` | `In Progress` (unchanged) | remove `agent-working`, add `agent-blocked` |
| `more_work` | `In Progress` (unchanged) | keep `agent-working` |
| `triaged` | `Todo` (unchanged) | add persona label (e.g. `backend`) |

`agent-working` and `agent-blocked` are mutually exclusive — the heartbeat manages this via read-modify-write on the labels array.

## Anti-Fragile Behaviors

### Degradation mode

If a Project field mutation fails, the heartbeat downgrades to read-only for that run. Comments are still posted and labels still applied; only field mutations are skipped. The comment will include a degradation marker (`❌ Degraded`).

### Circuit breaker

After 3 consecutive field mutation failures, all future runs auto-downgrade to read-only. The circuit breaker resets after a successful run with a working config.

### Stale lock cleanup

If `agent-working` has been on an issue longer than `stale_lock_hours` (default: 4 hours), the heartbeat removes it, posts a cleanup comment, and re-queues the issue.

### Schema drift sentry

On startup the heartbeat validates that field IDs in config match the actual GitHub Project schema. On mismatch it stops early with a repair message — no mutations are attempted.

## Debugging Live Issues

### Check the queue manually

```bash
gh issue list --assigned @me --state open
gh project item-list PROJECT_NUMBER --owner OWNER
```

### Check field values on an issue

```bash
gh api graphql -f query='
  query {
    node(id: "ISSUE_NODE_ID") {
      ... on Issue {
        projectItems(first: 1) {
          nodes {
            fieldValues(first: 5) {
              nodes {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  field { ... on ProjectV2FieldCommon { name } }
                }
              }
            }
          }
        }
      }
    }
  }
'
```

### Check heartbeat log

```bash
tail -20 .githubclip/heartbeat-log.jsonl | jq '.'
```

Each line is a JSON record: `timestamp`, `issue`, `heartbeat`, `step`, `status`.

### Common issues

| Symptom | Check | Fix |
|---|---|---|
| No issues in queue | Issues assigned to you? In Project? Status = Todo/In Progress? | Assign issues, add to Project, set Status |
| Wrong queue order | Project Priority/Status values correct? | Update fields via Project UI |
| Field mutations not working | `field_id` values null in config? | Re-run `/githubclip-init` (merge mode) |
| Stuck in read-only | Circuit breaker active? | Fix config, run `/heartbeat` once to reset |
| Persona not routing | Label exactly matches config key? | Check `cat .githubclip/config.yaml \| grep personas -A 20` |

## Refreshing Config

If Project fields are renamed or IDs drift, re-run init in merge mode:

```bash
/githubclip-init   # choose "merge" when prompted
```

Merge mode only adds missing values — it never deletes existing ones. It is safe to run at any time.
