# Shared fixtures: every test gets its own HOME, so nothing touches the real machine.

setup_home() {
  # Physical path: on macOS the temp dir sits behind the /var -> /private/var symlink
  mkdir -p "$BATS_TEST_TMPDIR/home"
  HOME="$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)"
  export HOME XDG_CONFIG_HOME="$HOME/.config"
  unset CLAUDE_CONFIG_DIR CLAUDE_CODE_ENTRYPOINT CLAUDE_PLUGIN_OPTION_LABEL_REPLIES MISE_SHELL CLAUDE_ACCOUNTS_SHELL_INIT CLAUDE_ACCOUNTS_MARKETPLACE
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  RESOLVE="$ROOT/plugin/account-badge/scripts/resolve"
  CLI="$ROOT/bin/claude-accounts"
  # CI sets TEST_BASH=/bin/bash on macOS to run everything under bash 3.2
  TEST_BASH="${TEST_BASH:-bash}"
}

write_config() {
  mkdir -p "$XDG_CONFIG_HOME/claude-accounts"
  printf '%s\n' "$1" > "$XDG_CONFIG_HOME/claude-accounts/accounts.json"
}

# login STATEFILE EMAIL: make an account look signed in
login() {
  mkdir -p "$(dirname "$1")"
  printf '{"oauthAccount":{"emailAddress":"%s"}}\n' "$2" > "$1"
}

# personal (default, ~/.claude) and work (~/.claude-work, owns ~/Work/acme)
two_accounts() {
  write_config '{"default":"personal","accounts":{"personal":{"label":"PERSONAL","emoji":"🟢","configDir":"~/.claude"},"work":{"label":"WORK","emoji":"🔴","configDir":"~/.claude-work","dirs":["~/Work/acme"]}}}'
  mkdir -p "$HOME/Work/acme/app" "$HOME/Work/acme-other" "$HOME/elsewhere"
}

resolve() { "$TEST_BASH" "$RESOLVE" "$@"; }

# field NAME: a field of the JSON in $output, as jq -r prints it
field() { jq -r ".$1" <<<"$output"; }
