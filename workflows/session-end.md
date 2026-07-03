# Session End Workflow

**Purpose:** Define the standard procedure for AI assistants to properly close out a development session, ensuring all work is documented and the project state is captured for seamless continuation.

---

## Overview

When the user indicates they're done for the day (or the AI detects a natural stopping point), this workflow ensures:
- All work is documented
- WHERE_WE_ARE is updated
- Session log is created
- Next session can resume seamlessly

---

## Workflow Steps

### Step 1: Detect Session End

The AI should ask about session end when:
- User explicitly says they're done
- A natural milestone is reached
- Significant time has passed
- User seems to be wrapping up

**Prompt:**
> "Are we done for today? If so, what is the current date and time?"

### Step 2: Confirm Session Completion

Wait for user to confirm:
- They are done for the session
- The current date and time

If user wants to continue, proceed with more work instead.

### Step 2.5: Present Pending Batched Tests (If Any)

If there are batchable UI tests that haven't been confirmed yet:

> "Before we close the session, there are [N] UI features awaiting your review:
> 
> **Pending Tests:**
> - [ ] [Feature 1]: [Brief description]
> - [ ] [Feature 2]: [Brief description]
> 
> Would you like to:
> 1. Test these now before we wrap up
> 2. Defer to next session (I'll document them as pending)"

**If user tests now:** Record confirmations, then proceed with documentation.

**If user defers:** Document in session log under "Pending User Confirmations" and note in WHERE_WE_ARE for next session.

**If no pending tests:** Skip to Step 3.

### Step 3: Prepare for Documentation

---
### CONTEXT REFRESH: Documentation Prep

**If you haven't created a session log recently, review:**
- `pillars/01-documentation-procedures.md` - Quick Reference Summary for session end format
- `templates/session-log.template.md` - Full template structure

**For quick refresh on familiar procedure, focus on:**
- Documentation Procedures Quick Reference → "Session End Documentation" section
- Session log template structure (what sections to include)

**If uncertain about the format or what to include, read the full Section 13 (Session Documentation) in the Documentation Procedures.**

**After reviewing, briefly confirm:**
> "Ready to document this session. I will create a session log and update WHERE_WE_ARE with current status and next steps."
---

### Step 4: Create Session Log

Create a new session log file in the logs folder:

**File:** `TDD/logs/YYYY-MM-DD-session-N.md`

Include:
- Session overview (date, duration estimate, active slice)
- Objectives for this session
- What was accomplished
- Decisions made (with rationale)
- Issues encountered
- Tests written/run
- Where we left off
- Notes for next session

### Step 5: Update WHERE_WE_ARE

Update `WHERE_WE_ARE.md` with:

1. **Current Status section:**
   - Active slice
   - Current objective
   - Any blockers

2. **Session History table:**
   - Add new row with date, session number, summary, status

3. **Next Steps section:**
   - Update with immediate actions for next session

4. **Quick Links section:**
   - Update link to latest session log

### Step 6: Confirm Documentation Complete

Present summary to user:

> "Session documentation complete:
> - Session log created: `TDD/logs/YYYY-MM-DD-session-N.md`
> - WHERE_WE_ARE updated with current status
> - Next steps documented
> 
> **Summary of this session:**
> [Brief 2-3 sentence summary]
> 
> **Ready for next session:**
> [First action items]"

### Step 7: Prompt for Git Commit

Ask the user if they want to save changes to version control:

> "Would you like to commit these changes to git?
> 
> **Suggested commit message:**
> ```
> session: End of session YYYY-MM-DD (#N)
> 
> - [Key accomplishment 1]
> - [Key accomplishment 2]
> ```
> 
> Let me know if you'd like me to run the git commands, or if you'll handle it yourself."

**Important:** Do NOT run git commands unless the user explicitly asks. This is a prompt, not automatic behavior.

---

## Session Log Template

**See `pillars/01-documentation-procedures.md` Section 13 (Session Documentation) for the authoritative session log template and format.**

The template includes sections for:
- Session Overview (date, duration, slice, status)
- Objectives This Session
- What Was Accomplished
- Decisions Made
- Issues Encountered
- Tests Written/Run
- Where We Left Off
- Notes for Next Session

For additional detail, you may also reference `templates/session-log.template.md`.

---

## WHERE_WE_ARE Update Template

When updating WHERE_WE_ARE, ensure these sections are current:

```markdown
## Current Status
**Active Slice:** [Current slice]
**Current Objective:** [What to work on next]
**Blockers:** [Any blockers, or "None"]

## Session History
| Date | Session | Summary | Status |
|------|---------|---------|--------|
| [New date] | #[N] | [Brief summary] | Completed |
| [Previous entries...] | | | |

## Next Steps
1. [Immediate next action]
2. [Following action]
3. [Third action if known]
```

---

## Edge Cases

### Session Interrupted Without Proper End

If a session wasn't properly closed:
1. Note this at the start of next session
2. Reconstruct what was done based on git history/file changes
3. Create a retroactive session log with "[Reconstructed]" note
4. Update WHERE_WE_ARE to current state

### Nothing Significant Accomplished

If the session was mostly discussion/planning:
1. Still create a session log
2. Document decisions and discussions
3. Note "Planning/Discussion session" in the summary
4. Update WHERE_WE_ARE if plans changed

### User Leaves Abruptly

If you detect the conversation ending without proper session close:
1. Note in your final message what would need to be documented
2. Suggest documenting at start of next session

### Multiple Short Sessions Same Day

If user has multiple sessions in one day:
1. Number sessions sequentially: `2025-01-15-session-1.md`, `2025-01-15-session-2.md`
2. Each session gets its own log
3. WHERE_WE_ARE reflects the latest state

### Slice Completed This Session

If a slice was completed and confirmed by the user during this session:
1. **Before session end documentation**, follow the `workflows/slice-completion.md` workflow
2. This includes: creating Implementation Notes, updating slice TDD with completion status, and getting user acknowledgment
3. The session log should document the slice completion as a major accomplishment
4. WHERE_WE_ARE updates should reflect the transition to the next slice

**Important:** Slice completion documentation is part of the session, not separate from it. Complete the slice-completion workflow first, then proceed with normal session-end documentation.

---

## Checklist Before Ending

Before confirming session is closed:

- [ ] User confirmed they're done
- [ ] Date/time obtained from user
- [ ] Pending batched tests presented (if any) - user tested or deferred
- [ ] If slice completed this session: slice-completion workflow followed (see `workflows/slice-completion.md`)
- [ ] Session log created with all sections
- [ ] WHERE_WE_ARE updated:
  - [ ] Current Status section
  - [ ] Session History table
  - [ ] Next Steps section
  - [ ] Quick Links (latest session log)
- [ ] Summary presented to user
- [ ] Any uncommitted documentation decisions logged
- [ ] User prompted about git commit (do NOT run git commands unless asked)

---

## Reminders

- **Always get date AND time from user** - Both are required, don't assume either
- **Document even small sessions** - Consistency matters
- **Be specific in next steps** - Help future sessions start quickly
- **Capture decisions** - Even small ones matter for context
- **Update WHERE_WE_ARE last** - After session log is complete
- **Update Quick Links with actual paths** - Replace placeholder paths like `TDD/logs/[YYYY-MM-DD]-session-[N].md` with the real session log filename you just created

---

**End of Session End Workflow**
