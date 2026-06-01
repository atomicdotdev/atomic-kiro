---
inclusion: always
---

# Atomic VCS Context

This project uses **Atomic VCS** instead of git. Atomic uses patch theory to represent changes as composable operations on a directed graph.

## Key Differences from Git

| Concept | Git | Atomic |
|---------|-----|--------|
| History unit | Commit | Change (content-addressed patch) |
| Branches | Pointer to commit | View (filtered perspective on graph) |
| Merge | 3-way merge | Insert change references (with dependency closure) |
| Storage | Object database | Single canonical graph (redb) |
| File model | Snapshots | DAG of vertices and edges |

## Common Commands

```bash
atomic init                    # Initialize repository
atomic status                  # Show working copy status
atomic add <file>              # Track a file
atomic record -m "message"     # Record a change
atomic log                     # View history
atomic view list               # List views
atomic view create <name>      # Create a view
atomic view switch <name>      # Switch to a view
atomic diff                    # Show differences
```

For inspecting history, provenance, and AI attestation in depth (`status`, `log`, `change -p`/`-a`, `diff`), use the `/atomic-vcs` skill.

## Views (not branches)

Views are change-set filters on a single canonical graph. All edges live in one global GRAPH table. A view determines which subset is visible by tracking which changes belong to it.

- **Shared** views: collaborative, visible to all (like `main`, `dev`, `release`)
- **Draft** views: personal workspaces, isolated (like feature branches)

```bash
atomic view create feature --draft --parent dev
atomic view switch feature
# ... work ...
atomic insert from-view feature --to-view dev
```

## Vault (Project Management)

The vault tracks intents (work items), goals (sessions), and memory (persistent knowledge):

```bash
atomic vault intent list           # List work items
atomic vault intent create "title" # Create work item
atomic vault goal start "name"     # Start work session
atomic vault memory list           # List persistent knowledge
```

## Do NOT Use Git Commands

This project has no `.git` directory. All version control operations use the `atomic` CLI.
