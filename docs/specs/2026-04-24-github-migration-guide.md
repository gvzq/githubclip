# GitHub MCP Migration Guide

**Date:** 2026-04-24
**Status:** Active
**Replaces:** `docs/github-migration-guide.md`

## Overview

WoterClip supports **GitHub Projects (v2)** as primary work queue, with backward compatibility for Linear. This spec covers the migration path, configuration differences, and operational procedures for teams switching providers.

## Why Migrate to GitHub

- Unified workspace: code, PRs, issues, and projects in one platform
- Custom fields: Project Status and Priority fields provide deterministic workflow state
- No separate Linear workspace required; configuration is repo-level
- GraphQL IDs prevent name-based drift across field renames
- Anti-fragile: built-in degradation and recovery patterns

## Pre-Migration Checklist

- [ ] GitHub repository created and accessible
- [ ] GitHub CLI authenticated: `gh auth status`
- [ ] GitHub Project (v2) exists or will be created during init
- [ ] Team members added to the repository
- [ ] Linear workspace available (optional backup during transition)

## Migration Steps

### Step 1 — Initialize WoterClip for GitHub

Run in the target GitHub repository:

```bash
/woterclip-init
```

Follow prompts:
1. Confirm GitHub repo target (`owner/repo`)
2. Select or create a GitHub Project
3. Choose persona preset (e.g. `engineering`)
4. Review and confirm summary

**Result:** `.woterclip/config.yaml` with GitHub configuration, Project fields created, labels created.

### Step 2 — Port Existing Work (If Needed)

If migrating from Linear:

1. Export Linear issues (export feature or API): capture title, description, persona labels, priority, state
2. Create corresponding GitHub issues with matching titles/descriptions; set Project fields and persona labels
3. Assign issues to the team member(s) who will work on them

### Step 3 — Validate via Dry-Run

```bash
/heartbeat --dry-run
```

Expected output:
- Issues ranked correctly by Status, Priority, update time
- Persona labels identified
- Queue formatted cleanly

### Step 4 — Run First Heartbeat

```bash
/heartbeat
```

On first run:
- Heartbeat comment #1 is posted
- Project fields updated if work changes state
- Labels applied/removed as needed

### Step 5 — Verify Anti-Fragile Behaviors

During first week:
- [ ] Stale lock cleanup works (trigger after `stale_lock_hours` elapses)
- [ ] Degradation mode activates on temporary API failure
- [ ] Circuit breaker prevents cascading failures
- [ ] Recovery works if heartbeat crashes mid-work

### Step 6 — Archive Linear (Optional)

Once confident in GitHub migration:
1. Run a final Linear export for audit/history
2. Update team docs to point to GitHub Project as source-of-truth
3. Keep Linear accessible for read-only historical queries if needed

## Configuration Reference

### Linear (legacy)

```yaml
provider: linear
linear:
  user_name: "Team Member"
  team: "Engineering"
  project: "WoterClip"
```

### GitHub (current)

```yaml
provider: github
github:
  owner: "myorg"
  repo: "myrepo"
  user_name: "myusername"
  project:
    project_id: "PVT_XXXXX"
    project_number: 5
  fields:
    status:
      field_id: "PVTF_XXXXX"
      option_ids:
        todo: "PVT_OPT_1"
        in_progress: "PVT_OPT_2"
        in_review: "PVT_OPT_3"
        done: "PVT_OPT_4"
        canceled: "PVT_OPT_5"
    priority:
      field_id: "PVTF_XXXXX"
      option_ids:
        urgent: "PVT_OPT_1"
        high: "PVT_OPT_2"
        medium: "PVT_OPT_3"
        low: "PVT_OPT_4"
        none: "PVT_OPT_5"
```

## Workflow Comparison

| Aspect | Linear | GitHub |
|---|---|---|
| Work queue | Linear Project issues | GitHub Project items |
| Status values | Linear workflow states | Status field (Todo/In Progress/In Review/Done/Canceled) |
| Priorities | Linear priority field | Priority field (Urgent/High/Medium/Low/None) |
| Agent state | Linear labels | GitHub repo labels |
| Locking | `agent-working` label | `agent-working` label |
| Blocking | `agent-blocked` label | `agent-blocked` label |
| Persona routing | Linear labels | GitHub labels |
| Comments | Linear issue thread | GitHub issue comments |
| Sub-tasks | Linear sub-issues | GitHub issue references (no sub-task model) |

## Troubleshooting

### Project field mutations not working

Check: field IDs correctly resolved in config; option IDs present; GitHub MCP has project mutation permission.

Fix: run `/woterclip-init` in merge mode to refresh field IDs; verify IDs match actual project schema.

### Issues not appearing in queue

Check: issues assigned to your GitHub login; issues in configured Project; Project Status is `Todo` or `In Progress`; no `agent-blocked` label (or new human comments present).

Fix: manually assign issues; add to Project if missing; set Status via Project UI.

### Heartbeat running in read-only mode

Check: circuit breaker was triggered (3+ field mutation failures); degradation mode message present in heartbeat comment.

Fix: review error message for failing mutation; verify GitHub account permissions; re-run init to refresh field IDs.

### Counter not incrementing correctly

The heartbeat counter is informational only — not functional. It recomputes from comment history on each run. Re-running heartbeat is safe regardless of counter state.

## Rollback to Linear

To revert during transition:

1. Update `.woterclip/config.yaml`:
   ```yaml
   provider: linear
   compat:
     source_provider: github
     migration_status: paused
   ```
2. Re-configure Linear context (team, user, project)
3. Run heartbeat — switches back to Linear MCP tools

Work completed during GitHub phase remains as GitHub issues; future work queues from Linear.

## Best Practices

1. Keep persona labels consistent across the Linear→GitHub transition
2. Use deterministic IDs — never rely on field/option display names; init resolves IDs upfront
3. Monitor degradation mode — repeated circuit breaker triggers indicate permission or API issues
4. Re-run init after any Project field rename to refresh IDs
5. Back up `.woterclip/config.yaml` before major changes
6. Test on non-critical work first; validate heartbeat on triage/low-impact issues before high-stakes work

## FAQ

**Can I use both Linear and GitHub simultaneously?**
No. Only one provider can be active in `.woterclip/config.yaml` at a time. Switch via config and re-run heartbeat.

**What happens to Linear issues after migration?**
They remain in Linear. Export/archive them or keep as read-only history.

**Do I need to recreate all Linear issues in GitHub?**
Only for issues you want in the active queue. Historical Linear issues can stay in Linear.

**What if a GitHub Project field gets renamed?**
Run `/woterclip-init` (merge mode) to auto-repair field IDs.

**Can I use WoterClip without a GitHub Project?**
No. GitHub MCP mode requires a Project v2 with Status and Priority fields for queue ranking.

**How do I report bugs with GitHub MCP?**
Check `references/verification-checklist.md` for troubleshooting steps, or file an issue on the WoterClip repo.
