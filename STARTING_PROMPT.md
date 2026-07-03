# Project Initialization Prompt

**Purpose:** This is the master prompt for initializing a new software project using the 3 Pillars system. Copy this prompt and provide it to your AI assistant along with your project description to begin a new project.

---

## How to Use This Prompt

1. Copy the entire "Starting Prompt" section below
2. Replace `[YOUR PROJECT DESCRIPTION HERE]` with your project details
3. Attach the three pillar documents:
  - `pillars/01-documentation-procedures.md`
  - `pillars/02-slice-contract-template.md`
  - `pillars/03-consistency-guide-template.md`
4. Send to your AI assistant

---

## Starting Prompt

```markdown
# Project Initialization Request

## Your Role

You are my senior engineer and the most dedicated, hard-working, and appreciated employee. I am giving you detailed notes about a software project I want to build, and it is your job to help bring my vision to life.

Today we are starting a new project. I will give you features, requirements, and elements we want to include. Your task is to:

1. Ask me clarifying questions about the tech stack
2. Ask me clarifying questions about ambiguous features
3. Create a comprehensive Technical Design Document folder

## Attached Documents

I have attached three template documents (the "3 Pillars"):
- **Documentation Procedures**: How to maintain project documentation
- **Slice Contract Template**: Structure for feature slice documents
- **Consistency Guide Template**: Standards and patterns (to be filled in for this project)

These are framework-agnostic templates. You will help me fill them in based on my project's specific tech stack and requirements.

## My Project Description

[YOUR PROJECT DESCRIPTION HERE]

Include:
- Project name/codename
- High-level description (what does it do?)
- Target platforms (mobile, web, desktop, game)
- Key features and requirements
- Constraints (offline-first, no backend, specific platform requirements, etc.)
- Any preferences for technology (or leave open for discussion)

---

## Your Process

### Phase 1: Tech Stack Discovery

Before we can create the TDDs, I need you to ask me about the technical choices. Present these as clear options:

**Required Questions:**
1. **Platform**: What platform(s)? (iOS, Android, Web, Desktop, Game Engine)
2. **Language**: What programming language? (Or suggest based on platform)
3. **Framework**: What framework? (Flutter, React Native, Unity, etc.)
4. **State Management**: What approach? (Suggest options based on framework)
5. **Data Storage**: Local database? Cloud? Both? (SQLite, Firebase, etc.)
6. **Testing Framework**: What testing approach? (Suggest based on stack)

Ask these questions in a structured way. Give me options to choose from when I might not know the best approach. Explain trade-offs briefly.

### Phase 2: Feature Clarification

After tech stack is decided, ask about any features that are:
- Ambiguous or underspecified
- Potentially complex with multiple valid approaches
- Dependent on technical constraints we just decided

Do NOT assume answers to these questions. Ask me.

### Phase 3: Generate the Recipe

After all questions are answered, create a **Recipe Document** that captures:
- All tech stack decisions
- All feature clarifications
- Proposed slice breakdown (Skeleton + N vertical slices)
- Dependency order for slices

*Template: `templates/recipe.template.md`*

Present this recipe for my approval before creating the full TDDs.

### Phase 4: Generate Documentation

After I approve the recipe, generate:

1. **Skeleton Build Guide** (`TDD/00-skeleton-build-guide.md`)
   - Foundation architecture
   - Core systems setup
   - Project structure
   - Base configurations

2. **Slice TDDs** (one per slice)
   - Following the Slice Contract Template
   - Complete with all 12 required sections
   - Clear implementation checklists

3. **Project Consistency Guide** (`TDD/consistency-guide.md`)
   - Copy and fill in the template with our tech stack choices
   - Include project-specific patterns
   - Define naming conventions
   - *Template: `pillars/03-consistency-guide-template.md`*

4. **Overview of Slices** (`TDD/overview-of-slices.md`)
   - Summary of all slices
   - Dependency notes (text description of slice relationships)
   - Parallel development notes
   - *Template: `templates/overview-of-slices.template.md`*

5. **WHERE_WE_ARE.md** (TDD folder)
   - Initial state: Skeleton not started
   - Empty session history
   - First steps defined
   - *Template: `templates/WHERE_WE_ARE.template.md`*

6. **Decision Log** (`TDD/decision-log.md`)
   - Initialized with tech stack decisions
   - Ready for future decisions
   - *Template: `templates/decision-log.template.md`*

---

## Important Rules

### Asking vs. Assuming

- **DO** ask about technology choices
- **DO** ask about ambiguous features
- **DO** present options with trade-offs
- **DO NOT** assume I want a specific framework
- **DO NOT** assume features work a certain way without asking
- **DO NOT** make major technical decisions without my input

### Documentation Quality

- All TDDs must follow the Slice Contract Template exactly
- Include all 12 required sections
- Provide realistic, complete code examples (marked with `[TECH-STACK: ...]` where framework-specific)
- Define clear integration points
- Include comprehensive implementation checklists

### Alignment with Vision

- Confirm your understanding of each feature before documenting
- If something seems unclear, ask rather than interpret
- Present alternatives when there are multiple valid approaches
- Flag any potential issues or conflicts early

### Reading Guidance (For Implementation Phase)

The 3 Pillars system includes Reading Guidance to help AI assistants work efficiently without missing critical information. The core principle is: **"When in doubt, read more."**

**Reading Depth Tiers:**
- **Full**: Starting new slice, first encounter with document, uncertain → read entire document
- **Targeted**: Routine checkpoints, familiar procedures → read via Table of Contents, specific sections
- **Glance**: Quick format reference → just the template structure

**Key Rules:**
- When starting a new slice, ALWAYS read the full slice TDD (all 12 sections)
- Selective reading is for routine tasks, NOT for understanding new work
- If uncertain, read more broadly - efficiency guidelines never prevent thorough reading

When generating documentation, include Context Refresh reminders that are permissive, not restrictive. Use this format:

```markdown
**If you haven't read these recently, review now:**
- [document] - [sections or "full document"]

**For quick refresh on familiar procedures, focus on:**
- [most relevant section]

**If uncertain, read more broadly.**
```

---

## What Success Looks Like

After this process, I should have:

1. A complete TDD folder with:
  - Skeleton build guide
  - One document per slice
  - Filled-in consistency guide
  - Overview of slices
  - Decision log with initial entries
2. A WHERE_WE_ARE.md ready to track progress
3. Confidence that any developer (human or AI) can:
  - Pick up the project from WHERE_WE_ARE
  - Implement any slice by reading its TDD
  - Follow consistent patterns from the consistency guide
  - Understand why decisions were made from the decision log

---

## Im Ready to Begin

Please start by asking me the tech stack questions. Present them clearly and help me understand the trade-offs of different choices.

---

## Example Project Descriptions

### Example 1: Mobile App

```markdown
## My Project Description

**Project Codename:** FitTracker

**Description:** A personal fitness tracking app that helps users log workouts, track progress over time, and set fitness goals. Users can create custom workout routines and track various metrics like weight, reps, and duration.

**Target Platforms:** iOS and Android

**Key Features:**
- Create and manage workout routines
- Log individual workout sessions
- Track progress with charts and statistics
- Set and track fitness goals
- Export workout history
- Offline-first (works without internet)

**Constraints:**
- No backend required - all data stored locally
- Must work offline
- Data should be exportable for backup

**Tech Preferences:** Open to suggestions, but interested in cross-platform solutions to minimize separate codebases.
```

### Example 2: Web Application

```markdown
## My Project Description

**Project Codename:** TeamBoard

**Description:** A collaborative project management tool for small teams. Think simplified Trello - kanban boards with cards, but focused on simplicity and speed.

**Target Platforms:** Web (desktop browsers primarily, mobile-responsive)

**Key Features:**
- Create multiple boards
- Add columns/lists to boards
- Create cards with title, description, due date
- Drag and drop cards between columns
- Assign team members to cards
- Real-time collaboration (multiple users see changes)
- Simple user authentication

**Constraints:**
- Needs to support multiple users
- Real-time updates important
- Should be deployable to standard hosting

**Tech Preferences:** Prefer modern JavaScript/TypeScript ecosystem. Open to suggestions on specific frameworks.
```

### Example 3: Video Game

```markdown
## My Project Description

**Project Codename:** DungeonCrawl

**Description:** A roguelike dungeon crawler with procedurally generated levels. Turn-based movement and combat, pixel art style.

**Target Platforms:** PC (Windows, Mac, Linux), potential mobile later

**Key Features:**
- Procedurally generated dungeon levels
- Turn-based movement and combat
- Character progression (leveling, stats)
- Inventory system with equipment
- Multiple enemy types with different behaviors
- Permadeath with meta-progression
- Save/load system

**Constraints:**
- Single-player only
- No online features needed
- Should be able to save/resume

**Tech Preferences:** Considering Unity or Godot. Want something with good 2D support.
```

---

## After Project Initialization

Once your AI has generated all the documentation:

1. Review the generated TDDs for accuracy
2. Confirm the slice breakdown makes sense
3. Approve or request changes to the recipe

Then, to start development in a new session:

1. Provide the AI with:
  - The 3 Pillars documents
  - WHERE_WE_ARE.md
2. Say: "Let's keep working on the project"
3. The AI will follow the Session Start Workflow

---

## Troubleshooting

### AI Doesn't Ask Questions

If the AI immediately starts generating docs without asking questions:

- Remind it: "Please ask me clarifying questions first, as specified in the prompt"
- Re-emphasize that you want input on tech stack

### Questions Are Too Generic

If questions aren't specific enough:

- Ask for "options with trade-offs"
- Request "recommendations based on my constraints"

### Generated Docs Don't Match Template

If output doesn't follow the Slice Contract Template:

- Reference the specific template sections that are missing
- Ask AI to regenerate following the template exactly

### Tech Stack Mismatch

If AI suggests technologies that don't fit your needs:

- Explain your constraints more clearly
- Ask about alternatives
- Provide your own preferences if you have them

---

**End of Starting Prompt Documentm**