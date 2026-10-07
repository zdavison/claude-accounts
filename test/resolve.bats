#!/usr/bin/env bats
load helpers

setup() {
  setup_home
  two_accounts
  login "$HOME/.claude.json" me@example.com
  login "$HOME/.claude-work/.claude.json" me@acme.com
}

@test "unset CLAUDE_CONFIG_DIR outside account dirs is the default account" {
  run resolve --cwd "$HOME/elsewhere"
  [ "$status" -eq 0 ]
  [ "$(field account)" = personal ]
  [ "$(field expected)" = personal ]
  [ "$(field mismatch)" = false ]
  [ "$(field text)" = "🟢 PERSONAL · me@example.com" ]
  [ "$(field level)" = ok ]
  [ "$(field configDir)" = "$HOME/.claude" ]
}

@test "work config dir inside a work dir is work, with the work email" {
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run resolve --cwd "$HOME/Work/acme/app"
  [ "$(field account)" = work ]
  [ "$(field expected)" = work ]
  [ "$(field text)" = "🔴 WORK · me@acme.com" ]
}

@test "defaults to the current directory when --cwd is not given" {
  cd "$HOME/Work/acme/app"
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run resolve
  [ "$(field expected)" = work ]
}

@test "personal session in a work dir is a mismatch" {
  run resolve --cwd "$HOME/Work/acme"
  [ "$(field mismatch)" = true ]
  [ "$(field level)" = warn ]
  [ "$(field expectedLabel)" = WORK ]
  [ "$(field text)" = "⚠ PERSONAL, but this dir belongs to WORK" ]
}

@test "trailing slash on CLAUDE_CONFIG_DIR still matches" {
  CLAUDE_CONFIG_DIR="$HOME/.claude-work/" run resolve --cwd "$HOME/Work/acme"
  [ "$(field account)" = work ]
  [ "$(field mismatch)" = false ]
}

@test "trailing slash and ~ in config dirs still match" {
  write_config '{"default":"personal","accounts":{"personal":{"configDir":"~/.claude"},"work":{"configDir":"~/.claude-work/","dirs":["~/Work/acme/"]}}}'
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run resolve --cwd "$HOME/Work/acme"
  [ "$(field account)" = work ]
  [ "$(field expected)" = work ]
}

@test "a sibling dir sharing a prefix does not belong to the account" {
  run resolve --cwd "$HOME/Work/acme-other"
  [ "$(field expected)" = personal ]
  [ "$(field mismatch)" = false ]
}

@test "a cwd reached through a symlink still belongs to the account" {
  ln -s "$HOME/Work/acme" "$HOME/acme-link"
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run resolve --cwd "$HOME/acme-link"
  [ "$(field expected)" = work ]
  [ "$(field mismatch)" = false ]
}

@test "paths with spaces match" {
  write_config '{"default":"personal","accounts":{"personal":{"configDir":"~/.claude"},"work":{"configDir":"~/claude work","dirs":["~/My Work/acme"]}}}'
  mkdir -p "$HOME/My Work/acme/x"
  login "$HOME/claude work/.claude.json" me@acme.com
  CLAUDE_CONFIG_DIR="$HOME/claude work" run resolve --cwd "$HOME/My Work/acme/x"
  [ "$(field account)" = work ]
  [ "$(field expected)" = work ]
  [ "$(field email)" = me@acme.com ]
}

@test "the longest matching dir wins" {
  write_config '{"default":"personal","accounts":{"personal":{"configDir":"~/.claude"},"work":{"configDir":"~/.claude-work","dirs":["~/Work"]},"client":{"configDir":"~/.claude-client","dirs":["~/Work/client"]}}}'
  mkdir -p "$HOME/Work/client/app"
  run resolve --cwd "$HOME/Work/client/app"
  [ "$(field expected)" = client ]
}

@test "label and emoji default from the name" {
  write_config '{"default":"personal","accounts":{"personal":{"configDir":"~/.claude"},"client":{"dirs":["~/Work/acme"]}}}'
  CLAUDE_CONFIG_DIR="$HOME/.claude-client" run resolve --cwd "$HOME/Work/acme"
  [ "$(field account)" = client ]
  [ "$(field text)" = "🔵 CLIENT · not logged in" ]
}

@test "a config dir no account uses is unknown and a mismatch" {
  CLAUDE_CONFIG_DIR="$HOME/.claude-other" run resolve --cwd "$HOME/elsewhere"
  [ "$(field account)" = null ]
  [ "$(field label)" = .claude-other ]
  [ "$(field mismatch)" = true ]
  [ "$(field text)" = "⚠ .claude-other, but this dir belongs to PERSONAL" ]
}

@test "without a config it still shows the config dir and email, with no mismatch" {
  rm "$XDG_CONFIG_HOME/claude-accounts/accounts.json"
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run resolve --cwd "$HOME/Work/acme"
  [ "$(field account)" = null ]
  [ "$(field expected)" = null ]
  [ "$(field mismatch)" = false ]
  [ "$(field text)" = "❔ .claude-work · me@acme.com" ]
}

@test "not logged in is a warning" {
  rm "$HOME/.claude-work/.claude.json"
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run resolve --cwd "$HOME/Work/acme"
  [ "$(field loggedIn)" = false ]
  [ "$(field level)" = warn ]
  [ "$(field text)" = "🔴 WORK · not logged in" ]
}

@test "invalid config JSON is reported, never guessed" {
  write_config '{not json'
  run resolve --cwd "$HOME/elsewhere"
  [ "$status" -eq 0 ]
  [[ "$(field error)" == "invalid config: "* ]]
  [[ "$(field text)" == "⚠ account unknown (invalid config: "* ]]
}

@test "an unreadable state file is reported" {
  printf '{broken' > "$HOME/.claude.json"
  run resolve --cwd "$HOME/elsewhere"
  [[ "$(field error)" == "cannot read $HOME/.claude.json" ]]
}

@test "missing jq still prints JSON" {
  mkdir -p "$BATS_TEST_TMPDIR/nojq"
  for t in dirname bash; do ln -s "$(command -v $t)" "$BATS_TEST_TMPDIR/nojq/$t"; done
  run env PATH="$BATS_TEST_TMPDIR/nojq" "$TEST_BASH" "$RESOLVE" --cwd "$HOME"
  [ "$status" -eq 0 ]
  [ "$output" = '{"account":null,"label":"?","emoji":"⚠","email":null,"loggedIn":false,"configDir":null,"expected":null,"expectedLabel":null,"mismatch":false,"error":"jq is not installed","level":"warn","text":"⚠ account unknown (jq is not installed)"}' ]
}
