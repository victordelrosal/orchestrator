#!/bin/bash
# Octopus Team Orchestrator
# Manages multi-terminal agent sessions via tmux + filesystem coordination.
#
# Usage: orchestrate.sh <model> <goal>
# Called by the octopus-team() shell function. Not meant to be run directly.

set -e

MODEL="${1:?Usage: orchestrate.sh <model> <goal>}"
GOAL="${2:?Usage: orchestrate.sh <model> <goal>}"
TEAM_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(pwd)/.octopus"
SESSION="octopus-team-$$"

# Colors
P='\033[1;35m'  # Purple
Y='\033[1;33m'  # Yellow
R='\033[1;31m'  # Red-Orange
B='\033[1;34m'  # Blue
G='\033[1;32m'  # Green
D='\033[0;90m'  # Dim
W='\033[1;37m'  # White
RST='\033[0m'

# ── Setup workspace ──
mkdir -p "$WORK_DIR"/{tasks,handoffs,state}
echo "pending" > "$WORK_DIR/state/pipeline"

echo ""
echo -e "${P}  ██ OCTOPUS TEAM ██${RST}"
echo -e "${D}  Workspace: $WORK_DIR${RST}"
echo ""
echo -e "${W}  Goal:${RST} $GOAL"
echo ""

# ── Stage 1: Purple Manager decomposes the goal ──
echo -e "${P}  [Purple Manager]${RST} Decomposing goal into agent tasks..."
echo ""

DECOMPOSE_PROMPT="You are the Purple Manager of the Octopus multi-agent team.

GOAL: $GOAL

Decompose this goal into exactly 4 task files. Write each file to the paths below.
Each file must contain a complete, self-contained task brief for the receiving agent.
Include all context the agent needs. The agent will NOT see other agents' tasks.

Write these files:
1. $WORK_DIR/tasks/01-research.md   (for Yellow Researcher)
2. $WORK_DIR/tasks/02-design.md     (for Red-Orange Designer)
3. $WORK_DIR/tasks/03-build.md      (for Blue Maker)
4. $WORK_DIR/tasks/04-market.md     (for Green Marketer)

Format each file as:
# Task: [title]
## Agent: [color] [name]
## Goal
[what to accomplish]
## Context
[all relevant context from the original goal]
## Output Format
[exactly what to deliver]
## Constraints
[scope limits, what NOT to do]

After writing all 4 files, write a pipeline plan to $WORK_DIR/state/plan.md explaining:
- Which stages run sequentially vs parallel
- Dependencies between stages
- Expected handoff sequence

IMPORTANT: Write all files now. Do not ask questions. Decompose and dispatch."

claude --dangerously-skip-permissions --model "$MODEL" -p "$DECOMPOSE_PROMPT" > /dev/null 2>&1

# Verify decomposition worked
if [[ ! -f "$WORK_DIR/tasks/01-research.md" ]]; then
  echo -e "${R}  Error: Decomposition failed. No task files created.${RST}"
  exit 1
fi

echo -e "${P}  [Purple Manager]${RST} Tasks decomposed:"
for f in "$WORK_DIR"/tasks/*.md; do
  echo -e "    ${D}$(basename "$f")${RST}"
done
if [[ -f "$WORK_DIR/state/plan.md" ]]; then
  echo -e "    ${D}state/plan.md${RST}"
fi
echo ""

# ── Stage 2: Sequential Research > Design, then Parallel Build + Market ──
# Research first (Designer needs the brief)
echo -e "${Y}  [Yellow Researcher]${RST} Spawning in tmux..."
echo "running" > "$WORK_DIR/state/01-research"

RESEARCH_PROMPT="You are the Yellow Researcher agent of the Octopus team.

$(cat "$WORK_DIR/tasks/01-research.md")

INSTRUCTIONS:
1. Do the research thoroughly using web search and any tools available.
2. Write your complete findings to: $WORK_DIR/handoffs/01-research-brief.md
3. The brief must be self-contained. The Designer will read ONLY this file.
4. When done, write the single word 'done' to: $WORK_DIR/state/01-research

FORMAT your brief as markdown with:
- Executive summary (3-5 bullet points)
- Detailed findings with sources
- Key takeaways and recommendations
- Anything the Designer needs to know"

tmux new-session -d -s "$SESSION" -n "researcher" \
  "printf '\e[38;2;255;193;7m[Yellow Researcher]\e[0m\n\n'; claude --dangerously-skip-permissions --model $MODEL -p \"$RESEARCH_PROMPT\" 2>&1; echo 'done' > '$WORK_DIR/state/01-research'; read -p 'Press enter to close...'"

echo -e "${Y}  [Yellow Researcher]${RST} Working... (tmux session: $SESSION)"

# Wait for research to complete
echo -e "${D}  Waiting for research to complete...${RST}"
while [[ "$(cat "$WORK_DIR/state/01-research" 2>/dev/null)" != "done" ]]; do
  sleep 3
done
echo -e "${Y}  [Yellow Researcher]${RST} Done."
echo ""

# ── Stage 3: Designer (needs research brief) ──
echo -e "${R}  [Red-Orange Designer]${RST} Spawning..."
echo "running" > "$WORK_DIR/state/02-design"

RESEARCH_BRIEF=""
if [[ -f "$WORK_DIR/handoffs/01-research-brief.md" ]]; then
  RESEARCH_BRIEF="$(cat "$WORK_DIR/handoffs/01-research-brief.md")"
fi

DESIGN_PROMPT="You are the Red-Orange Designer agent of the Octopus team.

$(cat "$WORK_DIR/tasks/02-design.md")

## Research Brief (from Yellow Researcher)
$RESEARCH_BRIEF

INSTRUCTIONS:
1. Use the research brief above as your foundation.
2. Create a complete design spec.
3. Write your output to: $WORK_DIR/handoffs/02-design-spec.md
4. The Maker and Marketer will read ONLY this file (plus the research brief).
5. When done, write the single word 'done' to: $WORK_DIR/state/02-design

FORMAT your spec as markdown with:
- Design overview and rationale
- Detailed component specs (ASCII wireframes if applicable)
- Technical requirements for the Maker
- Copy/messaging guidance for the Marketer"

tmux new-window -t "$SESSION" -n "designer" \
  "printf '\e[38;2;255;87;34m[Red-Orange Designer]\e[0m\n\n'; claude --dangerously-skip-permissions --model $MODEL -p \"$DESIGN_PROMPT\" 2>&1; echo 'done' > '$WORK_DIR/state/02-design'; read -p 'Press enter to close...'"

echo -e "${D}  Waiting for design to complete...${RST}"
while [[ "$(cat "$WORK_DIR/state/02-design" 2>/dev/null)" != "done" ]]; do
  sleep 3
done
echo -e "${R}  [Red-Orange Designer]${RST} Done."
echo ""

# ── Stage 4: Parallel - Maker + Marketer ──
echo -e "${B}  [Blue Maker]${RST} + ${G}[Green Marketer]${RST} Spawning in parallel..."

DESIGN_SPEC=""
if [[ -f "$WORK_DIR/handoffs/02-design-spec.md" ]]; then
  DESIGN_SPEC="$(cat "$WORK_DIR/handoffs/02-design-spec.md")"
fi

echo "running" > "$WORK_DIR/state/03-build"
echo "running" > "$WORK_DIR/state/04-market"

BUILD_PROMPT="You are the Blue Maker agent of the Octopus team.

$(cat "$WORK_DIR/tasks/03-build.md")

## Design Spec (from Red-Orange Designer)
$DESIGN_SPEC

## Research Brief (from Yellow Researcher)
$RESEARCH_BRIEF

INSTRUCTIONS:
1. Build exactly what the design spec describes.
2. Write working code, create files as needed in the current project directory.
3. Write a build summary to: $WORK_DIR/handoffs/03-build-done.md
4. When done, write the single word 'done' to: $WORK_DIR/state/03-build

Your build summary should list:
- All files created/modified
- How to run/verify the output
- Any deviations from the spec (with rationale)"

MARKET_PROMPT="You are the Green Marketer agent of the Octopus team.

$(cat "$WORK_DIR/tasks/04-market.md")

## Design Spec (from Red-Orange Designer)
$DESIGN_SPEC

## Research Brief (from Yellow Researcher)
$RESEARCH_BRIEF

INSTRUCTIONS:
1. Create all marketing/distribution assets described in your task.
2. Write copy, meta tags, social assets, or whatever is needed.
3. Write your output to: $WORK_DIR/handoffs/04-market-assets.md
4. When done, write the single word 'done' to: $WORK_DIR/state/04-market

Your output should include:
- All copy/content ready to use
- File paths for any created assets
- Distribution recommendations"

tmux new-window -t "$SESSION" -n "maker" \
  "printf '\e[38;2;66;133;244m[Blue Maker]\e[0m\n\n'; claude --dangerously-skip-permissions --model $MODEL -p \"$BUILD_PROMPT\" 2>&1; echo 'done' > '$WORK_DIR/state/03-build'; read -p 'Press enter to close...'"

tmux new-window -t "$SESSION" -n "marketer" \
  "printf '\e[38;2;76;175;80m[Green Marketer]\e[0m\n\n'; claude --dangerously-skip-permissions --model $MODEL -p \"$MARKET_PROMPT\" 2>&1; echo 'done' > '$WORK_DIR/state/04-market'; read -p 'Press enter to close...'"

echo -e "${B}  [Blue Maker]${RST}      Building... (parallel)"
echo -e "${G}  [Green Marketer]${RST}  Writing... (parallel)"
echo ""

# Wait for both
echo -e "${D}  Waiting for parallel stage to complete...${RST}"
while [[ "$(cat "$WORK_DIR/state/03-build" 2>/dev/null)" != "done" ]] || \
      [[ "$(cat "$WORK_DIR/state/04-market" 2>/dev/null)" != "done" ]]; do
  sleep 3
done
echo -e "${B}  [Blue Maker]${RST}      Done."
echo -e "${G}  [Green Marketer]${RST}  Done."
echo ""

# ── Stage 5: Purple Manager synthesizes ──
echo -e "${P}  [Purple Manager]${RST} Synthesizing all outputs..."

BUILD_DONE=""
MARKET_DONE=""
if [[ -f "$WORK_DIR/handoffs/03-build-done.md" ]]; then
  BUILD_DONE="$(cat "$WORK_DIR/handoffs/03-build-done.md")"
fi
if [[ -f "$WORK_DIR/handoffs/04-market-assets.md" ]]; then
  MARKET_DONE="$(cat "$WORK_DIR/handoffs/04-market-assets.md")"
fi

SYNTH_PROMPT="You are the Purple Manager of the Octopus team. All agents have completed their work.

ORIGINAL GOAL: $GOAL

## Research Brief (Yellow)
$RESEARCH_BRIEF

## Design Spec (Red-Orange)
$DESIGN_SPEC

## Build Summary (Blue)
$BUILD_DONE

## Marketing Assets (Green)
$MARKET_DONE

YOUR JOB:
1. Review all four outputs for coherence and completeness.
2. Integrate the Marketer's copy into the Maker's build if applicable (edit files directly).
3. Write a final synthesis report to: $WORK_DIR/handoffs/05-synthesis.md
4. List any gaps, conflicts, or follow-up items.
5. Verify the final output works (run it, check it, test it).

The synthesis report should include:
- What was accomplished
- All artifacts created (with file paths)
- Quality assessment
- Any remaining work needed"

tmux new-window -t "$SESSION" -n "manager" \
  "printf '\e[38;2;156;39;176m[Purple Manager] Synthesizing...\e[0m\n\n'; claude --dangerously-skip-permissions --model $MODEL -p \"$SYNTH_PROMPT\" 2>&1; echo 'done' > '$WORK_DIR/state/pipeline'; read -p 'Press enter to close...'"

echo -e "${D}  Waiting for synthesis...${RST}"
while [[ "$(cat "$WORK_DIR/state/pipeline" 2>/dev/null)" != "done" ]]; do
  sleep 3
done

echo ""
echo -e "${P}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${P}  OCTOPUS TEAM: COMPLETE${RST}"
echo -e "${P}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo ""
echo -e "  ${W}Artifacts:${RST}"
for f in "$WORK_DIR"/handoffs/*.md; do
  echo -e "    ${D}$f${RST}"
done
echo ""
echo -e "  ${W}Synthesis:${RST} $WORK_DIR/handoffs/05-synthesis.md"
echo -e "  ${W}tmux session:${RST} $SESSION (use 'tmux attach -t $SESSION' to review agent logs)"
echo ""

# Attach to the tmux session so user can review
tmux select-window -t "$SESSION:manager"
tmux attach -t "$SESSION"
