#!/usr/bin/env bats
load helpers

setup() {
  setup_home
  stub_tools
  mkdir -p "$HOME/Work/acme" "$HOME/Clients/globex"
  export SHELL=/bin/bash
}

# answer LINE...: run setup with these lines as the answers, in order
answer() { printf '%s\n' "$@" | cli setup; }

# Answers for: default account (all defaults), add work (all defaults, one dir), no more accounts,
# write it, don't log in to either account
FRESH=("" "" "" "" y work "" "" "" "~/Work/acme" "" n y n n)

@test "setup walks a fresh machine through two accounts and applies them" {
  run answer "${FRESH[@]}" n
  [ "$status" -eq 0 ]
  [ "$(config_json | jq -c .)" = '{"default":"personal","accounts":{"personal":{"label":"PERSONAL","emoji":"🟢","configDir":"~/.claude"},"work":{"label":"WORK","emoji":"🔴","configDir":"~/.claude-work","dirs":["~/Work/acme"]}}}' ]
  grep -qxF "CLAUDE_CONFIG_DIR = \"$HOME/.claude-work\"" "$HOME/Work/acme/mise.local.toml"
  grep -qxF "claude[unset] plugin install account-badge@account-switcher" "$STUB_LOG"
  grep -qxF "claude[$HOME/.claude-work] plugin install account-badge@account-switcher" "$STUB_LOG"
  [[ "$output" == *"claude-accounts doctor"* ]]
}

@test "setup takes custom labels, emoji, config dirs and several dirs" {
  run answer "" "" "" "" y client "Globex" "🟣" "~/.claude-globex" "~/Clients/globex" "~/Work/acme" "" n y n n n
  [ "$status" -eq 0 ]
  [ "$(config_json | jq -c .accounts.client)" = '{"label":"Globex","emoji":"🟣","configDir":"~/.claude-globex","dirs":["~/Clients/globex","~/Work/acme"]}' ]
}

@test "setup asks again after an invalid answer instead of exiting" {
  # a bad name, then personal's config dir; the retry offers the suggested dir again
  run answer "" "" "" "" y "Work!" work "" "" "~/.claude" "" "" "~/Work/acme" "" n y n n n
  [ "$status" -eq 0 ]
  [[ "$output" == *"lowercase letters, digits and -"* ]]
  [[ "$output" == *"personal and work share config dir"* ]]
  [ "$(config_json | jq -r .accounts.work.configDir)" = "~/.claude-work" ]
}

@test "an account other than the default needs at least one directory" {
  run answer "" "" "" "" y work "" "" "" "" "~/Work/acme" "" n y n n n
  [ "$status" -eq 0 ]
  [[ "$output" == *"at least one directory"* ]]
  [ "$(config_json | jq -c .accounts.work.dirs)" = '["~/Work/acme"]' ]
}

@test "setup offers to create a directory that doesn't exist" {
  run answer "" "" "" "" y work "" "" "" "~/Work/new" y "" n y n n n
  [ "$status" -eq 0 ]
  [ -d "$HOME/Work/new" ]
  [ "$(config_json | jq -c .accounts.work.dirs)" = '["~/Work/new"]' ]
}

@test "declining the summary writes nothing and changes nothing" {
  run answer "" "" "" "" y work "" "" "" "~/Work/acme" "" n n
  [ "$status" -ne 0 ]
  [ ! -e "$XDG_CONFIG_HOME/claude-accounts/accounts.json" ]
  [ ! -e "$HOME/Work/acme/mise.local.toml" ]
  ! grep -q 'plugin install' "$STUB_LOG"
}

@test "setup with an existing config can add to it" {
  cli init
  run answer a y work "" "" "" "~/Work/acme" "" n y n n n
  [ "$status" -eq 0 ]
  [ "$(config_json | jq -r '.accounts | keys | join(",")')" = "personal,work" ]
}

@test "setup with an existing config can start over" {
  cli init
  cli add old --dir "$HOME/Clients/globex"
  run answer s "" "" "" "" y work "" "" "" "~/Work/acme" "" n y n n n
  [ "$status" -eq 0 ]
  [ "$(config_json | jq -r '.accounts | keys | join(",")')" = "personal,work" ]
}

@test "setup logs in accounts that aren't signed in when asked" {
  login "$HOME/.claude.json" me@example.com
  # personal is signed in, so the only login question is for work
  run answer "${FRESH[@]:0:13}" y n
  [ "$status" -eq 0 ]
  grep -qxF "claude[$HOME/.claude-work] auth login" "$STUB_LOG"
  ! grep -qxF "claude[unset] auth login" "$STUB_LOG"
}

@test "setup adds the shell-init line to the shell rc when asked" {
  export SHELL=/usr/bin/fish
  run answer "${FRESH[@]}" y
  [ "$status" -eq 0 ]
  grep -qxF "claude-accounts shell-init fish | source" "$HOME/.config/fish/config.fish"
}

@test "setup uses the rc file and syntax for bash and zsh" {
  run answer "${FRESH[@]}" y
  grep -qxF 'eval "$(claude-accounts shell-init bash)"' "$HOME/.bashrc"
  rm "$XDG_CONFIG_HOME/claude-accounts/accounts.json"
  export SHELL=/bin/zsh
  run answer "${FRESH[@]}" y
  grep -qxF 'eval "$(claude-accounts shell-init zsh)"' "$HOME/.zshrc"
}

@test "setup doesn't offer the shell-init line when the rc already has it" {
  echo 'eval "$(claude-accounts shell-init bash)"' > "$HOME/.bashrc"
  # no answer for the rc question: setup must not ask it
  run answer "${FRESH[@]}"
  [ "$status" -eq 0 ]
  [ "$(grep -c shell-init "$HOME/.bashrc")" -eq 1 ]
}

@test "setup stops cleanly when input runs out" {
  run answer "" ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"no answer"* ]]
  [ ! -e "$XDG_CONFIG_HOME/claude-accounts/accounts.json" ]
}
