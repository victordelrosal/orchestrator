#!/bin/bash
# Octopus Team ASCII Banner - 5-color display for multi-terminal mode

# Yellow (Researcher)
printf '\e[38;2;255;193;7m'
printf ' ████   ████  ██████  ████  █████  ██  ██ ██████\n'

# Red-Orange (Designer)
printf '\e[38;2;255;87;34m'
printf '██  ██ ██       ██   ██  ██ ██  ██ ██  ██ ██\n'

# Blue (Maker)
printf '\e[38;2;66;133;244m'
printf '██  ██ ██       ██   ██  ██ █████  ██  ██ ██████\n'

# Green (Marketer)
printf '\e[38;2;76;175;80m'
printf '██  ██ ██       ██   ██  ██ ██     ██  ██     ██\n'

# Purple (Manager)
printf '\e[38;2;156;39;176m'
printf ' ████   ████    ██    ████  ██      ████  ██████\n'

# Team mode label
printf '\e[38;2;156;39;176m'
printf '\n Multi-Agent Orchestration OS\n'
printf '\e[1;35m ██ TEAM MODE ██\e[0m  Collaborative. Concurrent. Conversational.\n'

# Reset
printf '\e[0m\n'
