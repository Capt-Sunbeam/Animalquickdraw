# Slice Completion Workflow

**Purpose:** Define the standard procedure for marking a slice as complete, ensuring all requirements are met, documentation is created, and the project is ready to move to the next slice.

---

## Overview

A slice is not complete until:
1. All implementation checklist items are done
2. All tests are passing
3. User has confirmed UI/frontend features work
4. User explicitly acknowledges slice is ready for completion
5. Implementation Notes document is created
6. WHERE_WE_ARE is updated

This workflow ensures nothing is missed.

---

## Workflow Steps

### Step 1: Verify Checklist Completion

---
### CONTEXT REFRESH: Completion Verification

**Review the slice requirements:**
- Current slice TDD - Focus on Implementation Checklist and Exit Criteria sections
- `pillars/02-slice-contract-template.md` - Quick Reference Summary → Exit Criteria

**For quick reference on what "complete" means:**
- All checklist items done
- All tests passing
- User confirmed UI features
- Implementation Notes created
- WHERE_WE_ARE updated

**If uncertain whether something counts as complete, review the full Exit Criteria in the Slice Contract Template.**

**After reviewing, confirm:**
> "I have reviewed the slice requirements. Checking completion status..."
---

Go through the Implementation Checklist in the slice TDD:

```markdown
## Completion Status Check

### Implementation Checklist
- [x] Item 1 - DONE
- [x] Item 2 - DONE
- [ ] Item 3 - **NOT COMPLETE** [describe what's missing]
...

### Status: [READY / NOT READY]
```

If any items are incomplete, address them before proceeding.

### Step 2: Verify All Tests Passing

Run all tests related to this slice:

```
[Run test command for the slice]
```

**Required:**
- All unit tests passing
- All integration tests passing
- No regressions in other slices

If tests fail, fix issues before proceeding.

### Step 3: Batch User Confirmation for UI Features

Present all pending batchable UI tests as a single checklist. Blocking tests should have been requested and confirmed during implementation - this batch is for non-blocking UI quality confirmation.

> "Before marking this slice complete, please test these UI features:
> 
> **Test Checklist:**
> - [ ] [Feature 1]: [Location] - [Expected behavior]
> - [ ] [Feature 2]: [Location] - [Expected behavior]
> - [ ] [Feature 3]: [Location] - [Expected behavior]
> - [ ] [Feature 4]: [Location] - [Expected behavior]
> 
> Please test and report which pass and which have issues. I can continue with documentation while you test."

**User can test at their pace.** You may proceed with creating Implementation Notes (Step 4) while the user tests, but do NOT mark the slice complete until user confirms all features work.

**If user reports issues:** Fix them and re-request confirmation for the fixed items only.

**If user cannot test right now:** The slice remains "In Progress" until testing is complete. Document pending tests in WHERE_WE_ARE and session log. See `workflows/testing-protocol.md` → "Handling Deferred Testing".

### Step 4: Request User Acknowledgment

Once all UI features are confirmed working, request explicit acknowledgment before creating documentation:

> "All tests are passing and UI features are confirmed working.
> 
> **Slice [N]: [Name] is ready to be marked complete.**
> 
> **Summary:**
> - All [X] checklist items completed
> - All tests passing
> - UI features confirmed working
> 
> **Deviations from original design:**
> - [List any deviations, or "None"]
> 
> Do you approve marking this slice as complete? Once confirmed, I'll create the completion documentation."

**Wait for user acknowledgment before proceeding with documentation.**

### Step 5: Create Implementation Notes

---
### CONTEXT REFRESH: Implementation Notes Prep

**If you haven't written Implementation Notes recently, review:**
- `pillars/01-documentation-procedures.md` - Quick Reference Summary → "Slice Completion Documentation"
- `templates/implementation-notes.template.md` - Full template structure

**Key things Implementation Notes must capture:**
- Deviations from original TDD (what changed and why)
- Files created/modified
- Test summary
- Lessons learned

**If uncertain about format or what to include, read full Section 14 (Slice Completion Documentation) in Documentation Procedures.**

**After reviewing, confirm:**
> "Ready to create Implementation Notes documenting the actual implementation."
---

Create the Implementation Notes document:

**File:** `TDD/[slice-number]-[slice-name]-implementation-notes.md`

Include:
- Completion date
- Link to original TDD
- Summary of what was implemented
- All deviations from original design
- Files created/modified
- Testing summary
- Lessons learned
- Known limitations

### Step 6: Update Slice TDD with Completion Status

Add to the bottom of the slice TDD:

```markdown
---

## Implementation Status

**Status:** COMPLETE
**Completed:** [Date from user]
**Implementation Notes:** [Link to implementation notes document]

### Summary of Deviations
- [Brief list of significant deviations]
```

### Step 7: Update WHERE_WE_ARE

Update `WHERE_WE_ARE.md`:

1. **Current Status:**
   - Change Active Slice to next slice
   - Update Current Objective for next slice
   - Clear any slice-specific blockers

2. **Add to Completed Slices list** (if you maintain one)

3. **Next Steps:**
   - Update to reference next slice objectives

### Step 8: Confirm Completion to User

Notify the user that all documentation is complete:

> "Slice [N]: [Name] documentation is complete!
> 
> **Created:**
> - Implementation Notes: `[path]`
> - Slice TDD updated with completion status
> - WHERE_WE_ARE updated
> 
> **Next slice:** Slice [N+1]: [Name]
> - [Brief description of what's next]"

### Step 9: Prompt for Git Commit

Ask the user if they want to save the slice completion to version control:

> "Would you like to commit these changes to git?
> 
> **Suggested commit message:**
> ```
> feat(slice-N): Complete [Slice Name]
> 
> - [Key feature/functionality implemented]
> - Implementation notes and documentation added
> ```
> 
> Let me know if you'd like me to run the git commands, or if you'll handle it yourself."

**Important:** Do NOT run git commands unless the user explicitly asks. This is a prompt, not automatic behavior.

---

## Implementation Notes Template

**See `pillars/01-documentation-procedures.md` Section 14 (Slice Completion Documentation) for the authoritative Implementation Notes template and format.**

The template includes sections for:
- Completion date and TDD reference
- Implementation Summary
- Deviations from Original Design (with reason and impact)
- Files Created/Modified
- Key Implementation Details
- Testing Summary
- Lessons Learned
- Known Limitations

For additional detail, you may also reference `templates/implementation-notes.template.md`.

---

## Exit Criteria Checklist

Before a slice can be marked complete:

### Code Complete
- [ ] All features implemented per TDD
- [ ] All business logic working
- [ ] Error handling in place
- [ ] Edge cases handled

### Tests Complete
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing
- [ ] No test regressions in other slices

### User Verification
- [ ] All UI features tested by user
- [ ] User confirmed features work correctly
- [ ] User approved any design deviations

### Documentation Complete
- [ ] Implementation Notes document created
- [ ] Slice TDD updated with completion status
- [ ] WHERE_WE_ARE updated
- [ ] Decision Log updated (if any decisions made)

### Final Approval
- [ ] User explicitly acknowledged slice completion
- [ ] User prompted about git commit (do NOT run git commands unless asked)

---

## Edge Cases

### Minor Issues Discovered During Completion

If small issues are found during the completion process:
1. Fix if quick (< 30 minutes)
2. If larger, document in Known Limitations
3. Create follow-up task for next slice or maintenance

### User Finds UI Issue

If user reports an issue during UI confirmation:
1. Assess severity (blocking vs. cosmetic)
2. Blocking issues: Fix before completion
3. Cosmetic issues: Document and optionally defer
4. Re-request confirmation after fixes

### Significant Deviation Discovered Late

If you realize a major deviation wasn't documented:
1. Stop the completion process
2. Document the deviation properly
3. Assess impact on other slices
4. Get user approval for the deviation
5. Resume completion process

### Tests Failing That Weren't Caught Earlier

If tests fail during completion verification:
1. Do not mark slice complete
2. Fix the failing tests
3. Verify no regressions introduced
4. Resume from Step 2

---

## Reminders

- **Never skip user confirmation** - UI features must be tested by user
- **Get acknowledgment before documenting** - User approves completion, then AI creates documentation
- **Document all deviations** - Even small ones matter
- **Update WHERE_WE_ARE last** - After all other documentation
- **Be thorough with Implementation Notes** - They're the historical record

---

**End of Slice Completion Workflow**
