# Wsl Fleet

Wsl Fleet is a WSL distribution manager written in PowerShell 7. It builds a
distro from a Docker recipe, and lets you open it, restart it, copy it, archive
it or remove it.

Optional packs install the tools a project needs inside the instance - the
shell, Python, the Docker gmake targets, the Google Cloud CLI.

Every action is available both as a GUI and as a CLI.

## Features

- **Build an instance** - from a recipe, a Dockerfile, a saved image, or a
  registry reference - with an onboarding script and the packs it should carry
- **Manage the packs** of an instance, from the catalogue
- **The recipes themselves** - Dockerfiles, onboarding scripts, recipes:
  uploaded, edited, deleted - and the saved images
- **Live with an instance** - restart it, open a shell, change the look (icon,
  font, colours), duplicate it, compact it, register it with Docker Desktop or
  take it out
- **Archive and restore** - to a named archive, and back
- **Remove** an instance, and delete an archive
- **The fleet** - move the working folder (migrate), open the Windows-wide
  `.wslconfig`

---

## Prerequisites

- Windows 10/11.
- **WSL2** - `wsl --install` on a machine without it; every instance lives
  inside it.
- **Docker Desktop** (or Docker Engine running via WSL).
- **PowerShell 7** (`winget install Microsoft.PowerShell`), allowed to run
  local scripts — check it:
  ```powershell
  Get-ExecutionPolicy # Should return RemoteSigned or Unrestricted
  ```
  If it returns `Restricted` or `AllSigned` run:

  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

---

## Quick Start

Make sure Docker Desktop is running before you start.

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/JustVNRR/wsl-fleet.git
   cd wsl-fleet
   ```
2. **Start it** - the script asks whether you want the window or the console:
   ```powershell
   .\wsl-fleet.ps1
   ```

3. **Or launch the same entry as an executable**:
   ```powershell
   .\wsl-fleet.exe     # GUI
   .\wsl-fleet.exe cli # CLI
   ```
---

## Optional Tooling (Packs)
| Pack | Start here | Main targets |
| :--- | :--- | :--- |
| `oh_my_shell` | [The shell](src/distro/packs/oh_my_shell/README.md) | `wsl_config`, `wsl_status`, `env_*`, `packs_list` - and the whole shell: aliases, bindings, navigation, `fcheat`, `gmake` |
| `oh_my_code` | [Claude Code](src/distro/packs/oh_my_code/README.md) | `claude_status`, `claude_profile`, `claude_edit_profiles`, `claude_project` |
| `hide_my_ops` | [Project targets](src/distro/packs/hide_my_ops/README.md) | `docker_*`, `gh_pr_*` |
| `oh_my_cloud` | [The Google Cloud CLI](src/distro/packs/oh_my_cloud/README.md) | `gcp_*`, `gcs_*`, `iam_*`, `bigquery_*`, `cloudrun_*`, `vm_*`, `artifact_registry_*` |
| `oh_my_doc` | [Pandoc & PDF](src/distro/packs/oh_my_doc/README.md) | `pdf_from_md`, `pdf_open`, `docx_from_md`, `csl_from_catalog`, `font_from_*` |
| `oh_my_py` | [Python](src/distro/packs/oh_my_py/README.md) | `lint*`, `test*` |
| `hide_my_scaff` | [Scaffolding](src/distro/packs/hide_my_scaff/README.md) | `fnew`, `copier_project`, `cruft_project`, `ccds_project` |
| `oh_my_peg` | [Vision & OCR](src/distro/packs/oh_my_peg/README.md) | — |
| `oh_my_web` | [Firefox & VPN](src/distro/packs/oh_my_web/README.md) | `fox`, `pfox`, `fox_tweak_*`, `vpn_*` |

---

## Repo Structure

### Instance Manager Structure

```text
├── src/                     # The project's sources
│   ├── distro/              # The image's recipe, and the packs deployed into it
│   │   ├── build/           # The Dockerfile, the onboarding script, the ignore file
│   │   └── packs/           # One folder per pack, each with its README.md
│   ├── windows/             # The instance manager
│   │   ├── Start-Gui.ps1    # The GUI's entry
│   │   ├── Start-Cli.ps1    # The CLI's entry
│   │   ├── Views/           # The XAML views and the console views
│   │   ├── Presenters/      # One presenter per screen
│   │   ├── ViewModels/      # The WPF view models
│   │   ├── Services/        # What the gestures do, over the repositories
│   │   ├── Repositories/    # wsl.exe, the instance folders, Terminal, Docker, the packs
│   │   ├── Runners/         # The long gestures, one process each
│   │   ├── Entities/        # The domain types
│   │   ├── Dtos/            # What crosses the layers
│   │   ├── Mappers/         # Entity to DTO, and back
│   │   └── Tools/           # Shared helpers, native calls, the icon drawing
├── assets/
│   ├── themes/              # The GUI's themes
│   ├── fonts/               # The GUI's fonts
│   ├── dockerfiles/         # Seeded on first use from src\distro\build
│   ├── packs/               # Seeded on first use from src\distro\packs
│   └── dockerimages/        # Saved Docker images
├── docs/
│   ├── user-cli.md          # The console's guide
│   └── user-gui.md          # The window's guide
├── tests/                   # The suites that run the code
├── .github/
│   └── workflows/
│       ├── ci.yml           # Static checks, then the code suites on Windows
│       └── image.yml        # Rootfs image build (push/PR + weekly, catches upstream drift)
├── wsl-fleet.ps1            # The entry: one command at the root, the scripts in src\windows
├── .gitattributes           # Enforces strict LF line endings for shell scripts
├── .gitignore               # Prevents committing build artifacts (*.tar, *.vhdx)
├── LICENSE                  # MIT
└── README.md
```

### WSL Instance structure

Written by the build or by `gmake` targets. None of it is versioned, and
deleting the distro deletes all of it.

```text
~/.config/zsh/               # = the oh_my_shell pack's config/ folder, from the repository
├── gmake/
│   ├── .env.global          # Shared defaults (gmake env_global_enable)
│   ├── env.global.sample    # The header every .env.global opens on
│   ├── env.project.sample   # The header a project's .env opens on
│   ├── Makefile
│   └── make/*.mk            # the shell's modules
└── .zshrc, modules, lib/, prompts/, cheatsheets/

~/.config/packs/             # A pack lands here, its files and its tool together:
└── oh_my_cloud/             # added and removed by `.\wsl-fleet.ps1 manage_packs`.
                             # ~/.zshrc reads its zsh/ here, gmake its make/ - nothing is copied

~/projects/<project>/        # One directory per project
├── .env.sample              # The template's list of variables (copied once to .env)
├── .env                     # This project's identity (filled in by you; env_project_enable tops it up)
├── .envrc                   # direnv hook (the template's, or written by the scaffolding)
└── .venv/

~/.local/share/oh-my-zsh/    # Cloned at build time, or by the oh_my_shell pack's install
~/.local/bin/                # the packs that install outside apt: uv and its
                             # tools (python), the claude launcher (claude)
~/.local/share/uv/           # the Python builds it downloaded, and their environments
~/.config/gcloud/            # The two GCP logins (gcp_auth_cli, gcp_auth_libs)
/etc/wsl.conf                # Default user, automount, interop (onboarding.sh; reopened by gmake wsl_config)
/etc/resolv.conf             # Name servers (WSL's, or yours; reopened by gmake dns_resolve)
/etc/fstab                   # Mounts to apply at start (reopened by gmake fstab_config)
```

### Pack structure

```text
<pack>/
├── pack.conf              # the catalogue's line: description, family, requires, packages
├── install.sh             # what manage_packs runs inside the instance
├── install_root.sh        # the root half: run as WSL's root, before install.sh
├── remove.sh              # what runs before the folder goes
├── remove_root.sh         # the root half of the removal
├── make/*.mk              # its gmake targets, loaded as soon as the folder is there
├── zsh/*.zsh              # its shell files, read where they live (never copied)
├── cheatsheets/*.sh       # its fcheat sheets, each with a `# requires:` header
├── env.global.sample      # its share of the shared defaults
├── env.project.sample     # its share of a project's variables
├── config/                # oh_my_shell's own: the shell's files, copied into ~/.config/zsh
└── README.md              # its one page
```
---

### Pack configuration (pack.conf)

```text
| Declaration | What it says |
| :--- | :--- |
| `PACK_DESCRIPTION` | the pack's description |
| `PACK_REQUIRES` | the packs it requires |
| `PACK_VISIBLE` | whether the pack appears on the list of installable packs |
| `PACK_FAMILY` | the apt family it is offered on (default `debian`) |
| `PACK_PACKAGES` | the apt packages it installs |
| `PACK_OUTSIDE_APT` | the tools it installs outside apt, in `~/.local` |
| `PACK_IDENTIFYING_VARS` | the variables refused in a shared `.env.global` |
| `PACK_WELCOME` | the hint `build` prints after the build, when this pack was chosen |
```
---

## User Guide

- [CLI](docs/user-cli.md)
- [GUI](docs/user-gui.md)

---

## License

MIT — see [LICENSE](LICENSE).
