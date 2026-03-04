# Octopus Team

**Collaborative multi-agent orchestration for Octopus.**

Five agents. Five terminals. True parallel collaboration.

## What is this?

Octopus Team runs each agent in its own terminal window via tmux. All five agents spawn concurrently and **converse** with each other through a shared conversation log and blackboard. Agents with dependencies (Designer waits for Researcher, Maker waits for Designer) poll for their prerequisites while reading early findings from upstream agents.

This is not a sequential pipeline. It's a collaborative team.

```
  Purple Manager (decomposes, monitors, synthesizes)
       │
       ├─── Yellow Researcher    (starts immediately, posts findings as it goes)
       ├─── Red-Orange Designer  (reads early findings, designs when brief ready)
       ├─── Blue Maker           (reads design decisions, builds when spec ready)
       └─── Green Marketer       (reads findings + design, creates assets when spec ready)
       │
       └─── All agents converse via .octopus/conversation.jsonl
```

## How agents converse

All agents share a filesystem message bus:

```
.octopus/
  blackboard.md          # Mission board (Purple maintains)
  conversation.jsonl     # Append-only inter-agent chat log
  board/                 # Per-agent status files
  tasks/                 # Task decomposition (Purple writes)
  handoffs/              # Final deliverables (each agent writes)
  state/                 # Completion signals
```

**conversation.jsonl** is the conversation. Each line is JSON:
```json
{"ts":"2026-03-04T14:30:00Z","from":"yellow","to":"all","type":"finding","body":"Top competitor charges $49/mo. Users on Reddit say it's overpriced."}
{"ts":"2026-03-04T14:32:00Z","from":"red-orange","to":"yellow","type":"question","body":"What's the most requested feature users say the competitor lacks?"}
{"ts":"2026-03-04T14:33:00Z","from":"yellow","to":"red-orange","type":"answer","body":"Batch processing. Every thread mentions wanting to handle multiple invoices at once."}
```

Agents read this file between steps, answer questions, and post their own findings. The conversation is visible in real-time in the terminal that launched the team.

## Why separate terminals?

| Vanilla Octopus | Octopus Team |
|----------------|--------------|
| Subagents in one session | Each agent in its own terminal |
| Shared context window | Isolated context (no bloat) |
| Sequential handoffs | Concurrent with conversation |
| Fast for small tasks | Better for large, complex goals |
| No dependencies | Requires tmux |

The key benefits: **context isolation** (each agent gets 200K tokens fresh) and **true collaboration** (agents converse while working).

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
octopus-team --opus create a portfolio site for a developer
```

## What happens during a run

1. **Purple Manager** decomposes your goal into 4 task files
2. **All 5 agents spawn concurrently** in separate tmux windows
3. **Yellow Researcher** starts researching immediately, posting findings as it discovers them
4. **Red-Orange Designer** reads Yellow's early findings, polls for the complete brief, then designs
5. **Blue Maker + Green Marketer** read the conversation, poll for the design spec, then work
6. **Purple Manager** monitors the conversation, resolves questions, and synthesizes when all done
7. Agents converse via `conversation.jsonl` throughout the process

The terminal shows a **live conversation feed** while agents work.

## During a run

```bash
# Switch between agent windows in tmux
Ctrl+B then 0    # Researcher & Analyst (Yellow)
Ctrl+B then 1    # Designer (Red-Orange)
Ctrl+B then 2    # Maker (Blue)
Ctrl+B then 3    # Marketer (Green)
Ctrl+B then 4    # Manager (Purple)

# View the conversation
cat .octopus/conversation.jsonl

# View the blackboard
cat .octopus/blackboard.md

# View handoffs
ls .octopus/handoffs/
```

## Filesystem structure

Created in your project directory during a run:

```
.octopus/
  blackboard.md              # Mission board with status and decisions
  conversation.jsonl         # Inter-agent conversation log
  board/                     # Per-agent status files
    yellow.md
    red-orange.md
    blue.md
    green.md
  prompts/                   # Generated agent prompts
  launch/                    # Agent launcher scripts
  tasks/                     # Task decomposition
    01-research.md
    02-design.md
    03-build.md
    04-market.md
  handoffs/                  # Agent deliverables
    01-research-brief.md
    02-design-spec.md
    03-build-done.md
    04-market-assets.md
    05-synthesis.md
  state/                     # Pipeline state
    plan.md
    01-research              # "pending", "running", or "done"
    02-design
    03-build
    04-market
    pipeline
```

## Uninstall

1. Remove the `# >>> octopus-team-cli >>>` block from `~/.zshrc`
2. Delete: `rm -rf ~/.claude/octopus-team`

## Author

Victor del Rosal / [fiveinnolabs](https://fiveinnolabs.com) / March 2026
