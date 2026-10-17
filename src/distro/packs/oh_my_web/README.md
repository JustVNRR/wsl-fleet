# oh_my_web: Firefox and a WireGuard tunnel

[← Back to the README](../../../../README.md#optional-tooling-packs)

`fox`/`pfox` launch the browser with the light or the strict privacy profile; the `vpn_*` targets bring the tunnel up, down, and around profiles.

Firefox comes from Mozilla's own repository, and the servers live in `~/.config/vpn/servers.json`.

**Type:** installable

## Packages

| Package | What it is |
| :--- | :--- |
| `firefox` | the browser (Mozilla's repository - Ubuntu's is a snap stub) |
| `dbus-x11` | the session bus Firefox needs |
| `wireguard-tools` | the tunnel (`wg`) |
| `kmod` | kernel modules |
| `iproute2` | network configuration (`ip`) |
| `iptables` | the firewalling - the kill switch |
| `openresolv` | DNS handling for the tunnel |

## Requires

oh_my_shell.

## gmake

| Target | What it does |
| :--- | :--- |
| `fox_tweak_on` | Apply the strict privacy profile (fox/pfox pick one on their own) |
| `fox_tweak_off` | Take the profile out - the browser's own defaults again |
| `vpn_status` | Show the tunnel, the server, the kill switch, the DNS and the exit IP |
| `vpn_up` | Connect now - with the server `VPN_PROFILE` names, or the one you name |
| `vpn_up_from_list` | Connect now, picking the server from the JSON in a menu |
| `vpn_down` | Disconnect |
| `vpn_server` | Choose the server the distro starts with, and switch to it now |
| `vpn_ks_on` | Put the kill switch in the tunnel, and remount it |
| `vpn_ks_off` | Take the kill switch out of the tunnel, and remount it |
| `vpn_auto_on` | Bring the tunnel up when the distro starts |
| `vpn_auto_off` | Stop bringing it up with the distro |
| `vpn_edit_profiles` | Open the JSON of servers in the editor |

```sh
gmake vpn_status
gmake vpn_up
gmake vpn_up_from_list
```

## Environment

Global (`.env.global`) - `gmake env_global_enable` copies the block into
`~/.config/zsh/gmake/.env.global`, filling only what is missing:

| Variable | What it means |
| :--- | :--- |
| `VPN_PROFILE` | the server the tunnel uses - an id of `~/.config/vpn/servers.json` (`vpn_server` writes it) |
| `BASE_DNS` | the DNS used while the tunnel is up (a server's own entry wins) |
| `VPN_MTU` | the tunnel's MTU, for servers whose entry says nothing |
| `VPN_KILL_SWITCH` | keep the tunnel as the instance's only way out |

```sh
VPN_PROFILE=server-1
VPN_KILL_SWITCH=true
```

## Shell commands

| Command | What it does |
| :--- | :--- |
| `fox` | open the browser on the light privacy profile |
| `pfox` | open the private window on the strict profile, the check page first |

```sh
fox https://example.com
pfox
```

## Cheatsheets

Offered by `fcheat` (Alt+Z) beside every installed pack's:

| Sheet | What it covers |
| :--- | :--- |
| `vpn` | the tunnel's targets, the servers, the settings, what is really happening - shown while `wg` is installed |
| `web` | opening the browser, troubleshooting, the sound, the privacy profiles, the files it keeps - shown while `firefox` is installed |
