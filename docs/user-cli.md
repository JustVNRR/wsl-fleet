# WSL Fleet - CLI

[← Back to the README](../README.md#user-guide)

`wsl-fleet.ps1`, at the root of the repository, is the only thing to type:

```powershell
.\wsl-fleet.ps1        # asks: the GUI or the CLI
.\wsl-fleet.ps1 cli    # straight to the console
```

## How a visit works

The main menu holds the four fleet words. Picking one opens a window;
picking an instance or an archive opens its actions; an action that runs
closes the console behind it.

```text
WSL Fleet CLI
  > build        build an instance from the image
    settings     the working folder, .wslconfig, and the packs catalog
    instances    choose an instance and act on it
    archives     choose an archive: restore or delete
  up/down to move, Enter to choose, Escape to cancel
```

- **Escape goes back one window**, never further: from the actions to the list,
  from the list to the main menu, and from the main menu out. A cancelled
  action returns to its own menu, not past it.
- **Ctrl+C quits the console** from anywhere.
- Where there is no console to read a key from (a script, a pipe), the menus
  become numbered prompts and the answers are typed.
- The screen is cleared when a window opens, so each one starts clean; the
  questions inside a gesture print one after another, like a conversation.

## All commands

| Command | What it does |
| :--- | :--- |
| [`.\wsl-fleet.ps1 gui`](user-gui.md) | the window - see the [GUI guide](user-gui.md) |
| [`.\wsl-fleet.ps1 instances`](#instances) | choose an instance and act on it |
| [`.\wsl-fleet.ps1 archives`](#archives) | choose an archive: restore or delete |
| [`.\wsl-fleet.ps1 build`](#build) | build an instance from the image |
| [`.\wsl-fleet.ps1 settings`](#settings) | the working folder, .wslconfig, and the packs catalog |
| [`.\wsl-fleet.ps1 restart`](#restart) | restart an instance |
| [`.\wsl-fleet.ps1 shell`](#shell) | open a shell inside an instance |
| [`.\wsl-fleet.ps1 manage_packs`](#manage_packs) | choose the packs an instance should carry |
| [`.\wsl-fleet.ps1 theme`](#theme) | choose the icon, font and colours |
| [`.\wsl-fleet.ps1 register_docker`](#register_docker) | register an instance with Docker Desktop |
| [`.\wsl-fleet.ps1 unregister_docker`](#unregister_docker) | take an instance out of Docker Desktop |
| [`.\wsl-fleet.ps1 unregister`](#unregister) | remove an instance |
| [`.\wsl-fleet.ps1 archive`](#archive) | write an instance to a named archive |
| [`.\wsl-fleet.ps1 restore`](#restore) | rebuild an instance from an archive |
| [`.\wsl-fleet.ps1 delete_archive`](#delete_archive) | delete an archive |
| [`.\wsl-fleet.ps1 duplicate`](#duplicate) | copy an instance under another name |
| [`.\wsl-fleet.ps1 compact`](#compact) | reclaim the space an instance has freed |
| [`.\wsl-fleet.ps1 wslconfig`](#wslconfig) | open the Windows-wide WSL settings |
| [`.\wsl-fleet.ps1 migrate`](#migrate) | move the fleet to another folder |

The actions of an instance and of an archive are words of their own too, run
straight when the name follows them: `.\wsl-fleet.ps1 shell ubuntu-template`.

## Which WSL instances are ours

Every instance created by `build`, `restore` or `duplicate` carries a marker,
named `.wsl-fleet`, in its own folder next to its virtual disk:

```text
D:\WSL\ubuntu-template\
├── ext4.vhdx
├── terminal-icon.png        drawn from the name, and kept here
├── instance.json            its look: the font, the colours, the icon's recipe
└── .wsl-fleet
```

## Where things live

One working folder, decided once and kept in
`%LOCALAPPDATA%\wsl-fleet\root.txt`. The first time, it is the folder the
registered instances already live under when there is exactly one, then
`D:\WSL` when the D: drive exists, `%USERPROFILE%\WSL` otherwise. A remembered
folder that is gone is never silently replaced: when the instances still sit
under one existing folder, that one is taken up again and said out loud; with
nowhere to point at, the run stops and says so.

```text
D:\WSL\
├── ubuntu-template\          an instance is a folder: its disk, its marker
├── template-bac\
└── archives\                 an archive is a folder too
    └── ubuntu-template\
        ├── ubuntu-template.tar.gz   the instance's file system
        ├── instance.json            its look and build recipe
        └── terminal-icon.png        its icon
```

## `instances`

The instances - state and size - then what to do with the one you pick.
Folders no instance claims are named under the list; they are nobody's to act
on, and no command removes them.

```powershell
.\wsl-fleet.ps1 instances
```

```text
Our Instances
  > ubuntu-template                running      1.1 GB
    template-bac                   stopped      2.4 GB
  up/down to move, Enter to choose, Escape to cancel
```

```text
Availables actions for 'ubuntu-template'
  > shell           open a shell inside an instance
    restart         restart an instance
    manage_packs    choose the packs an instance should carry
    theme           choose the icon, font and colours
    duplicate       copy an instance under another name
    archive         write an instance to a named archive
    compact         reclaim the space an instance has freed
    register_docker register an instance with Docker Desktop
    unregister      remove an instance
  up/down to move, Enter to choose, Escape to cancel
```

The docker word is the one that changes: `register_docker` while the instance
is not in Docker Desktop, `unregister_docker` once it is. Escape at the
actions brings the list back; a cancelled action brings the actions back.

## `archives`

The archives, most recent first, then their actions: `restore` or
`delete_archive`.

```powershell
.\wsl-fleet.ps1 archives
```

```text
Our Archives
  > azerty_archive                     1.6 GB
    pres_rest_archive                  2.2 GB
  up/down to move, Enter to choose, Escape to cancel
```

```text
Availables actions for 'azerty_archive'
  > restore        rebuild an instance from an archive
    delete_archive delete an archive
  up/down to move, Enter to choose, Escape to cancel
```

## `build`

Builds a new instance, walks through the questions - the name, the road and
its source, the packs, the onboarding and the account - closes on the two last
ticks, applies the Windows Terminal profile, and opens the fresh instance in a
shell of its own.

```powershell
.\wsl-fleet.ps1 build
```

- **Escape climbs one question at a time**; at the name, it cancels the build.
- **Ctrl+C quits.**
- A road with a single source is taken without a question.
- The pack checklist: Space checks, `v` or Enter applies, Escape goes back to
  the source. Applying with nothing ticked means no pack.

```text
Name of the instance (CTRL+C to abort): ubuntu-ml-dev
Build from
  > Dockerfile
    Docker image
    Docker registry
    Recipe
```

The **Dockerfile** road builds from a file of the checkout (the repository
root is the context). The **Docker image** road loads a saved `.tar` and tags
it for the run - nothing is rebuilt. The **Docker registry** road takes any
reference a registry knows (`alpine:latest`), checked against the registry as
it is typed. The **Recipe** road builds from a recipe under
`assets\recipes\`: a folder carrying its Dockerfile.

The **onboarding** script is placed in the instance after the import and run
there; it creates the account. Skipped, no user name is asked and the instance
opens as the image says. The **packs** are installed once the instance exists;
a pack that fails does not fail the build, and `manage_packs` picks it up
later. The **two last ticks**: keep the working image (Dockerfile and Recipe
roads), and add the instance to Docker Desktop.

Docker Desktop must answer before the making: the questions come first, then
the probe - a refusal stops the run there, said.

## `settings`

The fleet's settings, and the packs of the catalog.

```powershell
.\wsl-fleet.ps1 settings
```

```text
Settings
  > migrate          move the fleet to another folder
    wslconfig        open the Windows-wide WSL settings
    availables packs edit, duplicate or delete a catalogue pack
  up/down to move, Enter to choose, Escape to cancel
```

A pack picked opens its three choices; `edit` opens its folder, `duplicate`
asks the new name, `delete` asks a yes or no - and when other packs depend on
the one leaving, they are named first, one per line, under the warning that
removing it may break them. Escape climbs back one window at a time.

## `restart`

Stops an instance and starts it again. Only running instances are listed.

```powershell
.\wsl-fleet.ps1 restart
```

**Whatever is open in there and not saved is lost**, exactly as when an
instance is stopped. The disk is not touched. It is what applies a change to
the files WSL reads when it starts - `/etc/wsl.conf` and `/etc/resolv.conf`,
which `gmake wsl_config` and `gmake dns_resolve` open.

## `shell`

Opens a shell in one of our instances. An instance that was stopped is started
on the way in. The shell opens **in your home**, not in the Windows folder you
ran the command from. `exit` brings you back to PowerShell.

```powershell
.\wsl-fleet.ps1 shell
```

## `manage_packs`

Several packs at once: the list shows every pack this repository carries for
the machine's distribution family, the ones the instance already has arrive
checked, and what comes back is applied - the missing ones installed, the
unchecked ones taken out.

```powershell
.\wsl-fleet.ps1 manage_packs
```

```text
Packs for 'new_distro2'
  > [x] oh_my_cloud  [debian] The Google Cloud CLI
    [ ] oh_my_peg    [debian] ffmpeg, ImageMagick and Tesseract OCR
  up/down to move, space to check, Enter to apply, Escape to cancel
```

Space checks and unchecks, Enter applies, Escape cancels. One question covers
both lists:

```text
Will install : oh_my_py, hide_my_ops
               (devops: required by oh_my_py)
Will remove  : oh_my_cloud
               Their tools leave, and the dependencies nothing needs any more.

Proceed? [Y/n]
```

A pack nobody ticked gets its reason on the line under the list - it arrives
because something requires it, or leaves because nothing does any more. An
unticked pack a ticked one requires is refused, said the same way, and nothing
is applied. If the boxes have not moved, it says so and stops there.

The packs to add are copied **before** anything is removed, so a package two
packs share is left in place. The root halves of the installs run first, as
WSL's own root; then the engine opens WSL's passwordless root door for the
`install.sh` runs and closes it after. **It asks no password.** One step is
left for you, named at the end: `gmake env_global_enable`, inside the
instance, merges the pack's environment samples into your `.env.global`.

The removal runs the pack's own `remove.sh`, then its folder leaves the
instance. What arrived as dependencies goes with the last pack that required
it. What the pack left in your files is not touched: your `gcloud` logins, the
variables in `.env.global`.

A failed install takes the pack's files back out and says which one; running
`manage_packs` again picks up where it stopped.

## `theme`

What an instance wears: its icon, its font and its colours. Each choice is
**applied the moment it is picked** and the console says what was written; the
menu stays for the next choice, and Escape leaves to the actions.

```powershell
.\wsl-fleet.ps1 theme
```

```text
Theme of 'ubuntu-ml-dev'
  > icon    the tile in the tab
    font    what the whole terminal is written in
    color   the background, the text, and sixteen colours
  up/down to move, Enter to choose, Escape to cancel
```

- **icon** - `By Default` (the letters and colours the name gives), `text`
  (one to three characters), `colors` (one of eight pairs), or `local file`
  (a PNG, JPG, ICO or BMP, copied in place). The icon is a file,
  `terminal-icon.png` in the instance's folder; the recipe of the last drawing
  is noted in `instance.json`, so changing one part keeps the other.
- **font** - the monospaced families Windows has that carry the glyphs a
  prompt is drawn with; the one in use is marked `(current)`.
- **color** - every scheme this machine can be told to use, each row drawn in
  its own colours; the one in use is marked `(current)`.

Nothing appears in an open tab while a menu still runs there: the colours show
when you leave, and the font and the icon belong to a tab as it is opened.

## `register_docker`

Puts one of your instances into Docker Desktop's WSL integration list, then
asks whether to restart Docker Desktop now - a restart is the only way it picks
the name up right away; answering no writes the name and nothing more.

```powershell
.\wsl-fleet.ps1 register_docker
.\wsl-fleet.ps1 register_docker mydistro
```

## `unregister_docker`

Takes one of your instances out of Docker Desktop's integration list - the
instance itself is untouched. An instance taken out keeps its `docker` client
until Docker Desktop restarts.

```powershell
.\wsl-fleet.ps1 unregister_docker
```

## `unregister`

Removes an instance and everything it left on Windows. It asks twice: the
destruction gate (the red warning, and the name typed back - the case does not
count), then `Archive it before deleting? [y/N]` - answering yes calls
`archive` first, and **if the archive fails, nothing is deleted**. Escape at
the gate aborts; so does an empty answer.

```powershell
.\wsl-fleet.ps1 unregister
```

It then unregisters the distribution and cleans up what it left: the
installation folder, orphaned Windows Terminal profiles, this repository's
appearance fragment, and its Docker Desktop entry.

### What is lost with the instance

The virtual disk is deleted: **nothing inside the instance survives**.

| Kept inside the instance | Before you unregister or rebuild |
| :--- | :--- |
| `~/projects/` | Nothing backs it up - push your work to a remote first |
| `~/.ssh/` | A key generated inside cannot be recovered: copy it out, or plan to revoke and regenerate it |
| `~/.config/gcloud/` | Both logins are redoable in minutes ([The Google Cloud CLI](../src/distro/packs/oh_my_cloud/README.md)) |
| `~/.config/zsh/gmake/.env.global` | A handful of lines; `gmake env_global_enable` recreates them |
| `~/.config/packs/oh_my_py/cheatsheets/templates.tsv` | Only for rows you added inside the instance: move the line into the pack to keep it |

`archive` is the way out: it writes the whole file system to a folder you can
restore from later.

## `archive`

Writes an instance to an archive: the file system, **plus what a tar cannot
carry** - the icon and its recipe, the font and the colour scheme, and whether
Docker Desktop knew the instance. The archive is named `<instance>_archive`; a
same-named one is replaced, said first.

```powershell
.\wsl-fleet.ps1 archive
```

If the instance is running, it has to be stopped for the export to read a
consistent disk - the script warns you first, because whatever is open and
unsaved goes with it.

## `restore`

Rebuilds an instance from an archive. It lists the archives, most recent
first; pick one, then name the new instance (an empty name cancels).

```powershell
.\wsl-fleet.ps1 restore
.\wsl-fleet.ps1 restore azerty_archive
```

If an instance already carries that name, it stops and tells you the command
to run first - **it deletes nothing on its own**. The icon, the font, the
colour scheme and Docker Desktop's knowledge of the instance come back with
it, from the values stored next to the tar. When the archive says Docker
Desktop knew it, the console asks whether to add it back - that restarts
Docker. If the font is no longer installed on Windows, the script says so
rather than failing. **The archive is kept.**

## `delete_archive`

Deletes an archive for good - the folder under `archives\`, its
`instance.json` and the tar it holds. Nothing is kept.

```powershell
.\wsl-fleet.ps1 delete_archive
.\wsl-fleet.ps1 delete_archive azerty_archive
```

## `duplicate`

Copies an instance under another name, leaving the original alone. The source
comes from the list, and the copy's name is typed - a name already taken is
refused. If the source is running, it has to be stopped for the copy; it is
started again afterwards when it was the one that stopped it.

```powershell
.\wsl-fleet.ps1 duplicate
```

The copy comes out dressed like its source, icon, font and colours included.
It needs **twice the disk's size** free at peak - the temporary archive and
the copy exist at the same time - and the script checks and shows the numbers
before starting.

## `compact`

Gives back to Windows the space the instance has freed inside itself: space is
only added to a virtual disk, never returned on its own. Nothing inside the
instance is touched.

```powershell
.\wsl-fleet.ps1 compact
```

It asks `Archive it first? [y/N]`. Answering yes takes an archive named after
the instance first - and **if the archive fails, nothing is compacted**. It
works on a running instance as well as a stopped one, and leaves it in the
state it was found in.

## `wslconfig`

Opens the Windows-wide WSL settings, `%USERPROFILE%\.wslconfig`, with the
application Windows gives that file.

```powershell
.\wsl-fleet.ps1 wslconfig
```

This is the machine's own file - the memory cap, the processors, the DNS
tunnel, the networking mode - not an instance's `/etc/wsl.conf`. When the file
is not there, it is created commented, so it documents itself.

A change here is read when the WSL machine starts: stop it with
`wsl --shutdown`, then open an instance again. `restart` does not do that - it
restarts one instance.

## `migrate`

Moves the whole fleet to another folder - another disk, typically. Each
instance is archived first, then unregistered right away - the space frees as
it goes - and when nothing is left but the archives folder, that folder
travels to the target. The working folder follows, once every instance made it.

```powershell
.\wsl-fleet.ps1 migrate
```

The target is the only question. The instances come back on the target side
with `.\wsl-fleet.ps1 restore`.
