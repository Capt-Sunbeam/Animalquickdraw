# Documentation Procedures

**Purpose:** Define how to maintain, update, and use the Technical Design Document folder throughout the development lifecycle. This document is framework-agnostic and applies to any software project.

---

## Table of Contents

1. [Overview](#overview)
2. [Reading Guidance & Context Refresh](#reading-guidance--context-refresh)
3. [Document Lifecycle](#document-lifecycle)
4. [When to Update Documents](#when-to-update-documents)
5. [Update Procedures](#update-procedures)
6. [Decision Log](#decision-log)
7. [Change Request Process](#change-request-process)
8. [Version Control](#version-control)
9. [Code-to-Design Traceability](#code-to-design-traceability)
10. [Review Process](#review-process)
11. [Document Maintenance Schedule](#document-maintenance-schedule)
12. [Progress Tracking (WHERE_WE_ARE)](#progress-tracking-where_we_are)
13. [Session Documentation](#session-documentation)
14. [Slice Completion Documentation](#slice-completion-documentation)

---

## Quick Reference Summary

**Use this section for quick refreshes on familiar procedures. For first-time reading or uncertainty, read the full sections.**

### Reading Guidance (Section 2)
- **Core principle:** "When in doubt, read more."
- **Full read:** New slice, first encounter with document, uncertain, architectural decisions
- **Targeted read:** Routine checkpoints, familiar procedures
- **Glance:** Quick format/template checks
- See Task-Specific Reading Map for what to read for common tasks

### Session End Documentation (Section 13)
1. Create session log: `TDD/logs/YYYY-MM-DD-session-N.md`
2. Update WHERE_WE_ARE: Current Status, Session History table, Next Steps
3. Include: objectives, accomplishments, decisions, issues, tests, where we left off

### Slice Completion Documentation (Section 14)
1. Create Implementation Notes: `TDD/[slice-number]-[slice-name]-implementation-notes.md`
2. Document all deviations from original TDD
3. Include: files created/modified, test summary, lessons learned
4. Update slice TDD with completion status
5. Update WHERE_WE_ARE to point to next slice

### Decision Log Format (Section 6)
```markdown
## Decision: [Title]
**Date:** YYYY-MM-DD | **Slice:** [Affected] | **Decided by:** [Who]
### Context → Decision → Rationale → Alternatives → Impact → Status
```

### When to Update Documents (Section 4)
- **Always**: Architecture changes, new events/actions, API changes, breaking changes
- **Consider**: UI flow changes, performance approach changes, edge cases
- **Skip**: Bug fixes, code cleanup, UI polish, dependency bumps

### Key Files
| File | Purpose | Update Frequency |
|------|---------|------------------|
| WHERE_WE_ARE.md | Project status | Every session |
| Session Logs | Session records | Every session |
| Decision Log | Design decisions | When decisions made |
| Implementation Notes | Actual vs planned | Slice completion |

### File Naming Convention

All TDD files use **kebab-case** (lowercase with hyphens):

| File Type | Pattern | Example |
|-----------|---------|---------|
| Slice TDDs | `NN-slice-name.md` | `01-task-management.md` |
| Skeleton | `00-skeleton-build-guide.md` | — |
| Implementation Notes | `NN-slice-name-implementation-notes.md` | `01-task-management-implementation-notes.md` |
| Session Logs | `YYYY-MM-DD-session-N.md` | `2025-01-15-session-1.md` |
| Recipe | `recipe.md` | — |
| Decision Log | `decision-log.md` | — |
| Consistency Guide | `consistency-guide.md` | — |
| Overview | `overview-of-slices.md` | — |

**Rules:**
- All lowercase (except date components)
- Hyphens between words
- Two-digit slice numbers with leading zero (`01`, `02`, not `1`, `2`)
- No underscores, no spaces

---

## Overview

The TDD folder is a living set of documents that evolve with the project. These procedures ensure:

- **Accuracy**: Documentation reflects actual implementation
- **Traceability**: Changes tracked and reasoned
- **Clarity**: Developers always have current, reliable reference
- **Efficiency**: Updates are structured and not burdensome
- **Continuity**: Any developer or AI can resume work seamlessly

### Document Types in TDD Folder

1. **Skeleton Build Guide**: Foundation architecture (rarely changes)
2. **Slice Documents**: Feature implementation specs (update as implemented)
3. **Supporting Documents**: Templates, procedures, overviews (stable)
4. **WHERE_WE_ARE**: Current project status and session history (updated every session)
5. **Session Logs**: Detailed record of each development session
6. **Implementation Notes**: Post-completion documentation of actual implementation

---

## Reading Guidance & Context Refresh

### Purpose

This section helps AI assistants read documentation efficiently without missing critical information. The goal is **efficiency without sacrificing quality** - read thoroughly when needed, selectively when appropriate.

### Core Principle

**"When in doubt, read more."**

These guidelines help you be efficient when efficiency is safe. They never prevent thorough reading when thoroughness is needed.

### Reading Depth Tiers

| Tier | When to Use | What to Read |
|------|-------------|--------------|
| **Full** | Starting new slice, first encounter with a document, uncertain about something | Entire relevant document(s) |
| **Targeted** | Routine checkpoints, familiar procedures | Table of Contents → specific sections needed |
| **Glance** | Quick format reference, template structure check | Just the template/example blocks |

### When to Read Fully

Read the COMPLETE document when:
- **Starting work on a new slice** - Read the full slice TDD, all 12 sections
- **First time referencing a document** in this session
- **Something isn't working** as expected
- **You're unsure** whether you have enough context
- **Making architectural decisions** that affect integration

### When Selective Reading is Sufficient

For ROUTINE tasks you've done before, you may read selectively:
- Session end documentation → Session log template + WHERE_WE_ARE update section
- Formatting a decision log entry → Decision Log format example only
- Checking a specific procedure → That section via Table of Contents

### How to Read Selectively (When Appropriate)

1. Read the Table of Contents or Quick Reference Summary
2. Go to the section(s) relevant to your current task
3. If that section references other sections, follow those references
4. **If still uncertain, read more broadly**

### Task-Specific Reading Map

Use this table to know what to read for common tasks:

| Task | Documents | What to Read | Depth |
|------|-----------|--------------|-------|
| **Starting new slice** | Slice TDD, Consistency Guide | Full slice TDD; relevant patterns in Consistency Guide | Full |
| **Resuming session** | WHERE_WE_ARE, current slice TDD | Full WHERE_WE_ARE; slice overview + current checklist items | Full/Targeted |
| **Session end** | Documentation Procedures, session-log template | Section 13 (Session Documentation); full template | Targeted |
| **Writing implementation notes** | Documentation Procedures, implementation-notes template | Section 14 (Slice Completion); full template | Targeted |
| **Slice completion check** | Slice Contract Template | Exit Criteria section; Implementation Checklist | Targeted |
| **Making design decision** | Consistency Guide, current slice TDD | Relevant pattern sections; Integration Points | Targeted/Full |
| **Writing tests** | Testing Protocol | Full document (it's concise) | Full |
| **Quick format check** | Any template | Just the template structure | Glance |

### Context Refresh Checkpoints

During long sessions, AI attention can drift from earlier instructions. Checkpoints remind you to refresh context at critical moments.

**Checkpoint Format:**

```markdown
---
### CONTEXT REFRESH: [Name]

**If you haven't read these recently, review now:**
- `document/path.md` - [specific sections or "full document"]

**For quick refresh on familiar procedures, focus on:**
- [Most relevant section]
- [Second most relevant section]

**If uncertain about anything, read more broadly.**

**After reading, briefly confirm your understanding.**
---
```

**Key difference from strict checkpoints:** These are *guidance*, not *restrictions*. If you need more context, get more context.

### Starting a New Slice (Special Guidance)

When beginning implementation of a new slice, this is NOT a time for selective reading:

1. **Read the FULL slice TDD** - all 12 sections, understand the complete picture
2. **Read relevant Consistency Guide sections** for patterns you'll use
3. **Review dependency slices'** Integration Points sections
4. **Check WHERE_WE_ARE** for any notes from previous sessions

Full understanding at slice start prevents rework later.

### The Efficiency Goal

The goal is NOT to minimize reading. The goal is to **avoid re-reading 700 lines of familiar content when you only need a 20-line template.**

If reading more would help you do better work, read more.

---

## Document Lifecycle

### Phase 1: Creation (Pre-Implementation)

**Status:** Draft  
**Purpose:** Design and planning

- All slice documents created before coding starts
- Reviewed for completeness and consistency
- Dependencies verified
- Approved for implementation

### Phase 2: Active Implementation

**Status:** In Progress  
**Purpose:** Reference and adjustment

- Document is the source of truth
- Deviations documented in Decision Log
- Updates made when design changes are agreed upon
- Implementation checklist tracked

### Phase 3: Slice Complete

**Status:** Implemented  
**Purpose:** Historical record and maintenance reference

- Document updated with final implementation details
- Any deviations from original plan documented in Implementation Notes
- Lessons learned captured
- Marked as complete in Overview of Slices and WHERE_WE_ARE

### Phase 4: Maintenance

**Status:** Stable  
**Purpose:** Reference for future work

- Updated only for significant changes
- Bug fixes generally don't require doc updates
- New features may require new slice documents

---

## When to Update Documents

### Always Update For:

1. **Architectural changes**: Database schema, event structure, state management patterns
2. **New events/actions added**: Event types and payloads
3. **API/interface changes**: Service method signatures that other slices depend on
4. **State machine changes**: New states or transitions
5. **Breaking changes**: Anything that affects integration contracts
6. **Major refactors**: File structure, naming conventions

### Consider Updating For:

1. **UI changes**: If interaction flow changes significantly
2. **Performance optimizations**: If approach fundamentally different
3. **Edge case discoveries**: If handling differs from original plan
4. **Testing strategy changes**: If test approach evolved

### Don't Update For:

1. **Bug fixes**: Unless they reveal design flaw
2. **Code cleanup**: Refactoring without design change
3. **UI polish**: Minor styling changes
4. **Dependency version bumps**: Unless API changes
5. **Documentation typos**: Fix in place without ceremony

---

## Update Procedures

### Step 1: Identify Need for Update

**Triggers:**
- Design discussion leads to new approach
- Implementation reveals design flaw
- Integration testing shows missing contract
- Stakeholder requests change

**Questions to ask:**
- Does this change affect other slices?
- Will future developers need to know this?
- Does this invalidate existing documentation?

### Step 2: Document the Change

**Create a Decision Log Entry** (see format below):

```markdown
## Decision: [Short title]
**Date:** YYYY-MM-DD
**Slice:** [Affected slice]
**Decided by:** [Name/Role]

### Context
What situation led to this decision?

### Decision
What was decided?

### Rationale
Why was this approach chosen?

### Alternatives Considered
What other options were evaluated?

### Impact
- Affects: [List of affected slices/modules]
- Migration needed: [Yes/No - describe if yes]
- Breaking change: [Yes/No]

### Status
- [ ] Documentation updated
- [ ] Code implemented
- [ ] Tests updated
- [ ] Integration verified
```

### Step 3: Update Affected Documents

**Procedure:**

1. Open relevant slice document(s)
2. Locate section(s) to update
3. Add version note if significant change:
   ```markdown
   > **Update (YYYY-MM-DD):** [Brief description of change]
   ```
4. Update content to reflect new design
5. Update Implementation Checklist if needed
6. Update Integration Points if contracts changed

### Step 4: Cross-Reference Updates

**Check if these need updates:**

- Other slices that depend on changed slice
- Overview of Slices (if dependencies changed)
- Consistency & Integration Guide (if patterns changed)
- Skeleton (rarely, but check if core infrastructure affected)
- WHERE_WE_ARE (if current objective affected)

### Step 5: Notify Team

**Communication:**

- Announce change in team channel/meeting
- Highlight if breaking change
- Point to Decision Log entry
- Update project board/tracker if applicable

---

## Decision Log

### Location

**File:** `TDD/decision-log.md`

Create this file to track all significant decisions made during implementation.

### Format

See template in Update Procedures above.

### Example Entry

```markdown
## Decision: Changed State Management Approach
**Date:** 2025-01-15
**Slice:** Skeleton
**Decided by:** Tech Lead

### Context
During implementation, we discovered the originally planned state management 
approach had performance issues with complex nested state updates.

### Decision
Switched to a more suitable state management pattern for our use case.

### Rationale
- Better performance for our specific data flow patterns
- More maintainable code structure
- Better developer experience with debugging tools

### Alternatives Considered
1. **Keep original approach with optimizations**: Would require complex workarounds
2. **Hybrid approach**: Added complexity not worth the benefit

### Impact
- Affects: Skeleton, all slices
- Migration needed: No (changed before initial implementation)
- Breaking change: No (internal change)

### Status
- [x] Documentation updated (Skeleton Build Guide)
- [x] Code implemented
- [x] Tests updated
- [x] Integration verified
```

---

## Change Request Process

### When a Change is Requested

1. **Document the request**:
   - Who requested?
   - What is being requested?
   - Why is it needed?

2. **Impact analysis**:
   - Which slices affected?
   - Is this a breaking change?
   - How much effort required?
   - Does this invalidate completed work?

3. **Decision**:
   - Approve: Follow update procedures
   - Defer: Add to backlog for later
   - Reject: Document reasoning

4. **Communication**:
   - Inform requester of decision
   - If approved, create Decision Log entry
   - Update affected documentation

---

## Version Control

### Document Versioning

**Simple approach:**

- Documents don't need detailed version numbers
- Major changes noted with date annotations in document
- Git commit history provides detailed version control

**Version note format:**

```markdown
> **Update (2025-01-15):** Added support for new feature. See Decision Log entry "Feature Name Design".
```

### Git Workflow

**Important:** The AI should NOT run git commands automatically. Git operations are user-controlled. The AI should prompt the user at appropriate moments (session end, slice completion) to ask if they want to commit changes.

**Branching:**

- TDD updates generally on same branch as implementation
- Major design changes may have separate design branch
- Merge TDD changes with code changes

**Commit messages (suggestions for user):**

- Good: `feat(slice-2): Update calculation logic to include new factor`
- Good: `docs: Complete slice 2 implementation notes`
- Good: `session: End of session 2025-01-15`
- Bad: `update docs`

**When to prompt user about committing:**

- At session end (after documentation is complete)
- At slice completion (after all completion documentation)
- After significant Decision Log entries

**How to prompt:**

> "Would you like me to help you commit these changes to git? I can suggest a commit message, but you'll need to run the commands or ask me to do so."

---

## Code-to-Design Traceability

### From Code to Design

**In code comments, reference design:**

```
[TECH-STACK: Use your language's comment syntax]

Example patterns:
- "Implements the algorithm defined in Slice 2: [Slice Name]"
- "See TDD/02-slice-name.md#section-name for design details"
```

**In commit messages:**

```
feat(slice-1): Implement feature state machine

Implements the lifecycle defined in TDD/01-slice-name.md
State transitions: StateA -> StateB -> StateC
```

### From Design to Code

**In TDD documents, reference code locations:**

```markdown
### [Feature] Service

**File: `[path/to/service/file]`**

Implementation of [feature description].
```

**This creates bidirectional traceability.**

---

## Review Process

### Document Review Checklist

Before marking a document as "ready for implementation":

- [ ] Follows Slice Contract Template structure
- [ ] All required sections present and complete
- [ ] Dependencies clearly stated and correct
- [ ] Event/action definitions include full payloads
- [ ] Integration points explicitly documented
- [ ] Edge cases considered
- [ ] Testing strategy defined
- [ ] Implementation checklist comprehensive
- [ ] Diagrams render correctly
- [ ] Code examples are realistic and complete
- [ ] Consistent terminology throughout

### Code Review with TDD

During code review, reviewer should:

1. **Reference the slice document**: Does implementation match design?
2. **Check integration contracts**: Are they honored?
3. **Verify data structures**: Match documented definitions?
4. **Look for undocumented changes**: Should they be documented?

If discrepancies found:

- **Minor deviation**: Accept and note for future doc update
- **Major deviation**: Require either code change or Decision Log entry + doc update

---

## Document Maintenance Schedule

### Every Session

- Update WHERE_WE_ARE at session end
- Create session log for completed sessions
- Update Implementation Checklists with progress

### Per Sprint/Milestone

- Review completed slices for accuracy
- Update Overview of Slices with progress
- Check cross-slice integration documentation is current

### Monthly

- Audit for obsolete information
- Update dependencies if changed
- Check for inconsistencies between slices

### After Major Releases

- Archive Decision Log entries (move to separate archive file)
- Update document status (from "In Progress" to "Implemented")
- Capture lessons learned
- Update any procedures based on experience

---

## Progress Tracking (WHERE_WE_ARE)

### Purpose

WHERE_WE_ARE.md is the **single source of truth** for project status. It enables any developer or AI assistant to understand the current state and resume work seamlessly.

### Location

**File:** `WHERE_WE_ARE.md` (TDD folder)

### When to Update

- **Every session end**: Add session summary, update current status
- **Slice completion**: Update active slice, add to completion list
- **Blocker encountered**: Document in blockers section
- **Major milestone**: Update current objective

### Update Procedure

1. Update "Current Status" section with:
   - Active slice name
   - Current objective
   - Any blockers

2. Add entry to "Session History" table:
   - Date
   - Session number
   - Brief summary (1-2 sentences)
   - Status (Completed/Paused/Blocked)

3. Update "Next Steps" with immediate actions for next session

### Content Requirements

WHERE_WE_ARE must always contain:
- What we're currently working on
- What was last accomplished
- What to do next
- Links to relevant TDD documents
- Session history for context

---

## Session Documentation

### Purpose

Session logs provide detailed records of development sessions, enabling context recovery and progress tracking.

### Location

**Folder:** `TDD/logs/`
**Naming:** `YYYY-MM-DD-session-N.md` (e.g., `2025-01-15-session-1.md`)

### When to Create

At the end of every development session when user confirms "we're done for today."

### Session Log Contents

```markdown
# Session Log: [Date] - Session #[N]

## Session Overview
**Date:** YYYY-MM-DD
**Duration:** [Approximate time]
**Slice:** [Active slice during session]
**Status:** Completed / Paused / Blocked

## Objectives This Session
- [What we planned to accomplish]

## What Was Accomplished
- [Detailed list of completed work]
- [Files created/modified]
- [Features implemented]

## Decisions Made
- [Any design decisions with brief rationale]
- [Reference Decision Log entries if applicable]

## Issues Encountered
- [Problems faced and how they were resolved]
- [Workarounds applied]

## Tests Written/Run
- [Tests created this session]
- [Test results summary]

## Where We Left Off
- [Current state of work]
- [Immediate next steps]

## Notes for Next Session
- [Context that would be helpful]
- [Things to remember]
```

### Session Documentation Workflow

1. User signals session end ("Are we done for today?")
2. AI asks for date/time
3. AI creates session log following template
4. AI updates WHERE_WE_ARE with session entry
5. AI confirms documentation is complete

---

## Slice Completion Documentation

### Purpose

Implementation Notes capture what was **actually built** versus what was **planned**. They serve as the authoritative record of the real implementation.

### Location

**File:** `TDD/[slice-number]-[slice-name]-implementation-notes.md`
**Example:** `TDD/01-task-management-implementation-notes.md`

### When to Create

When a slice is marked complete AND user has acknowledged completion.

### Implementation Notes Contents

```markdown
# Implementation Notes: Slice [N] - [Slice Name]

**Completed:** YYYY-MM-DD
**TDD Document:** [Link to original slice TDD]

## Implementation Summary
Brief overview of what was implemented.

## Deviations from Original Design

### [Deviation 1 Title]
**Original Plan:** [What the TDD specified]
**Actual Implementation:** [What was built]
**Reason for Deviation:** [Why the change was made]
**Impact:** [How this affects other slices or future work]

### [Deviation 2 Title]
[Same format...]

## Files Created/Modified
- `path/to/file1` - [Purpose]
- `path/to/file2` - [Purpose]

## Key Implementation Details
[Technical details worth documenting that weren't in the original TDD]

## Testing Summary
- Unit tests: [Count] tests, [Pass/Fail status]
- Integration tests: [Count] tests, [Pass/Fail status]
- User confirmation: [Date and what was confirmed]

## Lessons Learned
- [What would we do differently?]
- [What worked well?]

## Known Limitations
- [Any scope limitations or technical debt]
- [Planned future improvements]
```

### Completion Documentation Workflow

1. All checklist items in slice TDD are complete
2. All unit tests passing
3. User has confirmed UI/frontend features work (if applicable)
4. AI creates Implementation Notes document
5. AI updates WHERE_WE_ARE:
   - Move slice from "Active" to completed list
   - Update "Active Slice" to next slice
   - Update "Next Steps"
6. User acknowledges completion

---

## Documentation Best Practices

### Writing Style

- **Clear and direct**: Avoid ambiguity
- **Present tense**: "The service handles..." not "The service will handle..."
- **Active voice**: "EventProcessor applies events" not "Events are applied by EventProcessor"
- **Complete sentences**: Even in lists when explaining complex topics

### Formatting

- **Consistent headers**: Use ATX-style (`#` not underlines)
- **Code blocks**: Always specify language for syntax highlighting
- **Lists**: Use `-` for bullets, `1.` for numbered (Markdown auto-numbers)
- **Tables**: Use for structured comparison data
- **Bold/Italic**: **Bold** for emphasis, *italic* for terminology first use

### Diagrams

- **Mermaid preferred**: For diagrams (state, sequence, flow)
- **ASCII art**: Only for very simple diagrams
- **External images**: Avoid unless absolutely necessary

### Examples

- **Real, not toy**: Use actual project structure and naming
- **Complete**: Show enough context to be useful
- **Commented**: Explain non-obvious parts
- **Consistent**: Follow project conventions

---

## Special Cases

### Hotfix Documentation

**Scenario:** Critical bug requires immediate fix without full design process.

**Procedure:**
1. Implement and deploy fix
2. Within 24 hours, document what was changed
3. Add Decision Log entry explaining the emergency change
4. Update affected TDD documents
5. Schedule proper design review for next sprint

### Experimental Features

**Scenario:** Trying new approach without committing to design.

**Procedure:**
1. Create `TDD/experiments/` folder
2. Document experiment in lightweight format
3. Track results and learnings
4. If successful, promote to proper slice document
5. If failed, document lessons and archive

### Deprecated Features

**Scenario:** Removing a feature or significantly changing approach.

**Procedure:**
1. Add "Deprecated" marker to section:
   ```markdown
   > **DEPRECATED (YYYY-MM-DD):** This approach was replaced by [new approach]. See Decision Log entry "Migration to X".
   ```
2. Don't delete content immediately
3. After 2 releases, move to `TDD/archive/` folder
4. Update references in other documents

---

## Tools and Automation

### Recommended Tools

1. **Markdown editor**: VS Code with Markdown extensions or similar
2. **Diagram preview**: Mermaid preview extension
3. **Link checker**: Markdown Link Check (check for broken internal links)
4. **Spell checker**: Code Spell Checker extension or equivalent

### Automation Opportunities

Consider scripting:

- **Link validation**: Check all file references are valid
- **Checklist status**: Extract checklist items from all slices
- **Decision log aggregation**: Generate summary of all decisions
- **Document dependency graph**: Visualize slice dependencies

---

## Troubleshooting

### Problem: Documents Out of Sync with Code

**Solution:**
1. Hold documentation sync session
2. Go through each slice, validate against code
3. Create Decision Log entries for discrepancies
4. Schedule regular review to prevent future drift

### Problem: Too Many Small Updates

**Solution:**
1. Batch minor updates weekly
2. Use "pending updates" list
3. Don't update for every tiny change
4. Focus on material information

### Problem: Nobody Reads the Docs

**Solution:**
1. Reference docs in code reviews
2. Make docs part of onboarding
3. Link to relevant sections in PR descriptions
4. Keep docs concise and scannable
5. Update docs proves they're trustworthy

---

## Summary

Good documentation procedures ensure:

- **Developers trust the TDD**: It's accurate and current
- **Changes are traceable**: Decision Log provides history
- **Updates are efficient**: Clear process, not burdensome
- **Quality maintained**: Reviews and regular maintenance
- **Continuity preserved**: WHERE_WE_ARE and session logs enable seamless handoffs

The TDD folder is an investment in project success. Treat it as first-class artifact, not afterthought.

---

**End of Documentation Procedures**
