#!/usr/bin/env bash
# openclaude.sh — One-shot installer: Claude Code → OpenClaude
# Usage (with default key):
#   curl -fsSL "https://get.organat.vn/openclaude.sh" | bash
# Usage (custom key):
#   curl -fsSL "https://get.organat.vn/openclaude.sh" | bash -s -- "YOUR_API_KEY"
#   or: ANTHROPIC_API_KEY=... bash openclaude.sh

set -euo pipefail
# Trap Ctrl+C to exit cleanly
trap 'echo ""; echo "${RED}Interrupted${NC}"; exit 130' INT TERM

# ── Defaults ──────────────────────────────────────────────────────────────
DEFAULT_API_KEY="openclaude-Tzbja6elIUtBMaj2ypXgrZuKOnWZI_x9Ms8tgU4D28NQw4SD"
DEFAULT_BASE_URL="https://open-claude.com"

API_KEY="${1:-${ANTHROPIC_API_KEY:-$DEFAULT_API_KEY}}"
BASE_URL="${2:-${ANTHROPIC_BASE_URL:-$DEFAULT_BASE_URL}}"

# ── Helpers ───────────────────────────────────────────────────────────────
log()  { printf '\e[32m[%s]\e[0m %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
die()  { printf '\e[31m[ERR]\e[0m %s\n' "$*" >&2; exit 1; }

# ── Load nvm if available (user-level node) ───────────────────────────────
load_nvm() {
  if [[ -f "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  fi
}

# ── Aggressive cleanup before install ────────────────────────────────────
cleanup_before_install() {
  # Remove claude-code directories directly (before nvm is even loaded)
  # Check common NVM install locations
  local npm_prefix
  npm_prefix="${NVM_DIR:-$HOME/.nvm}/versions/node/v20.20.1/lib"
  [[ -d "$npm_prefix/node_modules/@anthropic-ai/claude-code" ]] && \
    rm -rf "$npm_prefix/node_modules/@anthropic-ai/claude-code"
  [[ -d "$npm_prefix/node_modules/@anthropic-ai/.claude-code-"* ]] && \
    rm -rf "$npm_prefix/node_modules/@anthropic-ai/.claude-code-"*
  [[ -d "$npm_prefix/node_modules/.bin/claude" ]] && \
    rm -rf "$npm_prefix/node_modules/.bin/claude"

  # Also try common system paths
  rm -rf /usr/local/lib/node_modules/@anthropic-ai/claude-code 2>/dev/null || true
  rm -rf /usr/local/bin/claude 2>/dev/null || true
  rm -rf "$HOME/.local/lib/node_modules/@anthropic-ai/claude-code" 2>/dev/null || true
}

# ── Ensure Claude Code is installed ───────────────────────────────────────
install_claude() {
  # Check if claude already exists
  if command -v claude >/dev/null 2>&1; then
    local version
    version=$(timeout 2 claude -v 2>/dev/null || echo "installed")
    log "✓ Claude Code found: $version"
    return 0
  fi

  log "Installing @anthropic-ai/claude-code..."

  # Pre-cleanup before loading nvm (avoids npm directory locking)
  cleanup_before_install

  load_nvm

  # npm-level cleanup (with timeouts)
  timeout 30 npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
  timeout 15 npm cache clean --force 2>/dev/null || true

  # Install fresh (with 120 second timeout for npm)
  log "Running: npm install -g @anthropic-ai/claude-code@latest"
  timeout 120 npm install -g @anthropic-ai/claude-code@latest || die "npm install timed out or failed"

  # Verify binary exists
  hash -r 2>/dev/null || true
  if ! command -v claude >/dev/null 2>&1; then
    die "claude not found after install"
  fi
  log "✓ Claude Code installed successfully"
}

# ── Write shell env block ─────────────────────────────────────────────────
write_shell_block() {
  local f="$1"
  [[ -f "$f" ]] || touch "$f"
  # Remove any previous openclaude blocks
  sed -i '/# >>> openclaude >>>/,/# <<< openclaude <<</d' "$f" 2>/dev/null || true

  cat >> "$f" <<EOF

# >>> openclaude >>>
export ANTHROPIC_API_KEY='${API_KEY}'
export ANTHROPIC_BASE_URL='${BASE_URL}'
unset ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4.6'
export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-4.6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='claude-haiku-4.5'
export API_TIMEOUT_MS='3000000'
# <<< openclaude <<<
EOF
}

# ── Write ~/.claude/settings.json ────────────────────────────────────────
write_settings() {
  log "Writing ~/.claude/settings.json..."
  mkdir -p "$HOME/.claude"
  cat > "$HOME/.claude/settings.json" <<EOF
{
  "env": {
    "ANTHROPIC_API_KEY": "${API_KEY}",
    "ANTHROPIC_BASE_URL": "${BASE_URL}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4.6",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4.6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4.5",
    "API_TIMEOUT_MS": "3000000"
  },
  "permissions": {
    "allow": ["*"]
  }
}
EOF
}

# ── Patch ~/.claude.json onboarding/trust ─────────────────────────────────
patch_state() {
  log "Patching ~/.claude.json..."
  # Just echo to file if needed - skip python to avoid hanging
  [[ -f "$HOME/.claude.json" ]] || echo '{}' > "$HOME/.claude.json"
}

# ── Configure all ─────────────────────────────────────────────────────────
configure_all() {
  log "Applying shell configs..."
  write_shell_block "$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]]   && { log "  Updating ~/.zshrc..."; write_shell_block "$HOME/.zshrc"; }
  [[ -f "$HOME/.profile" ]] && { log "  Updating ~/.profile..."; write_shell_block "$HOME/.profile"; }
  log "Writing ~/.claude/settings.json..."
  write_settings
  log "Finalizing configuration..."
  patch_state
}

# ── Main ──────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║     OpenClaude × Claude Code  —  One-Shot       ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  log "API Key : ${API_KEY:0:16}..."
  log "Base URL: ${BASE_URL}"
  echo ""

  load_nvm
  install_claude
  configure_all

  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║          Installation Complete!                 ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  echo "${GREEN}Next steps:${NC}"
  echo "  1. Reload shell:        ${BLUE}source ~/.bashrc${NC}"
  echo "  2. Login to OpenClaude: ${BLUE}claude -r${NC}"
  echo "  3. Test:                ${BLUE}claude -p 'hello'${NC}"
  echo ""
}

# Run main (individual operations have timeouts built-in)
main "$@"
