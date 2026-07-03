# Session Start Workflow

**Purpose:** Define the standard procedure for AI assistants to resume work on a project at the beginning of a development session.

---

## Overview

When a user initiates a new session with "let's keep working on the project" (or similar), the AI must follow this workflow to ensure seamless continuity and proper context loading.

---

## Workflow Steps

### Step 1: Acknowledge Session Start

Respond to the user acknowledging that you're starting a new session:

> "Starting a new development session. Let me load the project context."

### Step 2: Context Load

---
### CONTEXT REFRESH: Session Start

**Read these documents to understand project state:**
- `WHERE_WE_ARE.md` - Full document (it's the source of truth)
- Current slice TDD - Full document if starting the slice; Overview + Checklist if resuming

**For quick refresh on patterns (if you've worked on this project before):**
- `TDD/consistency-guide.md` - Quick Reference Summary, then sections relevant to current work

**If this is the START of a new slice:** Read the full slice TDD (all 12 sections). Do not skip sections - full understanding prevents rework.

**If uncertain about anything, read more broadly.**

**After reading, confirm your understanding:**
> "I have loaded the project context. Current status:
> - **Active Slice:** [slice name]
> - **Current Objective:** [what we're working on]
> - **Last Session:** [brief summary of last session]
> - **Next Steps:** [immediate actions from WHERE_WE_ARE]"
---

### Step 3: Review Last Session Context

If there's a recent session log referenced in WHERE_WE_ARE, briefly review it to understand:
- What was accomplished
- Where we left off
- Any notes for this session

### Step 4: Confirm Understanding with User

Before proceeding with implementation work, confirm with the user:

> "Based on WHERE_WE_ARE, our next steps are:
> 1. [First action]
> 2. [Second action]
> 
> Does this align with what you'd like to work on today, or would you like to adjust our focus?"

### Step 5: Begin Work

Once user confirms (or provides adjusted direction):
- Start working on the identified next steps
- Follow the patterns in the Consistency Guide
- Reference the current slice TDD for implementation details

---

## What to Read and When

| Document | When to Read | What to Look For |
|----------|--------------|------------------|
| WHERE_WE_ARE.md | Always first | Current status, active slice, next steps |
| Current Slice TDD | After WHERE_WE_ARE | Implementation details, checklist status |
| Consistency Guide | Before coding | Patterns, naming conventions, integration points |
| Last Session Log | If context unclear | What was done, issues encountered |

---

## Example Session Start

**User:** "Let's keep working on the project" [provides links to 3 PILLARS and WHERE_WE_ARE]

**AI Response:**
> "Starting a new development session. Let me load the project context."
> 
> [Reads WHERE_WE_ARE.md]
> 
> "I have loaded the project context. Current status:
> - **Active Slice:** Slice 2 - Points & Recurrence
> - **Current Objective:** Implement recurrence template system
> - **Last Session:** January 14 - Completed points calculation engine, started template models
> - **Next Steps:** 
>   1. Finish RecurrenceTemplate model
>   2. Implement template service methods
>   3. Add state handlers for template events
> 
> Does this align with what you'd like to work on today?"

**User:** "Yes, let's continue with the templates"

**AI:** [Begins implementation work following slice TDD and consistency guide]

---

## Edge Cases

### No WHERE_WE_ARE Exists

If WHERE_WE_ARE.md doesn't exist yet:
1. Check if this is a new project (look for TDD folder)
2. If new project: Suggest running the Starting Prompt workflow
3. If existing project without WHERE_WE_ARE: Offer to create one based on current state

### WHERE_WE_ARE is Outdated

If the timestamps suggest WHERE_WE_ARE hasn't been updated recently:
1. Note this to the user
2. Offer to review recent changes and update WHERE_WE_ARE
3. Proceed with caution, confirming state with user

### User Wants to Work on Something Different

If user wants to deviate from WHERE_WE_ARE's next steps:
1. Acknowledge the change in direction
2. Ask if this is a temporary deviation or a priority change
3. Note that WHERE_WE_ARE should be updated to reflect the change
4. Proceed with user's preferred work

### Multiple Sessions in One Day

If user is starting a second session on the same day:
1. Check if previous session was properly closed
2. If not, offer to create session log for earlier work
3. Continue from current state

---

## Reminders

- **Always read WHERE_WE_ARE first** - It's the single source of truth
- **Confirm before assuming** - User's intent may differ from documented next steps
- **Reference documentation** - Don't rely on memory from previous sessions
- **Note any discrepancies** - If code state doesn't match documentation, flag it

---

**End of Session Start Workflow**
