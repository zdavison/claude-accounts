#!/bin/sh
# Install claude-accounts, then start its setup:
#   curl -fsSL https://raw.githubusercontent.com/zdavison/claude-accounts/main/install.sh | sh
#
# CLAUDE_ACCOUNTS_VERSION=1.2.3  install that version (default: latest)
# CLAUDE_ACCOUNTS_NO_SETUP=1     install only; run `claude-accounts setup` yourself
set -eu

PKG="@zdavison/claude-accounts"
VERSION="${CLAUDE_ACCOUNTS_VERSION:-latest}"
# setup asks questions; when this script is piped into sh, its stdin is the script, not the user
TTY="${CLAUDE_ACCOUNTS_TTY:-/dev/tty}"

say() { printf '%s\n' "$*"; }
die() { printf 'claude-accounts install: %s\n' "$*" >&2; exit 1; }

hint() {
  case "$1" in
    mise) say "  mise:   https://mise.jdx.dev/getting-started.html" ;;
    jq) say "  jq:     mise use -g jq, or your package manager" ;;
    claude) say "  claude: npm install -g @anthropic-ai/claude-code" ;;
    bash) say "  bash:   your package manager" ;;
  esac
}

missing=""
for tool in bash jq mise claude; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
  say "claude-accounts needs these tools, which are not installed:"
  for tool in $missing; do hint "$tool"; done
  die "install them, then run this installer again"
fi

say "Installing $PKG@$VERSION..."
if mise use -g "npm:$PKG@$VERSION"; then
  bin="$(command -v claude-accounts 2>/dev/null || mise which claude-accounts 2>/dev/null || true)"
elif command -v npm >/dev/null 2>&1 && npm install -g "$PKG@$VERSION"; then
  bin="$(command -v claude-accounts 2>/dev/null || true)"
  [ -n "$bin" ] || bin="$(npm prefix -g)/bin/claude-accounts"
else
  die "could not install $PKG with mise or npm"
fi
[ -n "$bin" ] && [ -x "$bin" ] || die "installed $PKG, but cannot find the claude-accounts command"
say "Installed claude-accounts."

if [ -n "${CLAUDE_ACCOUNTS_NO_SETUP:-}" ] || ! (exec <"$TTY") 2>/dev/null; then
  say "Next, run: claude-accounts setup"
  exit 0
fi
"$bin" setup <"$TTY"
