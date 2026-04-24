# GitHub MCP 1:1 Verification Checklist

This document outlines the validation steps to verify WoterClip's GitHub MCP integration provides 1:1 behavioral parity with Linear and meets plan requirements.

## Pre-Implementation Validation

### Config Schema Validation

```bash
# Validate templates/config.yaml YAML syntax
python3 -c "import yaml; yaml.safe_load(open('templates/config.yaml')); print('✓ templates/config.yaml is valid YAML')"

# Check required top-level keys
- [ ] `version: 2` (updated for GitHub)
- [ ] `provider: github` (new field)
- [ ] `github` section with required sub-keys
- [ ] `heartbeat` section (cross-provider, preserved)
- [ ] `labels` section (preserved)
- [ ] `personas` section (preserved)
- [ ] `antifragile` section (new)
```

### Skill Frontmatter Validation

- [ ] `skills/heartbeat/SKILL.md` has valid frontmatter (`name`, `description`, `version`)
- [ ] `skills/init/SKILL.md` has valid frontmatter (`name`, `description`, `version`)
- [ ] `commands/heartbeat.md` has valid frontmatter (`description`, `argument-hint`)
- [ ] `commands/woterclip-init.md` has valid frontmatter (`description`)

### Reference Documentation

- [ ] `references/status-mapping.md` updated with GitHub Project states
- [ ] `references/label-conventions.md` updated with GitHub label patterns
- [ ] `references/comment-format.md` updated with GitHub issue links
- [ ] `references/github-status-mapping.md` created with GitHub-specific mapping
- [ ] `CLAUDE.md` updated with provider-agnostic language

## Phase 1: Read-Only Validation (Dry-Run)

### Queue Building and Ranking

1. **Setup:** Initialize WoterClip in a GitHub repo with at least 3-5 test issues in a GitHub Project

2. **Dry-run test:**
   ```
   /heartbeat --dry-run
   ```

3. **Validation points:**
   - [ ] Config loads without errors
   - [ ] Project items are fetched and displayed
   - [ ] Queue is correctly ranked by Status (In Progress > Todo), then Priority (Urgent > ... > None), then updated_at, then issue_number
   - [ ] Persona labels are correctly identified
   - [ ] Stale `agent-working` labels are detected (if any exist)

4. **Expected output:**
   ```
   Dry run — would pick:
     #XYZ [backend] "Issue title" (In Progress, High)
   
   Queue:
     #ABC [frontend] "Other issue" (Todo, Medium)
   ```

### State Query Tests

5. **Issue state mapping:**
   - [ ] Issue with Project Status=`Todo` appears in queue
   - [ ] Issue with Project Status=`In Progress` appears first in queue
   - [ ] Issue with Project Status=`In Review` is excluded from queue
   - [ ] Issue with Project Status=`Done` is excluded from queue
   - [ ] Issue with Project Status=`Canceled` is excluded from queue

6. **Priority mapping:**
   - [ ] Issue with Priority=`Urgent` ranks above High
   - [ ] Issue with Priority=`High` ranks above Medium
   - [ ] Issue with Priority=`None` ranks last

7. **Label filtering:**
   - [ ] Issue with persona label `backend` is included
   - [ ] Issue with persona label `frontend` is included
   - [ ] Issue without persona label defaults to Orchestrator (if is_default: true)
   - [ ] Issue with `agent-blocked` label and no new human comments is excluded
   - [ ] Issue with `agent-blocked` label and new human comments is included

## Phase 2: Write Operations (Comments)

### Comment Posting and Counter

1. **Setup:** Run heartbeat on a single low-risk test issue (e.g., triage task)

2. **Validation points:**
   - [ ] Heartbeat comment is posted with counter `#1`
   - [ ] Timestamp and duration are correctly formatted
   - [ ] Persona name is in footer
   - [ ] Issue link is correct
   - [ ] Comment format matches template

3. **Run heartbeat again on same issue:**
   - [ ] New comment has counter `#2`
   - [ ] Previous comment link is present in footer
   - [ ] No duplicate comments are posted

4. **Edit and delete comments test:**
   - [ ] Manually edit/delete some heartbeat comments
   - [ ] Re-run heartbeat
   - [ ] Counter still increments correctly (counts only valid bot comments)

### Label Management

5. **Lock/unlock cycle:**
   - [ ] Heartbeat adds `agent-working` label
   - [ ] Second heartbeat on same issue sees `agent-working` and doesn't re-add it
   - [ ] On completion, `agent-working` is removed

6. **Blocked state:**
   - [ ] Run heartbeat with outcome "blocked"
   - [ ] `agent-working` is removed
   - [ ] `agent-blocked` is added
   - [ ] Next heartbeat skips issue (unless new human comment)
   - [ ] Board member comments
   - [ ] Next heartbeat picks up issue again

## Phase 3: Project Field Updates (State Transitions)

### Field Mutation Tests

1. **Setup:** Ensure project field IDs are resolved in config

2. **Status field update:**
   - [ ] Run heartbeat with outcome "completed"
   - [ ] Issue Project Status changes from `In Progress` to `Done`
   - [ ] Issue remains in repo (not deleted)
   - [ ] Optional: issue is closed (if config `close_on_done: true`)

3. **Priority field update:**
   - [ ] Manually set issue Priority to `Low`
   - [ ] Run heartbeat
   - [ ] Issue is ranked lower than issues with `High` priority
   - [ ] Heartbeat completes without error

4. **Failure handling (anti-fragile):**
   - [ ] Simulate field mutation failure (e.g., missing field ID)
   - [ ] Heartbeat posts error comment
   - [ ] `agent-working` is kept (safe retry)
   - [ ] Circuit breaker: after N failures, run downgrades to read-only

## Phase 4: 1:1 Behavior Parity

### Comparison Matrix (Linear vs GitHub)

| Behavior | Linear | GitHub | Status |
|---|---|---|---|
| Queue source | Linear issues | GitHub Project items | ✓ |
| State storage | Status + Priority fields | Project Status/Priority fields | ✓ |
| Lock mechanism | `agent-working` label | `agent-working` label | ✓ |
| Sorting | Status > Priority > Updated > ID | Status > Priority > Updated > ID | ✓ |
| Blocking | `agent-blocked` label | `agent-blocked` label | ✓ |
| Persona routing | Linear labels | GitHub labels | ✓ |
| Heartbeat counter | Derived from comments | Derived from comments | ✓ |
| Comment format | Heartbeat #N template | Heartbeat #N template | ✓ |
| Stale lock cleanup | `agent-working` without comment | `agent-working` without comment | ✓ |

### Cross-Provider Compatibility

- [ ] Config can have `provider: github` without breaking existing `provider: linear` systems
- [ ] Persona system works identically in both providers
- [ ] Heartbeat skill routes to correct provider implementation
- [ ] Init skill handles both Linear and GitHub setup flows

## Phase 5: Anti-Fragile Safeguards

### Degradation Handling

1. **Circuit breaker test:**
   - [ ] Simulate 3+ consecutive field mutation failures
   - [ ] Heartbeat auto-switches to read-only mode
   - [ ] Comment is posted indicating "degraded mode"
   - [ ] Stale lock cleanup still works
   - [ ] Persona work is still executed

2. **Canary mutation test:**
   - [ ] First mutation of heartbeat is low-risk field test
   - [ ] If test fails, whole run downgrade to read-only

### Recovery Journal

1. **Setup:** Enable recovery journal in config

2. **Crash simulation:**
   - [ ] Start heartbeat on multiple issues
   - [ ] Interrupt mid-work (e.g., kill Claude session)
   - [ ] `.woterclip/heartbeat-log.jsonl` contains partial records
   - [ ] Next heartbeat reads log and resumes from last known state

### Schema Drift Sentry

1. **Setup:** Run successful heartbeat

2. **Simulate field ID drift:**
   - [ ] Manually change field ID in config to invalid ID
   - [ ] Run heartbeat
   - [ ] Schema sentry detects drift before queue build
   - [ ] Heartbeat stops with repair prompt

### Idempotent Re-Init

1. **Run init once:**
   - [ ] `.woterclip/config.yaml` created with all field IDs
   - [ ] Project fields are created
   - [ ] Labels are created

2. **Run init again (merge mode):**
   - [ ] No duplicate fields created
   - [ ] No duplicate labels created
   - [ ] Existing field IDs are preserved
   - [ ] Existing persona customizations untouched

3. **Run init again with overwrite:**
   - [ ] Old config backed up to `config.yaml.bak`
   - [ ] Fresh init completes successfully

## Phase 6: Edge Cases

### Pagination and Large Datasets

- [ ] Heartbeat handles repo with 50+ open issues
- [ ] Heartbeat handles project with 100+ items
- [ ] Comment fetching is paginated
- [ ] No timeouts on large data sets

### Permission and Accessibility

- [ ] Issue inaccessible due to permissions → skipped with audit log
- [ ] Project accessible but issue not → auto-add with default state
- [ ] Label creation fails due to permissions → logged, other labels created

### Identity Resolution

- [ ] Multiple heartbeats identify same actor correctly (by login)
- [ ] @-mentions use GitHub login, not display name
- [ ] Actor identity cached for performance

### Heartbeat Counter Ambiguity

- [ ] Multiple heartbeat comments from different tools → counter resets safely (informational only)
- [ ] Comment edited by human → counter parse still works
- [ ] Comment deleted → counter recomputes from remaining valid comments

## Performance Benchmarks

- [ ] Single issue heartbeat: < 30 seconds (read-only)
- [ ] Single issue heartbeat with work: < 5 minutes (persona-dependent)
- [ ] Heartbeat with 5 project items fetched: < 60 seconds (including work)
- [ ] Init: < 2 minutes (including field creation)

## Final Verification

- [ ] All reference files parse and render correctly
- [ ] No hardcoded Linear MCP tool names in non-reference files
- [ ] All `${CLAUDE_PLUGIN_ROOT}` references resolve correctly
- [ ] Config version is 2 (GitHub-era)
- [ ] Heartbeat skill version is 1.0.0+
- [ ] Init skill version is 2.0.0+
- [ ] No linter errors in markdown/YAML files
- [ ] Re-init idempotency check passes (run twice, no side effects)

## Known Limitations

- Project item filtering requires GraphQL queries (no REST endpoint for field filters)
- Field ID resolution is one-time during init; if user manually renames fields, init must be re-run
- MCP tool availability is checked at heartbeat start; if unavailable mid-work, heartbeat aborts safely
- Pagination max limit is set per API (typically 100 items per page)
