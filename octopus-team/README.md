# Octopus Team

**Multi-terminal agent orchestration for Octopus.**

Five agents. Five terminals. True parallel execution.

## What is this?

Octopus Team is an add-on to [Octopus](https://github.com/victordelrosal/octopus) that runs each agent in its own terminal window via tmux. Instead of subagents inside one Claude session, you get fully isolated agents with separate context windows, coordinating through the filesystem.

```
  Purple Manager (decomposes goal)
       │
       ├── Stage 1: Yellow Researcher (tmux window 1)
       │        writes research brief
       │
       ├── Stage 2: Red-Orange Designer (tmux window 2)
       │        reads brief, writes design spec
       │
       ├── Stage 3 (parallel):
       │   ├── Blue Maker (tmux window 3)
       │   │        reads spec, builds
       │   └── Green Marketer (tmux window 4)
       │            reads spec, writes copy
       │
       └── Stage 4: Purple Manager (tmux window 5)
                synthesizes all outputs
```

## Why separate terminals?

| Vanilla Octopus | Octopus Team |
|----------------|--------------|
| Subagents in one session | Each agent in its own terminal |
| Shared context window | Isolated context (no bloat) |
| Purple sees everything | Each agent sees only its task + prior handoff |
| Fast for small tasks | Better for large, complex goals |
| No dependencies | Requires tmux |

The key benefit: **context isolation**. Each agent gets a fresh context window with only the information it needs. No 200K token soup.

## Install

Requires: [Octopus](https://github.com/victordelrosal/octopus) (vanilla), tmux, claude CLI.

```bash
cd octopus/octopus-team
bash install-team.sh
source ~/.zshrc
```

## Usage

```bash
# Interactive (prompts for model + goal)
octopus-team

# Direct
octopus-team build a landing page for my SaaS product

# With model flag
octopus-team --sonnet create a portfolio site for a developer
```

## What happens during a run

1. **Purple Manager** decomposes your goal into 4 task files
2. **Yellow Researcher** spawns in a tmux window, researches, writes a brief
3. **Red-Orange Designer** spawns, reads the brief, writes a design spec
4. **Blue Maker + Green Marketer** spawn in parallel, both reading the spec
5. **Purple Manager** synthesizes all outputs, integrates, verifies

All agent outputs live in `.octopus/handoffs/` in your project directory.

## During a run

```bash
# Switch between agent windows
Ctrl+B then 0    # Researcher
Ctrl+B then 1    # Designer
Ctrl+B then 2    # Maker
Ctrl+B then 3    # Marketer
Ctrl+B then 4    # Manager (synthesis)

# View all windows
tmux list-windows

# View handoffs
ls .octopus/handoffs/
```

## Filesystem structure

Created in your project directory during a run:

```
.octopus/
  tasks/                  # Task decomposition (input per agent)
    01-research.md
    02-design.md
    03-build.md
    04-market.md
  handoffs/               # Agent outputs (filesystem = message bus)
    01-research-brief.md
    02-design-spec.md
    03-build-done.md
    04-market-assets.md
    05-synthesis.md
  state/                  # Pipeline state tracking
    plan.md
    01-research            # "running" or "done"
    02-design
    03-build
    04-market
    pipeline               # "pending", "running", or "done"
```

## Uninstall

1. Remove the `# >>> octopus-team-cli >>>` block from `~/.zshrc`
2. Delete: `rm -rf ~/.claude/octopus-team`

## Author

Victor del Rosal / [fiveinnolabs](https://fiveinnolabs.com) / March 2026
