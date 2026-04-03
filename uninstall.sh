#!/bin/sh
# openclaude-uninstall.sh — Restore Claude Code to default Anthropic settings
# Usage: curl -fsSL "https://get.organat.vn/uninstall.sh" | sh && sleep 2 && source ~/.bashrc && claude -r

set -e

# Colors
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
BLUE=$(printf '\033[0;34m')
NC=$(printf '\033[0m')

echo ""
echo "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo "${BLUE}║   OpenClaude Uninstall — Restore to Anthropic   ║${NC}"
echo "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── backup_file ───────────────────────────────────────────────────────────
backup_file() {
    f="$1"
    if [ -f "$f" ]; then
        cp "$f" "${f}.backup.$(date +%Y%m%d%H%M%S)"
        echo "  ${YELLOW}Backed up: $f${NC}"
    fi
}

# ── remove provider blocks from shell rc files ────────────────────────────
clean_rc() {
    f="$1"
    [ -f "$f" ] || return 0
    backup_file "$f"
    # Remove openclaude blocks
    sed -i '/# >>> openclaude >>>/,/# <<< openclaude <<</d' "$f" 2>/dev/null || true
    # Remove claudible / any leftover ANTHROPIC_ exports
    sed -i '/^export ANTHROPIC_/d'                          "$f" 2>/dev/null || true
    sed -i '/^# Claudible configuration/d'                  "$f" 2>/dev/null || true
    sed -i '/^# Claude Code configuration/d'                "$f" 2>/dev/null || true
    sed -i '/^# Claude Provider configuration/d'            "$f" 2>/dev/null || true
    sed -i '/^# server-lite configuration/d'                "$f" 2>/dev/null || true
    sed -i '/^export API_TIMEOUT_MS/d'                      "$f" 2>/dev/null || true
    echo "  ${GREEN}✓ Cleaned: $f${NC}"
}

# ── remove env keys from ~/.claude/settings.json ─────────────────────────
clean_settings() {
    f="$HOME/.claude/settings.json"
    [ -f "$f" ] || return 0

    if ! command -v jq >/dev/null 2>&1; then
        echo "  ${YELLOW}⚠ jq not found — skipping settings.json cleanup${NC}"
        echo "  ${YELLOW}  Remove manually: ANTHROPIC_* keys from ~/.claude/settings.json${NC}"
        return 0
    fi

    backup_file "$f"
    tmp=$(mktemp)
    jq 'del(
        .env.ANTHROPIC_API_KEY,
        .env.ANTHROPIC_AUTH_TOKEN,
        .env.ANTHROPIC_BASE_URL,
        .env.ANTHROPIC_DEFAULT_OPUS_MODEL,
        .env.ANTHROPIC_DEFAULT_SONNET_MODEL,
        .env.ANTHROPIC_DEFAULT_HAIKU_MODEL,
        .env.CLAUDE_CODE_DISABLE_1M_CONTEXT,
        .env.API_TIMEOUT_MS,
        .disableLoginPrompt,
        .statusLine
    ) | if .env == {} then del(.env) else . end
    ' "$f" > "$tmp" && mv "$tmp" "$f"
    echo "  ${GREEN}✓ Cleaned ~/.claude/settings.json${NC}"
}

# ── remove customApiKeyResponses from ~/.claude.json ─────────────────────
clean_state() {
    f="$HOME/.claude.json"
    [ -f "$f" ] || return 0

    backup_file "$f"
    python3 - "$f" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    data = json.loads(open(path).read())
except Exception:
    sys.exit(0)
data.pop("customApiKeyResponses", None)
data.pop("hasCompletedOnboarding", None)
# Remove hasTrustDialogAccepted from all projects
for proj in data.get("projects", {}).values():
    proj.pop("hasTrustDialogAccepted", None)
open(path, "w").write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY
    echo "  ${GREEN}✓ Cleaned ~/.claude.json${NC}"
}

# ── remove statusline helper ──────────────────────────────────────────────
clean_statusline() {
    f="$HOME/.claude/statusline.sh"
    if [ -f "$f" ]; then
        backup_file "$f"
        rm -f "$f"
        echo "  ${GREEN}✓ Removed ~/.claude/statusline.sh${NC}"
    fi
}

# ── main ──────────────────────────────────────────────────────────────────
echo "${BLUE}Cleaning shell configs...${NC}"
clean_rc "$HOME/.bashrc"
clean_rc "$HOME/.zshrc"
clean_rc "$HOME/.bash_profile"
clean_rc "$HOME/.profile"
clean_rc "$HOME/.zprofile"

echo ""
echo "${BLUE}Cleaning Claude Code settings...${NC}"
clean_settings
clean_state
clean_statusline

echo ""
echo "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo "${GREEN}║  Done! Claude Code restored to Anthropic default ║${NC}"
echo "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "${YELLOW}Next steps:${NC}"
echo "  1. Restart terminal or run: ${BLUE}source ~/.bashrc${NC}"
echo "  2. Login to Anthropic:      ${BLUE}claude -r${NC}"
echo ""
