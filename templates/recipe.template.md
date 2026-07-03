# Project Recipe: [Project Name]

**Purpose:** Pre-TDD document that consolidates the project description and tech stack decisions into a structured format used to generate full Technical Design Documents. This document is a historical snapshot - once approved, it is not updated.

**Location:** `TDD/recipe.md`
**Created:** [Date]
**Status:** Draft / Approved

---

## Project Overview

| Field | Value |
|-------|-------|
| **Project Name** | [Name or codename] |
| **Description** | [One paragraph description of what the project does] |
| **Target Platform(s)** | [iOS, Android, Web, Desktop, Game, etc.] |
| **Primary Users** | [Who will use this application] |
| **Key Constraints** | [Offline-first, no backend, specific requirements, etc.] |

---

## Tech Stack Summary

| Component | Choice | Notes |
|-----------|--------|-------|
| **Platform** | [mobile/web/desktop/game] | |
| **Language** | [Dart/TypeScript/C#/Python/etc.] | |
| **Framework** | [Flutter/React/Unity/Django/etc.] | |
| **State Management** | [Riverpod/Redux/Vuex/etc.] | |
| **Database/Storage** | [SQLite/PostgreSQL/Firebase/etc.] | |
| **Testing Framework** | [Jest/pytest/flutter_test/etc.] | |
| **Build/Deploy** | [CI/CD tools, hosting, etc.] | |
| **Other** | [Any additional tools or libraries] | |

---

## Feature List

*Consolidated list of features from the project description, organized by category.*

### Core Features
- [ ] [Feature 1]: [Brief description]
- [ ] [Feature 2]: [Brief description]
- [ ] [Feature 3]: [Brief description]

### Secondary Features
- [ ] [Feature 4]: [Brief description]
- [ ] [Feature 5]: [Brief description]

### Future Considerations (Out of Initial Scope)
- [Feature that may be added later]
- [Feature that may be added later]

---

## Slice Breakdown

*Proposed vertical slices for implementation. Each slice represents a complete, testable feature.*

### Slice 0: Skeleton
**Description:** Foundation architecture, project structure, core systems setup, base configurations.
**Key Deliverables:**
- Project structure and folder organization
- Database/storage setup
- Core services and utilities
- Navigation/routing framework
- Theme/styling foundation

### Slice 1: [Slice Name]
**Description:** [What this slice implements]
**Key Deliverables:**
- [Deliverable 1]
- [Deliverable 2]
- [Deliverable 3]

### Slice 2: [Slice Name]
**Description:** [What this slice implements]
**Key Deliverables:**
- [Deliverable 1]
- [Deliverable 2]

### Slice N: [Slice Name]
**Description:** [What this slice implements]
**Key Deliverables:**
- [Deliverable 1]
- [Deliverable 2]

---

## Slice Dependency Order

*Implementation order based on dependencies. Slices must be completed in this order unless noted as parallelizable.*

| Order | Slice | Depends On | Notes |
|-------|-------|------------|-------|
| 1 | Skeleton | None | Foundation - must be first |
| 2 | [Slice 1 Name] | Skeleton | [Any notes] |
| 3 | [Slice 2 Name] | Skeleton, Slice 1 | [Any notes] |
| 4 | [Slice 3 Name] | Slice 2 | [Any notes] |

---

## Open Questions

*Any unresolved items that need answers before TDD generation. Remove this section if all questions are resolved.*

1. **[Question topic]:** [The question that needs resolution]
   - *Options:* [Option A, Option B]
   - *Recommendation:* [If any]

2. **[Question topic]:** [The question that needs resolution]
   - *Options:* [Option A, Option B]
   - *Recommendation:* [If any]

*[If no open questions, state: "All questions resolved during tech stack and feature clarification."]*

---

## Approval

**By approving this Recipe, you confirm:**
- [ ] The tech stack choices are correct
- [ ] The feature list is complete for the initial release
- [ ] The slice breakdown makes sense
- [ ] The dependency order is logical
- [ ] All open questions have been resolved

**Approved by:** [Name]
**Approval Date:** [Date]

---

## What Happens Next

After approval, the following documents will be generated:

1. **Skeleton Build Guide** (`TDD/00-skeleton-build-guide.md`)
2. **Slice TDDs** (one per slice, following Slice Contract Template)
3. **Project Consistency Guide** (`TDD/consistency-guide.md`)
4. **Overview of Slices** (`TDD/overview-of-slices.md`)
5. **WHERE_WE_ARE.md** (TDD folder)
6. **Decision Log** (`TDD/decision-log.md`)

This Recipe document (`TDD/recipe.md`) will be preserved as a historical record of the initial project plan.

---

## Template Usage Notes

**When creating a Recipe document:**

1. Fill in Project Overview with information from the user's project description
2. Complete Tech Stack Summary with all decisions made during Phase 1 Q&A
3. Consolidate all features from user input into the Feature List
4. Break features into logical slices (aim for 3-7 slices depending on project size)
5. Determine slice dependencies and order
6. Document any unresolved questions in Open Questions
7. Present to user for approval before proceeding to TDD generation

**Important:**

- This document captures decisions, not rationale (rationale goes in Decision Log)
- Once approved, this document is frozen and not updated
- If major changes occur later, they are documented in Decision Log and relevant TDDs
- The Recipe serves as the "contract" for what will be built in the initial release
