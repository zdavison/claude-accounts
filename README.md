# claude-accounts

claude-accounts lets you use more than one Claude Code account on one machine. For example, you can have a personal account and a work account. The directory that you work in selects the account. Claude Code and Zed always show the account that a session uses.

- In `~/Work/acme`, the `claude` CLI and the Claude agent in Zed use the work account. In all other directories, they use the personal account.
- The CLI shows the account badge `🔴 WORK · you@acme.com` above the prompt.
- Zed shows the account badge as a Notice for each prompt.
- If a session uses the wrong account for its directory, the badge shows a warning: `⚠ PERSONAL, but this dir belongs to WORK`.

The CLI shows the badge above the prompt:

![Claude Code in a personal directory: 🟢 PERSONAL · you@example.com](assets/cli-personal.png)
![Claude Code in a work directory: 🔴 WORK · you@acme.com](assets/cli-work.png)

Zed shows the badge as a Notice:

![Zed in a work project: Notice: 🔴 WORK · you@acme.com](assets/zed-work.png)
![Zed in a personal project: Notice: 🟢 PERSONAL · you@example.com](assets/zed-personal.png)

## Requirements

- macOS or Linux
- [mise](https://mise.jdx.dev), activated in your shell
- jq
- Claude Code 2.1.289 or later

## Install

1. Install the package:

   ```sh
   mise use -g npm:@zdavison/claude-accounts
   ```

   You can also use npm: `npm install -g @zdavison/claude-accounts`.

2. Add this line to your shell rc file:

   ```sh
   export CLAUDE_ACCOUNTS_MARKETPLACE=zdavison/claude-accounts
   ```

   With this variable, `apply` installs the plugin from GitHub. Thus `claude plugin update` can update the plugin. Without this variable, `apply` installs the plugin from the package directory.

You can also clone the repository and add its `bin/` directory to your `PATH`. Then the clone is the source of the plugin.

To upgrade:

1. Upgrade the package.
2. For each account, run `claude plugin update account-badge@account-switcher` with the `CLAUDE_CONFIG_DIR` of that account.

## Set up

Run the setup command:

```sh
claude-accounts setup
```

The setup command asks which accounts you want. For each account, it asks for these values:

- the label and the emoji
- the config directory
- the directories that the account owns

Then the setup command does these steps:

1. It applies the configuration.
2. It offers to sign in to each account.
3. It offers to add the Zed wrapper to your shell rc file.

To add accounts later, run the setup command again. You can also start again from an empty configuration.

![claude-accounts setup with a personal account and a work account](assets/setup.png)

When the setup command is done, open a new shell. Then run `claude-accounts doctor` to check the setup. In a work directory, the doctor command shows the work account. In all other directories, it shows the personal account.

![claude-accounts doctor in a personal directory and in a work directory](assets/doctor.png)

### Set up from a script

To set up from a script, for example a dotfiles install script, use these commands:

```sh
claude-accounts init                                   # personal account in ~/.claude
claude-accounts add work --dir ~/Work/acme --emoji 🔴  # config directory ~/.claude-work
claude-accounts apply
claude-accounts login work
```

Then add the Zed wrapper to your shell rc file:

```sh
claude-accounts shell-init fish | source          # fish
eval "$(claude-accounts shell-init bash)"         # bash
eval "$(claude-accounts shell-init zsh)"          # zsh
```

## How it works

Each account has its own Claude Code config directory. Claude Code reads the config directory from `CLAUDE_CONFIG_DIR`.

The `apply` command writes `CLAUDE_CONFIG_DIR` into a `mise.local.toml` file in each directory of an account. Then mise sets `CLAUDE_CONFIG_DIR` for the CLI. Zed loads the shell environment of each project. Thus mise also sets `CLAUDE_CONFIG_DIR` for Zed.

One Zed process serves all windows. That process keeps the environment from when it started. Thus the Zed wrapper starts Zed without `CLAUDE_CONFIG_DIR`. As a result, the account of one project does not go into other projects.

The `apply` command installs the `account-badge` plugin into each account. The plugin reads the `CLAUDE_CONFIG_DIR` of the session and the email of the signed-in account. Thus the badge always shows the account that the session uses.

The configuration file is `~/.config/claude-accounts/accounts.json`. claude-accounts does not change these files:

- your `statusLine` setting
- your `CLAUDE.md` files
- your `settings.json` files
- a `mise.toml` file in your repository

## Commands

| Command | Description |
|---|---|
| `setup` | Ask for the accounts, then apply them, sign in, and set up the shell rc file |
| `init` | Create the configuration with a personal account, with no questions |
| `add <name> [--dir PATH]… [--label L] [--emoji E] [--config-dir D]` | Add an account |
| `remove <name>` | Remove an account. Its config directory stays on disk. |
| `set <name> label\|emoji\|configDir\|dirs+\|dirs- <value>` | Change an account |
| `apply [--marketplace SRC]` | Apply the configuration. You can run it again safely. |
| `which [DIR] [--json]` | Show the account in use in this directory or in DIR, and the expected account |
| `login <name>` | Sign in to an account |
| `shell-init fish\|bash\|zsh` | Print the Zed wrapper |
| `doctor` | Check the setup and show how to fix problems |

The plugin has one option, `label_replies`. If you set `label_replies`, Claude starts each reply with the account label. The default is off. To set the option, run `/plugin configure account-badge@account-switcher` in Claude Code.

## Limitations

- claude-accounts does not support Windows.
- claude-accounts does not support direnv.
- Zed is the only editor that claude-accounts supports.
- In the Claude Desktop app, the badge can show `⚠ account unknown`. Plugins in the Desktop app cannot run the script that finds the account.

## Releasing

Releases go to npm and GitHub with [pubz](https://github.com/zdavison/pubz).

Before a release, do these manual checks. The tests do not cover them.

1. In the CLI, make sure that the badge shows the correct account and email for two accounts.
2. In Zed, open a project of the default account. Make sure that the Notice shows the default account.
3. In Zed, open a work project. Make sure that the Notice shows the work account.
4. In a work directory, run `env -u CLAUDE_CONFIG_DIR claude`. Make sure that the badge shows `⚠ PERSONAL, but this dir belongs to WORK`.

To make a release, run the **publish** workflow:

1. On GitHub, open **Actions**.
2. Select the **publish** workflow.
3. Select patch, minor, or major, and run the workflow.

The workflow does these steps:

1. It runs the tests.
2. It sets the version in `package.json` and in the plugin with `scripts/set-version`.
3. It runs `pubz --ci`. pubz publishes to npm, adds a tag, and creates the GitHub release.

To make a release from your machine, run `bunx pubz --version "$(scripts/set-version patch)"`.

Each release must change the version of the plugin. Claude Code caches plugins by version.

The publish workflow uses npm trusted publishing. You can set up trusted publishing only after the package exists on npm. Thus, make the first release from your machine:

1. Run `npm login`.
2. Make the release from your machine.
3. On npmjs.com, open the settings of the package. Add a trusted publisher with the repository `zdavison/claude-accounts` and the workflow `publish.yml`.
