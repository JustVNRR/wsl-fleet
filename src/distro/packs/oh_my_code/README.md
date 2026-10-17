# oh_my_code: Claude Code (CLI)

[← Back to the README](../../../../README.md#optional-tooling-packs)

Claude Code, the agentic CLI, installed under the user's own `~/.local` from Anthropic's script: no apt package, no root, no Node.

**Type:** installable

## Packages

| Package | What it is |
| :--- | :--- |

Outside apt:

| Package | What it is |
| :--- | :--- |
| `claude` | the Claude Code CLI, from Anthropic's script |

## Requires

oh_my_shell.

## gmake

| Target | What it does |
| :--- | :--- |
| `claude_status` | Show Claude Code here: version, the versions on disk, the provider in force |
| `claude_profile` | Choose the provider this instance talks to, and apply it |
| `claude_edit_profiles` | Open the dictionary of providers in the editor |
| `claude_project` | Pick a project of this instance, and reopen its last session |

```sh
gmake claude_status
gmake claude_profile
```

## Environment

Global (`.env.global`) - `gmake env_global_enable` copies the block into
`~/.config/zsh/gmake/.env.global`, filling only what is missing:

| Variable | What it means |
| :--- | :--- |
| `CLAUDE_PROFILE` | the provider this instance talks to - an entry of `~/.config/claude/profiles.json` (`claude_profile` writes it) |

```sh
CLAUDE_PROFILE=claude
```

## Cheatsheets

Offered by `fcheat` (Alt+Z) beside every installed pack's:

| Sheet | What it covers |
| :--- | :--- |
| `claude` | what the instance has, the provider, the projects, what takes the space, the first run and stuck cases - shown while `claude` is installed |
