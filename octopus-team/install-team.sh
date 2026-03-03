#!/bin/bash
# Octopus Team Installer
# Adds the `octopus-team` terminal command for multi-terminal agent orchestration.
# Requires: tmux, claude CLI, and vanilla octopus already installed.
# Safe: idempotent, append-only, never touches existing config.

set -e

# Colors
PURPLE='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RED='\033[1;31m'
DIM='\033[0;90m'
RESET='\033[0m'

echo ""
echo -e "${PURPLE}  Octopus Team Installer${RESET}"
echo -e "${PURPLE}  ██ TEAM MODE ██  Multi-terminal agent orchestration${RESET}"
echo ""

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Prerequisite checks ──
echo -e "${BLUE}  [1/4]${RESET} Checking prerequisites"

# Check tmux
if ! command -v tmux &> /dev/null; then
  echo -e "${RED}  Error: tmux is required but not installed.${RESET}"
  echo -e "${DIM}        macOS: brew install tmux${RESET}"
  echo -e "${DIM}        Linux: sudo apt install tmux${RESET}"
  exit 1
fi
echo -e "${DIM}        tmux: $(tmux -V)${RESET}"

# Check claude
if ! command -v claude &> /dev/null; then
  echo -e "${RED}  Error: claude CLI is required but not installed.${RESET}"
  echo -e "${DIM}        Install: https://docs.anthropic.com/en/docs/claude-code${RESET}"
  exit 1
fi
echo -e "${DIM}        claude: found${RESET}"

# ── Copy files ──
echo -e "${BLUE}  [2/4]${RESET} Copying files to ~/.claude/"
mkdir -p ~/.claude/octopus-team

cp "$SCRIPT_DIR/orchestrate.sh" ~/.claude/octopus-team/orchestrate.sh
chmod +x ~/.claude/octopus-team/orchestrate.sh
echo -e "${DIM}        ~/.claude/octopus-team/orchestrate.sh${RESET}"

cp "$SCRIPT_DIR/octopus-team-banner.sh" ~/.claude/octopus-team/octopus-team-banner.sh
chmod +x ~/.claude/octopus-team/octopus-team-banner.sh
echo -e "${DIM}        ~/.claude/octopus-team/octopus-team-banner.sh${RESET}"

# ── Append shell function ──
echo -e "${BLUE}  [3/4]${RESET} Adding octopus-team() to ~/.zshrc"

MARKER="# >>> octopus-team-cli >>>"
if grep -qF "$MARKER" ~/.zshrc 2>/dev/null; then
  echo -e "${YELLOW}        Already present in ~/.zshrc (skipping)${RESET}"
  echo -e "${DIM}        To update, remove the octopus-team block from ~/.zshrc and re-run.${RESET}"
else
  cat >> ~/.zshrc << 'ZSHRC_BLOCK'

# >>> octopus-team-cli >>>
# Octopus Team - Multi-terminal agent orchestration
# https://github.com/victordelrosal/octopus
octopus-team() {
  # Show banner
  ~/.claude/octopus-team/octopus-team-banner.sh

  # Model selection
  local model_name=""
  if [[ "$1" == "--sonnet" ]]; then
    shift
    model_name="sonnet"
    echo -e "\033[1;36m  Sonnet selected\033[0m"
  elif [[ "$1" == "--opus" ]]; then
    shift
    model_name="opus"
    echo -e "\033[1;35m  Opus selected\033[0m"
  elif [[ "$1" == "--haiku" ]]; then
    shift
    model_name="haiku"
    echo -e "\033[1;33m  Haiku selected\033[0m"
  else
    # Interactive model selection
    echo ""
    echo -e "\033[1;33m  Which model for all agents?\033[0m"
    echo -e "    \033[1;35m[1]\033[0m Opus    (full power, recommended)"
    echo -e "    \033[1;36m[2]\033[0m Sonnet  (balanced)"
    echo -e "    \033[1;33m[3]\033[0m Haiku   (fast + cheap)"
    echo ""
    read -k 1 "model_choice?  > "
    echo ""
    if [[ "$model_choice" == "2" || "$model_choice" == "s" || "$model_choice" == "S" ]]; then
      model_name="sonnet"
      echo -e "\033[1;36m  Sonnet selected for all agents\033[0m"
    elif [[ "$model_choice" == "3" || "$model_choice" == "h" || "$model_choice" == "H" ]]; then
      model_name="haiku"
      echo -e "\033[1;33m  Haiku selected for all agents\033[0m"
    else
      model_name="opus"
      echo -e "\033[1;35m  Opus selected for all agents\033[0m"
    fi
    echo ""
  fi

  # Get goal from args or prompt
  local goal="$*"
  if [[ -z "$goal" ]]; then
    echo -e "\033[1;33m  What's the goal?\033[0m"
    echo -e "\033[0;90m  (describe what you want the 5-agent team to build)\033[0m"
    echo ""
    read "goal?  > "
    echo ""
  fi

  if [[ -z "$goal" ]]; then
    echo -e "\033[1;31m  No goal provided. Aborting.\033[0m"
    return 1
  fi

  # Launch orchestrator
  bash ~/.claude/octopus-team/orchestrate.sh "$model_name" "$goal"
}
# <<< octopus-team-cli <<<
ZSHRC_BLOCK
  echo -e "${GREEN}        Added to ~/.zshrc${RESET}"
fi

# ── Done ──
echo -e "${BLUE}  [4/4]${RESET} Verifying installation"
echo ""
echo -e "${GREEN}  Done! Octopus Team is installed.${RESET}"
echo ""
echo -e "  ${YELLOW}Next steps:${RESET}"
echo -e "    1. Run: ${PURPLE}source ~/.zshrc${RESET}"
echo -e "    2. Type: ${PURPLE}octopus-team${RESET} from any project directory"
echo ""
echo -e "  ${YELLOW}Usage:${RESET}"
echo -e "    ${DIM}octopus-team${RESET}                          Interactive mode"
echo -e "    ${DIM}octopus-team build a portfolio site${RESET}   Direct goal"
echo -e "    ${DIM}octopus-team --sonnet fix the login${RESET}   With model flag"
echo ""
echo -e "  ${YELLOW}What happens:${RESET}"
echo -e "    1. Purple Manager decomposes your goal into 4 agent tasks"
echo -e "    2. Yellow Researcher runs first (others need its output)"
echo -e "    3. Red-Orange Designer runs next (needs research brief)"
echo -e "    4. Blue Maker + Green Marketer run ${GREEN}in parallel${RESET}"
echo -e "    5. Purple Manager synthesizes all outputs"
echo -e "    6. Each agent runs in its own tmux window"
echo ""
echo -e "  ${YELLOW}During a run:${RESET}"
echo -e "    ${DIM}tmux list-windows${RESET}             See all agent windows"
echo -e "    ${DIM}Ctrl+B then 0-4${RESET}               Switch between agent windows"
echo -e "    ${DIM}.octopus/handoffs/${RESET}             All agent outputs"
echo ""
echo -e "  ${YELLOW}Uninstall:${RESET}"
echo -e "    1. Remove the ${DIM}# >>> octopus-team-cli >>>${RESET} block from ~/.zshrc"
echo -e "    2. Delete: ${DIM}rm -rf ~/.claude/octopus-team${RESET}"
echo ""
