# Consistency & Integration Guide Template

**Purpose:** Define development standards and integration contracts for your project. This is a **template** - fill in the `[TECH-STACK: ...]` sections with your project-specific choices.

**Version:** 1.0  
**Last Updated:** [DATE]  
**Project:** [PROJECT NAME]

---

## Table of Contents

1. [Overview](#overview)
2. [Naming Conventions](#naming-conventions)
3. [File Organization Standards](#file-organization-standards)
4. [Event/Action System Patterns](#eventaction-system-patterns)
5. [State Management Patterns](#state-management-patterns)
6. [Data Access Patterns](#data-access-patterns)
7. [Error Handling Standards](#error-handling-standards)
8. [UI/Component Patterns](#uicomponent-patterns)
9. [Testing Patterns](#testing-patterns)
10. [Integration Contracts](#integration-contracts)
11. [Code Review Checklist](#code-review-checklist)
12. [Performance Guidelines](#performance-guidelines)
13. [Accessibility Guidelines](#accessibility-guidelines)

---

## Quick Reference Summary

**Use this section to quickly find the right pattern. Read full sections when implementing new patterns.**

### Section Finder - "What pattern do I need?"

| I need to... | Go to Section |
|--------------|---------------|
| Name a file, class, function, or variable | Section 2: Naming Conventions |
| Find where to put a new file | Section 3: File Organization |
| Create or handle an event/action | Section 4: Event/Action Patterns |
| Work with state/providers/stores | Section 5: State Management |
| Query or modify database data | Section 6: Data Access Patterns |
| Handle errors properly | Section 7: Error Handling |
| Build a UI component or screen | Section 8: UI/Component Patterns |
| Write tests | Section 9: Testing Patterns |
| Integrate with another slice | Section 10: Integration Contracts |
| Review code | Section 11: Code Review Checklist |
| Optimize performance | Section 12: Performance Guidelines |
| Add accessibility features | Section 13: Accessibility Guidelines |

### Integration Checklist (Section 10)

When implementing a new slice, integrate at these points:
1. Add event/action types to constants file
2. Create database schema/tables
3. Register schema in database config
4. Implement state handlers
5. Create models, services, state, UI
6. Add routes/navigation
7. Write tests
8. Update documentation

### Code Review Quick Check (Section 11)

- [ ] Naming conventions followed
- [ ] No hardcoded strings (uses constants)
- [ ] Error handling at all layers
- [ ] Tests written and passing
- [ ] Integration points documented

### This is a Template

This document has `[TECH-STACK: ...]` placeholders. When setting up a new project:
1. Copy this template to your project's TDD folder
2. Fill in all placeholders with your project's specific choices
3. Remove sections that don't apply to your tech stack
4. Add project-specific patterns as needed

---

## Overview

This guide defines the standards that all feature slices must follow to ensure:

- **Consistency**: All code follows the same patterns and conventions
- **Integration**: Slices integrate smoothly without conflicts
- **Maintainability**: Code is readable and easy to modify
- **Quality**: High standards maintained across the codebase

### Guiding Principles

1. **Explicit over implicit**: Be clear in intent, avoid magic
2. **[PRINCIPLE: Add your project's key principle]**
3. **[PRINCIPLE: Add your project's key principle]**
4. **Type-safe**: Leverage your language's type system
5. **Testable**: Design for testability from the start

### Tech Stack Summary

| Component | Choice | Notes |
|-----------|--------|-------|
| Platform | [TECH-STACK: mobile/web/desktop/game] | |
| Language | [TECH-STACK: Dart/TypeScript/C#/Python/etc.] | |
| Framework | [TECH-STACK: Flutter/React/Unity/Django/etc.] | |
| State Management | [TECH-STACK: Riverpod/Redux/Vuex/etc.] | |
| Database/Storage | [TECH-STACK: SQLite/PostgreSQL/Firebase/etc.] | |
| Testing Framework | [TECH-STACK: Jest/pytest/flutter_test/etc.] | |

---

## Naming Conventions

### Files and Folders

[TECH-STACK: Define your file naming conventions]

**Files:**
```
[Examples of good file names]
- 
- 
- 

[Examples of bad file names]
- 
- 
- 
```

**Folders:**
```
[Examples of good folder names]
- 
- 

[Examples of bad folder names]
- 
- 
```

**Test files:**
```
[Define test file naming pattern]
Source: [path/to/source/file]
Test:   [path/to/test/file]
```

### Code Elements

[TECH-STACK: Define naming conventions for your language]

**Classes/Types:**
```
[Convention: PascalCase/camelCase/snake_case]
Examples:
- Good: 
- Bad: 
```

**Functions/Methods:**
```
[Convention]
Examples:
- Good: 
- Bad: 
```

**Variables:**
```
[Convention]
Examples:
- Good: 
- Bad: 
```

**Constants:**
```
[Convention]
Examples:
- Good: 
- Bad: 
```

**Private members:**
```
[Convention: underscore prefix, # prefix, etc.]
Examples:
- Good: 
- Bad: 
```

**State containers/Providers/Stores:**
```
[Convention for your state management]
Examples:
- Good: 
- Bad: 
```

### Event/Action Type Naming

**Format:** `[TECH-STACK: Define your event naming format]`

**Categories:**
[TECH-STACK: Define your event categories]
- Category A events: `prefix_*`
- Category B events: `prefix_*`
- Category C events: `prefix_*`

**Examples:**
```
Good:
- 
- 

Bad:
- 
- 
```

---

## File Organization Standards

### Project Structure

[TECH-STACK: Define your project's folder structure]

```
[project_root]/
├── [entry point]
├── [config files]
├── [core/shared modules]/
│   ├── [constants]/
│   ├── [database/storage]/
│   ├── [models]/
│   ├── [repositories/services]/
│   └── [utilities]/
├── [features]/
│   └── [feature_name]/
│       ├── [models]/
│       ├── [services]/
│       ├── [state]/
│       ├── [screens/pages]/
│       └── [components/widgets]/
├── [shared UI]/
│   ├── [components]/
│   └── [theme/styles]/
├── [global state]/
└── [tests]/
```

### Feature Slice Structure

Each feature slice follows this structure:

```
[features]/[feature_name]/
├── [models]/
│   └── [model files]
├── [services]/
│   └── [service files]
├── [state]/
│   └── [state management files]
├── [screens/pages]/
│   └── [full-page views]
└── [components/widgets]/
    └── [reusable UI pieces]
```

### Import Organization

[TECH-STACK: Define import ordering for your language]

Order imports in this sequence:
1. [First category]
2. [Second category]
3. [Third category]
4. [Fourth category]

```
[TECH-STACK: Example of properly ordered imports]
```

---

## Event/Action System Patterns

[TECH-STACK: Define your event/action system patterns]

### Event/Action Structure

All events/actions MUST include these base fields:

```
[TECH-STACK: Define your base event/action structure]
{
  // Required fields for all events
}
```

### Event/Action Payload Standards

**[Category] Events:** Include [required information]

```
[TECH-STACK: Example event payload]
```

### Event/Action Creation Pattern

Always use this pattern when creating events/actions:

```
[TECH-STACK: Standard pattern for creating and dispatching events/actions]
```

### Event/Action Handler Pattern

Handlers follow this pattern:

```
[TECH-STACK: Standard pattern for handling events/actions]
```

### Event/Action Registration

Add new event/action types to: `[TECH-STACK: path/to/constants/file]`

---

## State Management Patterns

[TECH-STACK: Define your state management patterns]

### State Container/Provider/Store Creation

**Global state** → `[path/to/global/state]`  
**Feature state** → `[path/to/feature/state]`

### State Types and Usage

[TECH-STACK: Define the different types of state containers you use]

**1. [Type 1: e.g., Read-only dependencies]**
```
[Example]
```

**2. [Type 2: e.g., Mutable state]**
```
[Example]
```

**3. [Type 3: e.g., Reactive/stream state]**
```
[Example]
```

**4. [Type 4: e.g., Async data]**
```
[Example]
```

**5. [Type 5: e.g., Parameterized state]**
```
[Example]
```

### Consumer/Subscriber Pattern

```
[TECH-STACK: Standard pattern for consuming/subscribing to state]
```

---

## Data Access Patterns

[TECH-STACK: Define your database/data access patterns]

### Query Patterns

**Select all with ordering:**
```
[TECH-STACK: Example]
```

**Select with filtering:**
```
[TECH-STACK: Example]
```

**Select single:**
```
[TECH-STACK: Example]
```

**Watch/Subscribe (reactive):**
```
[TECH-STACK: Example]
```

### Insert Patterns

**Single insert:**
```
[TECH-STACK: Example]
```

**Insert with conflict handling:**
```
[TECH-STACK: Example]
```

### Update Patterns

```
[TECH-STACK: Example]
```

### Delete Patterns

**Soft delete (preferred):**
```
[TECH-STACK: Example]
```

**Hard delete (use sparingly):**
```
[TECH-STACK: Example]
```

### Transaction Pattern

```
[TECH-STACK: Example of transaction handling]
```

---

## Error Handling Standards

### Three-Layer Approach

**1. Data/Repository Layer:** Throw specific exceptions

```
[TECH-STACK: Example of repository-level error handling]
```

**2. Service/Business Layer:** Catch and handle or rethrow

```
[TECH-STACK: Example of service-level error handling]
```

**3. UI/Presentation Layer:** Display user-friendly messages

```
[TECH-STACK: Example of UI-level error handling]
```

### Async Error Handling

```
[TECH-STACK: Pattern for handling async errors in your framework]
```

---

## UI/Component Patterns

[TECH-STACK: Define your UI patterns]

### Component File Organization

**Screens/Pages**: Full-page views in `[path]`
**Components/Widgets**: Reusable components in `[path]`

### Component Naming

```
Good:
- [Example of good component names]

Bad:
- [Example of bad component names]
```

### Component Structure Pattern

```
[TECH-STACK: Standard pattern for component structure]
```

### Responsive Design Pattern

```
[TECH-STACK: How to handle responsive design]
```

### Theme/Styling Usage

```
[TECH-STACK: How to use theme and styling]
```

### Shared Components

Use shared components from `[path/to/shared/components]`:

```
[TECH-STACK: Examples of using shared components]
```

---

## Testing Patterns

[TECH-STACK: Define your testing patterns]

### Test File Structure

```
[TECH-STACK: Standard test file structure]
```

### Unit Test Pattern

```
[TECH-STACK: Standard unit test pattern with setup/teardown]
```

### Component/Widget Test Pattern

```
[TECH-STACK: Standard component test pattern]
```

### Integration Test Pattern

```
[TECH-STACK: Standard integration test pattern]
```

### Test Running

**Commands:**
- Run all tests: `[command]`
- Run single test file: `[command]`
- Run with coverage: `[command]`

---

## Integration Contracts

### Where Slices Integrate

Every slice must integrate at these points:

#### 1. Event/Action Types (`[path/to/constants]`)

Add new event/action type constants.

#### 2. State Handlers (`[path/to/handlers]`)

Add handlers for new events/actions.

#### 3. Database/Schema (`[path/to/database]`)

Add new tables/collections.

#### 4. Routes (`[path/to/routes]`)

Add new routes/navigation.

#### 5. Navigation (if applicable)

Add to navigation menus.

### Dependency Declaration

Each slice document must declare dependencies:

```markdown
**Dependencies:** 
- Skeleton (database, event system)
- Slice 1 ([specific features])
- Slice 2 ([specific features])
```

### Integration Order

Slices must be implemented in order based on dependencies. Document your project's slice order here:

1. **Skeleton** → Foundation
2. **Slice 1** → [Name and purpose]
3. **Slice 2** → [Name and purpose]
4. [Continue as needed...]

---

## Code Review Checklist

Before merging any slice implementation:

### Code Quality
- [ ] Follows naming conventions throughout
- [ ] No hardcoded strings (uses constants)
- [ ] Comments explain complex logic
- [ ] No unused imports or variables
- [ ] Proper error handling implemented

### Event/Action System
- [ ] Event/action types added to constants
- [ ] Event/action payloads match documented structure
- [ ] Handlers implemented correctly
- [ ] Events properly deduplicated (if applicable)

### Database/Storage
- [ ] Schema changes added correctly
- [ ] Migrations defined (if schema changes)
- [ ] Indexes created for queried columns
- [ ] Queries use proper ordering and filtering

### State Management
- [ ] State containers follow naming conventions
- [ ] Dependencies correctly declared
- [ ] Errors handled gracefully
- [ ] No unnecessary rebuilds/re-renders

### UI
- [ ] Follows design system patterns
- [ ] Responsive to different screen sizes
- [ ] Proper loading and error states
- [ ] Accessibility labels added

### Testing
- [ ] Unit tests written and passing
- [ ] Component tests for complex components
- [ ] Integration tests for key flows
- [ ] Test coverage meets standards

### Integration
- [ ] Integrates cleanly with existing slices
- [ ] No regressions in existing functionality
- [ ] Documentation updated to reflect changes
- [ ] Implementation checklist complete

---

## Performance Guidelines

### Data Access Performance

[TECH-STACK: Performance guidelines for your data layer]

**1. Use indexes on frequently queried columns**
```
[Example]
```

**2. Limit query results when appropriate**
```
[Example]
```

**3. Use transactions for multiple writes**
```
[Example]
```

### State Management Performance

[TECH-STACK: Performance guidelines for your state management]

**1. Minimize re-renders/rebuilds**
```
[Example]
```

**2. Split state appropriately**
```
[Example]
```

**3. Use selective subscriptions**
```
[Example]
```

### UI Performance

[TECH-STACK: UI performance guidelines]

**1. Use virtualized lists for large datasets**
```
[Example]
```

**2. Cache computed values**
```
[Example]
```

---

## Accessibility Guidelines

[TECH-STACK: Accessibility guidelines for your platform]

### Semantic Labels
```
[Example of proper semantic labeling]
```

### Text Scaling
```
[Example of supporting text scaling]
```

### Color Contrast
```
[Guidance on color contrast requirements]
```

### Touch Targets
```
[Minimum touch target size requirements]
```

### Screen Reader Support
```
[Guidelines for screen reader compatibility]
```

---

## Slice Integration Summary

### Integration Checklist for New Slices

When implementing a new slice, integrate at these points in order:

1. Create feature folder structure in `[path/to/features]/[feature]/`
2. Add event/action types to `[path/to/constants]`
3. Create database schema in `[path/to/schema]`
4. Register schema/tables in `[path/to/database]`
5. Implement state handlers in `[path/to/handlers]`
6. Create models in `[path/to/feature/models]`
7. Implement services in `[path/to/feature/services]`
8. Create state containers in `[path/to/feature/state]`
9. Build UI in `[path/to/feature/screens]` and `[path/to/feature/components]`
10. Add routes in `[path/to/routes]`
11. Write tests in `[path/to/tests/feature]`
12. Update documentation in `TDD/` folder

---

## Summary

This Consistency & Integration Guide ensures:

- **Uniform code style** across all slices
- **Clear integration points** for new features
- **Best practices** for performance and maintainability
- **Quality standards** maintained throughout

**Key Principles to Remember:**

1. Follow naming conventions strictly
2. Integrate at the defined touch points
3. Handle errors at all three layers
4. Test comprehensively
5. Document changes in TDD folder

When in doubt, reference existing slice implementations and this guide.

---

**End of Consistency & Integration Guide Template**

---

## Template Usage Notes

This document is a **template**. When starting a new project:

1. Copy this file to your project's TDD folder
2. Replace all `[TECH-STACK: ...]` placeholders with your project's specific choices
3. Remove or modify sections that don't apply to your tech stack
4. Add additional sections specific to your framework
5. Update the "Tech Stack Summary" table
6. Fill in the "Integration Order" with your project's slices

The Starting Prompt will guide you through filling in this template during project initialization.
