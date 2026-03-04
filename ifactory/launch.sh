#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  OCTOPUS LAUNCH — Opens all 6 terminal windows and starts the iFactory pipeline
#  Run this once to start a new pipeline session.
# ═══════════════════════════════════════════════════════════════════════════════

BASE="${OCTOPUS_SPRINT_DIR:-~/octopus-collab}"

# Clean workspace for a fresh run (keep prompts, wipe outputs)
read -p "Reset workspace for a fresh run? (y/N) " RESET
if [[ "$RESET" == "y" || "$RESET" == "Y" ]]; then
  rm -f $BASE/logs/*.log
  rm -f $BASE/CHAT.md
  rm -rf $BASE/workspace/research/* $BASE/workspace/design/* \
         $BASE/workspace/build/* $BASE/workspace/marketing/* \
         $BASE/workspace/synthesis/*
  echo "Workspace reset."
fi

osascript << 'APPLESCRIPT'
tell application "Terminal"
    activate

    -- Window 1: PURPLE BRAIN — orchestrator (runs the full pipeline)
    do script "clear; printf '\\033]0;🟣 PURPLE — iFactory Brain\\007'; cd ~/octopus-collab && bash purple-brain.sh"
    set bounds of front window to {0, 0, 900, 700}

    delay 3  -- give purple-brain.sh time to create the log files

    -- Window 2: YELLOW — live research log (tail -F retries until file exists + follows)
    do script "clear; printf '\\033]0;🟡 YELLOW — Researcher\\007'; tail -F ~/octopus-collab/logs/yellow.log"
    set bounds of front window to {920, 0, 1820, 380}

    delay 0.3

    -- Window 3: RED — live design log
    do script "clear; printf '\\033]0;🔴 RED — Designer\\007'; tail -F ~/octopus-collab/logs/red.log"
    set bounds of front window to {920, 400, 1820, 780}

    delay 0.3

    -- Window 4: BLUE — live build log (activates Phase 2)
    do script "clear; printf '\\033]0;🔵 BLUE — Maker\\007'; tail -F ~/octopus-collab/logs/blue.log"
    set bounds of front window to {0, 720, 900, 1100}

    delay 0.3

    -- Window 5: GREEN — live marketing log (activates Phase 2)
    do script "clear; printf '\\033]0;🟢 GREEN — Marketer\\007'; tail -F ~/octopus-collab/logs/green.log"
    set bounds of front window to {920, 800, 1820, 1100}

    delay 0.3

    -- Window 6: CHAT MONITOR — live CHAT.md feed
    do script "clear; printf '\\033]0;💬 OCTOPUS TEAM CHAT\\007'; echo ''; echo '  ┌─────────────────────────────────────────────────────────┐'; echo '  │  OCTOPUS TEAM CHAT — LIVE                              │'; echo '  │  All agents post here as they work.                     │'; echo '  └─────────────────────────────────────────────────────────┘'; echo ''; tail -F ~/octopus-collab/CHAT.md"
    set bounds of front window to {0, 380, 900, 710}

end tell
APPLESCRIPT

echo "All 6 windows launched. Purple brain is running."
