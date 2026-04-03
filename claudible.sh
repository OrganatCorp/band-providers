#!/bin/sh

# Claudible Installer for Claude Code
# Configures Claude Code to use Claudible

set -e
# Allow Ctrl+C to exit gracefully
trap 'echo ""; echo "Interrupted"; exit 130' INT TERM

# Configuration (auto-populated by server)
ENDPOINT_URL="https://claudible.io"
API_KEY='sk-c101c69d0fa2429539d63635c5d4eca9372b06751e011d59ee7608e52f5af4e3'
HAIKU_MODEL="claude-haiku-4.5"
OPUS_MODEL="claude-opus-4.6"
SONNET_MODEL="claude-sonnet-4.6"

# Colors
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
BLUE=$(printf '\033[0;34m')
NC=$(printf '\033[0m')

echo "${BLUE}================================${NC}"
echo "${BLUE}  Claudible Configuration${NC}"
echo "${BLUE}================================${NC}"
echo ""

# Validate configuration
if [ "$ENDPOINT_URL" = "__""ENDPOINT_URL__" ] || [ -z "$ENDPOINT_URL" ]; then
    echo "${RED}Error: Endpoint URL not configured${NC}"
    exit 1
fi

if [ "$API_KEY" = "__""API_KEY__" ] || [ -z "$API_KEY" ]; then
    echo "${RED}Error: API key not configured${NC}"
    exit 1
fi

# Mask API key for display
MASKED_KEY=$(echo "$API_KEY" | cut -c 1-10)
echo "Endpoint URL: ${GREEN}$ENDPOINT_URL${NC}"
echo "API Key:      ${GREEN}${MASKED_KEY}...${NC}"
echo ""

# Function to backup file
backup_file() {
    f_path="$1"
    if [ -f "$f_path" ]; then
        cp "$f_path" "${f_path}.backup.$(date +%Y%m%d%H%M%S)"
        echo "${YELLOW}  Backed up: $f_path${NC}"
    fi
}

# Function to remove existing Claudible/Claude vars from shell rc file
remove_claude_vars() {
    f_path="$1"
    if [ -f "$f_path" ]; then
        sed '/^export ANTHROPIC_/d' "$f_path" > "${f_path}.tmp" && mv "${f_path}.tmp" "$f_path"
        sed '/^# Claude Code configuration/d' "$f_path" > "${f_path}.tmp" && mv "${f_path}.tmp" "$f_path"
        sed '/^# ClaudeVibeCode configuration/d' "$f_path" > "${f_path}.tmp" && mv "${f_path}.tmp" "$f_path"
        sed '/^# Claude Provider configuration/d' "$f_path" > "${f_path}.tmp" && mv "${f_path}.tmp" "$f_path"
        sed '/^# Claudible configuration/d' "$f_path" > "${f_path}.tmp" && mv "${f_path}.tmp" "$f_path"
        sed '/^# server-lite configuration/d' "$f_path" > "${f_path}.tmp" && mv "${f_path}.tmp" "$f_path"
        rm -f "${f_path}.tmp" 2>/dev/null || true
    fi
}

# Function to add Claude Code env vars to shell rc file
add_claude_vars() {
    f_path="$1"
    url="$2"
    key="$3"

    remove_claude_vars "$f_path"

    echo "" >> "$f_path"
    echo "# Claudible configuration" >> "$f_path"
    echo "export ANTHROPIC_BASE_URL=\"$url\"" >> "$f_path"
    echo "export ANTHROPIC_AUTH_TOKEN=\"$key\"" >> "$f_path"
}

# Function to install statusline script
install_statusline() {
    statusline_file="$HOME/.claude/statusline.sh"
    url="$1"
    key="$2"

    # Ensure .claude directory exists before download
    mkdir -p "$HOME/.claude"

    echo "${BLUE}Installing statusline script...${NC}"

    # Download statusline script from server
    dl_error=$(curl -fsSL "$url/statusline.sh?key=$key" -o "$statusline_file" 2>&1)
    if [ $? -eq 0 ]; then
        chmod +x "$statusline_file"
        echo "  ${GREEN}✓ Installed ~/.claude/statusline.sh${NC}"
        return 0
    else
        rm -f "$statusline_file" 2>/dev/null
        echo "  ${YELLOW}⚠ Could not download statusline script${NC}"
        echo "  ${YELLOW}  Reason: $dl_error${NC}"
        return 1
    fi
}

# Function to update settings.json
# Requires jq for JSON manipulation
update_settings_json() {
    settings_file="$HOME/.claude/settings.json"
    url="$1"
    key="$2"
    statusline_installed="$3"
    statusline_cmd="$HOME/.claude/statusline.sh"

    mkdir -p "$HOME/.claude"

    # Check for jq
    if ! command -v jq >/dev/null 2>&1; then
        echo ""
        echo "${RED}Error: jq is required but not installed.${NC}"
        echo ""
        echo "Please install jq first:"
        echo "  ${BLUE}macOS:${NC}        brew install jq"
        echo "  ${BLUE}Ubuntu/Debian:${NC} sudo apt-get install -y jq"
        echo "  ${BLUE}Fedora/RHEL:${NC}   sudo dnf install -y jq"
        echo "  ${BLUE}Arch Linux:${NC}    sudo pacman -S jq"
        echo ""
        echo "Then run this installer again."
        exit 1
    fi

    # If file doesn't exist, create empty object
    if [ ! -f "$settings_file" ]; then
        echo '{}' > "$settings_file"
    else
        backup_file "$settings_file"
    fi

    # Merge settings using jq
    tmp_file=$(mktemp)

    if [ "$statusline_installed" = "true" ]; then
        jq --arg url "$url" --arg key "$key" \
           --arg haiku "$HAIKU_MODEL" --arg opus "$OPUS_MODEL" --arg sonnet "$SONNET_MODEL" \
           --arg sl_cmd "$statusline_cmd" '
            .env.ANTHROPIC_BASE_URL = $url |
            .env.ANTHROPIC_AUTH_TOKEN = $key |
            .env.ANTHROPIC_DEFAULT_HAIKU_MODEL = $haiku |
            .env.ANTHROPIC_DEFAULT_OPUS_MODEL = $opus |
            .env.ANTHROPIC_DEFAULT_SONNET_MODEL = $sonnet |
            .env.CLAUDE_CODE_DISABLE_1M_CONTEXT = "1" |
            .disableLoginPrompt = true |
            .statusLine = {"type": "command", "command": $sl_cmd}
        ' "$settings_file" > "$tmp_file" && mv "$tmp_file" "$settings_file"
    else
        jq --arg url "$url" --arg key "$key" \
           --arg haiku "$HAIKU_MODEL" --arg opus "$OPUS_MODEL" --arg sonnet "$SONNET_MODEL" '
            .env.ANTHROPIC_BASE_URL = $url |
            .env.ANTHROPIC_AUTH_TOKEN = $key |
            .env.ANTHROPIC_DEFAULT_HAIKU_MODEL = $haiku |
            .env.ANTHROPIC_DEFAULT_OPUS_MODEL = $opus |
            .env.ANTHROPIC_DEFAULT_SONNET_MODEL = $sonnet |
            .env.CLAUDE_CODE_DISABLE_1M_CONTEXT = "1" |
            .disableLoginPrompt = true
        ' "$settings_file" > "$tmp_file" && mv "$tmp_file" "$settings_file"
    fi
}

# Configure shell rc files
configure_file() {
    rc_file="$1"
    echo "  Processing $rc_file"
    backup_file "$rc_file"
    add_claude_vars "$rc_file" "$ENDPOINT_URL" "$API_KEY"
    echo "  ${GREEN}✓ Updated $rc_file${NC}"
}

echo "${BLUE}Configuring shell environment...${NC}"

SHELL_FOUND=0
if [ -f "$HOME/.bashrc" ]; then
    configure_file "$HOME/.bashrc"
    SHELL_FOUND=1
fi
if [ -f "$HOME/.zshrc" ]; then
    configure_file "$HOME/.zshrc"
    SHELL_FOUND=1
fi

if [ "$SHELL_FOUND" -eq 0 ]; then
    echo "${YELLOW}  No .bashrc or .zshrc found${NC}"
fi

echo ""
echo "${BLUE}Installing statusline script (optional)...${NC}"
STATUSLINE_INSTALLED="false"
if install_statusline "$ENDPOINT_URL" "$API_KEY"; then
    STATUSLINE_INSTALLED="true"
fi

echo ""
echo "${BLUE}Updating Claude Code settings...${NC}"
update_settings_json "$ENDPOINT_URL" "$API_KEY" "$STATUSLINE_INSTALLED"
echo "  ${GREEN}✓ Updated ~/.claude/settings.json${NC}"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Claudible Configuration Complete!              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Claude Code is now configured to use Claudible:"
echo "  Endpoint: ${BLUE}$ENDPOINT_URL${NC}"
echo "  API Key:  ${BLUE}${MASKED_KEY}...${NC}"
echo ""
echo "${YELLOW}Next steps:${NC}"
echo "  1. Reload shell:  ${BLUE}source ~/.bashrc${NC}"
echo "  2. Run:           ${BLUE}claude${NC}"
echo "  3. Login:         ${BLUE}claude -r${NC}"
echo ""
