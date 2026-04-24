# How to Execute Phases 1-4 Testing

**Status:** All testing documentation and automation scripts ready  
**Location:** Repository `/docs/` and `/scripts/` directories  
**Execution:** In your target GitHub repository

---

## Quick Start (TL;DR)

```bash
# 1. Clone or navigate to your GitHub repository
cd your-github-repo

# 2. Run automated setup for Phase 1
bash path/to/woterclip/scripts/setup-phase1-testing.sh

# 3. Follow the step-by-step guide
cat path/to/woterclip/docs/phases-1-4-testing-guide.md

# 4. Check off items as you complete them
cat path/to/woterclip/docs/phases-1-4-execution-checklist.md

# 5. Document results
cat path/to/woterclip/docs/test-results-summary-template.md
```

---

## Files You Need

Copy these files from the WoterClip repository to your local environment:

```
woterclip/
├── docs/
│   ├── phases-1-4-testing-guide.md           ← Main reference (detailed steps + troubleshooting)
│   ├── phases-1-4-execution-checklist.md     ← Progress tracking (check off as you go)
│   └── test-results-summary-template.md      ← Document your results
└── scripts/
    └── setup-phase1-testing.sh               ← Automates Phase 1 setup
```

---

## Phase Execution Flow

### Phase 1: Read-Only Dry-Run (15 min)

**What it tests:** Queue building, ranking, persona routing, filtering

**How to execute:**
1. `bash scripts/setup-phase1-testing.sh` (automated setup)
2. Run `/heartbeat --dry-run` in Claude Code
3. Compare output to checklist in `docs/phases-1-4-execution-checklist.md` under "Phase 1"
4. Check off items as they pass

**Success criteria:**
- Queue ranks by Status (In Progress > Todo) then Priority
- Persona labels are recognized
- Blocked issues are excluded
- Output matches expected format

**Expected duration:** 15 minutes  
**Manual work:** Create project and issues (GitHub UI), then automate rest

---

### Phase 2: Comment Operations & Locking (10 min)

**What it tests:** Heartbeat comments, counter increments, label locking, distributed locks

**How to execute:**
1. Continue with same test environment from Phase 1
2. Run `/heartbeat` (not dry-run) on one issue
3. Verify comment posted with `Heartbeat #1`
4. Run `/heartbeat` again on same issue
5. Verify counter is `Heartbeat #2` and previous comment is linked
6. Check off items in checklist

**Success criteria:**
- Comments posted with correct format
- Counter increments (#1, #2, #3, etc.)
- `agent-working` label applied once
- No duplicate labels

**Expected duration:** 10 minutes  
**Manual work:** None (automates via Claude Code)

---

### Phase 3: Project Field Mutations (15 min)

**What it tests:** GitHub Project Status/Priority field updates, transition outcomes

**How to execute:**
1. Continue with same test environment from Phase 2
2. Note a test issue's current Project Status
3. Run `/heartbeat` to work on that issue
4. Check that Status field changed correctly in Project
5. Verify via `gh api graphql` (command in guide)
6. Check off items in checklist

**Success criteria:**
- Status field updates on completion (Todo → Done or In Progress → Done)
- Priority field is maintained (not overwritten)
- Transitions are deterministic (completed/blocked/more_work/triaged outcomes)
- Multiple issues are picked in correct order

**Expected duration:** 15 minutes  
**Manual work:** None (all via CLI/IDE)

---

### Phase 4: Anti-Fragile Behavior (20 min)

**What it tests:** Degradation mode, circuit breaker, recovery journal, drift sentry, idempotent re-init

**How to execute:**
1. Follow step-by-step in `docs/phases-1-4-testing-guide.md` under Phase 4
2. **Degradation test:** Corrupt config, run heartbeat, verify it degrades gracefully
3. **Circuit breaker:** Corrupt config, run heartbeat 3x, verify circuit breaker activates
4. **Recovery journal:** Check `.woterclip/heartbeat-log.jsonl` contents
5. **Drift sentry:** Corrupt config, run heartbeat, verify drift is detected
6. **Idempotent re-init:** Run `/woterclip-init` twice, verify config unchanged
7. Check off items in checklist

**Success criteria:**
- Degradation mode prevents crashes
- Circuit breaker auto-activates and resets
- Recovery journal has valid entries
- Schema drift is detected
- Re-init doesn't modify existing config

**Expected duration:** 20 minutes  
**Manual work:** Some config edits (provided as bash commands in guide)

---

## Full Execution Timeline

| Phase | Duration | Manual | Auto | Total |
|-------|----------|--------|------|-------|
| 1 | Setup: 5min | 5min | 10min | 15min |
| 2 | Execution | — | 10min | 10min |
| 3 | Execution | — | 15min | 15min |
| 4 | Execution | 5min | 15min | 20min |
| **Phases 1-4 Total** | | **10min** | **50min** | **60min** |

---

## What to Do During Each Phase

### While Running Phase 1 (Dry-Run)

✅ DO:
- Read the "Phase 1" section in `docs/phases-1-4-testing-guide.md` first
- Follow the validation checklist
- Note any unexpected behavior
- Compare dry-run output to expected output examples

❌ DON'T:
- Skip the setup steps
- Test with production issues
- Modify the implementation yet

### While Running Phases 2-4

✅ DO:
- Follow the step-by-step guide
- Check off items in the checklist
- Document any issues found
- Note timings and observations

❌ DON'T:
- Skip troubleshooting sections if something fails
- Modify config unless instructed
- Test on production repos

---

## If Something Fails

### Immediate Action

1. **Stop the current phase**
2. **Read the troubleshooting section** in `docs/phases-1-4-testing-guide.md` for your phase
3. **Check the logs:**
   ```bash
   cat .woterclip/heartbeat-log.jsonl | tail -20 | jq '.'
   ```

4. **Verify config:**
   ```bash
   cat .woterclip/config.yaml | head -20
   ```

5. **Check GitHub via CLI:**
   ```bash
   gh issue list --assigned @me
   gh label list
   ```

### Common Issues

| Issue | Solution |
|-------|----------|
| "Config not found" | Run `/woterclip-init` first |
| "No issues in queue" | Check issues assigned to you + in Project |
| "Queue ranking wrong" | Verify Project Status/Priority fields are set correctly |
| "Comment not posted" | Check persona TOOLS.md has GitHub tools |
| "Field mutation fails" | Check field IDs are not null in config |
| "Degradation not working" | Verify circuit_breaker config is enabled |

---

## Success Criteria (All Phases)

After completing all 4 phases, verify:

```bash
# Config is valid
cat .woterclip/config.yaml | head -10

# No stale Linear references
grep -r "mcp__claude_ai_Linear" .woterclip/ && echo "FOUND (BAD)" || echo "✓ None (good)"

# Labels exist
gh label list | grep -E "agent-working|agent-blocked"

# Heartbeat log has entries
wc -l .woterclip/heartbeat-log.jsonl
```

**All checks should show ✅**

---

## Document Your Results

1. Copy `docs/test-results-summary-template.md`
2. Fill in your results for each phase
3. Include any issues found and how they were resolved
4. Sign off when complete

**Keep this for your records!**

---

## Next Steps After Success

1. ✅ **Phases 1-4 complete** → Delete test issues and project
2. 🚀 **Deploy to production** → Use in real repositories
3. 📊 **Monitor logs** → Watch `.woterclip/heartbeat-log.jsonl` for errors
4. 🎯 **Customize personas** → Adjust SOUL.md for your team workflows
5. 📝 **Document findings** → Share test results with your team

---

## Support & Documentation

**While Testing:**
- `docs/phases-1-4-testing-guide.md` ← Main reference
- `docs/phases-1-4-execution-checklist.md` ← Progress tracking
- `docs/github-migration-guide.md` ← FAQ & troubleshooting

**After Testing:**
- `IMPLEMENTATION.md` ← Architecture overview
- `CLAUDE.md` ← Core system design
- `references/github-status-mapping.md` ← State transitions

---

## Summary

You now have **everything needed** to test Phases 1-4 in any GitHub repository:

✅ **Automated setup** (Phase 1)  
✅ **Step-by-step guides** (all phases)  
✅ **Detailed checklists** (all phases)  
✅ **Troubleshooting help** (all phases)  
✅ **Results template** (documentation)  

**Time to execute:** ~60 minutes total  
**Prerequisite:** GitHub repository with project support + GitHub CLI authentication

**Ready to test?** Start with Phase 1!
