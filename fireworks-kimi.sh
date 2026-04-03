#!/usr/bin/env bash
# fireworks-kimi.sh — One-shot installer: Claude Code → Fireworks AI (Kimi K2.5)
#
# Download sources (3-layer failover — works even when AIO server is down):
#   Layer 1: curl -fsSL "https://get.organat.vn/fireworks-kimi.sh"       | bash
#   Layer 2: curl -fsSL "https://get-cf.organat.vn/fireworks-kimi.sh"    | bash
#   Layer 3: curl -fsSL "https://raw.githubusercontent.com/OrganatCorp/band-providers/main/fireworks-kimi.sh" | bash
#
# Auto-failover (tries all 3 automatically):
#   bash <(curl -fsSL "https://get.organat.vn/fireworks-kimi.sh" \
#     || curl -fsSL "https://get-cf.organat.vn/fireworks-kimi.sh" \
#     || curl -fsSL "https://raw.githubusercontent.com/OrganatCorp/band-providers/main/fireworks-kimi.sh")

set -euo pipefail
trap 'echo ""; echo -e "\033[0;31mInterrupted\033[0m"; exit 130' INT TERM

# ── Defaults ──────────────────────────────────────────────────────────────
DEFAULT_API_KEY="fw_Vq4cbbXH1RhJXofLorUHTf"
DEFAULT_BASE_URL="https://api.fireworks.ai/inference/v1"

# Fireworks model IDs
KIMI_K2P5="accounts/fireworks/models/kimi-k2p5"
KIMI_K2_INSTRUCT="accounts/fireworks/models/kimi-k2-instruct-0905"

API_KEY="${1:-${FIREWORKS_API_KEY:-$DEFAULT_API_KEY}}"
BASE_URL="${2:-${FIREWORKS_BASE_URL:-$DEFAULT_BASE_URL}}"
MODEL="${KIMI_MODEL:-$KIMI_K2P5}"

# ── Colors ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { printf "${GREEN}[%s]${NC} %s\n" "$(date '+%H:%M:%S')" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
die()  { printf "${RED}[ERR]${NC} %s\n" "$*" >&2; exit 1; }

# ── Load nvm ─────────────────────────────────────────────────────────────
load_nvm() {
  [[ -f "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]] && source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
}

# ── Install Claude Code ───────────────────────────────────────────────────
install_claude() {
  if command -v claude >/dev/null 2>&1; then
    log "Claude Code found: $(timeout 2 claude -v 2>/dev/null || echo 'installed')"
    return 0
  fi
  log "Installing @anthropic-ai/claude-code..."
  load_nvm
  timeout 30 npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
  timeout 15 npm cache clean --force 2>/dev/null || true
  timeout 120 npm install -g @anthropic-ai/claude-code@latest || die "npm install failed"
  hash -r 2>/dev/null || true
  command -v claude >/dev/null 2>&1 || die "claude not found after install"
  log "Claude Code installed"
}

# ── Write shell env block ─────────────────────────────────────────────────
write_shell_block() {
  local f="$1"
  [[ -f "$f" ]] || touch "$f"
  sed -i '/# >>> fireworks-kimi >>>/,/# <<< fireworks-kimi <<</d' "$f" 2>/dev/null || true
  cat >> "$f" <<EOF

# >>> fireworks-kimi >>>
export ANTHROPIC_API_KEY='${API_KEY}'
export ANTHROPIC_BASE_URL='${BASE_URL}'
unset ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
export ANTHROPIC_DEFAULT_OPUS_MODEL='${KIMI_K2P5}'
export ANTHROPIC_DEFAULT_SONNET_MODEL='${KIMI_K2P5}'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='${KIMI_K2_INSTRUCT}'
export API_TIMEOUT_MS='3000000'
# <<< fireworks-kimi <<<
EOF
}

# ── Write ~/.claude/settings.json ─────────────────────────────────────────
write_settings() {
  mkdir -p "$HOME/.claude"
  [[ -f "$HOME/.claude/settings.json" ]] && \
    cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup.$(date +%Y%m%d%H%M%S)"
  cat > "$HOME/.claude/settings.json" <<EOF
{
  "env": {
    "ANTHROPIC_API_KEY": "${API_KEY}",
    "ANTHROPIC_BASE_URL": "${BASE_URL}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${KIMI_K2P5}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${KIMI_K2P5}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${KIMI_K2_INSTRUCT}",
    "API_TIMEOUT_MS": "3000000"
  },
  "permissions": { "allow": ["*"] }
}
EOF
}

# ── Configure all ─────────────────────────────────────────────────────────
configure_all() {
  log "Applying shell configs..."
  write_shell_block "$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]]   && write_shell_block "$HOME/.zshrc"
  [[ -f "$HOME/.profile" ]] && write_shell_block "$HOME/.profile"
  log "Writing ~/.claude/settings.json..."
  write_settings
  [[ -f "$HOME/.claude.json" ]] || echo '{}' > "$HOME/.claude.json"
}

# ── Main ──────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   Fireworks AI × Kimi K2.5 → Claude Code  (3-layer)    ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  log "API Key : ${API_KEY:0:12}..."
  log "Endpoint: ${BASE_URL}"
  log "Model   : ${MODEL}"
  echo ""
  echo -e "${CYAN}Download mirrors (auto-failover):${NC}"
  echo -e "  L1 (primary): get.organat.vn           — AIO server (K3s)"
  echo -e "  L2 (cloud):   get-cf.organat.vn         — Cloudflare Pages"
  echo -e "  L3 (public):  raw.githubusercontent.com  — GitHub raw"
  echo ""

  load_nvm
  install_claude
  configure_all

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║          Configuration Complete!                ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo -e "  1. Reload shell:  ${BLUE}source ~/.bashrc${NC}"
  echo -e "  2. Run:           ${BLUE}claude${NC}"
  echo ""
  echo -e "${CYAN}Switch provider:${NC}  ${BLUE}band-provider use fireworks-kimi${NC}"
  echo -e "${CYAN}Restore Anthropic:${NC} ${BLUE}band-provider off${NC}"
  echo ""
}

main "$@"
