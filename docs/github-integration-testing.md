# GitHub Integration — Validation Guide

Step-by-step testing for all 4 phases of the GitHub MCP implementation.
**Total estimated time:** ~60 minutes

## Prerequisites

```bash
gh auth status                        # must show authenticated
git remote -v | grep github           # must be in a GitHub repo
```

Create a dedicated test project in GitHub UI: **Projects → New Project → Table → "WoterClip Test"**

---

## Phase 1: Read-Only Dry-Run (15 min)

**Goal:** Verify queue building, ranking, and persona routing.

### Setup

Create 5 test issues, all assigned to yourself:

| Issue | Label | Project Status | Priority |
|---|---|---|---|
| "Backend Work" | `backend` | In Progress | High |
| "Frontend Task" | `frontend` | Todo | Medium |
| "Review Doc" | *(none)* | Todo | Low |
| "Blocked Item" | `agent-blocked` | In Progress | None |
| "In Review" | *(any)* | In Review | None |

### Initialize

```bash
/woterclip-init
# Confirm repo: owner/repo
# Select project: "WoterClip Test"
# Choose preset: engineering
```

Verify `.woterclip/config.yaml` created with non-null `field_id` values and labels created in repo.

### Run

```bash
/heartbeat --dry-run
```

### Validate

- [ ] "Backend Work" (In Progress, High) appears as picked issue
- [ ] "Frontend Task" (Todo, Medium) appears in queue second
- [ ] "Review Doc" (Todo, Low) appears in queue third
- [ ] "Blocked Item" excluded (has `agent-blocked` label)
- [ ] "In Review" excluded (status not Todo/In Progress)
- [ ] "Review Doc" shows `[orchestrator]` tag (no persona label → default)
- [ ] Output format matches:
  ```
  Dry run — would pick:
    #X [backend] "Backend Work" (In Progress, High)

  Queue:
    #Y [frontend] "Frontend Task" (Todo, Medium)
    #Z [orchestrator] "Review Doc" (Todo, Low)
  ```

### Troubleshoot

| Problem | Check | Fix |
|---|---|---|
| No issues in queue | Assigned to you? In Project? Status = Todo/In Progress? | Assign, add to Project, set Status |
| Wrong ranking | Project field values set correctly? | Update via Project UI |
| Persona not detected | Label exactly matches config key? | `cat .woterclip/config.yaml \| grep personas -A 20` |

---

## Phase 2: Comment Operations and Locking (10 min)

**Goal:** Verify heartbeat comments, counter increments, and label locking.

### Run

Pick the top-priority test issue (no existing comments). Run:

```bash
/heartbeat
```

### Validate — First Heartbeat

- [ ] Comment posted with header `## Heartbeat #1 — YYYY-MM-DD HH:MM UTC (Xm Ys)`
- [ ] Comment has Status, What was done, Next steps, Blockers sections
- [ ] Footer: `*WoterClip · persona-name · [#N](...)*`
- [ ] `agent-working` label applied to issue
- [ ] Issue remains open

### Validate — Counter Increment

Run heartbeat again on the same issue:

```bash
/heartbeat
```

- [ ] New comment with `Heartbeat #2`
- [ ] Footer links to previous: `from [Heartbeat #1](...)`
- [ ] No duplicate `agent-working` labels

### Troubleshoot

| Problem | Check | Fix |
|---|---|---|
| No comment posted | Dry-run works? Persona TOOLS.md has GitHub tools? | Check persona config |
| Counter wrong | View all comments: `gh issue view N --comments` | Counter resets cleanly on next run |
| Label not applied | Label exists? `gh label list \| grep agent-working` | Re-run `/woterclip-init` |

---

## Phase 3: Project Field Mutations (15 min)

**Goal:** Verify Project Status/Priority field updates on work completion.

### Run

Pick the "Frontend Task" issue (Status=Todo, Priority=Medium). Run:

```bash
/heartbeat
```

### Validate — Status Transitions

Check Project UI and confirm field updated based on outcome:

| Outcome | Expected Status | Expected Labels |
|---|---|---|
| `completed` | `Done` | `agent-working` removed |
| `blocked` | `In Progress` | `agent-working` removed, `agent-blocked` added |
| `more_work` | `In Progress` | `agent-working` stays |
| `triaged` | `Todo` | persona label added |

Verify via CLI:

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

### Validate — Tie-Break Ordering

Create two issues with identical Status and Priority but different `updated_at`. The more recently updated one must be picked first.

- [ ] Status transition matches outcome table above
- [ ] `agent-working` removed on completion
- [ ] Correct issue picked first in tie-break scenario

### Troubleshoot

| Problem | Check | Fix |
|---|---|---|
| Status not updating | `field_id` null in config? | Re-run `/woterclip-init` (merge mode) |
| Permission error | Project role = Admin or Editor? | Check Project → Settings |

---

## Phase 4: Anti-Fragile Behaviors (20 min)

**Goal:** Verify degradation, circuit breaker, recovery journal, drift sentry, and idempotent re-init.

### Setup

```bash
cp .woterclip/config.yaml .woterclip/config.yaml.working
```

### 4.1 Progressive Degradation

```bash
sed -i '' 's/PVT_FIELD_1/PVT_FIELD_INVALID/g' .woterclip/config.yaml
/heartbeat
cp .woterclip/config.yaml.working .woterclip/config.yaml
```

- [ ] Heartbeat completes without crash
- [ ] Comment posted in read-only mode
- [ ] Comment has degradation marker (`❌ Degraded` or similar)
- [ ] No field mutations attempted

### 4.2 Circuit Breaker

```bash
sed -i '' 's/PVT_FIELD_1/PVT_FIELD_INVALID/g' .woterclip/config.yaml
/heartbeat
/heartbeat
/heartbeat
cp .woterclip/config.yaml.working .woterclip/config.yaml
/heartbeat   # should succeed and reset circuit breaker
```

- [ ] After 3 failures: comment indicates circuit breaker triggered
- [ ] Read-only mode active (no mutations attempted)
- [ ] Recovery run succeeds and resets

### 4.3 Recovery Journal

```bash
tail -10 .woterclip/heartbeat-log.jsonl | jq '.'
```

- [ ] File exists at `.woterclip/heartbeat-log.jsonl`
- [ ] Each line is valid JSON with: `timestamp`, `issue`, `heartbeat`, `step`, `status`
- [ ] Entries cover all heartbeat runs

### 4.4 Schema Drift Sentry

```bash
sed -i '' 's/PVT_FIELD_1/PVT_FIELD_INVALID/g' .woterclip/config.yaml
/heartbeat
cp .woterclip/config.yaml.working .woterclip/config.yaml
```

- [ ] Heartbeat detects drift and stops early
- [ ] Message indicates "schema drift" or "field mismatch"
- [ ] No mutations attempted

### 4.5 Idempotent Re-Init

```bash
cp .woterclip/config.yaml .woterclip/config.yaml.pre-reinit
/woterclip-init   # choose "merge"
diff .woterclip/config.yaml.pre-reinit .woterclip/config.yaml
/woterclip-init   # run again
diff .woterclip/config.yaml.pre-reinit .woterclip/config.yaml
```

- [ ] First diff shows no changes
- [ ] Second diff shows no changes (idempotent)

---

## Final Verification

```bash
# No stale Linear references
grep -r "mcp__claude_ai_Linear" .woterclip/ && echo "FOUND (BAD)" || echo "✓ None"

# Config is valid YAML
python3 -c "import yaml; yaml.safe_load(open('.woterclip/config.yaml'))" && echo "✓ Valid"

# Required labels exist
gh label list | grep -E "agent-working|agent-blocked"

# Heartbeat log populated
wc -l .woterclip/heartbeat-log.jsonl
```

All 4 phases passing:

- [ ] Phase 1: dry-run queue/ranking/routing ✅
- [ ] Phase 2: comments/counter/locking ✅
- [ ] Phase 3: field mutations/transitions ✅
- [ ] Phase 4: anti-fragile mechanisms ✅

## Cleanup

```bash
rm .woterclip/config.yaml.working .woterclip/config.yaml.pre-reinit

# Delete test labels (optional)
gh label delete agent-working agent-blocked -y --repo owner/repo

# Delete test issues and project via GitHub UI
```

## Next Steps

1. Delete test issues and project
2. Run `/heartbeat` on real production issues
3. Monitor `.woterclip/heartbeat-log.jsonl` for errors
4. Adjust persona `SOUL.md` files for your team's workflows
