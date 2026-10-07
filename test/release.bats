#!/usr/bin/env bats
load helpers

setup() {
  setup_home
  # A scratch copy of the repo, so set-version can commit without touching the real one
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/scripts" "$REPO/plugin/account-badge/.claude-plugin"
  cp "$ROOT/package.json" "$REPO/"
  cp "$ROOT/plugin/account-badge/.claude-plugin/plugin.json" "$REPO/plugin/account-badge/.claude-plugin/"
  cp "$ROOT/scripts/set-version" "$REPO/scripts/"
  git -C "$REPO" init -q
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  git -C "$REPO" add -A
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q -m base
  jq '.version = "1.2.3"' "$REPO/package.json" > "$REPO/p" && mv "$REPO/p" "$REPO/package.json"
  jq '.version = "1.2.3"' "$REPO/plugin/account-badge/.claude-plugin/plugin.json" > "$REPO/p" \
    && mv "$REPO/p" "$REPO/plugin/account-badge/.claude-plugin/plugin.json"
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q -am "at 1.2.3"
}

set_version() {
  (cd "$REPO" && GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t \
    GIT_COMMITTER_EMAIL=t@example.com "$TEST_BASH" scripts/set-version "$@")
}
versions() {
  echo "$(jq -r .version "$REPO/package.json") $(jq -r .version "$REPO/plugin/account-badge/.claude-plugin/plugin.json")"
}

@test "the npm package and the plugin carry the same version" {
  [ "$(jq -r .version "$ROOT/package.json")" = "$(jq -r .version "$ROOT/plugin/account-badge/.claude-plugin/plugin.json")" ]
}

@test "set-version patch bumps both files and commits the release" {
  run set_version patch
  [ "$status" -eq 0 ]
  [ "$output" = 1.2.4 ]
  [ "$(versions)" = "1.2.4 1.2.4" ]
  [ "$(git -C "$REPO" log -1 --format=%s)" = "chore: release v1.2.4" ]
  [ -z "$(git -C "$REPO" status --porcelain)" ]
}

@test "set-version minor and major reset the lower parts" {
  run set_version minor
  [ "$output" = 1.3.0 ]
  run set_version major
  [ "$output" = 2.0.0 ]
  [ "$(versions)" = "2.0.0 2.0.0" ]
}

@test "set-version takes an explicit version, with or without a v" {
  run set_version v3.1.4
  [ "$output" = 3.1.4 ]
  [ "$(versions)" = "3.1.4 3.1.4" ]
}

@test "set-version rejects anything else and changes nothing" {
  run set_version banana
  [ "$status" -ne 0 ]
  [[ "$output" == *"patch, minor, major or a version like 1.2.3"* ]]
  [ "$(versions)" = "1.2.3 1.2.3" ]
  [ "$(git -C "$REPO" log -1 --format=%s)" = "at 1.2.3" ]
}

@test "set-version to the current version is a no-op" {
  run set_version 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = 1.2.3 ]
  [ "$(git -C "$REPO" log -1 --format=%s)" = "at 1.2.3" ]
}
