#!/usr/bin/env bats
load helpers

setup() {
  setup_home
  stub_tools
  two_accounts
}

@test "apply creates config dirs, sets mise env and installs the plugin in every account" {
  run cli apply --marketplace /src/market
  [ "$status" -eq 0 ]
  [ -d "$HOME/.claude-work" ]
  grep -qxF "CLAUDE_CONFIG_DIR = \"$HOME/.claude-work\"" "$HOME/Work/acme/mise.local.toml"
  grep -qxF "mise set --file $HOME/Work/acme/mise.local.toml CLAUDE_CONFIG_DIR=$HOME/.claude-work" "$STUB_LOG"
  grep -qxF "mise trust --quiet $HOME/Work/acme/mise.local.toml" "$STUB_LOG"
  grep -qxF "claude[unset] plugin marketplace add /src/market" "$STUB_LOG"
  grep -qxF "claude[unset] plugin install account-badge@account-switcher" "$STUB_LOG"
  grep -qxF "claude[$HOME/.claude-work] plugin install account-badge@account-switcher" "$STUB_LOG"
}

@test "apply is idempotent: a second run installs nothing new" {
  cli apply
  cli apply
  [ "$(grep -c 'plugin install' "$STUB_LOG")" -eq 2 ]
}

@test "apply edits mise.local.toml with mise set, never the committed mise.toml" {
  printf '[tools]\npnpm = "latest"\n' > "$HOME/Work/acme/mise.toml"
  cli apply
  [ "$(cat "$HOME/Work/acme/mise.toml")" = "$(printf '[tools]\npnpm = "latest"')" ]
  ! grep -q -- "--file $HOME/Work/acme/mise.toml" "$STUB_LOG"
}

@test "the marketplace source defaults to CLAUDE_ACCOUNTS_MARKETPLACE, then the checkout" {
  CLAUDE_ACCOUNTS_MARKETPLACE=owner/repo cli apply
  grep -qxF "claude[unset] plugin marketplace add owner/repo" "$STUB_LOG"
  rm "$STUB_DIR/installed"; : > "$STUB_LOG"
  cli apply
  grep -qxF "claude[unset] plugin marketplace add $ROOT" "$STUB_LOG"
}

@test "apply stops with the account name when a dir does not exist" {
  rm -r "$HOME/Work/acme"
  run cli apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"work: $HOME/Work/acme does not exist"* ]]
}

@test "apply removes the env from dirs no longer in the config" {
  cli apply
  mkdir -p "$HOME/Work/b"
  cli set work dirs+ "$HOME/Work/b"
  cli set work dirs- "$HOME/Work/acme"
  run cli apply
  [ "$status" -eq 0 ]
  grep -qxF "mise unset --file $HOME/Work/acme/mise.local.toml CLAUDE_CONFIG_DIR" "$STUB_LOG"
  ! grep -q "unset --file $HOME/Work/b/" "$STUB_LOG"
}

@test "remove undoes the env of the removed account" {
  cli apply
  run cli remove work
  [ "$status" -eq 0 ]
  grep -qxF "mise unset --file $HOME/Work/acme/mise.local.toml CLAUDE_CONFIG_DIR" "$STUB_LOG"
}

@test "apply handles dirs and config dirs with spaces" {
  write_config '{"default":"personal","accounts":{"personal":{"configDir":"~/.claude"},"work":{"configDir":"~/claude work","dirs":["~/My Work/acme"]}}}'
  mkdir -p "$HOME/My Work/acme"
  run cli apply
  [ "$status" -eq 0 ]
  [ -d "$HOME/claude work" ]
  grep -qxF "CLAUDE_CONFIG_DIR = \"$HOME/claude work\"" "$HOME/My Work/acme/mise.local.toml"
}

@test "apply refuses a config with problems" {
  write_config '{"default":"personal","accounts":{"personal":{"configDir":"~/.claude"},"a":{"dirs":["~/Work"]},"b":{"dirs":["~/Work/x"]}}}'
  run cli apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"overlaps"* ]]
}

@test "an installed package (not a git checkout) installs the plugin from GitHub" {
  pkg="$BATS_TEST_TMPDIR/pkg"
  mkdir -p "$pkg"
  cp -R "$ROOT/bin" "$ROOT/plugin" "$ROOT/.claude-plugin" "$pkg/"
  run "$TEST_BASH" "$pkg/bin/claude-accounts" apply
  [ "$status" -eq 0 ]
  grep -qxF "claude[unset] plugin marketplace add zdavison/claude-accounts" "$STUB_LOG"
}

@test "a git checkout installs the plugin from itself" {
  cli apply
  grep -qxF "claude[unset] plugin marketplace add $ROOT" "$STUB_LOG"
}
