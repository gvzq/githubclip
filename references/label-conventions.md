# Label Conventions

WoterClip uses GitHub repository labels for persona routing and agent state tracking. Labels are provider-agnostic but documented here for GitHub usage.

## Label Organization

All WoterClip labels are created in the target repository (configurable prefix default: `WoterClip`). Labels are organized by purpose: system state and persona routing.

## System State Labels

Labels that track agent work state:

| Label | Purpose | Applied by | Removed by |
|---|---|---|---|
| `agent-working` | Agent is actively working this issue | Heartbeat (step 6: lock) | Heartbeat (step 10: update state) on done/blocked |
| `agent-blocked` | Agent is blocked, needs Board attention | Heartbeat (step 10) | Board (manually) or heartbeat when new context appears |

### System Label Rules

- `agent-working` and `agent-blocked` are **mutually exclusive** — never both present simultaneously
- `agent-working` is managed via read-modify-write: fetch issue labels, append, write full set
- Stale `agent-working` labels (older than `stale_lock_hours`) are auto-cleaned by heartbeat
- `agent-blocked` issues are skipped from queue UNLESS new human comments exist since last agent comment
- Labels are applied by reading the current set, modifying locally, then writing the full set back

## Persona Labels

Persona labels route work to the appropriate persona. Created by `/woterclip-init` and registered in `config.yaml`.

| Label | Persona | Role | Typical Signals |
|---|---|---|---|
| `backend` | Backend Engineer | Implementation in backend services | API, endpoint, route, database, migration, query, webhook |
| `frontend` | Frontend Engineer | Implementation in frontend/UI | Component, UI, page, layout, styling, responsive, animation |
| `infra` | Infra Engineer | Infrastructure and deployment | Deploy, CI/CD, Docker, env vars, infrastructure |
| `qa` | QA Engineer | Quality assurance | Test, coverage, E2E, integration test, flaky |
| `ceo` | CEO | Strategic decisions | Strategy, prioritization, roadmap, architecture, cross-cutting |
| *(none)* | Orchestrator (default) | Mechanical triage | Unlabeled issues — routed by Orchestrator persona |

### Persona Label Rules

- **One persona label per issue.** Never dual-label — decompose into sub-issues instead.
- Persona labels are applied by Orchestrator during triage or manually by Board.
- Custom persona labels are created via `/persona-create` and registered in `config.yaml` → `personas` section.
- Persona labels are **immutable at runtime** — change only by Orchestrator re-triage or manual Board intervention.

## Label Lifecycle

```
New issue (unlabeled)
  → Orchestrator triages → applies persona label (e.g., "backend")
  → Heartbeat picks up → adds "agent-working"
  → Work completes → removes "agent-working"
  
  OR
  
  → Work blocked → removes "agent-working", adds "agent-blocked"
  → Board unblocks → removes "agent-blocked"
  → Next heartbeat picks up again
```

## Read-Modify-Write Pattern (GitHub)

GitHub labels are managed as a list on an issue. To safely add or remove a label:

1. **Fetch** current labels on the issue via GitHub API/MCP
2. **Modify** locally (filter/append)
3. **Write** the full label set back to the issue

Example (pseudocode):
```
labels = get_issue_labels(issue_id)
labels.append("agent-working")
set_issue_labels(issue_id, labels)  // writes full set
```

This pattern is safe because:
- WoterClip runs as a **single heartbeat instance per repo** (local lockfile prevents concurrent writers)
- Label write is atomic (replaces entire label set)
- No other agents modify WoterClip labels concurrently

## Label Query Patterns

When filtering issues:

- **Has persona label:** `label:"backend"` or `label:"frontend"` etc.
- **Is agent-working:** `label:"agent-working"`
- **Is blocked:** `label:"agent-blocked"`
- **No persona assigned:** use client-side filter after fetch
- **Exclude blocked:** `NOT label:"agent-blocked"` or client-side filter with human-comment check

## Label Naming

- Use lowercase with hyphens: `agent-working`, `agent-blocked`
- Persona labels match `config.yaml` → `personas[*].label` exactly
- Avoid spaces and special characters
- Keep names under 50 characters for readability
