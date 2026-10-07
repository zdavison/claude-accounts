#!/usr/bin/env bats
load helpers

setup() {
  setup_home
  stub_tools
  two_accounts
  login "$HOME/.claude.json" me@example.com
  login "$HOME/.claude-work/.claude.json" me@acme.com
}

@test "which reports this shell's account" {
  cd "$HOME/Work/acme"
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run cli which --json
  [ "$(field account)" = work ]
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run cli which
  [ "${lines[0]}" = "🔴 WORK · me@acme.com" ]
}

@test "which DIR reports what mise would give a session started there" {
  cli apply
  run cli which "$HOME/Work/acme" --json
  [ "$(field account)" = work ]
  [ "$(field mismatch)" = false ]
}

@test "login signs in with the account's config dir" {
  run cli login work
  [ "$status" -eq 0 ]
  grep -qxF "claude[$HOME/.claude-work] auth login" "$STUB_LOG"
  run cli login personal
  grep -qxF "claude[unset] auth login" "$STUB_LOG"
}

@test "shell-init wraps the Zed binaries that exist" {
  printf '#!/bin/sh\n' > "$BATS_TEST_TMPDIR/bin/zeditor"; chmod +x "$BATS_TEST_TMPDIR/bin/zeditor"
  run cli shell-init fish
  [ "${lines[0]}" = "set -gx CLAUDE_ACCOUNTS_SHELL_INIT 1" ]
  [[ "$output" == *"function zeditor"* ]]
  [[ "$output" == *"env -u CLAUDE_CONFIG_DIR '$BATS_TEST_TMPDIR/bin/zeditor' \$argv"* ]]
  run cli shell-init bash
  [ "${lines[0]}" = "export CLAUDE_ACCOUNTS_SHELL_INIT=1" ]
  [[ "$output" == *"zeditor() { env -u CLAUDE_CONFIG_DIR '$BATS_TEST_TMPDIR/bin/zeditor' \"\$@\"; }"* ]]
}

@test "the bash wrapper really strips CLAUDE_CONFIG_DIR" {
  printf '#!/bin/sh\necho "dir=${CLAUDE_CONFIG_DIR:-unset}"\n' > "$BATS_TEST_TMPDIR/bin/zeditor"; chmod +x "$BATS_TEST_TMPDIR/bin/zeditor"
  run bash -c "eval \"\$('$TEST_BASH' '$CLI' shell-init bash)\"; CLAUDE_CONFIG_DIR=/x zeditor"
  [ "$output" = "dir=unset" ]
}

@test "doctor passes on a healthy setup" {
  cli apply
  cd "$HOME/elsewhere"
  MISE_SHELL=bash CLAUDE_ACCOUNTS_SHELL_INIT=1 run cli doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *"✘"* ]]
}

@test "doctor reports each problem with its fix" {
  cli apply
  rm "$HOME/.claude-work/.claude.json"
  cd "$HOME/Work/acme"
  STUB_CLAUDE_VERSION=2.1.200 run cli doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✘ Claude Code 2.1.200 is older than 2.1.289"* ]]
  [[ "$output" == *"✘ mise is not activated in this shell"* ]]
  [[ "$output" == *"✘ work: not logged in"*"fix: claude-accounts login work"* ]]
  [[ "$output" == *"✘ ⚠ PERSONAL, but this dir belongs to WORK"* ]]
}

@test "doctor reports a dir whose env is not set up" {
  cli apply
  rm "$HOME/Work/acme/mise.local.toml"
  MISE_SHELL=bash run cli doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✘ work: $HOME/Work/acme uses the default (~/.claude), not $HOME/.claude-work"* ]]
}
