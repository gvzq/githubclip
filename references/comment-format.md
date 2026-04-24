# Comment Format

All heartbeat comments follow a structured template posted via GitHub issue comments. Comments are provider-agnostic in structure but adapted for GitHub links.

## Standard Template

```markdown
## Heartbeat #N — YYYY-MM-DD HH:MM UTC (Xm Ys duration)

**Status:** In Progress | Completed | Blocked

### What was done
- [`a1b2c3d`](https://github.com/OWNER/REPO/commit/a1b2c3d) feat(api): commit message
- Description of non-commit work

### Next steps
- Next steps for this issue

### Blockers
None

---
*WoterClip · persona-name · [#123](https://github.com/OWNER/REPO/issues/123) · from [Heartbeat #N-1](link)*
```

## Blocked Template

```markdown
## Heartbeat #N — YYYY-MM-DD HH:MM UTC (Xm Ys duration)

**Status:** Blocked

### Blocker
Clear description of what is blocking progress.

### Action needed
@github-user — specific ask for what they need to do.

### What was done before blocking
- Work completed before hitting the blocker

---
*WoterClip · persona-name · [#123](https://github.com/OWNER/REPO/issues/123)*
```

## Triage Template (Orchestrator)

```markdown
## Heartbeat #N — YYYY-MM-DD HH:MM UTC (Xm Ys duration)

**Status:** Triaged

### Routing decision
**→ backend** — API endpoint implementation

### Why
Reasoning for routing choice

### Next
Awaiting backend persona to pick up

---
*WoterClip · orchestrator · [#123](https://github.com/OWNER/REPO/issues/123)*
```

## Rules

- **Always include** heartbeat counter (`#N`) and timestamp with duration (e.g., "2m 34s")
- **Always include** persona name and issue link in footer
- Reference previous heartbeat comment link for carry-forward context (except first heartbeat)
- **Blocked comments must name** who needs to act: `@github-login` from config `github.user_name`
- **Completion comments must list** shipped commits/PRs with links
- Use `⚠️` flag for uncertain work that needs manual verification
- Fast-path triage comments: `**Triage:** → backend` for obvious routing to persona
- Use relative links for same-repo references; use full URLs for cross-repo

## Heartbeat Counter

The counter is **derived from GitHub issue comments**, not stored locally:

1. Parse the last WoterClip heartbeat comment on the issue for `Heartbeat #N` pattern
2. Increment N for the new comment
3. If no previous comment exists, start at `#1`
4. If comments are deleted/edited, recompute from remaining valid bot-authored comments only

## Footer Format

The footer line connects the comment to its operational context:

- `WoterClip` — identifies this as an agent heartbeat comment
- `persona-name` — which persona produced this work (matches `config.yaml` → `personas[*].label` or name)
- `[#123](...)` — GitHub issue number with link
- `from [Heartbeat #N-1](...)` — link to previous heartbeat comment (omit on first heartbeat, omit if no prior heartbeats)

## GitHub Links

- **Commit link:** `[a1b2c3d](https://github.com/OWNER/REPO/commit/a1b2c3d)`
- **Issue link:** `[#123](https://github.com/OWNER/REPO/issues/123)`
- **PR link:** `[#456](https://github.com/OWNER/REPO/pull/456)`
- **Comment link:** `[#123 (comment-id)](https://github.com/OWNER/REPO/issues/123#issuecomment-comment-id)`

## Anti-Fragile Markers

- `⚠️ Uncertain` — work completed but uncertain, needs manual verification
- `🔄 Partial` — work in progress, will continue next heartbeat
- `❌ Degraded` — run completed in degraded mode (read-only), Project field updates skipped
- `🔧 Repaired` — auto-repair was applied (e.g., missing Project field values initialized)
