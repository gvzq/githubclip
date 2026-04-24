---
description: Initialize githubclip in this repo (config, personas, GitHub Project fields, labels)
---

Initialize githubclip in this repository using the githubclip-init skill.

Follow the full initialization procedure from the skill:
1. Verify GitHub MCP is available
2. Gather GitHub context (repo, login)
3. Select or create GitHub Project
4. Enforce required custom fields (`Status`, `Priority`)
5. Create GitHub labels (state + persona labels)
6. Ask which persona preset to scaffold
7. Scaffold `.githubclip/` with config and persona templates from `${CLAUDE_PLUGIN_ROOT}/templates/`
8. Validate configuration and run mutation smoke test
9. Offer schedule setup
10. Print summary of what was created

If `.githubclip/` already exists, ask whether to overwrite, merge, or cancel before proceeding.

**GitHub-specific setup:**
- Requires GitHub MCP or `gh` CLI (authenticated)
- Creates/validates GitHub Project v2 with custom fields
- Resolves and stores stable GraphQL IDs for all fields and options
- Creates repository labels for persona routing and agent state tracking
