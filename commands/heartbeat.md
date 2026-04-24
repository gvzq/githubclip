---
description: Run a WoterClip heartbeat cycle (pick up issues, do work, report)
argument-hint: "[--dry-run] [--persona NAME]"
---

Run the WoterClip heartbeat using the heartbeat skill.

**Provider-aware:** automatically detects provider from `.woterclip/config.yaml` (`github` or `linear`) and routes to the appropriate heartbeat implementation.

Arguments passed: $ARGUMENTS

Parse the arguments:
- If `--dry-run` is present, pass it through to the heartbeat procedure (Step 3 reports what would be picked without doing work)
- If `--persona <name>` is present, filter to only issues matching that persona's label

Execute the full heartbeat procedure (GitHub Project items, persona routing, work, reporting, state updates). On any error or exit, ensure the lockfile at `.woterclip/.heartbeat-lock` is deleted.

**Anti-fragile behaviors enabled:**
- Schema validation and drift detection
- Progressive degradation on write failures
- Canary mutation check
- Recovery journal for crash resume
