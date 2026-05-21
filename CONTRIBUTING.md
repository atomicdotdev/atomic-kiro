# Contributing to atomic-kiro

## Prerequisites

- [Atomic VCS](https://atomic.dev) installed (`atomic --version`)
- [Kiro IDE](https://kiro.dev) installed
- Node.js 18+

## Setup

```bash
git clone https://github.com/atomicdotdev/atomic-kiro
cd atomic-kiro
./install.sh
```

## Project structure

| Path | Purpose |
|---|---|
| `skills/` | Kiro skill definitions (SKILL.md files) |
| `hooks/` | Shell scripts for Kiro hook triggers |
| `steering/` | Always-included Kiro steering context |
| `AGENTS.md` | Agent prompt for project roots |
| `install.js` | npm install script |
| `install.sh` | Dev install script |

## Making changes

This repo uses Atomic VCS. All changes should be recorded with `atomic record`.

```bash
atomic add <file>
atomic record -m "type: short description"
```

Commit message types: `feat`, `fix`, `docs`, `chore`.

## Submitting changes

1. Fork the repository
2. Create a draft view for your work: `atomic view create my-feature --draft`
3. Make your changes and record them
4. Open a pull request against `main`

## Skill development

Skills live in `skills/<name>/SKILL.md`. Each skill is a markdown file with a YAML frontmatter header:

```markdown
---
name: my-skill
description: One-line description shown in skill picker.
---

# Skill content here
```

After editing a skill, run `atomic vault query enrich` to update the knowledge graph.

## License

By contributing, you agree your contributions are licensed under the [Apache 2.0 License](LICENSE).
