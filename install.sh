#!/usr/bin/env bash

# Performance Skills Installer Script
# Works with OpenCode, Claude Code, and Local project custom agents directories

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
  if [ -n "${TEMP_DIR}" ] && [ -d "${TEMP_DIR}" ]; then
    rm -rf "${TEMP_DIR}"
  fi
}
trap cleanup EXIT

# Detect if running via curl/pipe (meaning no local script file)
RUNNING_VIA_CURL=0
if [ -z "${BASH_SOURCE[0]:-}" ]; then
  RUNNING_VIA_CURL=1
fi

if [ "${RUNNING_VIA_CURL}" -eq 1 ]; then
  echo -e "Running remote installer. Downloading latest skills from GitHub..."
  TEMP_DIR="$(mktemp -d)"
  if ! git clone --depth 1 https://github.com/hluaguo/perf-pipeline-skill.git "${TEMP_DIR}" > /dev/null 2>&1; then
    echo -e "${RED}Error: Failed to download repository from GitHub. Make sure you have git installed.${NC}"
    exit 1
  fi
  REPO_SKILLS_DIR="${TEMP_DIR}/skills"
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
  
  # Create targets
  mkdir -p "${pipeline_target}" "${review_target}"
  
  # Copy files
  cp -R "${REPO_SKILLS_DIR}/perf-pipeline/"* "${pipeline_target}/"
  cp -R "${REPO_SKILLS_DIR}/perf-review/"* "${review_target}/"
  
  echo -e "${GREEN}✓ Successfully installed perf-pipeline and perf-review skills to ${agent_name}.${NC}"
}

# Determine installation options
INSTALLED=0

# Option 1: OpenCode / Gemini Global Config
OPENCODE_DIR="${HOME}/.config/opencode/skills"
GEMINI_DIR="${HOME}/.gemini/config/skills"

# Check and install to OpenCode / Gemini
if [ -d "${HOME}/.config/opencode" ] || [ -d "${HOME}/.gemini" ]; then
  if [ -d "${HOME}/.config/opencode" ]; then
    install_to_path "${OPENCODE_DIR}" "OpenCode Global Customizations"
    INSTALLED=1
  fi
  if [ -d "${HOME}/.gemini" ]; then
    install_to_path "${GEMINI_DIR}" "Gemini Global Customizations"
    INSTALLED=1
  fi
fi

# Option 2: Claude Code Global Customizations
CLAUDE_DIR="${HOME}/.claude/skills"
if [ -d "${HOME}/.claude" ]; then
  install_to_path "${CLAUDE_DIR}" "Claude Code"
  INSTALLED=1
fi

# Option 3: Local git workspace project customizations
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_ROOT="$(git rev-parse --show-toplevel)"
  LOCAL_AGENTS_DIR="${GIT_ROOT}/.agents/skills"
  
  echo ""
  read -p "Would you like to install these skills locally inside this Git project? (y/n): " -n 1 -r
  echo ""
  if [[ ${REPLY:-} =~ ^[Yy]$ ]]; then
    install_to_path "${LOCAL_AGENTS_DIR}" "Local Project (.agents)"
    INSTALLED=1
  fi
fi

if [ "${INSTALLED}" -eq 0 ]; then
  echo -e "${YELLOW}Warning: No global agent configurations (OpenCode, Claude, Gemini) were detected.${NC}"
  echo -e "Please run this script inside a Git project to install locally, or specify a custom folder below."
  echo ""
  read -p "Enter custom path to install skills folder (e.g. ./skills): " CUSTOM_PATH
  if [ -n "${CUSTOM_PATH:-}" ]; then
    install_to_path "${CUSTOM_PATH}" "Custom Directory"
    INSTALLED=1
  fi
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
  echo -e "${RED}Installation cancelled or failed.${NC}"
fi
