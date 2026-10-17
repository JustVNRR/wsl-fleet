# oh_my_py: Python 3, uv and ruff

[← Back to the README](../../../../README.md#optional-tooling-packs)

Python for a project's life: uv manages the interpreters and the virtualenvs, ruff lints and formats, and the targets below drive the linter and the test suites.

The system carries only the build headers most Python wheels compile against.

**Type:** installable

## Packages

| Package | What it is |
| :--- | :--- |
| `build-essential` | the compiler and headers Python wheels build against |
| `python3-dev` | the Python headers |
| `libffi-dev` | the FFI headers |
| `libssl-dev` | the TLS headers |

Outside apt:

| Package | What it is |
| :--- | :--- |
| `uv` | the Python and virtualenv manager |

## Requires

oh_my_shell, hide_my_ops, hide_my_scaff.

## gmake

| Target | What it does |
| :--- | :--- |
| `lint` | Run all checks (Python + shell), non-destructive |
| `lint-py` | Check Python code with ruff (optional: `PY_TARGETS="..."`) |
| `lint-sh` | Check shell scripts with shellcheck (optional: `SH_TARGETS="..."`) |
| `lint-format` | Auto-fix and format Python code with ruff (optional: `PY_TARGETS="..."`) |
| `test` | Run the whole test suite |
| `test-fast` | Run fast tests only, without external infrastructure (CI lane) |
| `test-functional` | Run functional tests (a real local infrastructure is needed, e.g. `.env`, Docker, model) |
| `test-gcp` | Run tests hitting a real GCP environment (test/staging/prod) |

```sh
gmake lint            # check the project (ruff + shellcheck)
gmake test-fast       # the CI lane
gmake lint-format     # write the fixes
```

## Cheatsheets

Offered by `fcheat` (Alt+Z) beside every installed pack's:

| Sheet | What it covers |
| :--- | :--- |
| `python` | uv: interpreters, virtualenvs, packages, isolated tools, execution - shown while `uv` is installed |
| `test` | the four pytest lanes |
| `lint` | ruff and shellcheck: the checks, and the one that writes |
