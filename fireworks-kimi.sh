#!/usr/bin/env bash
# fireworks-kimi.sh — Claude Code → Fireworks AI (Kimi K2.5)
# Standalone client, không cần AIO server
#
# curl -fsSL "https://get.organat.vn/fireworks-kimi.sh" | bash

set -euo pipefail
trap 'echo ""; echo -e "\033[0;31mInterrupted\033[0m"; exit 130' INT TERM

# CF Worker dịch claude-* → Fireworks kimi-k2p5 (always up, no AIO needed)
BASE_URL="https://fireworks.organat.vn"
API_KEY="fw_Vq4cbbXH1RhJXofLorUHTf"
OPUS_MODEL="claude-opus-4-6"
SONNET_MODEL="claude-sonnet-4-6"
HAIKU_MODEL="claude-haiku-4-5"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { printf "${GREEN}[%s]${NC} %s\n" "$(date '+%H:%M:%S')" "$*"; }

load_nvm() {
  [[ -f "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]] && source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
}

install_claude() {
  if command -v claude >/dev/null 2>&1; then
    log "Claude Code: $(timeout 2 claude -v 2>/dev/null || echo installed)"; return 0
  fi
  log "Installing @anthropic-ai/claude-code..."
  load_nvm
  timeout 120 npm install -g @anthropic-ai/claude-code@latest || { echo "npm install failed"; exit 1; }
  hash -r 2>/dev/null || true
}

write_settings() {
  mkdir -p "$HOME/.claude"
  [[ -f "$HOME/.claude/settings.json" ]] && cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.bak"
  cat > "$HOME/.claude/settings.json" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "${BASE_URL}",
    "ANTHROPIC_API_KEY": "${API_KEY}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${OPUS_MODEL}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${SONNET_MODEL}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${HAIKU_MODEL}",
    "API_TIMEOUT_MS": "3000000"
  },
  "permissions": { "allow": ["*"] }
}
EOF
}

write_shell_block() {
  local f="$1"; [[ -f "$f" ]] || touch "$f"
  sed -i '/# >>> fireworks-kimi >>>/,/# <<< fireworks-kimi <<</d' "$f" 2>/dev/null || true
  cat >> "$f" << EOF

# >>> fireworks-kimi >>>
export ANTHROPIC_BASE_URL="${BASE_URL}"
export ANTHROPIC_API_KEY="${API_KEY}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="${OPUS_MODEL}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${SONNET_MODEL}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${HAIKU_MODEL}"
export API_TIMEOUT_MS="3000000"
unset ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
# <<< fireworks-kimi <<<
EOF
}

main() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   Fireworks AI × Kimi K2.5 — Standalone Client     ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
  log "Endpoint : ${BASE_URL}  (CF Worker → Fireworks)"
  log "Model    : Kimi K2.5  (dùng claude-opus-4-6 alias)"
  echo ""
  load_nvm; install_claude
  log "Writing ~/.claude/settings.json..."
  write_settings
  log "Updating shell rc files..."
  write_shell_block "$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]]   && write_shell_block "$HOME/.zshrc"
  [[ -f "$HOME/.profile" ]] && write_shell_block "$HOME/.profile"
  [[ -f "$HOME/.claude.json" ]] || echo '{}' > "$HOME/.claude.json"
  echo ""
  echo -e "${GREEN}Done! Chạy:${NC}  ${YELLOW}source ~/.bashrc && claude -r${NC}"
  echo ""
}

main "$@"
