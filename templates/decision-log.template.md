# Decision Log: [Project Name]

**Purpose:** Track design decisions made during development. New entries are added at the top. This is a living document updated throughout the project lifecycle.

**Last Updated:** [Date]

---

## Entry Format Guide

This log uses two entry formats based on decision significance:

### When to Use Quick Entry
- Minor implementation choices
- Small deviations from TDD that don't affect other slices
- Tool or library selection for isolated features
- Code organization decisions within a slice

### When to Use Full Entry
- Architectural decisions affecting multiple slices
- Changes to integration contracts
- Deviations that impact the overall system design
- Decisions that future developers need full context to understand
- Breaking changes or migrations

---

## Decisions

*New entries go here, at the top of this section.*

---

### [Decision Title]
**Date:** YYYY-MM-DD | **Slice:** [Affected slice or "All"] | **Type:** Quick

**Decision:** [What was decided]

**Context:** [Brief context - why this came up]

---

### [Decision Title]
**Date:** YYYY-MM-DD | **Slice:** [Affected slice or "All"] | **Type:** Full

#### Context
[What situation led to this decision? What problem were we solving?]

#### Decision
[What was decided? Be specific and clear.]

#### Rationale
[Why was this approach chosen over alternatives?]

#### Alternatives Considered
1. **[Alternative A]:** [Brief description and why it wasn't chosen]
2. **[Alternative B]:** [Brief description and why it wasn't chosen]

#### Impact
- **Affects:** [List of affected slices/modules]
- **Migration needed:** [Yes/No - describe if yes]
- **Breaking change:** [Yes/No]

#### Status
- [x] Documentation updated
- [x] Code implemented
- [ ] Tests updated
- [ ] Integration verified

---

## Initial Tech Stack Decisions

*Entries below this line are from project initialization. They document the initial tech stack choices made during the Recipe phase.*

---

### Initial Tech Stack Selection
**Date:** [Project start date] | **Slice:** All | **Type:** Full

#### Context
Project initialization - selecting the technology stack based on project requirements.

#### Decision
[Summary of tech stack chosen - reference Recipe document for full details]

#### Rationale
[Brief summary of why this stack was chosen for this project]

#### Alternatives Considered
[List major alternatives that were discussed during Phase 1]

#### Impact
- **Affects:** All slices
- **Migration needed:** N/A (initial setup)
- **Breaking change:** N/A (initial setup)

#### Status
- [x] Documentation updated (Recipe document)
- [ ] Code implemented (Skeleton)
- [ ] Tests updated
- [ ] Integration verified

---

## Template Usage Notes

**When adding a new decision:**

1. Add the new entry directly below the "## Decisions" header
2. Choose Quick or Full format based on the guidance above
3. Fill in all required fields (don't leave placeholders)
4. Update the "Last Updated" date at the top of the document
5. If the decision affects TDD documents, update those as well

**Quick Entry Required Fields:**
- Date
- Slice affected
- Decision statement
- Brief context

**Full Entry Required Fields:**
- All Quick Entry fields, plus:
- Detailed context
- Rationale
- Alternatives considered
- Impact assessment
- Status checklist

**Tips:**
- Be specific enough that someone reading this in 6 months understands the decision
- Link to relevant TDD sections when applicable
- If a decision reverses a previous decision, reference the original entry
- Use "All" for slice when the decision affects the entire project
