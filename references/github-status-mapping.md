# GitHub Status Mapping

Maps between GitHub Project custom fields and githubclip agent states.

## Provider Context

- **Queue Source:** GitHub Project v2 items (deterministic, single source of truth)
- **State Storage:** Project custom fields + Issue labels
- **Repo Scope:** Single target repository (`owner/repo`)

## GitHub Project → githubclip Behavior

### Status Field Values

| Project Status | githubclip Behavior | Included in Queue |
|---|---|---|
| **Todo** | In the inbox, eligible for pickup (lower priority than In Progress) | ✓ Yes |
| **In Progress** | In the inbox, priority pickup (agent or human started work) | ✓ Yes |
| **In Review** | Ignored — human is reviewing, agent should not touch | ✗ No |
| **Done** | Ignored — completed | ✗ No |
| **Canceled** | Ignored — canceled | ✗ No |

### Priority Field Values

| Project Priority | Sort Rank | Applied When |
|---|---|---|
| **Urgent** | 1 | Critical issues |
| **High** | 2 | High importance |
| **Medium** | 3 | Standard work |
| **Low** | 4 | Nice-to-have |
| **None** | 5 | Unspecified |

## githubclip Outcomes → GitHub State Changes

| Heartbeat Outcome | Project Status | Labels | Issue Close |
|---|---|---|---|
| **Work completed** | → `Done` | Remove `agent-working` | Optional (per config) |
| **Work in progress** | Stay `In Progress` | Keep `agent-working` | — |
| **Blocked** | Stay `In Progress` | Remove `agent-working`, add `agent-blocked` | — |
| **Triaged by Orchestrator** | Stay `Todo` | Add persona label if missing | — |
| **More work needed** | Stay `In Progress` | Keep `agent-working` | — |

## Inbox Query Algorithm

### Queue Building (Project Items)

1. Fetch paginated Project items from configured project
2. Filter to:
   - Content type: `Issue` only (exclude DraftIssue, PullRequest)
   - Repository: matches configured `owner/repo`
   - Assignee: current actor (GitHub login)
   - Status: `Todo` or `In Progress`
3. Repair missing Project item fields:
   - If issue not in project → add item, set `Status=Todo`, set `Priority=None`
   - If issue missing field values → initialize to defaults
4. Apply persona label filter (if `--persona` flag set)

### Sort Order

1. **Status Rank:** `In Progress` (rank 0) > `Todo` (rank 1)
2. **Priority Rank:** `Urgent` (1) > `High` (2) > `Medium` (3) > `Low` (4) > `None` (5)
3. **Updated At:** Most recent first
4. **Issue Number:** Lowest first (final tie-break)

### Filter Rules

- Include issues with matching persona label or default persona (Orchestrator)
- Exclude `agent-blocked` issues unless new human comments exist since last agent comment
- Exclude issues in any other Project status
- Respect `--persona <name>` flag to limit routing

## Stale Detection and Cleanup

- **Stale lock:** Issue has `agent-working` label but no heartbeat comment within `stale_lock_hours`
- **Cleanup:** Remove `agent-working` label and post explanatory comment
- **Next heartbeat:** Issue re-enters queue if status conditions met

## Lock Semantics

### Distributed Lock Safety

- **Local lock:** `.githubclip/.heartbeat-lock` file
- **Issue lock:** `agent-working` label + timestamp verification from latest heartbeat comment
- **Dual-prevention:** On lock acquisition, check if another heartbeat is active via:
  - `agent-working` label exists
  - Last heartbeat comment timestamp is recent (within `stale_lock_hours`)
  - If true, skip this issue and continue to next

### Lock Release

On **any exit path** (success, error, early return), delete lockfile. State of `agent-working` label depends on outcome:
- **Completed:** remove `agent-working`
- **Blocked:** remove `agent-working`, add `agent-blocked`
- **More work:** keep `agent-working`

## Identity Resolution

- **Assignee identity:** Always compare by GitHub `login` (never display name)
- **User identity:** Resolve `user_name` to GitHub login once at startup for @-mentions

## Error Handling and Degradation

### Read-Mode Failures

- Issue returned by search but inaccessible in project (`REDACTED`): skip with audit log, continue
- Missing Project item for an assigned issue: add to project with defaults, continue
- Pagination timeout: retry with exponential backoff (429/5xx)

### Write-Mode Failures

- Field update fails: post error comment, keep `agent-working`, decide on retry
- Comment post fails: retry before releasing lock
- Multiple field mutations fail: circuit breaker triggers, switch to read-only for this run

## Anti-Fragile Patterns

- **Progressive degradation:** continue triage even if Project field writes unavailable
- **Circuit breaker:** after N consecutive write failures, auto-downgrade to read-only
- **Replay safety:** all mutations are idempotent (set value, not toggle)
- **Drift sentry:** schema checksum validation at heartbeat start
- **Recovery journal:** append action records to heartbeat log for crash recovery
- **Canary apply:** first mutation per run is a low-risk field check
- **Reconciliation pass:** optional end-of-run cleanup of stale labels/inconsistent states
