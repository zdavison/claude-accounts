#!/usr/bin/env bats
load helpers

setup() {
  setup_home
  two_accounts
  login "$HOME/.claude.json" me@example.com
  NOTICE="$ROOT/plugin/account-badge/scripts/notice"
}

hook() { printf '{"cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"hi"}' "$1" | "$TEST_BASH" "$NOTICE"; }

@test "agent clients get the account as a Notice ending in a newline" {
  CLAUDE_CODE_ENTRYPOINT=sdk-ts run hook "$HOME/elsewhere"
  [ "$status" -eq 0 ]
  [ "$(jq -r .systemMessage <<<"$output")" = "🟢 PERSONAL · me@example.com" ]
  [ "$(jq -j .systemMessage <<<"$output" | tail -c 1 | od -An -c | tr -d ' ')" = '\n' ]
}

@test "the Notice uses the hook's cwd, so mismatches show" {
  CLAUDE_CODE_ENTRYPOINT=sdk-ts run hook "$HOME/Work/acme"
  [ "$(jq -r .systemMessage <<<"$output")" = "⚠ PERSONAL, but this dir belongs to WORK" ]
}

@test "the terminal gets no Notice, because the band shows it" {
  CLAUDE_CODE_ENTRYPOINT=cli run hook "$HOME/elsewhere"
  [ "$output" = '{}' ]
}

@test "label_replies adds the reply instruction" {
  CLAUDE_CODE_ENTRYPOINT=cli CLAUDE_PLUGIN_OPTION_LABEL_REPLIES=true run hook "$HOME/elsewhere"
  [ "$(jq -r .hookSpecificOutput.hookEventName <<<"$output")" = UserPromptSubmit ]
  [[ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" == *'"🟢 PERSONAL · me@example.com"'* ]]
}
