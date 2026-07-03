# Implementation Notes: Slice [N] - [Slice Name]

**Purpose:** Document the actual implementation versus the planned design, capturing deviations, lessons learned, and the final state of the completed slice.

---

## Completion Summary

| Field | Value |
|-------|-------|
| **Completed** | YYYY-MM-DD |
| **Original TDD** | `TDD/[XX]-[slice-name].md` |
| **Sessions to Complete** | [Number of sessions] |
| **Primary Developer** | [Name or "AI-assisted"] |

---

## Implementation Summary

*[2-3 paragraph summary of what was implemented, written as if explaining to someone unfamiliar with the project]*

[Paragraph 1: What the slice provides - main functionality]

[Paragraph 2: How it integrates with the rest of the system]

[Paragraph 3: Any notable implementation choices or approaches]

---

## Deviations from Original Design

*[Document all significant differences between the TDD and actual implementation]*

### [Deviation 1 Title]

**Original Plan:**
> [Quote or describe what the TDD specified]

**Actual Implementation:**
[What was actually built]

**Reason for Deviation:**
[Why the change was necessary - technical constraints, better approach discovered, requirements changed, etc.]

**Impact:**
- [How this affects the current slice]
- [How this affects other slices]
- [Any technical debt introduced]

**Decision Log Entry:** [Link if applicable, or "N/A"]

---

### [Deviation 2 Title]

*[Same format as above]*

---

### No Deviations

*[If implementation matched the TDD exactly, state: "Implementation followed the TDD with no significant deviations."]*

---

## Files Created

| File Path | Purpose | Lines |
|-----------|---------|-------|
| `path/to/file1.[ext]` | [What this file does] | [~count] |
| `path/to/file2.[ext]` | [What this file does] | [~count] |
| `path/to/file3.[ext]` | [What this file does] | [~count] |

**Total new files:** [count]

---

## Files Modified

| File Path | Changes Made |
|-----------|--------------|
| `path/to/existing1.[ext]` | [Brief description of modifications] |
| `path/to/existing2.[ext]` | [Brief description of modifications] |

**Total files modified:** [count]

---

## Key Implementation Details

*[Technical details worth documenting that weren't in the original TDD or emerged during implementation]*

### [Topic 1]
[Details that future developers should know]

### [Topic 2]
[Details that future developers should know]

---

## Testing Summary

### Unit Tests

| Test File | Tests | Status |
|-----------|-------|--------|
| `path/to/test1.[ext]` | [X] tests | All passing |
| `path/to/test2.[ext]` | [X] tests | All passing |

**Total unit tests:** [count]
**Coverage:** [percentage if known]

### Integration Tests

| Test File | Tests | Status |
|-----------|-------|--------|
| `path/to/integration_test.[ext]` | [X] tests | All passing |

**Total integration tests:** [count]

### User Confirmation

| Feature | Confirmed | Date | Notes |
|---------|-----------|------|-------|
| [Feature 1] | Yes | YYYY-MM-DD | [Any notes] |
| [Feature 2] | Yes | YYYY-MM-DD | [Any notes] |
| [Feature 3] | Yes | YYYY-MM-DD | [Any notes] |

---

## Performance Notes

*[Any performance observations or optimizations made]*

- [Performance consideration 1]
- [Performance consideration 2]

*[If no performance notes, state "No significant performance considerations for this slice"]*

---

## Lessons Learned

### What Worked Well
- [Positive observation about approach, tools, or process]
- [Positive observation]
- [Positive observation]

### What Could Be Improved
- [Improvement suggestion for future slices]
- [Improvement suggestion]
- [Improvement suggestion]

### Unexpected Challenges
- [Challenge that wasn't anticipated and how it was handled]
- [Challenge]

---

## Known Limitations

*[Any scope limitations, technical debt, or intentional simplifications]*

| Limitation | Reason | Future Resolution |
|------------|--------|-------------------|
| [Limitation 1] | [Why it exists] | [Planned fix or "Acceptable"] |
| [Limitation 2] | [Why it exists] | [Planned fix or "Acceptable"] |

---

## Dependencies Created

*[What this slice provides that other slices may depend on]*

### For Future Slices
- **[Capability/Interface 1]:** [Description of what other slices can use]
- **[Capability/Interface 2]:** [Description]

### Integration Points
- **[Event/Action]:** [Events that other slices should handle]
- **[State/Data]:** [State that other slices can access]

---

## Notes for Future Maintenance

*[Context that would help someone maintaining or extending this slice]*

- [Maintenance note 1]
- [Maintenance note 2]
- [Areas that might need revisiting]

---

## Appendix: Session History

*[Sessions that contributed to this slice]*

| Session | Date | Key Accomplishments |
|---------|------|---------------------|
| #[N] | YYYY-MM-DD | [What was done] |
| #[N+1] | YYYY-MM-DD | [What was done] |
| #[N+2] | YYYY-MM-DD | [What was done] |

---

## Template Usage Notes

**When creating Implementation Notes:**

1. Create this document when a slice is marked COMPLETE
2. Reference the original TDD throughout
3. Be honest about deviations - they're valuable history
4. Include all file paths for traceability
5. Document lessons learned while they're fresh
6. Link to Decision Log for major decisions
7. This is a historical document - accuracy over brevity

**This document should answer:**
- What was actually built?
- How does it differ from the plan?
- Why were changes made?
- What should future developers know?
- What could we do better next time?
