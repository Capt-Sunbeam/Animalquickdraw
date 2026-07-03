# Overview of Slices: [Project Name]

**Purpose:** Summary document showing all slices, their relationships, dependencies, and development order. Updated as slices are completed.

**Last Updated:** [Date]

---

## Project Summary

[Brief 2-3 sentence description of the project and its scope. Reference the Recipe document for full details.]

**Total Slices:** [N] (Skeleton + [N-1] feature slices)

---

## Slice Summary

| # | Slice Name | Description | Dependencies |
|---|------------|-------------|--------------|
| 0 | Skeleton | Foundation architecture and core systems | None |
| 1 | [Name] | [Brief description] | Skeleton |
| 2 | [Name] | [Brief description] | Skeleton, Slice 1 |
| 3 | [Name] | [Brief description] | Slice 2 |
| 4 | [Name] | [Brief description] | Slice 2, Slice 3 |

*Note: For current slice status, see `WHERE_WE_ARE.md` - it is the single source of truth for progress tracking.*

---

## Dependency Notes

*Text explanation of how slices depend on each other.*

**Skeleton (Slice 0):** Must be completed first. Provides the foundation that all other slices build upon, including database setup, core services, navigation framework, and base UI components.

**Slice 1 → Slice 2:** [Explain what Slice 2 needs from Slice 1. Example: "Slice 2 (Points System) requires the Task model and TaskService from Slice 1 (Task Management) to calculate points based on task completion."]

**Slice 2 → Slice 3:** [Explain the dependency relationship.]

**Slice 2, Slice 3 → Slice 4:** [Explain when a slice depends on multiple previous slices.]

---

## Parallel Development Notes

*Guidance on which slices can potentially be developed simultaneously.*

**Parallelizable after Skeleton:**
- [Slice X] and [Slice Y] have no dependencies on each other and can be developed in parallel after Skeleton is complete.

**Sequential requirements:**
- [Slice Z] must wait for [Slice W] because [brief reason].

**Coordination points:**
- If developing [Slice A] and [Slice B] in parallel, coordinate on [shared interface/event/component] to avoid integration conflicts.

*Note: Parallel development requires careful coordination. When in doubt, develop sequentially.*

---

## Slice Document Links

| Slice | TDD Document | Implementation Notes |
|-------|--------------|----------------------|
| Skeleton | `TDD/00-skeleton-build-guide.md` | [Link when complete] |
| Slice 1 | `TDD/01-[slice-name].md` | [Link when complete] |
| Slice 2 | `TDD/02-[slice-name].md` | [Link when complete] |
| Slice 3 | `TDD/03-[slice-name].md` | [Link when complete] |

---

## Template Usage Notes

**When creating an Overview of Slices:**

1. Fill in Project Summary with brief context
2. Add all slices to the Summary Table
3. Write Dependency Notes explaining why each dependency exists
4. Identify any parallel development opportunities
5. Add links to TDD documents as they're created

**When updating this document:**

- Add Implementation Notes links when slices are completed
- Update "Last Updated" date
- If slice scope changes, update the description and dependencies

**Note:** Slice status tracking is handled in `WHERE_WE_ARE.md`, not in this document. This document focuses on slice definitions, dependencies, and documentation links.
