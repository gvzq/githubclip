# githubclip

GitHub-backed agent orchestration for Claude Code. A single Claude instance wears different "hats" (personas) based on GitHub issue labels – an Orchestrator routes work, a CEO makes strategic calls, and worker personas execute.

## How It Works

```
GitHub Issues → /heartbeat → Persona Matching → Work → Report Back
```

1. **Issues** live in a GitHub Project with persona labels (`backend`, `frontend`, etc.)
2. **Heartbeat** picks the highest-priority issue and resolves which persona handles it
3. **Personas** (CEO, Backend, Frontend, ...) define identity, tools, and runtime config
4. **Reports** are structured comments on the GitHub issue with progress, commits, and blockers
5. **Schedule** runs heartbeats automatically via Claude Code's `/schedule`

The human is the **Board** – the ultimate escalation target when the agent is blocked.

## Install

In Claude Code, add and install from this marketplace:

```bash
/plugin marketplace add gvzq/githubclip
/plugin install githubclip@githubclip
```

Or use the UI: run `/plugin` → **Add Marketplace** → enter `gvzq/githubclip`, then install `githubclip`.

Or for local development:

```bash
git clone https://github.com/gvzq/githubclip.git
claude --plugin-dir /path/to/githubclip
```

### Prerequisites

- [Claude Code](https://claude.ai/code) installed
- **[GitHub plugin](https://claude.ai/marketplace)** installed from the Claude marketplace — search for `claude-plugins-official / GitHub` and enable it. This provides the GitHub MCP integration githubclip depends on.

  Alternatively, connect GitHub MCP manually by adding to your `.mcp.json` or global MCP config:
  ```json
  {
    "mcpServers": {
      "github": {
        "type": "stdio",
        "command": "github-mcp-server",
        "args": ["stdio"],
        "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "<your-token>" }
      }
    }
  }
  ```
- GitHub repository with a GitHub Project v2 (with `Status` and `Priority` custom fields)
- Issues assigned to your GitHub account

## Quick Start

```bash
# 1. Initialize githubclip in your repo (creates config + personas + labels)
/githubclip-init

# 2. Run a single heartbeat cycle
/heartbeat

# 3. Or schedule recurring heartbeats
/schedule 30m /heartbeat

# 4. Check status
/githubclip-status
```

## The Heartbeat Loop

Each `/heartbeat` runs an 11-step cycle:

1. **Load config** – read `.githubclip/config.yaml`, check lockfile
2. **Check inbox** – query GitHub Project for assigned issues, filter and sort
3. **Pick issue** – highest priority In Progress, then Todo
4. **Resolve persona** – match issue label → persona directory, load SOUL.md + TOOLS.md
5. **Validate tools** – check required MCP tools are available
6. **Lock issue** – add `agent-working` label
7. **Understand context** – read issue, comments, heartbeat counter
8. **Do work** – follow persona instructions (CEO triages, workers implement)
9. **Report** – post structured comment with progress, commits, sub-issues
10. **Update state** – manage Project status and labels based on outcome
11. **Next or exit** – pick another issue or clean up and stop

Use `--dry-run` to see what would be picked without doing work. Use `--persona backend` to force a specific persona.

## Personas

Each persona gets its own directory with three files:

| File | Purpose |
|------|---------|
| `SOUL.md` | Identity, posture, voice, decision framework |
| `TOOLS.md` | Available tools and integrations |
| `config.yaml` | Runtime config (model, thinking effort, max turns) |

### Default Personas

| Persona | Role | Model | Turns | Label |
|---------|------|-------|-------|-------|
| Orchestrator | Route issues, decompose work | Haiku | 50 | *(default – no label)* |
| CEO | Strategy, prioritization, architecture | Sonnet | 100 | `ceo` |
| Backend | API, database, server-side | Opus | 300 | `backend` |
| Frontend | UI, components, styling | Sonnet | 200 | `frontend` |

Create custom personas with `/persona-create` or copy directories between repos.

### Per-Repo Structure

After `/githubclip-init`, your repo gets:

```
.githubclip/
├── config.yaml              # GitHub settings, heartbeat behavior, persona routing
├── heartbeat-log.jsonl      # Append-only heartbeat history (created at runtime)
└── personas/
    ├── orchestrator/
    │   ├── SOUL.md
    │   ├── TOOLS.md
    │   └── config.yaml
    ├── ceo/
    │   ├── SOUL.md
    │   ├── TOOLS.md
    │   └── config.yaml
    ├── backend/
    │   ├── SOUL.md
    │   ├── TOOLS.md
    │   └── config.yaml
    └── frontend/
        ├── SOUL.md
        ├── TOOLS.md
        └── config.yaml
```

## Commands

| Command | Description |
|---------|-------------|
| `/heartbeat` | Run one heartbeat cycle |
| `/heartbeat --dry-run` | Show what would be picked up |
| `/heartbeat --persona backend` | Force a specific persona |
| `/githubclip-init` | Initialize githubclip in a repo |
| `/githubclip-status` | Current state, queue, blocked issues |
| `/githubclip-status --history` | Recent heartbeat history |
| `/persona-create` | Create a new persona interactively |
| `/persona-list` | List configured personas |

## Label System

githubclip uses GitHub labels for state management:

| Label | Purpose |
|-------|---------|
| `agent-working` | Agent is actively working this issue |
| `agent-blocked` | Agent is blocked, needs Board attention |
| `backend`, `frontend`, etc. | Routes issue to the matching persona |

All labels are created under a `githubclip` group by `/githubclip-init`.

## Schedule Cadences

| Workload | Cadence | Command |
|----------|---------|---------|
| Active sprint | Every 15-30 min | `/schedule 15m /heartbeat` |
| Steady state | Every 1-2 hours | `/schedule 1h /heartbeat` |
| Background | Every 4-6 hours | `/schedule 4h /heartbeat` |
| Manual only | No schedule | `/heartbeat` when needed |

## Migrating from Paperclip

Use `/persona-import` to convert Paperclip agent directories into githubclip personas. It maps SOUL.md, TOOLS.md, HEARTBEAT.md role-specific sections, and AGENTS.md safety rules into the githubclip format. Budget tracking, PARA memory, and approval workflows are not imported (replaced by Claude Code built-in features or intentionally omitted from v1).

## Background

githubclip is a fork of [woterclip](https://github.com/wotai/woterclip), which was itself inspired by [Paperclip](https://github.com/paperclipai/paperclip) — an agent orchestration platform that uses a central API for task management, agent checkout, and chain-of-command routing. githubclip takes the same core ideas – persona-based identity, structured heartbeats, hierarchical escalation – and rebuilds them as a Claude Code plugin backed by GitHub instead of a custom API. The result is simpler (no server, no database, no separate processes) while keeping the parts that worked well: SOUL.md for agent identity, structured comments for audit trails, and a CEO/worker hierarchy for task decomposition.

## Design

See [`docs/specs/2026-03-25-githubclip-design.md`](docs/specs/2026-03-25-githubclip-design.md) for the full design spec and [`docs/specs/2026-03-25-githubclip-implementation-plan.md`](docs/specs/2026-03-25-githubclip-implementation-plan.md) for the build order.

## License

MIT
