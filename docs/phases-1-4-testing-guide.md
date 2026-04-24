# WoterClip GitHub MCP Testing Suite (Phases 1-4)

This guide provides step-by-step instructions, test scripts, and validation checklists for testing all phases of the GitHub MCP implementation.

## Prerequisites

Before running any phase:

```bash
# Verify GitHub CLI is installed and authenticated
gh auth status

# Verify you're in a GitHub repository
git remote -v | grep github

# Create a test branch (optional but recommended)
git checkout -b test/woterclip-github-mcp
```

## Phase 1: Read-Only Dry-Run Validation

### 1.1 Setup Test Environment

```bash
# In your GitHub repository, create a test project
# Via GitHub UI: Projects → New Project → Table format
# Name: "WoterClip Test"

# Create 5-10 test issues with various states
# Examples:
# - Issue #1: "Test Backend Work" → Project Status: In Progress, Priority: High
# - Issue #2: "Test Frontend Task" → Project Status: Todo, Priority: Medium
# - Issue #3: "Review Doc" → Project Status: In Review, Priority: Low
# - Issue #4: "Done Task" → Project Status: Done, Priority: None
# - Issue #5: "Blocked Work" → Project Status: In Progress, Priority: High (add agent-blocked label)

# Assign all issues to yourself (required for queue inclusion)
```

### 1.2 Initialize WoterClip

```bash
# In your repository, run:
/woterclip-init

# Follow prompts:
# 1. Confirm GitHub repo target (owner/repo)
# 2. Select or create a GitHub Project (use test project from 1.1)
# 3. Choose persona preset (recommend "engineering")
# 4. Review summary

# Expected output:
# ✓ WoterClip initialized!
# ✓ GitHub Project fields created
# ✓ Labels created
# ✓ Config saved to .woterclip/config.yaml
```

### 1.3 Run Dry-Run Test

```bash
# Execute heartbeat in dry-run mode
/heartbeat --dry-run

# Capture output and verify against checklist below
```

### 1.4 Phase 1 Validation Checklist

```markdown
## Dry-Run Output Validation

- [ ] **No errors during config load**
  - Config parses successfully
  - Provider is "github"
  - Project ID is not null

- [ ] **Project items fetched**
  - Output shows issues from your test set
  - Count matches assigned issues with Status in (Todo, In Progress)

- [ ] **Queue ranking is correct**
  - In Progress issues appear before Todo issues
  - Within same status, Priority ranking is maintained:
    - Urgent > High > Medium > Low > None
  - Within same status/priority, updated_at is descending (newest first)

- [ ] **Persona labels detected**
  - Issues without persona label default to "orchestrator"
  - Issues with persona label (backend, frontend, etc.) are identified

- [ ] **Blocked issues excluded**
  - Issues with `agent-blocked` label do NOT appear in queue
  - (Add a test issue with agent-blocked label to verify)

- [ ] **Dry-run output format**
  ```
  Dry run — would pick:
    #XYZ [backend] "Issue title" (In Progress, High)
  
  Queue:
    #ABC [frontend] "Other issue" (Todo, Medium)
  ```

## Expected Behavior Examples

### Example 1: Correct Ranking
```
Issue A: Status=Todo, Priority=Urgent → Rank 1 (first)
Issue B: Status=Todo, Priority=High → Rank 2
Issue C: Status=In Progress, Priority=None → Rank 3 (different status)
```
Why: Status takes priority (In Progress would be first if it had high priority)

### Example 2: Blocked Exclusion
```
Issue X: Status=In Progress, Priority=High, Label=agent-blocked → Excluded (blocked)
Issue Y: Status=In Progress, Priority=Medium → Would be picked
```

### Example 3: Persona Routing
```
Issue A: Label=backend → Routes to Backend persona
Issue B: Label=frontend → Routes to Frontend persona
Issue C: No label → Routes to Orchestrator (default)
```
```

### 1.5 Phase 1 Troubleshooting

**Problem: "Config not found"**
```bash
# Solution: Run /woterclip-init first
/woterclip-init
```

**Problem: "No issues in queue"**
```bash
# Check:
# 1. Are issues assigned to you?
gh issue list --assigned @me

# 2. Are issues in the Project?
# (Verify via Project UI)

# 3. Is Project Status set to Todo or In Progress?
# (Verify via Project table view)
```

**Problem: "Wrong ranking order"**
```bash
# Verify Project field values via GitHub CLI:
gh api graphql -f query='
  query {
    node(id: "PROJECT_ID") {
      ... on ProjectV2 {
        items(first: 10) {
          nodes {
            content { ... on Issue { number title } }
            fieldValues(first: 5) { nodes { 
              ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2FieldCommon { name } } }
            } }
          }
        }
      }
    }
  }'
# Verify Status and Priority values match expected field options
```

**Problem: "Persona label not recognized"**
```bash
# Check config for correct persona definitions:
cat .woterclip/config.yaml | grep -A 20 "personas:"

# Verify label exactly matches (case-sensitive):
gh label list | grep -E "backend|frontend|ceo"
```

---

## Phase 2: Comment Operations and Locking

### 2.1 Setup

Use the same test environment from Phase 1. Pick the top-priority issue for testing.

### 2.2 Run First Heartbeat (Single Issue)

```bash
# Run heartbeat on ONE issue (not --dry-run)
/heartbeat

# Do minimal work or let it complete
```

### 2.3 Phase 2 Validation Checklist

```markdown
## Comment & Lock Operations

- [ ] **Heartbeat comment posted**
  - Comment appears on issue with "Heartbeat #1"
  - Timestamp is current (HH:MM UTC)
  - Duration is shown (e.g., "1m 23s")

- [ ] **Comment format correct**
  ```
  ## Heartbeat #1 — 2026-04-24 12:34 UTC (1m 23s)
  
  **Status:** In Progress | Completed | Blocked
  
  ### What was done
  - [commit-sha] feat(api): description
  - or description of work
  
  ### Next steps
  - Next work item
  
  ### Blockers
  None
  
  ---
  *WoterClip · persona-name · [#123](...) · from [Heartbeat #0](...)*
  ```

- [ ] **`agent-working` label applied**
  - Issue now has `agent-working` label
  - Label appears in issue UI

- [ ] **Persona name in footer**
  - Footer shows correct persona (orchestrator, backend, frontend, etc.)

- [ ] **Heartbeat counter at #1**
  - First heartbeat is always #1

- [ ] **Issue remains open**
  - Issue state is still "Open" (not closed)

## Lock Safety Tests

- [ ] **Re-running heartbeat on same issue**
  - Run `/heartbeat --dry-run` to see same issue at top
  - Run `/heartbeat` again
  - New comment has counter "#2"
  - Previous comment link appears in footer
  - No duplicate "agent-working" labels

- [ ] **Stale lock cleanup**
  - Let `agent-working` label sit for > `stale_lock_hours` (default 4 hours)
  - Run heartbeat
  - Old stale `agent-working` is removed
  - Cleanup comment is posted
  - Issue re-enters queue
```

### 2.4 Phase 2 Troubleshooting

**Problem: "No comment posted"**
```bash
# Check GitHub MCP tools available:
/heartbeat --dry-run  # First verify dry-run works

# If dry-run works but heartbeat doesn't post comment:
# - Check persona TOOLS.md has GitHub tools listed
# - Check persona config has reasonable max_turns
```

**Problem: "Heartbeat counter wrong"**
```bash
# Check all comments on issue:
gh issue view ISSUE_NUMBER --comments

# Verify only bot-authored comments are counted
# (humancomments are ignored for counter)
```

**Problem: "`agent-working` label not applied"**
```bash
# Verify label exists:
gh label list | grep "agent-working"

# Check labels in config match GitHub repo labels exactly (case-sensitive)
```

---

## Phase 3: Project Field Mutations

### 3.1 Setup

Continue with Phase 2 test environment. Pick an issue that completed work.

### 3.2 Run Heartbeat with Completion

```bash
# Pick an issue and complete work such that outcome is "completed"
# (For test: Orchestrator persona performing triage counts as work)
/heartbeat

# Expect: issue Status changes to "Done"
```

### 3.3 Phase 3 Validation Checklist

```markdown
## Project Field Mutation Tests

- [ ] **Status field updated on completion**
  - Issue Project Status changes from "In Progress" or "Todo" → "Done"
  - Verify via Project UI: issue appears in "Done" column
  - Verify via GitHub CLI:
    ```bash
    gh api graphql -f query='
      query { node(id: "ISSUE_ID") { ... on Issue { projectItems(first: 1) { nodes { fieldValues(first: 5) { nodes { ... on ProjectV2ItemFieldSingleSelectValue { name } } } } } } }
    '
    ```

- [ ] **`agent-working` label removed on completion**
  - `agent-working` label no longer appears on issue

- [ ] **Issue remains open** (unless close_on_done: true)
  - Issue state is still "Open"
  - (If close_on_done configured: issue is closed)

- [ ] **Blocked outcome works**
  - Force heartbeat to blocked state (e.g., missing prerequisite)
  - Status stays "In Progress"
  - `agent-blocked` label is added
  - `agent-working` label is removed

- [ ] **In Progress outcome**
  - Force heartbeat to "more_work" outcome (incomplete)
  - Status stays "In Progress"
  - `agent-working` label stays applied

- [ ] **Triaged outcome**
  - Orchestrator triages unlabeled issue
  - Issue gets persona label (e.g., "backend")
  - Status stays "Todo"

## Tie-Break Ordering Test

- [ ] **Multiple issues with same status/priority**
  - Create issues:
    - Issue #10: In Progress, High, updated 1 hour ago
    - Issue #20: In Progress, High, updated 5 min ago
  - Heartbeat should pick #20 first (most recent updated_at)
  - Then #10
```

### 3.4 Phase 3 Troubleshooting

**Problem: "Status field not updating"**
```bash
# Check field IDs are resolved in config:
cat .woterclip/config.yaml | grep -A 10 "fields:"
# Verify field_id and all option_ids are not null

# If null, re-run init:
/woterclip-init  # Choose "merge" mode
```

**Problem: "Field update fails with permission error"**
```bash
# Verify GitHub account has permission to update project:
# 1. Go to Project UI → Settings
# 2. Check your role is "Admin" or "Editor"
# 3. Check repository settings → collaborators

# Re-run init to test field mutations again
```

**Problem: "Blocked label not applied"**
```bash
# Force blocked outcome by having heartbeat incomplete task:
# (This is test-specific; run as Backend persona and let task timeout)

# Check labels exist:
gh label list | grep "agent-blocked"
```

---

## Phase 4: Anti-Fragile Behavior Testing

### 4.1 Progressive Degradation Mode

```bash
# Simulate field mutation failure by:
# 1. Update config with invalid field IDs (change one digit):
cat .woterclip/config.yaml | sed 's/PVT_FIELD_1/PVT_FIELD_INVALID/g' > .woterclip/config-bad.yaml
cp .woterclip/config.yaml .woterclip/config-backup.yaml
cp .woterclip/config-bad.yaml .woterclip/config.yaml

# 2. Run heartbeat:
/heartbeat

# 3. Verify degradation behavior:
# - Heartbeat still runs and posts comment
# - Comment has marker "❌ Degraded" or similar
# - Field mutations are skipped (labels still applied)
# - agent-working label is kept (safe for retry)

# 4. Restore good config:
cp .woterclip/config-backup.yaml .woterclip/config.yaml
```

### 4.2 Circuit Breaker Test

```bash
# Simulate 3+ consecutive failures:
# Run heartbeat 3 times with invalid field IDs
/heartbeat
/heartbeat
/heartbeat

# After 3 failures:
# - Heartbeat auto-switches to read-only
# - Comment indicates "circuit breaker triggered"
# - Run still completes successfully (degraded)

# Restore good config:
cp .woterclip/config-backup.yaml .woterclip/config.yaml
```

### 4.3 Canary Mutation Test

```bash
# Canary is first mutation of each run
# If first mutation (e.g., field update) fails:
# - Entire run downgrades to read-only
# - No further mutations attempted

# Verify by:
# 1. Intentionally cause first mutation to fail
# 2. Heartbeat completes with read-only marker
```

### 4.4 Schema Drift Sentry

```bash
# Simulate field ID drift:
# 1. Corrupt field ID in config (same as 4.1)
# 2. Run heartbeat

# Expected: Drift is detected and reported
# Heartbeat stops with "run repair" message

# Correct and re-run:
cp .woterclip/config-backup.yaml .woterclip/config.yaml
/heartbeat
```

### 4.5 Recovery Journal Test

```bash
# Check recovery journal exists:
cat .woterclip/heartbeat-log.jsonl | tail -5

# Each line is a JSON record with:
# - timestamp (ISO 8601)
# - issue number
# - heartbeat counter
# - step (queued, locked, worked, reported, updated)
# - status (ok, error)

# Verify after each heartbeat run:
tail -20 .woterclip/heartbeat-log.jsonl | jq '.'
```

### 4.6 Idempotent Re-Init

```bash
# Test re-init doesn't delete user fields/options:
# 1. Back up config:
cp .woterclip/config.yaml .woterclip/config-before-reinit.yaml

# 2. Re-run init (choose "merge" mode):
/woterclip-init

# 3. Verify config is unchanged:
diff .woterclip/config-before-reinit.yaml .woterclip/config.yaml
# Should show no differences (merge mode only adds missing, never deletes)

# 4. Run init again:
/woterclip-init

# 5. Verify still idempotent:
diff .woterclip/config-before-reinit.yaml .woterclip/config.yaml
# Should still show no differences
```

### 4.7 Phase 4 Validation Checklist

```markdown
## Anti-Fragile Behaviors

- [ ] **Progressive degradation mode**
  - Broken field ID triggers degradation
  - Heartbeat continues in read-only
  - Comment marked with degradation indicator
  - No cascading failures

- [ ] **Circuit breaker activation**
  - 3 consecutive failures trigger circuit breaker
  - Run auto-downgrades to read-only
  - Subsequent runs don't attempt writes
  - Reset after config fix + successful run

- [ ] **Canary mutation works**
  - First mutation is test operation
  - If test fails → entire run is read-only
  - Prevents partial/inconsistent state

- [ ] **Schema drift sentry**
  - Detects field ID mismatch
  - Stops with repair message
  - Prevents bad mutations

- [ ] **Recovery journal populated**
  - `.woterclip/heartbeat-log.jsonl` exists
  - Each run appends new records
  - Records are valid JSON

- [ ] **Idempotent re-init**
  - Re-running init preserves existing fields
  - No duplicate field creation
  - No deletion of user fields/options
  - Config is stable across re-runs
```

---

## Summary Validation

After completing all 4 phases, verify:

```bash
# 1. All files exist and are valid:
ls -la .woterclip/
cat .woterclip/config.yaml | head -10

# 2. No stale Linear references:
grep -r "mcp__claude_ai_Linear" .woterclip/ || echo "✓ No Linear refs"

# 3. Heartbeat log populated:
wc -l .woterclip/heartbeat-log.jsonl

# 4. Labels are correct:
gh label list

# 5. Project has required fields:
gh api graphql -f query='
  query {
    node(id: "PROJECT_ID") {
      ... on ProjectV2 {
        fields(first: 10) {
          nodes {
            ... on ProjectV2Field {
              name
            }
          }
        }
      }
    }
  }
'
```

## Post-Testing Cleanup (Optional)

```bash
# Remove test labels:
gh label delete agent-working agent-blocked -y --repo owner/repo
gh label delete backend frontend ceo -y --repo owner/repo

# Delete test project (via GitHub UI)

# Or revert all changes:
git checkout .woterclip/
git status
```

## Next Steps on Success

1. ✅ All 4 phases validated
2. Run heartbeat on real production issues
3. Monitor heartbeat logs for errors
4. Adjust personas as needed for your workflows
5. Celebrate! 🎉
