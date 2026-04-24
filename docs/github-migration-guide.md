# GitHub MCP Migration Guide

This guide helps teams migrate WoterClip from Linear to GitHub Project-backed workflow.

## Overview

WoterClip now supports **GitHub Projects (v2)** as a primary work queue source, while maintaining **backward compatibility with Linear**. This guide outlines the migration path and key differences.

## Why Migrate to GitHub?

- **Unified workspace:** all work (code, PRs, issues, projects) in one platform
- **Custom fields:** Project Status and Priority fields provide Linux-like workflow state without duplication
- **Simpler setup:** no need for separate Linear workspace; repo-level configuration
- **API-first design:** deterministic GraphQL IDs prevent name-based drift
- **Anti-fragile:** built-in degradation and recovery patterns

## Pre-Migration Checklist

- [ ] GitHub repository is created and accessible
- [ ] GitHub CLI (`gh`) is authenticated: `gh auth status`
- [ ] GitHub Project (v2) exists or you'll create it during init
- [ ] Team members are added to the repository
- [ ] Linear workspace remains available (optional backup during transition)

## Migration Steps

### Step 1: Initialize WoterClip for GitHub

In your target GitHub repository:

```bash
/woterclip-init
```

Follow the prompts:
1. Confirm GitHub repo target (`owner/repo`)
2. Select or create a GitHub Project
3. Choose persona preset (e.g., `engineering`)
4. Review and confirm summary

Result: `.woterclip/config.yaml` with GitHub configuration, GitHub Project fields created, labels created.

### Step 2: Port Existing Work (If Needed)

If migrating from Linear:

1. **Export Linear issues:**
   - Use Linear export feature or API to fetch all issues in your target project
   - Note issue titles, descriptions, persona labels, priority, state

2. **Create corresponding GitHub issues:**
   - Create issues in target GitHub repo with same titles/descriptions
   - Set Project fields (Status, Priority) to match Linear values
   - Apply persona labels

3. **Reassign to current actor:**
   - Ensure issues are assigned to the team member(s) who will work on them

### Step 3: Validate Dry-Run

```bash
/heartbeat --dry-run
```

Expected output shows:
- Issues correctly ranked by Status, Priority, update time
- Persona labels identified
- Queue formatted cleanly

If this succeeds, GitHub integration is correctly configured.

### Step 4: Run First Heartbeat

```bash
/heartbeat
```

This picks up the highest-priority item and executes the work based on persona. On first run:
- Heartbeat comment #1 is posted
- Project fields are updated (if work changes state)
- Labels are applied/removed as needed

### Step 5: Verify Anti-Fragile Behaviors

During first week of GitHub heartbeats:
- [ ] Stale lock cleanup works (run heartbeat after letting one sit for `stale_lock_hours`)
- [ ] Degradation mode activates on temporary API failure (manually simulate or observe)
- [ ] Circuit breaker prevents cascading failures
- [ ] Recovery works if heartbeat crashes mid-work

### Step 6: Archive Linear (Optional)

Once confident in GitHub migration:
1. Run one final Linear export for audit/history
2. Update team documentation to point to GitHub Project as source-of-truth
3. Keep Linear accessible for read-only historical queries if needed
4. Optionally: set Linear workspace to read-only mode

## Configuration Differences

### Linear Config (Legacy)

```yaml
provider: linear
linear:
  user_name: "Team Member"
  team: "Engineering"
  project: "WoterClip"
```

### GitHub Config (New)

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
        # ... more options
    priority:
      field_id: "PVTF_XXXXX"
      option_ids:
        urgent: "PVT_OPT_1"
        # ... more options
```

## Workflow Differences

| Aspect | Linear | GitHub |
|---|---|---|
| Work queue | Linear Project issues | GitHub Project items |
| Status values | Linear workflow states | GitHub Project Status field (Todo/In Progress/In Review/Done/Canceled) |
| Priorities | Linear priority field | GitHub Project Priority field (Urgent/High/Medium/Low/None) |
| Agent state | Linear labels | GitHub repo labels |
| Locking | `agent-working` label | `agent-working` label |
| Blocking | `agent-blocked` label | `agent-blocked` label |
| Persona routing | Linear labels | GitHub labels |
| Comments | Linear issue thread | GitHub issue comments |
| Sub-tasks | Linear sub-issues | GitHub issue references (no sub-task model) |

## Troubleshooting

### "Project field mutations not working"

**Check:**
- Field IDs are correctly resolved in config (not null)
- Option IDs are present for all required options
- GitHub MCP has permission to mutate project items

**Fix:**
- Run `/woterclip-init` again in merge mode to refresh field IDs
- Check field IDs match actual project schema

### "Issues not appearing in queue"

**Check:**
- Issues are assigned to your GitHub login
- Issues are in the configured Project
- Project Status is `Todo` or `In Progress`
- No `agent-blocked` label (or has new human comments)

**Fix:**
- Manually assign issues to your GitHub login
- Add issues to Project if missing
- Set Project Status via Project UI

### "Heartbeat running in read-only mode"

**Check:**
- Circuit breaker was triggered (3+ field mutation failures)
- Degradation mode message in heartbeat comment

**Fix:**
- Check error message for which field mutation failed
- Verify GitHub account permissions
- Re-run init to refresh field IDs
- Run heartbeat again once permissions are fixed

### "Counter not incrementing correctly"

**Check:**
- Previous heartbeat comments exist on the issue
- Comments are not deleted

**Fix:**
- Heartbeat counter is **informational only** (not functional)
- Re-running heartbeat safely even if counter seems off
- Counter recomputes on next heartbeat

## Rollback to Linear

If you need to revert to Linear during transition:

1. Update `.woterclip/config.yaml`:
   ```yaml
   provider: linear
   compat:
     source_provider: github
     migration_status: paused
   ```

2. Re-configure Linear context (team, user, project)

3. Run heartbeat — it will switch back to Linear MCP tools

Linear-specific work completed during GitHub phase will remain as GitHub issues, but future work will be queued from Linear.

## Best Practices

1. **Keep personas consistent:** same persona labels across Linear→GitHub migration
2. **Use deterministic IDs:** never rely on field/option display names; init resolves IDs upfront
3. **Monitor degradation mode:** if circuit breaker triggers repeatedly, investigate permission/API issues
4. **Re-init on field renames:** if you rename a Project field, run init again to update IDs
5. **Backup config:** save `.woterclip/config.yaml` before major changes
6. **Test on non-critical work first:** validate heartbeat behavior on triage/low-impact issues before high-stakes work

## FAQ

**Q: Can I use both Linear and GitHub at the same time?**
A: No, only one provider can be active in `.woterclip/config.yaml` at a time. Switch via config and re-run heartbeat.

**Q: What happens to Linear issues after migration?**
A: They remain in Linear. You can export/archive them, or keep them as read-only history.

**Q: Do I need to manually recreate all my Linear issues in GitHub?**
A: Only if you want them in the active queue. Historical Linear issues can remain in Linear.

**Q: What if a GitHub Project field gets renamed?**
A: Run `/woterclip-init` again (merge mode) to auto-repair field IDs.

**Q: Can I use WoterClip without a GitHub Project?**
A: No, GitHub MCP mode requires a Project v2 with Status and Priority fields for queue ranking.

**Q: How do I report bugs or issues with GitHub MCP?**
A: Check `/references/verification-checklist.md` for troubleshooting, or file an issue on the WoterClip repo.
