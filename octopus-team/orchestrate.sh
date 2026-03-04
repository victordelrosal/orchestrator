#!/bin/bash
# Octopus Team Orchestrator v2 - Collaborative Mode
# All agents spawn concurrently and converse via shared blackboard + conversation log.
# Agents with dependencies poll for prerequisite files from upstream agents.
#
# Architecture:
#   blackboard.md        - Human-readable mission board (Purple maintains)
#   conversation.jsonl   - Append-only inter-agent chat log
#   board/{agent}.md     - Per-agent status (each agent owns its own file)
#   handoffs/{NN}-*.md   - Final deliverables
#   state/{NN}-*         - Completion signals
#
# Usage: orchestrate.sh <model> <goal>
# Called by the octopus-team() shell function.

set -e

MODEL="${1:?Usage: orchestrate.sh <model> <goal>}"
GOAL="${2:?Usage: orchestrate.sh <model> <goal>}"
WORK_DIR="$(pwd)/.octopus"
SESSION="octopus-team-$$"

# Colors
P='\033[1;35m'  Y='\033[1;33m'  R='\033[1;31m'
B='\033[1;34m'  G='\033[1;32m'  D='\033[0;90m'
W='\033[1;37m'  RST='\033[0m'

# ── Setup workspace ──────────────────────────────────────────────────────────
mkdir -p "$WORK_DIR"/{tasks,handoffs,state,board,prompts,launch}
echo "pending" > "$WORK_DIR/state/pipeline"
echo "pending" > "$WORK_DIR/state/01-research"
echo "pending" > "$WORK_DIR/state/02-design"
echo "pending" > "$WORK_DIR/state/03-build"
echo "pending" > "$WORK_DIR/state/04-market"
: > "$WORK_DIR/conversation.jsonl"

# ── Create initial blackboard ────────────────────────────────────────────────
cat > "$WORK_DIR/blackboard.md" << BOARD
# Octopus Blackboard

## Mission
$GOAL

## Agent Status
| Agent | Color | Status | Role |
|-------|-------|--------|------|
| Researcher & Analyst | Yellow | SPAWNING | Scout mode: research the opportunity |
| Designer | Red-Orange | SPAWNING | Wait for research, then design |
| Maker | Blue | SPAWNING | Wait for design spec, then build |
| Marketer | Green | SPAWNING | Wait for design spec, then create assets |
| Manager | Purple | ORCHESTRATING | Decomposing goal, monitoring team |

## Decisions
(Purple posts decisions here)

## Blockers
(none)
BOARD

echo ""
echo -e "${P}  ██ OCTOPUS TEAM ██  ${W}Collaborative Mode${RST}"
echo -e "${D}  Workspace: $WORK_DIR${RST}"
echo ""
echo -e "  ${W}Goal:${RST} $GOAL"
echo ""

# ── Conversation helper ──────────────────────────────────────────────────────
post_msg() {
  local from="$1" to="$2" type="$3" body="$4"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local escaped_body
  escaped_body=$(printf '%s' "$body" | sed 's/"/\\"/g' | tr '\n' ' ')
  printf '{"ts":"%s","from":"%s","to":"%s","type":"%s","body":"%s"}\n' \
    "$ts" "$from" "$to" "$type" "$escaped_body" >> "$WORK_DIR/conversation.jsonl"
}

# ── Stage 1: Purple decomposes the goal ──────────────────────────────────────
echo -e "${P}  [Purple Manager]${RST} Decomposing goal into agent tasks..."
post_msg "purple" "all" "status" "Decomposing goal into agent tasks."

DECOMPOSE_PROMPT="You are the Purple Manager of the Octopus multi-agent team.

GOAL: $GOAL

Decompose this goal into exactly 4 task files. Write each file to the paths below.
Each file must contain a complete, self-contained task brief for the receiving agent.
Include all context the agent needs.

Write these files:
1. $WORK_DIR/tasks/01-research.md   (for Yellow Researcher & Analyst)
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

After writing all 4 files, write a pipeline plan to $WORK_DIR/state/plan.md explaining
which stages run in parallel and what the dependencies are.

IMPORTANT: Write all files now. Do not ask questions. Decompose and dispatch."

claude --dangerously-skip-permissions --model "$MODEL" -p "$DECOMPOSE_PROMPT" > /dev/null 2>&1

# Verify decomposition
if [[ ! -f "$WORK_DIR/tasks/01-research.md" ]]; then
  echo -e "${R}  Error: Decomposition failed. No task files created.${RST}"
  exit 1
fi

echo -e "${P}  [Purple Manager]${RST} Tasks decomposed."
for f in "$WORK_DIR"/tasks/*.md; do
  echo -e "    ${D}$(basename "$f")${RST}"
done
echo ""
post_msg "purple" "all" "status" "All tasks decomposed. Spawning 5 agents concurrently."

# ── Shared conversation protocol ─────────────────────────────────────────────
# This text is embedded in every agent prompt so they know how to converse.

CONVO_PROTOCOL="
## CONVERSATION PROTOCOL (READ THIS CAREFULLY)
You are part of a collaborative multi-agent team. All 5 agents run concurrently
in separate terminals and communicate via shared files.

### Reading messages from other agents
- Read $WORK_DIR/conversation.jsonl to see messages from other agents.
- Each line is JSON: {ts, from, to, type, body}
- Types: status, finding, question, answer, decision, blocker

### Posting messages
- Use bash to append to the conversation log:
  echo '{\"ts\":\"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"from\":\"YOUR_COLOR\",\"to\":\"all\",\"type\":\"finding\",\"body\":\"Your message\"}' >> $WORK_DIR/conversation.jsonl
- Post status updates when you start, make progress, and finish.
- Post findings that other agents should know about.
- Post questions when you need input from another agent.

### Between major steps
- Read conversation.jsonl to check for questions directed at you.
- If another agent asked you something, answer before continuing.

### Your status board
- Write your current status to $WORK_DIR/board/YOUR_COLOR.md
- Update it as your work progresses.
"

# ── Build agent prompts ──────────────────────────────────────────────────────

# Yellow Researcher (no dependencies, starts immediately)
YELLOW_TASK=""
[[ -f "$WORK_DIR/tasks/01-research.md" ]] && YELLOW_TASK=$(cat "$WORK_DIR/tasks/01-research.md")

cat > "$WORK_DIR/prompts/yellow.md" << YELLOWEOF
You are the Yellow Researcher & Analyst agent of the Octopus team.

## Your Task
$YELLOW_TASK

$CONVO_PROTOCOL

Replace YOUR_COLOR with "yellow" in all conversation messages.

## Dependencies
None. You start immediately. Other agents are waiting for your research.

## Instructions
1. Post a status message to conversation.jsonl: you are starting research.
2. Research thoroughly using web search and all tools available.
3. Post key findings to conversation.jsonl as you discover them (type: "finding").
   This lets the Designer start preparing while you work.
4. Write your complete research brief to: $WORK_DIR/handoffs/01-research-brief.md
   Format: Executive summary, detailed findings with sources, key takeaways,
   recommendations, and anything the Designer needs to know.
5. Post a final status message: research complete.
6. Write the single word 'done' to: $WORK_DIR/state/01-research

IMPORTANT: Post findings AS you discover them, not just at the end.
The Designer is waiting and can start work once they see your early findings.
YELLOWEOF

# Red-Orange Designer (depends on Yellow)
DESIGN_TASK=""
[[ -f "$WORK_DIR/tasks/02-design.md" ]] && DESIGN_TASK=$(cat "$WORK_DIR/tasks/02-design.md")

cat > "$WORK_DIR/prompts/red-orange.md" << ROEOF
You are the Red-Orange Designer agent of the Octopus team.

## Your Task
$DESIGN_TASK

$CONVO_PROTOCOL

Replace YOUR_COLOR with "red-orange" in all conversation messages.

## Dependencies
You need the Yellow Researcher's brief before you can finalize your design.
The brief will appear at: $WORK_DIR/handoffs/01-research-brief.md

## Instructions
1. Post a status message: you are preparing while waiting for research.
2. Read conversation.jsonl for any early findings from Yellow.
3. While the research brief does not exist yet, you CAN:
   - Study the goal and start thinking about architecture
   - Post questions to Yellow via conversation.jsonl
   - Sketch preliminary ideas based on early findings
4. Check periodically if the research brief exists using bash:
   if [ -f "$WORK_DIR/handoffs/01-research-brief.md" ]; then echo "ready"; fi
   If not ready, read conversation.jsonl for updates, then check again in 30 seconds.
   Repeat until the file appears.
5. Once the brief exists, read it and create your design.
6. Post key design decisions to conversation.jsonl as you make them (type: "finding").
7. Write your complete design spec to: $WORK_DIR/handoffs/02-design-spec.md
   Include: design overview, architecture, wireframes (ASCII), component specs,
   technical requirements for the Maker, copy/messaging guidance for the Marketer.
8. Post a final status: design complete.
9. Write 'done' to: $WORK_DIR/state/02-design

IMPORTANT: Post design decisions early. The Maker and Marketer are waiting.
ROEOF

# Blue Maker (depends on Red-Orange)
BUILD_TASK=""
[[ -f "$WORK_DIR/tasks/03-build.md" ]] && BUILD_TASK=$(cat "$WORK_DIR/tasks/03-build.md")

cat > "$WORK_DIR/prompts/blue.md" << BLUEEOF
You are the Blue Maker agent of the Octopus team.

## Your Task
$BUILD_TASK

$CONVO_PROTOCOL

Replace YOUR_COLOR with "blue" in all conversation messages.

## Dependencies
You need the Red-Orange Designer's spec before you can build.
The spec will appear at: $WORK_DIR/handoffs/02-design-spec.md
You also benefit from the research brief at: $WORK_DIR/handoffs/01-research-brief.md

## Instructions
1. Post a status message: you are preparing while waiting for design spec.
2. Read conversation.jsonl for early findings and design decisions.
3. While the design spec does not exist yet, you CAN:
   - Set up your development environment
   - Read early findings and design decisions from conversation.jsonl
   - Post technical questions to the Designer or Researcher
4. Check periodically if the design spec exists using bash:
   if [ -f "$WORK_DIR/handoffs/02-design-spec.md" ]; then echo "ready"; fi
   If not ready, read conversation.jsonl, then check again in 30 seconds.
   Repeat until the file appears.
5. Read the design spec (and research brief if available).
6. Build exactly what the spec describes.
7. Post progress updates to conversation.jsonl as you build (type: "status").
8. Write a build summary to: $WORK_DIR/handoffs/03-build-done.md
   Include: files created/modified, how to verify, test results, known limitations.
9. Post a final status: build complete.
10. Write 'done' to: $WORK_DIR/state/03-build

Security: validate inputs, no hardcoded secrets, use parameterized queries.
BLUEEOF

# Green Marketer (depends on Red-Orange)
MARKET_TASK=""
[[ -f "$WORK_DIR/tasks/04-market.md" ]] && MARKET_TASK=$(cat "$WORK_DIR/tasks/04-market.md")

cat > "$WORK_DIR/prompts/green.md" << GREENEOF
You are the Green Marketer agent of the Octopus team.

## Your Task
$MARKET_TASK

$CONVO_PROTOCOL

Replace YOUR_COLOR with "green" in all conversation messages.

## Dependencies
You need the Red-Orange Designer's spec for messaging and positioning.
The spec will appear at: $WORK_DIR/handoffs/02-design-spec.md
You benefit from the research brief at: $WORK_DIR/handoffs/01-research-brief.md

## Instructions
1. Post a status message: you are preparing while waiting for design spec.
2. Read conversation.jsonl for early findings and design decisions.
3. While the design spec does not exist yet, you CAN:
   - Research the target audience using web search
   - Read early findings from Yellow in conversation.jsonl
   - Post positioning questions to conversation.jsonl
4. Check periodically if the design spec exists using bash:
   if [ -f "$WORK_DIR/handoffs/02-design-spec.md" ]; then echo "ready"; fi
   If not ready, read conversation.jsonl, then check again in 30 seconds.
   Repeat until the file appears.
5. Read the design spec and research brief.
6. Create all marketing and distribution assets.
7. Post progress to conversation.jsonl.
8. Write your deliverables to: $WORK_DIR/handoffs/04-market-assets.md
   Include: audience definition, positioning, all copy/assets, channel strategy, metrics.
9. Post a final status: marketing complete.
10. Write 'done' to: $WORK_DIR/state/04-market
GREENEOF

# Purple Manager (monitors all, synthesizes at end)
cat > "$WORK_DIR/prompts/purple.md" << PURPLEEOF
You are the Purple Manager of the Octopus team. You are the orchestrator.

## Mission
$GOAL

All four specialist agents are running concurrently in separate terminals.
Your job is to monitor their conversation, coordinate, resolve blockers, and synthesize.

$CONVO_PROTOCOL

Replace YOUR_COLOR with "purple" in all conversation messages.

## Phase 1: Monitor and Coordinate
While agents are working:
1. Read $WORK_DIR/conversation.jsonl every 30-60 seconds.
2. When agents post questions, provide answers or route them to the right agent.
3. When agents post blockers, help resolve them.
4. Post decisions to conversation.jsonl (type: "decision") when choices need to be made.
5. Update $WORK_DIR/blackboard.md with key decisions and status changes.

## Phase 2: Wait for All Agents
Monitor these state files until all show 'done':
- $WORK_DIR/state/01-research (Yellow)
- $WORK_DIR/state/02-design (Red-Orange)
- $WORK_DIR/state/03-build (Blue)
- $WORK_DIR/state/04-market (Green)

Use bash to check:
while [ "\$(cat $WORK_DIR/state/01-research 2>/dev/null)" != "done" ] || \\
      [ "\$(cat $WORK_DIR/state/02-design 2>/dev/null)" != "done" ] || \\
      [ "\$(cat $WORK_DIR/state/03-build 2>/dev/null)" != "done" ] || \\
      [ "\$(cat $WORK_DIR/state/04-market 2>/dev/null)" != "done" ]; do
  sleep 15
done

Between checks, read conversation.jsonl and respond to any questions.

## Phase 3: Synthesize
Once all agents are done:
1. Read all handoff files:
   - $WORK_DIR/handoffs/01-research-brief.md (Yellow)
   - $WORK_DIR/handoffs/02-design-spec.md (Red-Orange)
   - $WORK_DIR/handoffs/03-build-done.md (Blue)
   - $WORK_DIR/handoffs/04-market-assets.md (Green)
2. Integrate Marketer's copy into Maker's build (edit files directly if needed).
3. Verify the output works (run it, check it, test it).
4. Write a synthesis report to: $WORK_DIR/handoffs/05-synthesis.md
   Include: what was accomplished, all artifacts (file paths), quality assessment,
   key decisions from the conversation, and remaining work.
5. Update $WORK_DIR/blackboard.md with final status.
6. Post a final message to conversation.jsonl: synthesis complete.
7. Write 'done' to: $WORK_DIR/state/pipeline
PURPLEEOF

# ── Create launcher scripts ──────────────────────────────────────────────────
create_launcher() {
  local agent="$1" color_code="$2" label="$3" state_file="$4"
  cat > "$WORK_DIR/launch/$agent.sh" << LAUNCHER
#!/bin/bash
printf '\e[${color_code}m[$label]\e[0m\n'
printf '\e[0;90mBlackboard:   $WORK_DIR/blackboard.md\e[0m\n'
printf '\e[0;90mConversation: $WORK_DIR/conversation.jsonl\e[0m\n\n'
claude --dangerously-skip-permissions --model $MODEL -p "\$(cat '$WORK_DIR/prompts/$agent.md')" 2>&1
echo 'done' > '$WORK_DIR/state/$state_file'
echo ""
printf '\e[${color_code}m[$label] Complete. Press enter to close.\e[0m\n'
read
LAUNCHER
  chmod +x "$WORK_DIR/launch/$agent.sh"
}

create_launcher "yellow"     "38;2;255;193;7"  "Yellow Researcher & Analyst" "01-research"
create_launcher "red-orange" "38;2;255;87;34"  "Red-Orange Designer"         "02-design"
create_launcher "blue"       "38;2;66;133;244" "Blue Maker"                  "03-build"
create_launcher "green"      "38;2;76;175;80"  "Green Marketer"              "04-market"
create_launcher "purple"     "38;2;156;39;176" "Purple Manager"              "pipeline"

# ── Spawn ALL agents concurrently ────────────────────────────────────────────
echo -e "${P}  Spawning all 5 agents concurrently...${RST}"
echo ""

tmux new-session -d -s "$SESSION" -n "researcher" "$WORK_DIR/launch/yellow.sh"
echo -e "  ${Y}[0] Yellow${RST}       Researcher & Analyst  ${D}(starts immediately)${RST}"

tmux new-window -t "$SESSION" -n "designer" "$WORK_DIR/launch/red-orange.sh"
echo -e "  ${R}[1] Red-Orange${RST}  Designer               ${D}(polls for research brief)${RST}"

tmux new-window -t "$SESSION" -n "maker" "$WORK_DIR/launch/blue.sh"
echo -e "  ${B}[2] Blue${RST}        Maker                  ${D}(polls for design spec)${RST}"

tmux new-window -t "$SESSION" -n "marketer" "$WORK_DIR/launch/green.sh"
echo -e "  ${G}[3] Green${RST}       Marketer               ${D}(polls for design spec)${RST}"

tmux new-window -t "$SESSION" -n "manager" "$WORK_DIR/launch/purple.sh"
echo -e "  ${P}[4] Purple${RST}      Manager                ${D}(monitoring + synthesis)${RST}"

echo ""
echo -e "${P}  All agents spawned. Collaborative mode active.${RST}"
echo -e "${D}  tmux session: $SESSION${RST}"
echo ""
post_msg "purple" "all" "status" "All 5 agents spawned. Collaborative mode active."

# ── Live conversation monitor ────────────────────────────────────────────────
echo -e "${W}  ── Live Conversation ──${RST}"
echo -e "${D}  Showing inter-agent messages. Ctrl+C to skip to tmux.${RST}"
echo ""

LAST_LINE_COUNT=0
SKIP_MONITOR=0
trap 'SKIP_MONITOR=1' INT

while [[ "$SKIP_MONITOR" -eq 0 ]]; do
  # Check if pipeline is done
  SP=$(cat "$WORK_DIR/state/pipeline" 2>/dev/null)
  if [[ "$SP" == "done" ]]; then
    break
  fi

  # Print new conversation messages
  CURRENT_LINES=$(wc -l < "$WORK_DIR/conversation.jsonl" 2>/dev/null | tr -d ' ')
  CURRENT_LINES=${CURRENT_LINES:-0}

  if [[ "$CURRENT_LINES" -gt "$LAST_LINE_COUNT" ]]; then
    tail -n +"$((LAST_LINE_COUNT + 1))" "$WORK_DIR/conversation.jsonl" | \
      head -n "$((CURRENT_LINES - LAST_LINE_COUNT))" | \
      while IFS= read -r line; do
        FROM=$(printf '%s' "$line" | sed -n 's/.*"from":"\([^"]*\)".*/\1/p')
        TYPE=$(printf '%s' "$line" | sed -n 's/.*"type":"\([^"]*\)".*/\1/p')
        BODY=$(printf '%s' "$line" | sed -n 's/.*"body":"\([^"]*\)".*/\1/p')

        case "$FROM" in
          yellow)     FC="${Y}" ;;
          red-orange) FC="${R}" ;;
          blue)       FC="${B}" ;;
          green)      FC="${G}" ;;
          purple)     FC="${P}" ;;
          *)          FC="${D}" ;;
        esac

        SHORT=$(printf '%.90s' "$BODY")
        echo -e "  ${FC}[$FROM]${RST} ${D}$TYPE${RST} $SHORT"
      done
    LAST_LINE_COUNT=$CURRENT_LINES
  fi

  sleep 5
done

trap - INT

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${P}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${P}  OCTOPUS TEAM: COMPLETE${RST}"
echo -e "${P}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo ""
echo -e "  ${W}Artifacts:${RST}"
for f in "$WORK_DIR"/handoffs/*.md; do
  [[ -f "$f" ]] && echo -e "    ${D}$f${RST}"
done
echo ""

MSG_COUNT=$(wc -l < "$WORK_DIR/conversation.jsonl" 2>/dev/null | tr -d ' ')
MSG_COUNT=${MSG_COUNT:-0}
echo -e "  ${W}Messages exchanged:${RST} $MSG_COUNT"
echo -e "  ${W}Conversation log:${RST}   $WORK_DIR/conversation.jsonl"
echo -e "  ${W}Blackboard:${RST}         $WORK_DIR/blackboard.md"
echo -e "  ${W}Synthesis:${RST}          $WORK_DIR/handoffs/05-synthesis.md"
echo ""
echo -e "  ${W}tmux session:${RST} $SESSION"
echo -e "  ${D}  Ctrl+B then 0-4 to switch agent windows${RST}"
echo -e "  ${D}  Ctrl+B then d to detach${RST}"
echo ""

# Attach to tmux for review
tmux select-window -t "$SESSION:manager"
tmux attach -t "$SESSION"
