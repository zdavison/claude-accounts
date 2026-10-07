# claude-accounts

Use several Claude Code accounts on one machine — personal, work, a client — with the account
chosen by directory and always visible.

- Under `~/Work/acme`, `claude` and Zed's Claude agent use the work account; everywhere else, personal.
- The terminal shows `🔴 WORK · you@acme.com` above the prompt. Zed shows it as a Notice on every prompt.
- If a session is on the wrong account for its directory, both say so:
  `⚠ PERSONAL, but this dir belongs to WORK`.

## Requirements

macOS or Linux, [mise](https://mise.jdx.dev) activated in your shell, jq, and Claude Code 2.1.289 or later.

## Install

```sh
mise use -g github:OWNER/claude-accounts      # OWNER: the GitHub account hosting this repo
export CLAUDE_ACCOUNTS_MARKETPLACE=OWNER/claude-accounts   # add to your shell rc
```
Or clone the repo and put its `bin/` on your `PATH` (the checkout is then the plugin source).

## Set up

```sh
claude-accounts init                                   # personal account, ~/.claude
claude-accounts add work --dir ~/Work/acme --emoji 🔴  # uses ~/.claude-work
claude-accounts apply
claude-accounts login work
```
Add the Zed wrapper to your shell rc:
```sh
claude-accounts shell-init fish | source          # fish
eval "$(claude-accounts shell-init bash)"         # bash / zsh (use zsh for zsh)
```
Then check everything with `claude-accounts doctor`.

## How it works

- Each account has its own Claude Code config dir (`CLAUDE_CONFIG_DIR`). `apply` writes
  `CLAUDE_CONFIG_DIR` into a `mise.local.toml` in each of the account's directories, so mise sets it
  for the CLI and for Zed (which loads the project's shell environment).
- One Zed process serves all windows and keeps the environment it started with; the shell-init
  wrapper starts Zed without `CLAUDE_CONFIG_DIR` so one project's account never leaks into another.
- `apply` installs the `account-badge` plugin into every account. It reads the real
  `CLAUDE_CONFIG_DIR` and that account's signed-in email, so the badge can't be wrong.
- Config lives in `~/.config/claude-accounts/accounts.json`. The tool never edits your
  `statusLine`, `CLAUDE.md`, `settings.json`, or a committed `mise.toml`.

## Commands

| Command | |
|---|---|
| `init` | Create the config with a personal account |
| `add <name> [--dir PATH]… [--label L] [--emoji E] [--config-dir D]` | Add an account |
| `remove <name>` | Remove an account (its config dir is kept) |
| `set <name> label\|emoji\|configDir\|dirs+\|dirs- <value>` | Change an account |
| `apply [--marketplace SRC]` | Set everything up; safe to re-run |
| `which [DIR] [--json]` | Account in use here (or in DIR) and the one expected |
| `login <name>` | Sign in to an account |
| `shell-init fish\|bash\|zsh` | Print the Zed wrapper |
| `doctor` | Check the setup and say how to fix problems |

Plugin option: `label_replies` (off by default) also asks Claude to start each reply with the
account label. Set it with `/config` in Claude Code.

## Limitations

Windows, direnv, and editors other than Zed are not supported yet. In the Claude Desktop app the
badge may show `⚠ account unknown` because mods there cannot run the resolver.

## Release checklist

1. `bats test` and `claude plugin test` (in `plugin/account-badge`) pass.
2. Terminal: badge shows the right account and email for two accounts.
3. Zed: the Notice shows the right account in a default-account project and in a work project.
4. Mismatch: in a work dir, `env -u CLAUDE_CONFIG_DIR claude` shows `⚠ PERSONAL, but this dir belongs to WORK`.
