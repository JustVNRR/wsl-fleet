# WSL Fleet - GUI

[← Back to the README](../README.md#user-guide)


```powershell
.\wsl-fleet.ps1 gui
```

`wsl-fleet.exe`, with no argument or double-clicked, opens it directly.

## The fleet list

The window lists the instances and the archives in one alphabetical walk - a
same-named archive shows right beside its instance. Each row carries its state
(running, stopped, archived) and its size. A folder no instance claims is said
under the list; it is nobody's to act on.

The header carries the window's buttons:

| Button | What it does |
| :--- | :--- |
| **+** | a new instance - the build form |
| refresh | reread the fleet by hand |
| gear | the settings window |
| sun | switch the current theme's light and dark version |

## An instance's actions

Each row carries its buttons:

| Button | What it does |
| :--- | :--- |
| open | a new terminal window on the instance's own profile - its icon, colours and font ride along |
| restart | stop and start it again |
| packs | the pack checklist - tick, untick, and APPLY; the requirements and removals are shown live underneath, with their reasons, and APPLY greys while there is nothing to do |
| appearance | the look: icon letters and colours, font and colour scheme, or an image of your own through the file picker, shown live in a small terminal preview |
| duplicate | a copy under a name of its own - the engine's guard refuses a taken name, and the room for twice the disk is checked |
| archive | the same backup `archive` writes: it asks the name, and stops a running instance for the export |
| compact | the same compaction `compact` runs, behind a gate - the instance must be idle, and the archive-first box is offered |
| Docker cube | register the instance with Docker Desktop, or take it out |
| trash | remove the instance - the same gate `unregister` puts up: what is lost, spelled out, and the exact name typed back |

While a long action runs, a progress band scrolls at the bottom of the window,
and the report line says what happened when it ends. A run that needs
Docker's own questions opens a console window of its own.

## An archive's actions

| Button | What it does |
| :--- | :--- |
| restore | rebuild an instance from the archive: it asks the name the new instance takes (the archive's own, prefilled - an empty name cancels), then imports; the archive is kept |
| trash | delete the archive - what is lost, spelled out, and the name typed back |

## The build form

The **+** button opens it: the name, the account, the road and its source, the
packs - in one form.

**Build from** is a toggle, one road at a time, and only its row shows:

| Road | What it takes |
| :--- | :--- |
| Dockerfile | a file under `assets\dockerfiles\` - each row carries upload, download and a trash |
| Docker image | a saved `.tar` under `assets\dockerimages\` |
| Docker registry | a reference typed by hand, `alpine:latest` |
| Recipe | a folder under `assets\recipes\` - its Dockerfile and its sidecar files |

A **Run onboarding shell** box sits above the onboarding row - ticked for a
Dockerfile, unticked for an image or a registry name, both being presumed
complete as they are. Unticked, the user-name field and the row grey out with
it.

The lists open on their first row - the repository's own among them, editable
and deletable like any other. The files are seeded into the assets on the
first run, and they come back by deleting the folder. A name that already
exists is refused right there, and a Docker that is not running is offered its
start over the form.

The run opens a console window of its own - Docker's questions included, since
only it can ask them - and ends by opening the fresh instance in its own
window. The fleet list rereads itself the moment the run ends.

## The settings window

The **gear** opens it.

- **Root folder** - the working folder in a greyed box, and an edit button
  opening a move dialog: a warning that every instance is stopped and archived
  on the way, the folder in a box, Cancel or the red CONFIRM. A confirmed
  folder archives the whole fleet and moves it there (`migrate`).
- **WSL config** - `%USERPROFILE%\.wslconfig` in the same greyed box; the edit
  button opens the file as Windows opens files, created first if the machine
  has none (`wslconfig`).
- **Packs Catalog** - the packs of `assets\packs\`: the edit button opens the
  selected pack's folder, a duplicate copies it under a new name (the copy's
  description rewritten in its `pack.conf`), the trash removes it whole - the
  red CONFIRM first, naming the packs that depend on it when any do. The base
  set comes back by deleting `assets\packs\`.
- **The face** - the window's font, its size and its colour theme; the themes
  are the `.xaml` files under `assets\themes\`, dark and light versions
  shipped. The row carries upload, download, an edit button and a trash; the
  sun in the header switches the current theme's version on the spot.
