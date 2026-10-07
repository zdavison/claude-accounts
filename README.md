# claude-accounts

Use several Claude Code accounts on one machine — personal, work, a client — with the account
chosen by directory and always visible.

- Under `~/Work/acme`, `claude` and Zed's Claude agent use the work account; everywhere else, personal.
- The terminal shows `🔴 WORK · you@acme.com` above the prompt. Zed shows it as a Notice on every prompt.
- If a session is on the wrong account for its directory, both say so:
  `⚠ PERSONAL, but this dir belongs to WORK`.

In Claude Code, the badge sits above the prompt:

![Claude Code in a personal directory: 🟢 PERSONAL · you@example.com](assets/cli-personal.png)
![Claude Code in a work directory: 🔴 WORK · you@acme.com](assets/cli-work.png)

In Zed, every prompt gets a Notice naming the account:

![Zed in a work project: Notice: 🔴 WORK · you@acme.com](assets/zed-work.png)
![Zed in a personal project: Notice: 🟢 PERSONAL · you@example.com](assets/zed-personal.png)

## Requirements

macOS or Linux, [mise](https://mise.jdx.dev) activated in your shell, jq, and Claude Code 2.1.289 or later.

## Install

```sh
mise use -g npm:@zdavison/claude-accounts      # or: npm install -g @zdavison/claude-accounts
export CLAUDE_ACCOUNTS_MARKETPLACE=zdavison/claude-accounts   # add to your shell rc
```
The second line makes `apply` install the plugin from GitHub, so `claude plugin update` keeps it
current. Without it, the plugin is installed from the CLI's own install directory.

Or clone the repo and put its `bin/` on your `PATH` (the checkout is then the plugin source).

To upgrade, upgrade the package, then run `claude plugin update account-badge@account-switcher`
once per account (with that account's `CLAUDE_CONFIG_DIR`).

## Set up

```sh
claude-accounts setup
```
It asks which accounts you want and, for each one, its label, emoji, Claude config dir and the
directories it owns. Then it applies the config, offers to sign in each account, and offers to
add the Zed wrapper to your shell rc. Run it again to add accounts or start over.

![claude-accounts setup walking through a personal and a work account](assets/setup.png)

Afterwards, open a new shell and check everything with `claude-accounts doctor`. In a work
directory it reports the work account; anywhere else, the personal one:

![claude-accounts doctor in a personal and a work directory](assets/doctor.png)

To script it instead (e.g. in a dotfiles install script):
```sh
claude-accounts init                                   # personal account, ~/.claude
claude-accounts add work --dir ~/Work/acme --emoji 🔴  # uses ~/.claude-work
claude-accounts apply
claude-accounts login work
```
and add the Zed wrapper to your shell rc:
```sh
claude-accounts shell-init fish | source          # fish
eval "$(claude-accounts shell-init bash)"         # bash / zsh (use zsh for zsh)
```

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
| `setup` | Interactive walkthrough: choose accounts, apply, sign in, shell rc |
| `init` | Create the config with a personal account, no questions |
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

## Releasing

Releases go to npm and GitHub with [pubz](https://github.com/zdavison/pubz). Before releasing,
check what the tests can't:

1. Terminal: the badge shows the right account and email for two accounts.
2. Zed: the Notice shows the right account in a default-account project and in a work project.
3. Mismatch: in a work dir, `env -u CLAUDE_CONFIG_DIR claude` shows `⚠ PERSONAL, but this dir belongs to WORK`.

Then run the **publish** workflow (Actions → publish → patch/minor/major). It runs the tests,
sets the version in `package.json` and the plugin with `scripts/set-version`, and runs
`pubz --ci`, which publishes to npm, tags, and creates the GitHub release.

To release from your machine instead: `bunx pubz --version "$(scripts/set-version patch)"`.
The plugin's version must change with every release: Claude Code caches plugins by version.

The publish workflow uses npm trusted publishing, which can only be set up once the package
exists on npm. Do the first release from your machine (`npm login` first), then add the
workflow under the package's Settings → Trusted Publisher on npmjs.com
(repository `zdavison/claude-accounts`, workflow `publish.yml`).
