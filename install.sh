#!/usr/bin/env bash

# Performance Skills Installer Script
# Works with Gemini, OpenCode, Claude Code, and Local project custom agents directories

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${CYAN}${BOLD}     Performance Optimization & Auditor Skills      ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""

# Setup temp directory cleanup
TEMP_DIR=""
cleanup() {
  if [ -n "${TEMP_DIR:-}" ] && [ -d "${TEMP_DIR}" ]; then
    rm -rf "${TEMP_DIR}"
  fi
}
trap cleanup EXIT

# Detect if running via curl/pipe (meaning no local script file)
RUNNING_VIA_CURL=0
if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "/dev/stdin" ] || [ "${BASH_SOURCE[0]}" = "-" ]; then
  RUNNING_VIA_CURL=1
fi

if [ "${RUNNING_VIA_CURL}" -eq 1 ]; then
  echo -e "Running remote installer. Downloading latest skills..."
  TEMP_DIR="$(mktemp -d)"
  if git clone --depth 1 https://github.com/hluaguo/perf-pipeline-skill.git "${TEMP_DIR}" > /dev/null 2>&1; then
    REPO_SKILLS_DIR="${TEMP_DIR}/skills"
  elif curl -sSL https://github.com/hluaguo/perf-pipeline-skill/archive/refs/heads/main.tar.gz -o "${TEMP_DIR}/archive.tar.gz" > /dev/null 2>&1; then
    tar -xzf "${TEMP_DIR}/archive.tar.gz" -C "${TEMP_DIR}"
    REPO_SKILLS_DIR="${TEMP_DIR}/perf-pipeline-skill-main/skills"
  else
    echo -e "${RED}Error: Failed to download repository from GitHub via git or curl.${NC}"
    exit 1
  fi
else
  # Running locally
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_SKILLS_DIR="${SCRIPT_DIR}/skills"
fi

# Check if skills directory exists
if [ ! -d "${REPO_SKILLS_DIR}" ]; then
  echo -e "${RED}Error: Cannot find 'skills' folder at ${REPO_SKILLS_DIR}.${NC}"
  echo -e "Make sure you are running this installer inside the cloned repository or have an active internet connection."
  exit 1
fi

# Function to install skills to a specific target
install_to_path() {
  local target_root="$1"
  local agent_name="$2"
  
  local pipeline_target="${target_root}/perf-pipeline"
  local review_target="${target_root}/perf-review"
  
  echo -e "Installing to ${BOLD}${agent_name}${NC} at ${YELLOW}${target_root}${NC}..."
  
  # Create targets (clean up existing ones to avoid stale files)
  rm -rf "${pipeline_target}" "${review_target}"
  mkdir -p "${pipeline_target}" "${review_target}"
  
  # Copy files
  cp -R "${REPO_SKILLS_DIR}/perf-pipeline/"* "${pipeline_target}/"
  cp -R "${REPO_SKILLS_DIR}/perf-review/"* "${review_target}/"
  
  echo -e "${GREEN}✓ Successfully installed perf-pipeline and perf-review skills to ${agent_name}.${NC}"
}

# Determine default installation targets
INSTALL_PROJECT=0
INSTALL_CUSTOM=0
CUSTOM_PATH=""
MODE="interactive"
INSTALL_GLOBAL_ALL=0

# Active targets
declare -a TARGET_PATHS=()
declare -a TARGET_NAMES=()

# Global target config detection
declare -a DETECTED_PATHS=()
declare -a DETECTED_NAMES=()

if [ -d "${HOME}/.gemini" ]; then
  DETECTED_PATHS+=("${HOME}/.gemini/config/skills")
  DETECTED_NAMES+=("Gemini")
fi
if [ -d "${HOME}/.claude" ]; then
  DETECTED_PATHS+=("${HOME}/.claude/skills")
  DETECTED_NAMES+=("Claude Code")
fi
if [ -d "${HOME}/.config/opencode" ]; then
  DETECTED_PATHS+=("${HOME}/.config/opencode/skills")
  DETECTED_NAMES+=("OpenCode")
fi

# Determine project targets
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel)"
  PROJECT_TYPE="Git Project"
else
  PROJECT_ROOT="$(pwd)"
  PROJECT_TYPE="Current Directory"
fi
PROJECT_SKILLS_DIR="${PROJECT_ROOT}/.agents/skills"

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: install.sh [options]"
      echo ""
      echo "Options:"
      echo "  -g, --global     Install to all detected global agent environments (Gemini, Claude, OpenCode)"
      echo "  --gemini         Install globally to Gemini only"
      echo "  --claude         Install globally to Claude Code only"
      echo "  --opencode       Install globally to OpenCode only"
      echo "  -p, --project    Install to the current project's local agent environment (.agents/skills)"
      echo "  -a, --all        Install to both all detected global and project directories"
      echo "  -d, --path PATH  Install to a custom path"
      echo "  -h, --help       Show this help message"
      exit 0
      ;;
    -g|--global)
      MODE="non-interactive"
      INSTALL_GLOBAL_ALL=1
      shift
      ;;
    --gemini)
      MODE="non-interactive"
      TARGET_PATHS+=("${HOME}/.gemini/config/skills")
      TARGET_NAMES+=("Gemini")
      shift
      ;;
    --claude)
      MODE="non-interactive"
      TARGET_PATHS+=("${HOME}/.claude/skills")
      TARGET_NAMES+=("Claude Code")
      shift
      ;;
    --opencode)
      MODE="non-interactive"
      TARGET_PATHS+=("${HOME}/.config/opencode/skills")
      TARGET_NAMES+=("OpenCode")
      shift
      ;;
    -p|--project)
      MODE="non-interactive"
      INSTALL_PROJECT=1
      shift
      ;;
    -a|--all)
      MODE="non-interactive"
      INSTALL_GLOBAL_ALL=1
      INSTALL_PROJECT=1
      shift
      ;;
    -d|--path)
      MODE="non-interactive"
      INSTALL_CUSTOM=1
      if [ -n "${2:-}" ]; then
        CUSTOM_PATH="$2"
        shift 2
      else
        echo -e "${RED}Error: --path requires an argument.${NC}"
        exit 1
      fi
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Run with --help to see usage details."
      exit 1
      ;;
  esac
done

# If global all was requested or if we should default to all detected paths in non-interactive mode
if [ "${INSTALL_GLOBAL_ALL}" -eq 1 ] || { [ "${MODE}" = "non-interactive" ] && [ "${INSTALL_PROJECT}" -eq 0 ] && [ "${INSTALL_CUSTOM}" -eq 0 ] && [ ${#TARGET_PATHS[@]} -eq 0 ]; }; then
  if [ ${#DETECTED_PATHS[@]} -gt 0 ]; then
    for i in "${!DETECTED_PATHS[@]}"; do
      TARGET_PATHS+=("${DETECTED_PATHS[$i]}")
      TARGET_NAMES+=("${DETECTED_NAMES[$i]}")
    done
  else
    # Fallback to default Gemini config if no folders found
    TARGET_PATHS+=("${HOME}/.gemini/config/skills")
    TARGET_NAMES+=("Gemini")
  fi
fi

# If no flags are passed, check if we can run interactively
INTERACTIVE=0
TTY_DEVICE=""
if [ "${MODE}" = "interactive" ]; then
  if [ -t 0 ]; then
    INTERACTIVE=1
    TTY_DEVICE="/dev/stdin"
  elif [ -c /dev/tty ]; then
    INTERACTIVE=1
    TTY_DEVICE="/dev/tty"
  fi
fi

if [ "${INTERACTIVE}" -eq 1 ]; then
  echo -e "Choose installation target:"
  
  # Print detected global agents
  local idx=1
  declare -a MENU_KEYS=()
  declare -a MENU_ACTIONS=()
  declare -a MENU_VALS=()
  
  if [ ${#DETECTED_PATHS[@]} -gt 0 ]; then
    for i in "${!DETECTED_PATHS[@]}"; do
      echo -e "  [${idx}] Global - ${BOLD}${DETECTED_NAMES[$i]}${NC} (${YELLOW}${DETECTED_PATHS[$i]}${NC})"
      MENU_KEYS+=("${idx}")
      MENU_ACTIONS+=("single-global")
      MENU_VALS+=("${i}")
      idx=$((idx + 1))
    done
    
    # If there is more than 1 global agent, offer "All Global"
    if [ ${#DETECTED_PATHS[@]} -gt 1 ]; then
      echo -e "  [${idx}] Global - ${BOLD}All Detected Agents${NC}"
      MENU_KEYS+=("${idx}")
      MENU_ACTIONS+=("all-global")
      MENU_VALS+=("")
      idx=$((idx + 1))
    fi
  else
    # Offer default Gemini global
    echo -e "  [${idx}] Global - ${BOLD}Gemini${NC} (Create default at ${YELLOW}${HOME}/.gemini/config/skills${NC})"
    MENU_KEYS+=("${idx}")
    MENU_ACTIONS+=("default-gemini")
    MENU_VALS+=("")
    idx=$((idx + 1))
  fi
  
  # Project-local option
  echo -e "  [${idx}] Project-local - ${BOLD}${PROJECT_TYPE}${NC} (${YELLOW}${PROJECT_SKILLS_DIR}${NC})"
  MENU_KEYS+=("${idx}")
  MENU_ACTIONS+=("project")
  MENU_VALS+=("")
  idx=$((idx + 1))
  
  # Both option
  echo -e "  [${idx}] Both - ${BOLD}All Global + Project-local${NC}"
  MENU_KEYS+=("${idx}")
  MENU_ACTIONS+=("both")
  MENU_VALS+=("")
  idx=$((idx + 1))
  
  # Custom option
  echo -e "  [${idx}] Custom Path"
  MENU_KEYS+=("${idx}")
  MENU_ACTIONS+=("custom")
  MENU_VALS+=("")
  idx=$((idx + 1))
  
  # Cancel option
  echo -e "  [${idx}] Cancel"
  MENU_KEYS+=("${idx}")
  MENU_ACTIONS+=("cancel")
  MENU_VALS+=("")
  
  echo ""
  
  local choice=""
  while true; do
    echo -n "Select option [1-${idx}]: "
    read -r choice < "${TTY_DEVICE}"
    
    # Find matching menu item
    local found=0
    local action=""
    local val=""
    for i in "${!MENU_KEYS[@]}"; do
      if [ "${choice}" = "${MENU_KEYS[$i]}" ]; then
        found=1
        action="${MENU_ACTIONS[$i]}"
        val="${MENU_VALS[$i]}"
        break
      fi
    done
    
    if [ "${found}" -eq 1 ]; then
      case "${action}" in
        single-global)
          TARGET_PATHS+=("${DETECTED_PATHS[$val]}")
          TARGET_NAMES+=("${DETECTED_NAMES[$val]}")
          break
          ;;
        all-global)
          for i in "${!DETECTED_PATHS[@]}"; do
            TARGET_PATHS+=("${DETECTED_PATHS[$i]}")
            TARGET_NAMES+=("${DETECTED_NAMES[$i]}")
          done
          break
          ;;
        default-gemini)
          TARGET_PATHS+=("${HOME}/.gemini/config/skills")
          TARGET_NAMES+=("Gemini")
          break
          ;;
        project)
          INSTALL_PROJECT=1
          break
          ;;
        both)
          # Add all global
          if [ ${#DETECTED_PATHS[@]} -gt 0 ]; then
            for i in "${!DETECTED_PATHS[@]}"; do
              TARGET_PATHS+=("${DETECTED_PATHS[$i]}")
              TARGET_NAMES+=("${DETECTED_NAMES[$i]}")
            done
          else
            TARGET_PATHS+=("${HOME}/.gemini/config/skills")
            TARGET_NAMES+=("Gemini")
          fi
          INSTALL_PROJECT=1
          break
          ;;
        custom)
          INSTALL_CUSTOM=1
          break
          ;;
        cancel)
          echo -e "${YELLOW}Installation cancelled.${NC}"
          exit 0
          ;;
      case_end_dummy)
          # Fallback placeholder to maintain syntax safety
          ;;
      esac
    else
      echo -e "${RED}Invalid selection. Please choose 1-${idx}.${NC}"
    fi
  done
else
  # Non-interactive fallback when no arguments are provided
  if [ ${#TARGET_PATHS[@]} -eq 0 ] && [ "${INSTALL_PROJECT}" -eq 0 ] && [ "${INSTALL_CUSTOM}" -eq 0 ]; then
    echo -e "${YELLOW}No CLI arguments passed and non-interactive environment detected.${NC}"
    echo -e "Installing to both Global (All detected) and Project-local by default."
    
    # Add all global
    if [ ${#DETECTED_PATHS[@]} -gt 0 ]; then
      for i in "${!DETECTED_PATHS[@]}"; do
        TARGET_PATHS+=("${DETECTED_PATHS[$i]}")
        TARGET_NAMES+=("${DETECTED_NAMES[$i]}")
      done
    else
      TARGET_PATHS+=("${HOME}/.gemini/config/skills")
      TARGET_NAMES+=("Gemini")
    fi
    INSTALL_PROJECT=1
  fi
fi

# Request custom path if interactive choice was selected
if [ "${INSTALL_CUSTOM}" -eq 1 ] && [ -z "${CUSTOM_PATH}" ]; then
  if [ "${INTERACTIVE}" -eq 1 ]; then
    echo -n "Enter custom installation path: "
    read -r CUSTOM_PATH < "${TTY_DEVICE}"
  fi
  if [ -z "${CUSTOM_PATH}" ]; then
    echo -e "${RED}Error: Custom path cannot be empty.${NC}"
    exit 1
  fi
fi

# Run the installation
INSTALLED=0

# Install global if selected
if [ ${#TARGET_PATHS[@]} -gt 0 ]; then
  for i in "${!TARGET_PATHS[@]}"; do
    install_to_path "${TARGET_PATHS[$i]}" "${TARGET_NAMES[$i]}"
    INSTALLED=1
  done
fi

# Install project-local if selected
if [ "${INSTALL_PROJECT}" -eq 1 ]; then
  install_to_path "${PROJECT_SKILLS_DIR}" "Local Project (${PROJECT_TYPE})"
  INSTALLED=1
fi

# Install custom path if selected
if [ "${INSTALL_CUSTOM}" -eq 1 ] && [ -n "${CUSTOM_PATH}" ]; then
  # Make path absolute if it starts with tilde or is relative
  if [[ "${CUSTOM_PATH}" == ~* ]]; then
    CUSTOM_PATH="${CUSTOM_PATH/#\~/$HOME}"
  fi
  install_to_path "${CUSTOM_PATH}" "Custom Path"
  INSTALLED=1
fi

if [ "${INSTALLED}" -eq 1 ]; then
  echo ""
  echo -e "${BLUE}${BOLD}====================================================${NC}"
  echo -e "${GREEN}${BOLD}             Installation Completed!                ${NC}"
  echo -e "${BLUE}${BOLD}====================================================${NC}"
  echo -e "You can now use the following trigger words in your chat agent:"
  echo -e "  - ${CYAN}perf-pipeline:${NC} \"optimize performance\", \"profile the codebase\", \"find bottlenecks\""
  echo -e "  - ${CYAN}perf-review:${NC} \"review performance PR\", \"audit optimization branch\", \"validate merge safety\""
  echo -e "${BLUE}${BOLD}====================================================${NC}"
else
  echo -e "${RED}Installation failed or cancelled.${NC}"
  exit 1
fi
