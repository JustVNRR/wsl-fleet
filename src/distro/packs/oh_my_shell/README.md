# oh_my_shell: oh-my-zsh, Starship and daily CLI tools

[← Back to the README](../../../../README.md#optional-tooling-packs)

**Type:** installable

## Packages

| Package | What it is |
| :--- | :--- |
| `apt-transport-https` | apt over HTTPS |
| `apt-utils` | apt's helper tools |
| `ca-certificates` | the TLS roots |
| `curl` | the HTTP client |
| `gnupg` | the keys signed repositories need |
| `wget` | the downloader |
| `locales` | locale data |
| `adduser` | user creation |
| `sudo` | privilege escalation |
| `tzdata` | timezone data |
| `whiptail` | the dialog boxes |
| `zsh` | the shell |
| `nano` | a simple editor |
| `git` | version control |
| `openssh-client` | ssh |
| `strace` | the syscall tracer |
| `lsof` | open files and ports |
| `make` | GNU make |
| `less` | the pager |
| `iputils-ping` | ping |
| `tree` | directory trees |
| `tar` | tar archives |
| `unzip` | zip archives |
| `bzip2` | bzip2 files |
| `unrar` | rar archives |
| `p7zip-full` | 7z archives |
| `gzip` | gzip files |
| `xz-utils` | xz files |
| `zstd` | zstd files |
| `bat` | cat with syntax colours |
| `direnv` | per-directory environments |
| `eza` | the ls replacement |
| `fd-find` | fd, a find replacement |
| `fzf` | the fuzzy finder |
| `gh` | the GitHub CLI |
| `jq` | JSON processing |
| `ripgrep` | rg, a grep replacement |
| `rlwrap` | readline for other programs |
| `shellcheck` | the shell linter |
| `zoxide` | a smarter cd |
| `sqlite3` | the SQLite CLI |

Outside apt:

| Package | What it is |
| :--- | :--- |
| `starship` | the prompt |
| `tldr` | simplified man pages |

## Required by

Every other pack.

## Prompt

The prompt is based on Starship, it shows :
- the active virtualenv when one is set,
- the working directory,
- the git branch with its status when relevant.

```bash
[~]
❯
```

```bash
(my-project-env) [~/projects/my-project]
⎇ main ❯
```

## Aliases

| Alias | What it does |
| :--- | :--- |
| `b` | `cd -` - back to the previous directory |
| `ports` | the listening ports (`lsof`) |
| `zsh_conf` | open the shell configuration in VS Code |
| `reload` | restart zsh |
| `ls`, `ll`, `la`, `tree` | eza, with icons and git status |
| `cat` | batcat, with syntax highlighting |
| `grep` | grep, colourised |

```sh
zsh_conf        # open ~/.config/zsh in VS Code
reload          # restart zsh
```

## Bindings

| Keys | What it does |
| :--- | :--- |
| Alt+O | fuzzy-find a visible file and open it in VS Code |
| Alt+A | the same, hidden files included |
| Ctrl+X then V | open the shell configuration in VS Code |
| Alt+R | open the persistent history file in VS Code |
| Ctrl+X then G | insert the path of a visible file at the cursor |
| Alt+Y | insert an alias at the cursor |
| Alt+Z | load a cheatsheet command into the prompt |
| Escape | leave a completion menu |

## Shell commands

| Command | What it does |
| :--- | :--- |
| `gmake` | the project's gmake, from any directory, with the shared settings loaded |
| `fcheat` | load a cheatsheet command into the prompt |
| `falias` | insert an alias at the cursor |
| `fv`, `fa` | open a file in VS Code through the picker - visible, or hidden too |
| `fb` | git branch checkout |
| `fgl` | git log browser |
| `cdv`, `cda` | fuzzy cd - visible directories, or hidden too |
| `extract` | unpack an archive into a dedicated directory |

```sh
gmake test-fast         # from any directory - the project's own gmake
extract archive.tar.zst
fcheat                  # pick a command; it lands in the prompt
```

## gmake

The instance's own targets: they run in an instance, from any directory. The
`_up`/`_down` pairs take effect at the next start, and each edits its own line
of `/etc/wsl.conf` and nothing else - a missing section is created, a repeated
run changes nothing.

| Target | What it does | Writes |
| :--- | :--- | :--- |
| `wsl_status` | Show what the instance runs on: the distribution, the kernel, init, its files, its memory, its services | — |
| `wsl_config` | Open `/etc/wsl.conf` in nano, under sudo - the instance's own settings | — |
| `dns_resolve` | Open `/etc/resolv.conf` in nano, under sudo - the name servers | — |
| `fstab_config` | Open `/etc/fstab` in nano, under sudo - what to mount at start | — |
| `packs_list` | List the packs this instance carries - the folders under `~/.config/packs` | — |
| `env_global_enable` / `env_global_manage` | Create or complete `~/.config/zsh/gmake/.env.global` from the samples - then open it in the editor | — |
| `env_project_enable` / `env_project_manage` | Create or complete the current project's `.env` from the samples - then open it in the editor | — |
| `systemd_up` / `systemd_down` | systemd becomes PID 1, or stops being it | `[boot] systemd=` |
| `automount_up` / `automount_down` | The Windows drives appear under `/mnt` at every start, or stop | `[automount] enabled=` |
| `interop_up` / `interop_down` | Windows programs become runnable from the instance, or stop | `[interop] enabled=` |
| `windows_path_up` / `windows_path_down` | The Windows `PATH` joins this instance's `PATH`, or stays out - it only matters while interop is on | `[interop] appendWindowsPath=` |
| `fstab_up` / `fstab_down` | `/etc/fstab` is applied at start, or left aside | `[automount] mountFsTab=` |

## Cheatsheets

The shell's own sheets - `fcheat` (Alt+Z) lists them beside every pack's:

| Sheet | What it covers |
| :--- | :--- |
| `bash` | navigation, files, text processing, find, system and processes, archives and networking, shell hooks |
| `git` | inspection, staging, committing, branches, sync, stash, undo and rebase |
| `make` | the shell's own gmake targets: the packs, the env files, the WSL configuration, the switches |
