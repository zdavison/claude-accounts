#!/usr/bin/env bats
load helpers

setup() {
  setup_home
  stub_tools
}

@test "init creates a personal default and is a no-op the second time" {
  run cli init
  [ "$status" -eq 0 ]
  [ "$(config_json | jq -c .)" = '{"default":"personal","accounts":{"personal":{"label":"PERSONAL","emoji":"🟢","configDir":"~/.claude"}}}' ]
  run cli init
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "commands other than init need a config" {
  run cli add work
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude-accounts init"* ]]
}

@test "add stores dirs absolute with ~" {
  cli init
  mkdir -p "$HOME/Work/acme"
  cd "$HOME/Work"
  run cli add work --dir acme --dir "$HOME/Work/other/" --label Job --emoji 🔴
  [ "$status" -eq 0 ]
  [ "$(config_json | jq -c .accounts.work)" = '{"dirs":["~/Work/acme","~/Work/other"],"label":"Job","emoji":"🔴"}' ]
}

@test "add rejects a duplicate name" {
  cli init
  cli add work --dir ~/Work/acme
  run cli add work --dir ~/Work/b
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "add rejects overlapping dirs and leaves the config unchanged" {
  cli init
  cli add work --dir "$HOME/Work"
  before="$(config_json)"
  run cli add client --dir "$HOME/Work/client"
  [ "$status" -eq 1 ]
  [[ "$output" == *"overlaps"* ]]
  [ "$(config_json)" = "$before" ]
}

@test "add rejects a name that is not lowercase letters, digits and -" {
  cli init
  run cli add "Work Stuff"
  [ "$status" -eq 1 ]
  [[ "$output" == *"account names use"* ]]
}

@test "an option without its value fails instead of hanging" {
  cli init
  run cli add work --dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"--dir needs a value"* ]]
}

@test "remove refuses the default account" {
  cli init
  run cli remove personal
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot remove the default account"* ]]
}

@test "remove deletes the account but keeps its config dir" {
  cli init
  cli add work --dir "$HOME/Work/acme"
  mkdir -p "$HOME/.claude-work"
  run cli remove work
  [ "$status" -eq 0 ]
  [ "$(config_json | jq '.accounts | has("work")')" = false ]
  [ -d "$HOME/.claude-work" ]
}

@test "set changes a field, and dirs+/dirs- add and remove dirs with validation" {
  cli init
  cli add work --dir "$HOME/Work/acme"
  cli add client
  run cli set work label JOB
  [ "$status" -eq 0 ]
  [ "$(config_json | jq -r .accounts.work.label)" = JOB ]
  run cli set client dirs+ "$HOME/Work/acme/sub"
  [ "$status" -eq 1 ]
  [[ "$output" == *"overlaps"* ]]
  run cli set work dirs+ "$HOME/Work/b"
  [ "$(config_json | jq -c .accounts.work.dirs)" = '["~/Work/acme","~/Work/b"]' ]
  run cli set work dirs- "$HOME/Work/acme/"
  [ "$(config_json | jq -c .accounts.work.dirs)" = '["~/Work/b"]' ]
  run cli set work colour red
  [ "$status" -eq 1 ]
}

@test "the default account cannot be given dirs" {
  cli init
  run cli set personal dirs+ "$HOME/Work"
  [ "$status" -eq 1 ]
  [[ "$output" == *"default account (personal) cannot have dirs"* ]]
}

@test "add resolves . and .. so the stored dir matches and overlaps are caught" {
  cli init
  mkdir -p "$HOME/Work/acme" "$HOME/Work/acme-other"
  cd "$HOME/Work/acme"
  run cli add work --dir .
  [ "$status" -eq 0 ]
  [ "$(config_json | jq -c .accounts.work.dirs)" = '["~/Work/acme"]' ]
  run cli add w2 --dir "$HOME/Work/acme-other/.."
  [ "$status" -eq 1 ]
  [[ "$output" == *"overlaps"* ]]
}

@test "a dir that does not exist cannot use . or .." {
  cli init
  run cli add work --dir "$HOME/nope/../x"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
  [ "$(config_json | jq '.accounts | has("work")')" = false ]
}

@test "a symlinked dir is stored as its real path, so physical cwds match" {
  cli init
  mkdir -p "$HOME/real/proj" "$HOME/Work"
  ln -s "$HOME/real/proj" "$HOME/Work/link"
  run cli add work --dir "$HOME/Work/link"
  [ "$(config_json | jq -c .accounts.work.dirs)" = '["~/real/proj"]' ]
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run resolve --cwd "$HOME/real/proj"
  [ "$(field expected)" = work ]
  CLAUDE_CONFIG_DIR="$HOME/.claude-work" run resolve --cwd "$HOME/Work/link"
  [ "$(field expected)" = work ]
}
