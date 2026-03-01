#!/usr/bin/env bash
# clawsetup - Install or update the custom OpenClaw fork with full agent autonomy.
# Usage: curl -fsSL https://raw.githubusercontent.com/caydenchapple/openclaw/main/scripts/clawsetup.sh | bash
set -euo pipefail

REPO_URL="https://github.com/caydenchapple/openclaw.git"
AUTOMATION_REPO_URL="https://github.com/ashwwwin/automation-mcp.git"
INSTALL_DIR="${CLAWSETUP_DIR:-$HOME/.clawsetup}"
REPO_DIR="$INSTALL_DIR/openclaw"
BIN_DIR="$HOME/.local/bin"
AUTOMATION_DIR="$HOME/.local/share/automation-mcp"
DRY_RUN=0
SKIP_AUTOMATION=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)       DRY_RUN=1 ;;
    --skip-automation) SKIP_AUTOMATION=1 ;;
    --help|-h)
      echo "clawsetup -- Install custom OpenClaw fork"
      echo ""
      echo "Usage: curl -fsSL .../clawsetup.sh | bash [-s -- OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dry-run           Print what would happen"
      echo "  --skip-automation   Skip automation-mcp setup"
      echo "  --help              Show this help"
      exit 0
      ;;
  esac
done

step()  { printf '\n\033[36m>> %s\033[0m\n' "$1"; }
ok()    { printf '   \033[32m%s\033[0m\n' "$1"; }
warn()  { printf '   \033[33m%s\033[0m\n' "$1"; }
err()   { printf '   \033[31m%s\033[0m\n' "$1"; }

has() { command -v "$1" >/dev/null 2>&1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    ok "[dry-run] $*"
  else
    "$@"
  fi
}

ensure_node() {
  if has node; then
    local ver
    ver=$(node -v | sed 's/^v//')
    local major
    major=$(echo "$ver" | cut -d. -f1)
    if [ "$major" -ge 22 ]; then
      ok "Node.js v$ver"
      return
    fi
    warn "Node.js $ver found but 22+ required."
  fi

  step "Installing Node.js..."
  if [ "$(uname)" = "Darwin" ]; then
    if has brew; then
      run brew install node@22
    else
      warn "Homebrew not found. Installing via official script..."
      run bash -c 'curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs'
    fi
  else
    if has apt-get; then
      run bash -c 'curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs'
    elif has dnf; then
      run bash -c 'curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - && sudo dnf install -y nodejs'
    elif has brew; then
      run brew install node@22
    else
      err "Cannot auto-install Node.js. Please install Node.js 22+ and re-run."
      exit 1
    fi
  fi
}

ensure_git() {
  if has git; then
    ok "Git installed."
    return
  fi
  step "Installing Git..."
  if [ "$(uname)" = "Darwin" ]; then
    if has brew; then run brew install git;
    else run xcode-select --install; fi
  elif has apt-get; then run sudo apt-get install -y git
  elif has dnf; then run sudo dnf install -y git
  else
    err "Cannot auto-install Git. Please install git and re-run."
    exit 1
  fi
}

ensure_pnpm() {
  if has pnpm; then
    ok "pnpm ready."
    return
  fi
  step "Installing pnpm..."
  run npm install -g pnpm
}

ensure_bun() {
  if has bun; then
    ok "Bun ready."
    return
  fi
  step "Installing Bun..."
  run bash -c 'curl -fsSL https://bun.sh/install | bash'
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
}

# ── Banner ──
echo ""
printf '  \033[36mclawsetup - Custom OpenClaw Installer\033[0m\n'
printf '  \033[90mgithub.com/caydenchapple/openclaw\033[0m\n'
echo ""
if [ "$DRY_RUN" -eq 1 ]; then warn "DRY RUN - no changes will be made."; fi

# ── 1. Prerequisites ──
step "Checking prerequisites..."
ensure_git
ensure_node
ensure_pnpm

# ── 2. Clone or update ──
step "Setting up OpenClaw..."
run mkdir -p "$INSTALL_DIR"

if [ -d "$REPO_DIR/.git" ]; then
  ok "Existing install found. Updating..."
  if [ "$DRY_RUN" -eq 0 ]; then
    cd "$REPO_DIR"
    git pull --rebase origin main
  fi
else
  ok "Cloning from $REPO_URL..."
  run git clone "$REPO_URL" "$REPO_DIR"
fi

# ── 3. Build ──
step "Building OpenClaw..."
if [ "$DRY_RUN" -eq 0 ]; then
  cd "$REPO_DIR"
  pnpm install
  pnpm build
fi
ok "Build complete."

# ── 4. Add to PATH ──
step "Adding openclaw to PATH..."
run mkdir -p "$BIN_DIR"

wrapper="$BIN_DIR/openclaw"
if [ "$DRY_RUN" -eq 0 ]; then
  cat > "$wrapper" << WRAPPER
#!/usr/bin/env bash
exec node "$REPO_DIR/dist/cli.js" "\$@"
WRAPPER
  chmod +x "$wrapper"
fi

add_to_shell_rc() {
  local rc="$1"
  if [ -f "$rc" ]; then
    if ! grep -q "$BIN_DIR" "$rc" 2>/dev/null; then
      if [ "$DRY_RUN" -eq 0 ]; then
        printf '\n# clawsetup\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$rc"
      fi
      ok "Added $BIN_DIR to $rc"
    fi
  fi
}

add_to_shell_rc "$HOME/.bashrc"
add_to_shell_rc "$HOME/.zshrc"
export PATH="$BIN_DIR:$PATH"
ok "openclaw wrapper at $wrapper"

# ── 5. Apply custom settings ──
step "Applying clawsetup settings (full agent autonomy)..."
if [ "$DRY_RUN" -eq 0 ]; then
  node "$REPO_DIR/dist/cli.js" approvals trust
fi
ok "Agent trusted with full autonomous control."

# ── 6. Automation-mcp (optional) ──
if [ "$SKIP_AUTOMATION" -eq 0 ]; then
  step "Setting up automation-mcp (desktop control)..."
  ensure_bun

  if [ -d "$AUTOMATION_DIR/.git" ]; then
    ok "automation-mcp already installed. Updating..."
    if [ "$DRY_RUN" -eq 0 ]; then
      cd "$AUTOMATION_DIR"
      git pull
      bun install
    fi
  else
    ok "Cloning automation-mcp..."
    if [ "$DRY_RUN" -eq 0 ]; then
      git clone "$AUTOMATION_REPO_URL" "$AUTOMATION_DIR"
      cd "$AUTOMATION_DIR"
      bun install
    fi
  fi

  if has mcporter; then
    ok "Configuring mcporter server..."
    if [ "$DRY_RUN" -eq 0 ]; then
      mcporter config add automation --transport stdio --command "bun run $AUTOMATION_DIR/index.ts --stdio"
    fi
  else
    warn "mcporter not found. To enable MCP automation tools, install mcporter and run:"
    warn "  mcporter config add automation --transport stdio --command \"bun run $AUTOMATION_DIR/index.ts --stdio\""
  fi

  ok "automation-mcp ready."
else
  warn "Skipped automation-mcp setup (--skip-automation)."
fi

# ── Done ──
echo ""
printf '  \033[32m============================================\033[0m\n'
printf '  \033[32mclawsetup complete!\033[0m\n'
printf '  \033[32m============================================\033[0m\n'
echo ""
printf '  OpenClaw:       %s\n' "$REPO_DIR"
printf '  CLI wrapper:    %s\n' "$wrapper"
printf '  Dashboard:      http://127.0.0.1:18789/\n'
echo ""
printf '  \033[36mQuick start:\033[0m\n'
printf '    openclaw models set          # pick a model (interactive)\n'
printf '    openclaw gateway run         # start the gateway + dashboard\n'
printf '    openclaw tui                 # terminal chat UI\n'
printf '    openclaw dashboard           # open the web dashboard\n'
echo ""
printf '  \033[36mUpdate later:\033[0m\n'
printf '    \033[90mcurl -fsSL https://raw.githubusercontent.com/caydenchapple/openclaw/main/scripts/clawsetup.sh | bash\033[0m\n'
echo ""
