# Testing Protocol

**Purpose:** Define the standard testing practices for AI-assisted development, ensuring continuous testing throughout implementation rather than as an afterthought.

---

## Overview

Testing is not a final step before completion. Tests are written and run **continuously** during implementation. This protocol ensures:

- Tests are written alongside code, not after
- Tests are run frequently to catch issues early
- UI features require explicit user confirmation
- Test failures are addressed immediately

---

## Core Principles

### 1. Test-Alongside Development

Write tests as you implement, not after:

```
❌ Wrong: Implement entire feature → Write all tests → Fix issues
✅ Right: Implement method → Write test → Verify → Next method
```

### 2. Run Tests Frequently

Run tests after every significant change:
- After completing a function/method
- After completing a class/module
- Before committing code
- Before marking any checklist item complete

### 3. Fix Failures Immediately

When a test fails:
1. Stop and investigate
2. Fix the issue
3. Verify the fix
4. Continue implementation

Do not accumulate test failures.

### 4. User Confirmation for UI

Automated tests cannot fully verify UI/UX. User must confirm:
- Visual appearance
- Interaction flows
- Responsiveness
- Edge case behaviors

---

## Testing Workflow

### During Implementation

---
### CONTEXT REFRESH: Test Protocol

**When starting work on a new feature or component, review testing expectations:**
- This document (Testing Protocol) - Core Principles section
- Current slice TDD - Testing Strategy section

**Key testing principles to follow:**
1. Write tests alongside implementation (not after)
2. Run tests after each significant change
3. Fix failures immediately - don't accumulate
4. Request user confirmation for UI features

**This is a short document.** If uncertain about testing approach, read it fully - it won't take long.

**After reviewing, briefly confirm your testing approach for this feature.**
---

### For Each Feature/Component

1. **Plan tests before implementing**
   - What scenarios need to be tested?
   - What are the edge cases?
   - What are the error conditions?

2. **Implement incrementally with tests**
   ```
   Implement function A → Write test for A → Run test → Pass? Continue
   Implement function B → Write test for B → Run test → Pass? Continue
   ```

3. **Run full test suite periodically**
   - After completing a logical unit of work
   - Before moving to next checklist item
   - Before any documentation updates

4. **Document test status**
   - Note tests written in session log
   - Update checklist when tests pass
   - Flag any skipped or pending tests

---

## Test Categories

### Unit Tests

**Purpose:** Test individual functions, methods, or classes in isolation

**When to write:** Immediately after implementing the code being tested

**What to test:**
- Happy path (normal operation)
- Edge cases (boundary conditions)
- Error handling (invalid inputs, exceptions)
- State transitions (if applicable)

**Example structure:**
```
describe('[FeatureName]', () => {
  describe('[MethodName]', () => {
    test('should [expected behavior] when [condition]')
    test('should handle [edge case]')
    test('should throw [error] when [invalid condition]')
  })
})
```

### Integration Tests

**Purpose:** Test how components work together

**When to write:** After unit tests pass, before marking feature complete

**What to test:**
- Component interactions
- Data flow between layers
- Event/action propagation
- State consistency across components

### UI/Component Tests

**Purpose:** Test UI components render and behave correctly

**When to write:** After component implementation, before user confirmation

**What to test:**
- Component renders without errors
- Props/inputs are handled correctly
- User interactions trigger expected behaviors
- Loading and error states display correctly

### Manual/User Tests

**Purpose:** Verify features work correctly from user perspective

**When to perform:** Before marking any UI feature complete

**What to test:**
- Visual appearance matches expectations
- Interactions feel correct
- Responsive behavior works
- Edge cases behave appropriately

---

## Test Execution Protocol

### Running Tests

**Reference your project's Consistency Guide (`TDD/consistency-guide.md`) for the actual test commands.** The Consistency Guide's Testing Patterns section (Section 9) defines the specific commands for your tech stack.

**After each function/method:** Run the specific test file or individual test

**After each component/module:** Run all tests for that feature

**Before checklist item completion:** Run the full test suite

### Handling Test Failures

1. **Stop implementation** - Don't continue with failing tests

2. **Analyze the failure**
   - Is it a code bug?
   - Is it a test bug?
   - Is it an environment issue?

3. **Fix the issue**
   - Fix the code (most common)
   - Fix the test if test was wrong
   - Document if it's a known/accepted issue

4. **Verify the fix**
   - Run the specific test
   - Run related tests
   - Run full suite if significant change

5. **Document if needed**
   - Note in Decision Log if approach changed
   - Update tests if requirements changed

### Reporting Test Results

When reporting test status:

```markdown
## Test Results

**Run at:** [timestamp]
**Command:** [test command used]

| Category | Total | Passed | Failed | Skipped |
|----------|-------|--------|--------|---------|
| Unit     | [n]   | [n]    | [n]    | [n]     |
| Integration | [n] | [n]   | [n]    | [n]     |
| Component | [n]  | [n]    | [n]    | [n]     |

**Failed Tests:**
- [Test name]: [Brief reason]

**Skipped Tests:**
- [Test name]: [Reason for skip]
```

---

## Test Priority and Batching

The goal is to let the AI work autonomously until user input is genuinely needed. Tests are categorized by whether they block continued work.

### Blocking Tests (Request Immediately)

Tests where the answer affects what the AI builds next:

- **Core functionality** - Can't build feature B if feature A is broken
- **Data persistence** - Can't continue if saves don't work
- **Navigation/routing** - Can't build next screen if can't reach it
- **Integration points** - Can't build dependent features if integration fails
- **Authentication/authorization** - Can't build protected features if access doesn't work

**Rule:** If the AI's next implementation steps depend on the answer, request immediately.

### Batchable Tests (Queue for Later)

Tests that confirm quality but don't change implementation direction:

- Visual appearance matches expectations
- Responsive behavior on different screen sizes
- Animations and transitions feel right
- Edge case displays (empty states, error states, loading states)
- Polish and refinement details
- Non-critical UX flows

**Rule:** Track these and batch them at slice completion or session end.

### Tracking Pending Tests

During implementation, maintain a running list of batchable tests:

```markdown
**Pending User Tests (Batchable):**
- [ ] Task list empty state displays correctly
- [ ] Card hover animations feel smooth
- [ ] Mobile responsive layout works
- [ ] Error toast notifications appear correctly
```

Present this batch when:
1. **Slice is otherwise complete** - Before creating Implementation Notes
2. **Session is ending** - As part of session-end workflow
3. **User asks** - To review pending tests early

### Batched Test Request Format

When presenting batched tests:

> "The following UI features are ready for testing. Please test when convenient:
> 
> **Test Checklist:**
> - [ ] [Feature 1]: [What to test, expected behavior]
> - [ ] [Feature 2]: [What to test, expected behavior]
> - [ ] [Feature 3]: [What to test, expected behavior]
> 
> Let me know which items pass and which have issues. I can continue with other work while you test."

---

## User Confirmation Protocol

### When to Request

**For blocking tests:** Request immediately during implementation.

**For batchable tests:** Queue and present at slice completion or session end.

### How to Request (Blocking Tests)

> "I need your confirmation before continuing:
> 
> **Feature:** [Feature name]
> **Why this is blocking:** [What depends on this working]
> 
> **What to test:**
> 1. [Specific test action]
> 
> **Expected behavior:**
> - [What should happen]
> 
> Please confirm this works so I can proceed with [next steps]."

### How to Request (Batched Tests)

> "The following UI features are ready for your review:
> 
> **Test Checklist:**
> - [ ] [Feature 1]: [Location] - [Expected behavior]
> - [ ] [Feature 2]: [Location] - [Expected behavior]
> - [ ] [Feature 3]: [Location] - [Expected behavior]
> 
> Please test when convenient and report:
> - Which items pass (just the numbers/names is fine)
> - Which items have issues (describe what's wrong)
> 
> I can continue with documentation/other work while you test."

### Recording Confirmation

When user confirms:
```markdown
**User Confirmation:** [Date]
- [Feature 1]: Confirmed working
- [Feature 2]: Confirmed working
- [Feature 3]: [Issue noted - describe]
```

### Handling User-Reported Issues

1. **Acknowledge the issue**
2. **Assess severity**
   - Blocking: Fix before continuing
   - Non-blocking: Fix or document for later
3. **Fix the issue**
4. **Re-request confirmation**
5. **Document the fix**

### Handling Deferred Testing

If the user declines or defers UI testing requests:

1. **Acknowledge the deferral** - Don't pressure the user
2. **Do NOT check off the UI confirmation item** - It remains incomplete
3. **Continue with non-UI work** - You may proceed with other implementation tasks that don't require user testing
4. **Track the pending confirmation** - Note which features still need user testing
5. **If session ends with testing incomplete:**
   - Document the deferred tests in the session log under "Where We Left Off"
   - Add to "Notes for Next Session" that user confirmation is pending
   - Do NOT mark the slice as complete - user confirmation is required for slice completion

```markdown
## Where We Left Off

### Pending User Confirmations
- [ ] [Feature 1]: Awaiting user testing
- [ ] [Feature 2]: Awaiting user testing

*Note: These features cannot be marked complete until user confirms they work.*
```

---

## Test Coverage Guidelines

### Minimum Coverage Expectations

| Layer | Minimum Coverage | Notes |
|-------|------------------|-------|
| Services/Business Logic | 80% | Core logic must be well-tested |
| State Handlers | 90% | Critical for data integrity |
| Utilities | 70% | Common functions |
| UI Components | 60% | Focus on complex components |

### What Must Be Tested

**Always test:**
- Business logic functions
- State transitions
- Event/action handlers
- Data transformations
- Error handling paths

**Should test:**
- UI component rendering
- User interaction handlers
- Async operations
- Edge cases

**Optional test:**
- Pure display components
- Simple pass-through functions
- Framework boilerplate

---

## Test Documentation

### In Session Logs

Document tests in every session log:

```markdown
## Tests Written/Run

### New Tests This Session
- `path/to/test_file.test`: [X] tests for [feature]
- `path/to/other_test.test`: [X] tests for [feature]

### Test Run Results
- **Time:** [timestamp]
- **Total:** [X] tests
- **Passed:** [X] 
- **Failed:** [X] (describe any failures)

### User Confirmations
- [Feature]: Confirmed by user at [time]
```

### In Slice TDDs

The Testing Strategy section should list:
- Required test categories
- Key scenarios to test
- User confirmation requirements

### In Implementation Notes

Document final test status:
- Total tests written
- Coverage achieved
- Any known gaps
- User confirmations received

---

## Edge Cases

### Test Takes Too Long

If a test is slow:
1. Investigate why (network, database, etc.)
2. Consider mocking slow dependencies
3. Split into unit vs. integration tests
4. Document if slowness is acceptable

### Flaky Tests

If a test sometimes passes, sometimes fails:
1. Investigate root cause (timing, state, randomness)
2. Fix the flakiness
3. If unfixable, document and potentially skip with reason

### Can't Test Without User

If something truly requires user testing:
1. Document that it requires manual testing
2. Create clear test instructions
3. Don't mark complete without user confirmation
4. Consider if automated tests could partially cover it

### Test Infrastructure Issues

If tests fail due to environment issues:
1. Document the issue
2. Try to resolve (restart, clean, etc.)
3. If persistent, note in session log
4. Don't skip testing - fix the infrastructure

---

## Reminders

- **Tests are not optional** - They're part of implementation
- **Run tests frequently** - Catch issues early
- **Fix failures immediately** - Don't accumulate debt
- **User confirmation is mandatory** - For UI features
- **Document test status** - In every session log

---

**End of Testing Protocol**
