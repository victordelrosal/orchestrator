#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  PURPLE BRAIN — iFactory Autonomous Orchestration Engine
#  Powered by Octopus | Five Innovators | Victor del Rosal
#
#  This script IS the Purple Manager agent. It runs the full venture pipeline:
#  Phase 1 (parallel): Yellow research + Red design
#  Phase 2 (parallel): Blue build + Green marketing (with Phase 1 context)
#  Phase 3: Purple synthesis + SHIP/KILL/PIVOT decision
#
#  Human role: ARCHITECT only. Watch. Do not intervene.
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# BASE: where logs and workspace live (defaults to ~/octopus-collab, override with env)
BASE="${OCTOPUS_SPRINT_DIR:-~/octopus-collab}"
LOGS=$BASE/logs
# PROMPTS: where agent prompt files live (co-located with this script in ifactory/prompts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPTS="$SCRIPT_DIR/prompts"

# Pre-create all log files with headers so agent windows can tail -F from the start
mkdir -p $LOGS
echo "[ YELLOW — Researcher & Analyst ] Waiting for agent to start..." > $LOGS/yellow.log
echo "[ RED — Designer ] Waiting for agent to start..." > $LOGS/red.log
echo "[ BLUE — Maker ] Waiting for Phase 2 to begin..." > $LOGS/blue.log
echo "[ GREEN — Marketer ] Waiting for Phase 2 to begin..." > $LOGS/green.log
echo "[ PURPLE SYNTHESIS ] Waiting for Phases 1 & 2 to complete..." > $LOGS/purple-synthesis.log

# Colors for Purple's status output
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

log_purple() {
  echo -e "${PURPLE}[PURPLE | $(date +%H:%M:%S)]${NC} $1"
  echo "[PURPLE | $(date +%H:%M)] $1" >> $BASE/CHAT.md
}

log_status() {
  echo -e "${WHITE}────────────────────────────────────────────${NC}"
  echo -e "${WHITE}$1${NC}"
  echo -e "${WHITE}────────────────────────────────────────────${NC}"
}

# ─── BANNER ──────────────────────────────────────────────────────────────────
clear
echo -e "${PURPLE}"
cat << 'BANNER'
  ██████  ██    ██ ██████  ██████  ██      ███████     ██████  ██████   █████  ██ ███    ██
  ██   ██ ██    ██ ██   ██ ██   ██ ██      ██          ██   ██ ██   ██ ██   ██ ██ ████   ██
  ██████  ██    ██ ██████  ██████  ██      █████       ██████  ██████  ███████ ██ ██ ██  ██
  ██      ██    ██ ██   ██ ██      ██      ██          ██   ██ ██   ██ ██   ██ ██ ██  ██ ██
  ██       ██████  ██   ██ ██      ███████ ███████     ██████  ██   ██ ██   ██ ██ ██   ████
BANNER
echo -e "${NC}"
echo -e "${WHITE}  iFactory Autonomous Venture Pipeline${NC}"
echo -e "${WHITE}  Powered by Octopus | Five Innovators | © Victor del Rosal 2026${NC}"
echo ""
echo -e "${WHITE}  Problem: Solo Founder Admin Swamp${NC}"
echo -e "${WHITE}  Mission: Research → Design → Build → Market → SHIP/KILL/PIVOT${NC}"
echo ""

# ─── PREFLIGHT ───────────────────────────────────────────────────────────────
log_status "PREFLIGHT CHECK"
echo "Checking Claude CLI..."
if ! command -v claude &> /dev/null; then
  echo "ERROR: claude CLI not found. Install Claude Code first."
  exit 1
fi
echo "Claude CLI: OK"

echo "Checking log directory..."
mkdir -p $LOGS
echo "Logs directory: OK"

echo "Checking prompt files..."
for f in yellow-research red-design blue-build green-market purple-synthesis; do
  if [ ! -f "$PROMPTS/$f.md" ]; then
    echo "ERROR: Missing prompt file: $PROMPTS/$f.md"
    exit 1
  fi
done
echo "All 5 prompt files: OK"
echo ""

# Reset CHAT.md with fresh header
cat > $BASE/CHAT.md << 'CHAT_HEADER'
# OCTOPUS TEAM CHAT
# iFactory Pipeline — Solo Founder Admin Swamp
# Real-time coordination channel
# ─────────────────────────────────────────────────────────────────────────────

CHAT_HEADER

log_purple "iFactory pipeline initialized. Starting autonomous venture creation. Human: stand by and observe."

# ─── PHASE 1: PARALLEL — YELLOW + RED ────────────────────────────────────────
log_status "PHASE 1: SPAWNING YELLOW (Researcher) + RED (Designer) IN PARALLEL"

log_purple "Spawning YELLOW Researcher. Mission: validate pain, size market, map competitors."
echo -e "${YELLOW}  → Yellow process starting... watch logs/yellow.log${NC}"

claude -p "$(cat $PROMPTS/yellow-research.md)" \
  --permission-mode bypassPermissions \
  --allowedTools "Bash,Read,Write,Glob,Grep,WebSearch" \
  --model sonnet \
  2>&1 | tee $LOGS/yellow.log &
YELLOW_PID=$!

sleep 2  # stagger launch slightly

log_purple "Spawning RED Designer. Mission: design core loop, UX flow, build spec for BLUE."
echo -e "${RED}  → Red process starting... watch logs/red.log${NC}"

claude -p "$(cat $PROMPTS/red-design.md)" \
  --permission-mode bypassPermissions \
  --allowedTools "Bash,Read,Write,Glob,Grep" \
  --model sonnet \
  2>&1 | tee $LOGS/red.log &
RED_PID=$!

echo ""
log_status "Phase 1 running in parallel. Yellow PID: $YELLOW_PID | Red PID: $RED_PID"
echo "Watching agent windows for live output..."
echo ""

# ─── WAIT FOR PHASE 1 ────────────────────────────────────────────────────────
wait $YELLOW_PID
YELLOW_EXIT=$?
echo -e "${YELLOW}  ✓ Yellow complete (exit: $YELLOW_EXIT)${NC}"

wait $RED_PID
RED_EXIT=$?
echo -e "${RED}  ✓ Red complete (exit: $RED_EXIT)${NC}"

echo ""
log_status "PHASE 1 COMPLETE"
log_purple "Yellow and Red finished. Reading their outputs before spawning Blue + Green."

# Check what Yellow and Red produced
echo "Yellow research files:"
ls $BASE/workspace/research/ 2>/dev/null | sed 's/^/  /'
echo "Red design files:"
ls $BASE/workspace/design/ 2>/dev/null | sed 's/^/  /'
echo ""

# ─── PHASE 2: PARALLEL — BLUE + GREEN ────────────────────────────────────────
log_status "PHASE 2: SPAWNING BLUE (Maker) + GREEN (Marketer) IN PARALLEL"

log_purple "Spawning BLUE Maker. Mission: build Weekly Dispatch MVP. Using RED's spec + YELLOW's research."
echo -e "${BLUE}  → Blue process starting... watch logs/blue.log${NC}"

claude -p "$(cat $PROMPTS/blue-build.md)" \
  --permission-mode bypassPermissions \
  --allowedTools "Bash,Read,Write,Glob,Grep" \
  --model sonnet \
  2>&1 | tee $LOGS/blue.log &
BLUE_PID=$!

sleep 2

log_purple "Spawning GREEN Marketer. Mission: positioning, launch copy, 30-day plan. Running parallel with Blue."
echo -e "${GREEN}  → Green process starting... watch logs/green.log${NC}"

claude -p "$(cat $PROMPTS/green-market.md)" \
  --permission-mode bypassPermissions \
  --allowedTools "Bash,Read,Write,Glob,Grep,WebSearch" \
  --model sonnet \
  2>&1 | tee $LOGS/green.log &
GREEN_PID=$!

echo ""
log_status "Phase 2 running in parallel. Blue PID: $BLUE_PID | Green PID: $GREEN_PID"
echo ""

# ─── WAIT FOR PHASE 2 ────────────────────────────────────────────────────────
wait $BLUE_PID
BLUE_EXIT=$?
echo -e "${BLUE}  ✓ Blue complete (exit: $BLUE_EXIT)${NC}"

wait $GREEN_PID
GREEN_EXIT=$?
echo -e "${GREEN}  ✓ Green complete (exit: $GREEN_EXIT)${NC}"

echo ""
log_status "PHASE 2 COMPLETE"
log_purple "Blue and Green finished. Moving to final synthesis."

echo "Blue build files:"
ls $BASE/workspace/build/ 2>/dev/null | sed 's/^/  /'
echo "Green marketing files:"
ls $BASE/workspace/marketing/ 2>/dev/null | sed 's/^/  /'
echo ""

# ─── PHASE 3: PURPLE SYNTHESIS ───────────────────────────────────────────────
log_status "PHASE 3: PURPLE SYNTHESIS — QUALITY GATES + SHIP/KILL/PIVOT"

log_purple "Running synthesis. Applying VdROS governance. Will deliver SHIP/KILL/PIVOT decision."
echo -e "${PURPLE}  → Purple synthesis starting... watch logs/purple-synthesis.log${NC}"
echo ""

claude -p "$(cat $PROMPTS/purple-synthesis.md)" \
  --permission-mode bypassPermissions \
  --allowedTools "Bash,Read,Write,Glob,Grep" \
  --model opus \
  2>&1 | tee $LOGS/purple-synthesis.log

PURPLE_EXIT=$?

# ─── PIPELINE COMPLETE ───────────────────────────────────────────────────────
echo ""
echo -e "${PURPLE}"
cat << 'DONE_BANNER'
  ██████  ██ ██████  ███████ ██      ██ ███    ██ ███████     ██████  ██████  ███    ███ ██████  ██      ███████ ████████ ███████
  ██   ██ ██ ██   ██ ██      ██      ██ ████   ██ ██         ██      ██    ██ ████  ████ ██   ██ ██      ██         ██    ██
  ██████  ██ ██████  █████   ██      ██ ██ ██  ██ █████      ██      ██    ██ ██ ████ ██ ██████  ██      █████      ██    █████
  ██      ██ ██      ██      ██      ██ ██  ██ ██ ██         ██      ██    ██ ██  ██  ██ ██      ██      ██         ██    ██
  ██      ██ ██      ███████ ███████ ██ ██   ████ ███████     ██████  ██████  ██      ██ ██      ███████ ███████    ██    ███████
DONE_BANNER
echo -e "${NC}"
echo ""
log_status "FULL PIPELINE COMPLETE"
echo ""
echo -e "  Research:   ${YELLOW}workspace/research/${NC}"
echo -e "  Design:     ${RED}workspace/design/${NC}"
echo -e "  Build:      ${BLUE}workspace/build/${NC}"
echo -e "  Marketing:  ${GREEN}workspace/marketing/${NC}"
echo -e "  Synthesis:  ${PURPLE}workspace/synthesis/${NC}"
echo ""
echo -e "  Final decision: ${WHITE}cat ~/octopus-collab/workspace/synthesis/04-ship-recommendation.md${NC}"
echo ""

# Print the final decision prominently
if [ -f "$BASE/workspace/synthesis/04-ship-recommendation.md" ]; then
  echo -e "${WHITE}════════════════════ FINAL DECISION ════════════════════${NC}"
  cat "$BASE/workspace/synthesis/04-ship-recommendation.md"
  echo -e "${WHITE}═════════════════════════════════════════════════════════${NC}"
fi

echo ""
echo -e "${PURPLE}iFactory pipeline complete. Victor: the factory has run.${NC}"
