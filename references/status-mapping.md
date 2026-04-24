# Status Mapping

Maps between provider-specific workflow states and githubclip agent states, with GitHub as the primary provider.

## GitHub Project States → githubclip Behavior

### Status Field

| Project Status | githubclip Behavior | In Queue |
|---|---|---|
| **Todo** | Inbox eligible for pickup (lower priority than In Progress) | ✓ |
| **In Progress** | Inbox priority pickup (agent or human started work) | ✓ |
| **In Review** | Ignored — human review in progress, agent should not touch | ✗ |
| **Done** | Ignored — completed | ✗ |
| **Canceled** | Ignored — canceled or declined | ✗ |

### Priority Field (ordering within status)

| Priority | Rank | Usage |
|---|---|---|
| **Urgent** | 1 | Critical, blocks others |
| **High** | 2 | Important, high value |
| **Medium** | 3 | Standard work |
| **Low** | 4 | Nice-to-have, can defer |
| **None** | 5 | Unspecified or default |

## githubclip Outcomes → GitHub State Changes

| Heartbeat Outcome | Project Status | Labels | Issue Close |
|---|---|---|---|
| **Work completed** | → `Done` | Remove `agent-working` | Per config |
| **Work in progress** | Stay `In Progress` | Keep `agent-working` | — |
| **Blocked** | Stay `In Progress` | Remove `agent-working`, add `agent-blocked` | — |
| **Triaged by Orchestrator** | Stay `Todo` | Add persona label if missing | — |
| **More work needed** | Stay `In Progress` | Keep `agent-working` | — |

## Queue Building Algorithm

### GitHub Project Items Query

1. **Fetch Project items** (paginated)
   - Filter: `content_type = Issue` (exclude DraftIssue, PullRequest)
   - Filter: `repo = owner/repo` (single repository)
   - Filter: `assignee = current_actor` (GitHub login)
   - Filter: `status in (Todo, In Progress)`

2. **Repair missing project state**
   - If issue not yet a project item → add to project, set Status=Todo, Priority=None
   - If item has no Status/Priority values → initialize to defaults

3. **Apply persona label filter**
   - Include issues with matching persona label OR default persona (Orchestrator)
   - If `--persona <name>` flag set → filter to that persona only

4. **Exclude blocked work**
   - Skip issues with `agent-blocked` label UNLESS new human comments exist since last agent comment

### Sort Order (Deterministic Tiebreaker)

1. **Status Rank:** `In Progress` (0) > `Todo` (1)
2. **Priority Rank:** `Urgent` (1) > `High` (2) > `Medium` (3) > `Low` (4) > `None` (5)
3. **Updated At:** Most recent first (ISO 8601)
4. **Issue Number:** Lowest first (final tiebreaker)

### Filter Rules Summary

- Include: matching persona label OR default persona
- Include: status in (Todo, In Progress)
- Exclude: `agent-blocked` with no new human comments
- Exclude: issues not assigned to current actor
- Exclude: issues from other repositories
- Exclude: DraftIssue and PullRequest types

## Stale Lock Detection

- **Condition:** Issue has `agent-working` label but no heartbeat comment within `stale_lock_hours`
- **Action:** Remove `agent-working` label and post cleanup comment
- **Next heartbeat:** Issue re-enters queue if status conditions are met

## Distributed Lock Safety

### Lock Acquisition
- Check if `agent-working` already present on issue
- Verify no recent heartbeat timestamp (within `stale_lock_hours`)
- Add `agent-working` label and record timestamp in comment

### Lock Release (All Exit Paths)
- **Completed:** Remove `agent-working`
- **Blocked:** Remove `agent-working`, add `agent-blocked`
- **More work:** Keep `agent-working`
- Always delete local `.githubclip/.heartbeat-lock` file

## Identity Resolution

- **Assignee matching:** By GitHub login only (not display name)
- **Actor identity:** Resolved once at heartbeat start, cached for @-mentions
- **Persona routing:** Exact label match (case-sensitive)

## Migration from Linear

For repos migrating from Linear:

| Linear State | → GitHub Status |
|---|---|
| Backlog | (not created in project) |
| Todo | Todo |
| In Progress | In Progress |
| In Review | In Review |
| Done | Done |
| Canceled | Canceled |

Use `compat.source_provider: linear` in config during transition period.
