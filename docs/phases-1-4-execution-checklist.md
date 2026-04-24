# Phases 1-4 Execution Checklist

**Status:** Ready for execution in your GitHub repository
**Date:** 2026-04-24
**Implementation:** All code/docs complete; testing pending

---

## Overview

This checklist tracks your progress through all 4 execution phases. Each phase validates specific aspects of the GitHub MCP implementation.

**Estimated Duration:**
- Phase 1 (dry-run): 15 minutes
- Phase 2 (comments/labels): 10 minutes
- Phase 3 (field mutations): 15 minutes
- Phase 4 (anti-fragile): 20 minutes
- **Total: ~60 minutes**

---

## Phase 1: Read-Only Dry-Run Validation

**Goal:** Verify queue building, ranking, and persona routing work correctly

### Setup (5 min)

- [ ] `gh auth status` shows authenticated
- [ ] In a GitHub repository directory
- [ ] Create GitHub Project (v2) named "WoterClip Test"
- [ ] Create 5 test issues:
  - [ ] Issue #X: "Backend Work" (backend label, assigned to self)
  - [ ] Issue #Y: "Frontend Task" (frontend label, assigned to self)
  - [ ] Issue #Z: "Review Doc" (no label, assigned to self)
  - [ ] Issue #A: "Blocked" (agent-blocked label, assigned to self)
  - [ ] Issue #B: "Extra" (any label, assigned to self)
- [ ] Add all issues to Project with Status/Priority values:
  - [ ] #X: In Progress, High
  - [ ] #Y: Todo, Medium
  - [ ] #Z: Todo, Low
  - [ ] #A: In Progress, None
  - [ ] #B: In Review, None

### Initialization (5 min)

- [ ] Run `/woterclip-init` in Claude Code
- [ ] Confirm repo: `owner/repo`
- [ ] Select project: "WoterClip Test"
- [ ] Choose persona: "engineering"
- [ ] Config created at `.woterclip/config.yaml`
- [ ] Fields resolved and saved (field_ids are not null)
- [ ] Labels created: `agent-working`, `agent-blocked`, `backend`, `frontend`, `ceo`

### Dry-Run Test (5 min)

- [ ] Run `/heartbeat --dry-run`
- [ ] No errors during execution
- [ ] Output shows issues from your test set

### Validation

- [ ] **Queue Ranking:**
  - [ ] Issue #X (In Progress, High) appears first
  - [ ] Issue #Y (Todo, Medium) appears second (different status, lower priority)
  - [ ] Issue #Z (Todo, Low) appears third (same status, lower priority)
  - [ ] Issue #A not in queue (In Review status excluded)
  - [ ] Issue #B not in queue (agent-blocked label)

- [ ] **Persona Routing:**
  - [ ] Issue #X shows `[backend]` tag
  - [ ] Issue #Y shows `[frontend]` tag
  - [ ] Issue #Z shows `[orchestrator]` tag (no persona label → default)

- [ ] **Output Format:**
  ```
  Dry run — would pick:
    #X [backend] "Backend Work" (In Progress, High)
  
  Queue:
    #Y [frontend] "Frontend Task" (Todo, Medium)
    #Z [orchestrator] "Review Doc" (Todo, Low)
  ```

### Phase 1 Status

- [ ] **✅ PASSED** - All checks passed, queue ranking is correct
- [ ] **⚠️ PARTIAL** - Most checks passed, minor issues (list below)
- [ ] **❌ FAILED** - Issues require investigation (list below)

**Issues/Notes:**
```
[List any issues here]
```

---

## Phase 2: Comment Operations and Locking

**Goal:** Verify heartbeat comments, counter increments, and label locking work

### Setup (5 min)

- [ ] Completed Phase 1 successfully
- [ ] Pick one test issue (e.g., #X "Backend Work")
- [ ] Ensure it has no comments yet

### First Heartbeat Run (5 min)

- [ ] Run `/heartbeat` (not dry-run)
- [ ] Heartbeat completes without error
- [ ] No timeouts or stuck operations

### Comment Validation (5 min)

- [ ] Comment posted on the issue
- [ ] Comment includes `Heartbeat #1` (first heartbeat)
- [ ] Timestamp shows current date/time (UTC)
- [ ] Duration is shown (e.g., "2m 34s")
- [ ] Persona name is in footer (e.g., "backend" or "orchestrator")
- [ ] Issue link is correct: `[#X](...)`
- [ ] Comment has structure:
  - [ ] Title: `## Heartbeat #1 — YYYY-MM-DD HH:MM UTC (Xm Ys)`
  - [ ] Status line: `**Status:** In Progress | Completed | Blocked`
  - [ ] Sections: What was done, Next steps, Blockers
  - [ ] Footer: `*WoterClip · persona-name · [#X](...)*`

### Label Lock Validation (5 min)

- [ ] Issue has `agent-working` label after heartbeat
- [ ] Label is visible in issue UI
- [ ] No other unexpected labels added

### Counter Increment Test (5 min)

- [ ] Run `/heartbeat --dry-run` again on same issue
- [ ] Issue #X still at top of queue
- [ ] Run `/heartbeat` again (second time)
- [ ] New comment posted
- [ ] Counter is now `Heartbeat #2`
- [ ] Footer includes link to previous comment: `from [Heartbeat #1](...)`
- [ ] No duplicate labels (only one `agent-working`)

### Phase 2 Status

- [ ] **✅ PASSED** - Comments posted correctly, counter incremented
- [ ] **⚠️ PARTIAL** - Some issues (list below)
- [ ] **❌ FAILED** - Requires investigation (list below)

**Issues/Notes:**
```
[List any issues here]
```

---

## Phase 3: Project Field Mutations

**Goal:** Verify Project Status/Priority field updates work correctly

### Setup (5 min)

- [ ] Completed Phase 2 successfully
- [ ] Pick another test issue (e.g., #Y "Frontend Task")
- [ ] Verify it has Status=Todo, Priority=Medium in Project

### Single Field Update (5 min)

- [ ] Note current Project Status (should be "Todo")
- [ ] Run `/heartbeat` to work on #Y
- [ ] Heartbeat completes

### Field Update Validation (10 min)

- [ ] Comment posted on issue
- [ ] Go to Project → view issue row
- [ ] Status field has changed:
  - [ ] If work "completed": Status = "Done"
  - [ ] If work "blocked": Status = "In Progress" + `agent-blocked` label
  - [ ] If work "in progress": Status = "In Progress" (unchanged)
  - [ ] If "triaged": Status = "Todo" (unchanged)

- [ ] Verify via GitHub CLI:
  ```bash
  gh api graphql -f query='
    query {
      node(id: "ISSUE_ID") {
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

### Label Updates (5 min)

- [ ] On completion:
  - [ ] `agent-working` label removed
  - [ ] Issue remains open (unless close_on_done config is true)

- [ ] On blocked:
  - [ ] `agent-working` removed
  - [ ] `agent-blocked` added
  - [ ] Status = "In Progress" (not changed to Done)

### Multiple Issues Test (5 min)

- [ ] Pick two more test issues with same status/priority
- [ ] Run heartbeat multiple times
- [ ] Verify correct one is picked first (by updated_at order)
- [ ] Verify second is picked on next heartbeat run

### Phase 3 Status

- [ ] **✅ PASSED** - Field mutations work, status transitions correct
- [ ] **⚠️ PARTIAL** - Some field updates work (list below)
- [ ] **❌ FAILED** - Field mutations not working (list below)

**Issues/Notes:**
```
[List any issues here]
```

---

## Phase 4: Anti-Fragile Behavior Testing

**Goal:** Verify degradation, circuit breaker, and recovery mechanisms

### Setup (5 min)

- [ ] Completed Phase 3 successfully
- [ ] Back up working config: `cp .woterclip/config.yaml .woterclip/config.yaml.working`

### 4.1 Progressive Degradation (5 min)

- [ ] Corrupt field ID in config (intentionally break one):
  ```bash
  sed -i '' 's/PVT_FIELD_1/PVT_FIELD_INVALID/g' .woterclip/config.yaml
  ```

- [ ] Run `/heartbeat`
- [ ] Heartbeat still completes (doesn't crash)
- [ ] Comment is posted (read-only mode)
- [ ] Comment includes degradation marker (⚠️, ❌, or similar)
- [ ] No field mutations attempted
- [ ] Issue still has `agent-working` label (safe for retry)

- [ ] Restore config: `cp .woterclip/config.yaml.working .woterclip/config.yaml`

### 4.2 Circuit Breaker (5 min)

- [ ] Corrupt field ID again
- [ ] Run heartbeat 3 times in a row:
  ```bash
  /heartbeat
  /heartbeat
  /heartbeat
  ```

- [ ] After 3 failures:
  - [ ] Heartbeat still completes
  - [ ] Latest comment has circuit-breaker indicator
  - [ ] Read-only mode is active (no mutations attempted)

- [ ] Restore config: `cp .woterclip/config.yaml.working .woterclip/config.yaml`
- [ ] Run `/heartbeat` again
- [ ] Succeeds (circuit breaker resets on success)

### 4.3 Recovery Journal (5 min)

- [ ] Check heartbeat log exists: `.woterclip/heartbeat-log.jsonl`
- [ ] View recent entries:
  ```bash
  tail -10 .woterclip/heartbeat-log.jsonl | jq '.'
  ```

- [ ] Each line is valid JSON with:
  - [ ] `timestamp` (ISO 8601 format)
  - [ ] `issue` (issue number)
  - [ ] `heartbeat` (counter)
  - [ ] `step` (queued, locked, worked, reported, updated)
  - [ ] `status` (ok or error)

- [ ] Log contains entries from all heartbeat runs

### 4.4 Idempotent Re-Init (5 min)

- [ ] Back up config: `cp .woterclip/config.yaml .woterclip/config.yaml.pre-reinit`
- [ ] Run `/woterclip-init` again
- [ ] Choose "merge" mode when prompted
- [ ] Compare configs:
  ```bash
  diff .woterclip/config.yaml.pre-reinit .woterclip/config.yaml
  ```

- [ ] Diff shows no differences (merge is non-destructive)
- [ ] Run `/woterclip-init` again
- [ ] Still no differences (idempotent)

### 4.5 Schema Drift Sentry (5 min)

- [ ] Corrupt field ID again:
  ```bash
  sed -i '' 's/PVT_FIELD_1/PVT_FIELD_INVALID/g' .woterclip/config.yaml
  ```

- [ ] Run `/heartbeat`
- [ ] Heartbeat detects drift and stops early
- [ ] Message indicates "schema drift" or "field mismatch"
- [ ] No mutations are attempted

- [ ] Restore config: `cp .woterclip/config.yaml.working .woterclip/config.yaml`

### Phase 4 Status

- [ ] **✅ PASSED** - All anti-fragile mechanisms working
- [ ] **⚠️ PARTIAL** - Some mechanisms work (list below)
- [ ] **❌ FAILED** - Anti-fragile not working (list below)

**Issues/Notes:**
```
[List any issues here]
```

---

## Final Verification

### All Phases Complete

- [ ] Phase 1: ✅ PASSED
- [ ] Phase 2: ✅ PASSED
- [ ] Phase 3: ✅ PASSED
- [ ] Phase 4: ✅ PASSED

### Code Review

- [ ] No stale Linear MCP references: `grep -r "mcp__claude_ai_Linear" .woterclip/ && echo "FOUND" || echo "✓ None"`
- [ ] Config is valid YAML: `cat .woterclip/config.yaml | head -5`
- [ ] All required files exist:
  - [ ] `.woterclip/config.yaml`
  - [ ] `.woterclip/personas/*/SOUL.md`
  - [ ] `.woterclip/personas/*/TOOLS.md`
  - [ ] `.woterclip/personas/*/config.yaml`
  - [ ] `.woterclip/heartbeat-log.jsonl`

### GitHub State

- [ ] Project has Status and Priority fields
- [ ] Repository has required labels:
  - [ ] `agent-working`
  - [ ] `agent-blocked`
  - [ ] Persona labels (backend, frontend, etc.)

### Cleanup (Optional)

- [ ] Delete test issues (or keep for reference)
- [ ] Remove test labels if unwanted
- [ ] Archive test project or keep for future testing
- [ ] Delete backup configs:
  ```bash
  rm .woterclip/config.yaml.working .woterclip/config.yaml.pre-reinit
  ```

---

## Sign-Off

**Tester:** ________________  
**Date:** ________________  
**Repository:** ________________  

**Overall Result:**
- [ ] ✅ ALL PHASES PASSED - Ready for production use
- [ ] ⚠️ MOSTLY PASSED - Issues logged, proceed with caution
- [ ] ❌ FAILED - Do not use in production until issues resolved

**Comments:**
```
[Add any final notes or recommendations]
```

---

## Next Steps (on Success)

1. ✅ Delete test issues and project
2. 🚀 Deploy WoterClip to production repos
3. 📊 Monitor heartbeat logs for errors
4. 🔧 Adjust persona SOUL.md files for your workflows
5. 📝 Document any team-specific customizations

---

## Troubleshooting Reference

If any phase fails, see:
- `docs/phases-1-4-testing-guide.md` → Troubleshooting sections for each phase
- `IMPLEMENTATION.md` → Known limitations
- `docs/github-migration-guide.md` → FAQ section
