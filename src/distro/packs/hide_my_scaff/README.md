# hide_my_scaff

[← Back to the README](../../../../README.md#optional-tooling-packs)

Creating a project with the `fnew` picker, the three gmake targets it delegates to (copier, cruft, ccds), and the `.env` every project wants.

The scaffolding tools are not installed - `uvx` takes each from uv's cache the first time a target runs.

**Type:** hidden - never offered; it arrives with the packs that require it.

## Packages

| Package | What it is |
| :--- | :--- |

Outside apt:

| Package | What it is |
| :--- | :--- |
| `uv` | the tool runner - `uvx` fetches copier, cruft and ccds on first use |

## Required by

oh_my_py.

## gmake

| Target | What it does |
| :--- | :--- |
| `copier_project` | Scaffold a project with Copier from `~/projects` (fnew picker) |
| `cruft_project` | Scaffold a project with Cruft/Cookiecutter from `~/projects` (fnew picker) |
| `ccds_project` | Scaffold a project with CCDS v2 from `~/projects` (fnew picker) |
| `finish_scaffold` | The step every scaffold target ends on: runs the template pack's own after-copy step |

```sh
gmake copier_project PROJECT_NAME=<name> PROJECT_TEMPLATE_REPO=<url>    # skip the picker
```

## Environment

Global (`.env.global`) - `gmake env_global_enable` copies the block into
`~/.config/zsh/gmake/.env.global`, filling only what is missing:

| Variable | What it means |
| :--- | :--- |
| `TEMPLATE_PACK` | the pack whose step runs after a direct `copier_project`/`cruft_project` call (`oh_my_py` - its step is `init_venv`) |
| `PROJECT_TEMPLATE_REPO` | optional default template for direct calls |
| `PROJECT_TEMPLATE_VERSION` | optional pinned version for direct calls |

```sh
TEMPLATE_PACK=oh_my_py
```

## Shell commands

| Command | What it does |
| :--- | :--- |
| `fnew` | Pick a template from every installed pack's catalog, and scaffold from it |

```sh
fnew                          # pick a template from the catalogs
fnew gh:owner/repo cruft      # straight from a URL the catalog does not list
```

## Cheatsheets

Offered by `fcheat` (Alt+Z) beside every installed pack's:

| Sheet | What it covers |
| :--- | :--- |
| `project` | `fnew` and the three targets it delegates to |
