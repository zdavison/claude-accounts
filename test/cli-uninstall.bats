#!/usr/bin/env bats
load helpers

setup() {
  setup_home
  stub_tools
  two_accounts
  export CLAUDE_ACCOUNTS_EDITORS=test-zed SHELL=/bin/bash
  printf '#!/bin/sh\n' > "$BATS_TEST_TMPDIR/bin/test-zed"
  chmod +x "$BATS_TEST_TMPDIR/bin/test-zed"
  printf '# my rc\nalias ll="ls -l"\n' > "$HOME/.bashrc"
  printf '[tools]\npnpm = "latest"\n' > "$HOME/Work/acme/mise.toml"
  cli apply
  # what setup adds when Zed is installed
  printf '\n%s\n%s\n' "# Start Zed without an account's CLAUDE_CONFIG_DIR (claude-accounts)" \
    'eval "$(claude-accounts shell-init bash)"' >> "$HOME/.bashrc"
  : > "$STUB_LOG"
}

@test "uninstall removes the mise env, the plugin, the shell rc line and the config" {
  run cli uninstall --yes
  [ "$status" -eq 0 ]
  grep -qxF "mise unset --file $HOME/Work/acme/mise.local.toml CLAUDE_CONFIG_DIR" "$STUB_LOG"
  grep -qxF "claude[unset] plugin uninstall account-badge@account-switcher" "$STUB_LOG"
  grep -qxF "claude[$HOME/.claude-work] plugin uninstall account-badge@account-switcher" "$STUB_LOG"
  grep -qxF "claude[unset] plugin marketplace remove account-switcher" "$STUB_LOG"
  grep -qxF "claude[$HOME/.claude-work] plugin marketplace remove account-switcher" "$STUB_LOG"
  [ ! -e "$XDG_CONFIG_HOME/claude-accounts" ]
  [ "$(cat "$HOME/.bashrc")" = "$(printf '# my rc\nalias ll="ls -l"')" ]
}

@test "uninstall keeps the Claude config dirs and the committed mise.toml, and says how to finish" {
  run cli uninstall --yes
  [ -d "$HOME/.claude-work" ]
  [ -f "$HOME/Work/acme/mise.toml" ]
  [[ "$output" == *"~/.claude-work"* ]]
  [[ "$output" == *"npm uninstall -g @zdavison/claude-accounts"* ]]
}

@test "uninstall asks first, and changes nothing when the answer is no" {
  run bash -c "printf 'n\n' | '$TEST_BASH' '$CLI' uninstall"
  [ "$status" -ne 0 ]
  [ -f "$XDG_CONFIG_HOME/claude-accounts/accounts.json" ]
  grep -q 'shell-init' "$HOME/.bashrc"
  ! grep -q 'plugin uninstall' "$STUB_LOG"
}

@test "uninstall edits a symlinked shell rc in place, keeping the link" {
  mv "$HOME/.bashrc" "$HOME/dotfiles-bashrc"
  ln -s "$HOME/dotfiles-bashrc" "$HOME/.bashrc"
  cli uninstall --yes
  [ -L "$HOME/.bashrc" ]
  ! grep -q 'shell-init' "$HOME/dotfiles-bashrc"
}

@test "uninstall cleans up the fish and zsh rc files too" {
  mkdir -p "$XDG_CONFIG_HOME/fish"
  printf 'set x 1\n\n%s\nclaude-accounts shell-init fish | source\n' "# Start Zed without an account's CLAUDE_CONFIG_DIR (claude-accounts)" > "$XDG_CONFIG_HOME/fish/config.fish"
  printf 'eval "$(claude-accounts shell-init zsh)"\n' > "$HOME/.zshrc"
  cli uninstall --yes
  [ "$(cat "$XDG_CONFIG_HOME/fish/config.fish")" = "set x 1" ]
  [ ! -s "$HOME/.zshrc" ]
}

@test "uninstall works when there is no config" {
  rm -r "$XDG_CONFIG_HOME/claude-accounts"
  run cli uninstall --yes
  [ "$status" -eq 0 ]
  ! grep -q 'shell-init' "$HOME/.bashrc"
}
