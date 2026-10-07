#!/usr/bin/env bats
load helpers

# install.sh runs with a PATH that holds only these stubs (plus real bash and jq), so the test
# controls every tool it can find.
setup() {
  setup_home
  export STUB_LOG="$BATS_TEST_TMPDIR/stub.log" STUB_DIR="$BATS_TEST_TMPDIR"
  : > "$STUB_LOG"
  T="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$T" "$BATS_TEST_TMPDIR/mise-bin" "$BATS_TEST_TMPDIR/npm-prefix/bin"
  ln -s "$(command -v bash)" "$T/bash"
  ln -s "$(command -v jq)" "$T/jq"
  # A claude-accounts that logs its arguments and the first line it reads
  cat > "$BATS_TEST_TMPDIR/fake-ca" <<'SH'
#!/usr/bin/env bash
IFS= read -r line || line="<eof>"
echo "claude-accounts $* <$line>" >> "$STUB_LOG"
SH
  chmod +x "$BATS_TEST_TMPDIR/fake-ca"
  stub mise '
case "$1 $2" in
  "use -g") [ -z "${MISE_FAILS:-}" ] || exit 1; command -p ln -sf "$STUB_DIR/fake-ca" "$STUB_DIR/mise-bin/claude-accounts" ;;
  "which claude-accounts") [ -e "$STUB_DIR/mise-bin/claude-accounts" ] && echo "$STUB_DIR/mise-bin/claude-accounts" || exit 1 ;;
esac'
  stub claude ''
  stub npm '
case "$1" in
  install) command -p ln -sf "$STUB_DIR/fake-ca" "$STUB_DIR/npm-prefix/bin/claude-accounts" ;;
  prefix) echo "$STUB_DIR/npm-prefix" ;;
esac'
  # The answers setup would read from the terminal
  printf 'first answer\n' > "$BATS_TEST_TMPDIR/tty"
  export CLAUDE_ACCOUNTS_TTY="$BATS_TEST_TMPDIR/tty"
  unset CLAUDE_ACCOUNTS_VERSION CLAUDE_ACCOUNTS_NO_SETUP MISE_FAILS
}

# stub NAME BODY: a tool on the test PATH that logs its arguments, then runs BODY
stub() {
  printf '#!/usr/bin/env bash\necho "%s $*" >> "$STUB_LOG"\n%s\nexit 0\n' "$1" "$2" > "$T/$1"
  chmod +x "$T/$1"
}

install() { PATH="$T" /bin/sh "$ROOT/install.sh" </dev/null; }

@test "install.sh installs the package with mise, then runs setup on the terminal" {
  run install
  [ "$status" -eq 0 ]
  grep -qxF "mise use -g npm:@zdavison/claude-accounts@latest" "$STUB_LOG"
  grep -qxF "claude-accounts setup <first answer>" "$STUB_LOG"
}

@test "install.sh installs a pinned version" {
  CLAUDE_ACCOUNTS_VERSION=1.2.3 run install
  grep -qxF "mise use -g npm:@zdavison/claude-accounts@1.2.3" "$STUB_LOG"
}

@test "install.sh falls back to npm when mise can't install the package" {
  MISE_FAILS=1 run install
  [ "$status" -eq 0 ]
  grep -qxF "npm install -g @zdavison/claude-accounts@latest" "$STUB_LOG"
  grep -qxF "claude-accounts setup <first answer>" "$STUB_LOG"
}

@test "install.sh names every missing tool and installs nothing" {
  rm "$T/jq" "$T/claude"
  run install
  [ "$status" -ne 0 ]
  [[ "$output" == *"jq"* ]]
  [[ "$output" == *"claude"* ]]
  ! grep -q '^mise use' "$STUB_LOG"
}

@test "install.sh skips setup without a terminal and says what to run" {
  CLAUDE_ACCOUNTS_TTY="$BATS_TEST_TMPDIR/no-such-tty" run install
  [ "$status" -eq 0 ]
  ! grep -q '^claude-accounts setup' "$STUB_LOG"
  [[ "$output" == *"claude-accounts setup"* ]]
}

@test "install.sh skips setup when asked to" {
  CLAUDE_ACCOUNTS_NO_SETUP=1 run install
  [ "$status" -eq 0 ]
  ! grep -q '^claude-accounts setup' "$STUB_LOG"
  [[ "$output" == *"claude-accounts setup"* ]]
}

@test "install.sh fails clearly when neither mise nor npm can install the package" {
  rm "$T/npm"
  MISE_FAILS=1 run install
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not install"* ]]
}

@test "install.sh skips setup on a later run, when a config already exists" {
  mkdir -p "$XDG_CONFIG_HOME/claude-accounts"
  echo '{}' > "$XDG_CONFIG_HOME/claude-accounts/accounts.json"
  run install
  [ "$status" -eq 0 ]
  grep -qxF "mise use -g npm:@zdavison/claude-accounts@latest" "$STUB_LOG"
  ! grep -q '^claude-accounts setup' "$STUB_LOG"
  [[ "$output" == *"claude-accounts doctor"* ]]
}
