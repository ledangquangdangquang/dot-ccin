# UbuntuConfig

![Ubuntu](https://img.shields.io/badge/ubuntu-26.04-orange?logo=ubuntu&logoColor=orange)
![Sway](https://img.shields.io/badge/Sway-1.9-68751C?logo=sway&logoColor=white)
![Nix](https://img.shields.io/badge/nixpkgs-2.34.7-informational.svg?style=flat&logo=nixos&logoColor=CAD3F5&colorA=24273A&colorB=8aadf4)

Personal Ubuntu dotfiles managed with Nix flakes and Home Manager.

## Showcase

![screenshot](./assets/screenshot.png)

## Component Table

| Component | Description |
| --- | --- |
| Window Manager | Sway on Wayland |
| Bar | i3status-rust |
| Terminal Emulator | Foot, Kitty |
| Application Launcher | Fuzzel |
| Notification Daemon | SwayNC |
| File Manager | Superfile |
| Text Editor | Neovim |
| Browser | Firefox |
| PDF Viewer | Zathura |
| Screenshot | Grim + Slurp + Satty |
| Shell | Zsh + Starship |
| Theme | Catppuccin Mocha |
| Input Method | Fcitx5 + Unikey |
| Terminal Multiplexer | Tmux |
| System Monitor | Btop |
| File Viewer | Bat |
| File Explorer | Eza |
| Fuzzy Finder | Fzf |

## Quick Install

Paste this into a terminal on Ubuntu:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ledangquangdangquang/UbuntuConfig/main/install.sh)
```

The script installs Nix if needed, enables flakes, clones this repo to
`~/UbuntuConfig`, writes the current Linux username to `flake.nix`, applies the
matching Home Manager profile, sets zsh as the default shell, and registers the
Sway session with Ubuntu's display manager. Run the installer while logged in
as the user that should own the configuration.

## Repository Layout

```text
.
├── flake.nix          # Flake inputs and Home Manager entry
├── home.nix           # Minimal Home Manager entry point
├── modules/           # Focused Home Manager modules
├── dotfiles/          # App configs linked into ~/.config
├── Wallpapers/        # Wallpaper and avatar assets
├── AGENTS.md          # Contributor/agent guide
└── flake.lock         # Locked dependency versions
```

## Important Modules

- `modules/default.nix`: Imports all focused Home Manager modules.
- `modules/dotfiles.nix`: Links selected `dotfiles/` folders into `~/.config`.
- `modules/packages.nix`: User packages shared by the desktop environment.
- `modules/fcitx.nix`: Fcitx5 input method configuration.
- `modules/notifications.nix`: SwayNC and notification sound configuration.
- `modules/power.nix`: Fuzzel-based suspend, logout, reboot, and shutdown menu.
- `modules/clipboard.nix`: Clipboard history watcher, picker, and clear-history commands.
- `modules/screenshot.nix`: Screenshot commands and tools.
- `modules/wifi.nix` and `modules/bluetooth.nix`: Network menu helpers.
- `modules/zsh.nix`: Zsh setup, aliases, shell functions.
- `modules/git.nix`: Git identity, Git alias, SSH config for GitHub.
- `modules/gtk.nix`: GTK theme, fonts, cursor theme.
- `modules/tmux.nix`: Tmux prefix, session management, restore, clipboard, and theme.
- `modules/firefox/default.nix`: Firefox package, policies, profile config.

See [`docs/architecture.md`](docs/architecture.md) for the evaluation flow,
module ownership, generated commands, and extension points.

## Common Commands

```bash
nix flake check
```

Validate and build the flake checks.

```bash
nix fmt
git diff --exit-code -- '*.nix'
```

Format Nix files and verify that formatting produces no uncommitted changes. The flake and formatting checks also run automatically on pushes and pull requests through GitHub Actions.

```bash
nix build ".#homeConfigurations.${USER}.activationPackage"
```

Build the Home Manager activation package and catch evaluation/build warnings.

```bash
nix fmt
```

Format Nix files with the formatter declared in `flake.nix`.

## Tmux Shortcuts

Prefix key: `Alt-a`.

Start tmux manually when needed:

```bash
tmux new -A -s main
```

Basic session commands:

```bash
tmux ls                         # List sessions
tmux new -s work                # Create a new session
tmux new -A -s main             # Create or attach to main
tmux attach -t work             # Attach from outside tmux
tmux switch-client -t work      # Switch session from inside tmux
tmux kill-session -t work       # Remove a session
tmux kill-server                # Remove all sessions
```

Use `attach` only from a normal shell. If already inside tmux, use `switch-client` or `Alt-a` then `s`.

| Shortcut | Action |
| --- | --- |
| `Alt-a` then `s` | Open the session chooser; press `x` to delete with confirmation |
| `Alt-a` then `r` | Reload tmux config |
| `Alt-a` then `\|` | Split pane horizontally in the current directory |
| `Alt-a` then `-` | Split pane vertically in the current directory |
| `Alt-a` then `c` | Create a new window in the current directory |
| `Alt-h` | Move to the left pane |
| `Alt-j` | Move to the pane below |
| `Alt-k` | Move to the pane above |
| `Alt-l` | Move to the right pane |
| `Alt-Shift-h` | Resize pane left by 5 cells |
| `Alt-Shift-j` | Resize pane down by 5 cells |
| `Alt-Shift-k` | Resize pane up by 5 cells |
| `Alt-Shift-l` | Resize pane right by 5 cells |
| Copy mode `y` | Copy selection to Wayland clipboard with `wl-copy` |

`Alt-a` shortcuts only work inside tmux.

Sessions are saved every 15 minutes with `tmux-continuum` and restored after reboot with `tmux-resurrect`.

## Maintenance

Nix keeps old builds in `/nix/store`, so clean garbage when `/` is low on space or rebuild fails with a disk-space error:

```bash
nix store gc
```

This configuration also enables a weekly user timer that keeps the last 7 days of user and Home Manager profile history, then runs garbage collection:

```bash
systemctl --user list-timers nix-cleanup.timer
systemctl --user start nix-cleanup.service
```

Check disk usage before rebuilding:

```bash
df -h / /home
```

## Customization

To add a new app config:

1. Put the config directory under `dotfiles/<app>/`.
2. Add `<app>` to `configApps` in `modules/dotfiles.nix`.
3. Run `home-manager switch --flake ".#$USER"`.

Add new Home Manager logic to a focused file under `modules/`, then import it from `modules/default.nix`. User and host-specific values are centralized in `flake.nix`; `home.nix` remains the minimal entry point.

## Notes

- Sway keyboard shortcuts are defined in `dotfiles/sway/config` and summarized in `dotfiles/sway/keyshortcuts.txt` (`Mod+i`).
- `dotfiles/niri/` is inactive/experimental and is not the primary compositor configuration.
- Shell aliases are managed in `modules/zsh.nix`.
- Do not commit secrets, SSH private keys, browser sessions, or generated logs.

### Register Sway on Ubuntu

```sh
sudo tee /usr/share/wayland-sessions/sway-nix.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Sway (Nix)
Comment=Sway with Nix applications
Exec=/usr/bin/env PATH=$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin XDG_DATA_DIRS=$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share /usr/bin/sway --unsupported-gpu
Type=Application
DesktopNames=sway
EOF
```

## Other Distros

This repo is built for Ubuntu. Most of the Nix-managed config works on any Linux distro, but a few things differ.

### Package Manager

| Distro | Command |
| --- | --- |
| Ubuntu/Debian | `apt` |
| Fedora | `dnf` |
| Arch/Manjaro | `pacman` |
| openSUSE | `zypper` |

`install.sh` uses `apt`. Replace the package list and install commands if running on a different distro.

### Sway GPU Flags

- **Ubuntu + NVIDIA**: requires `--unsupported-gpu` in the `.desktop` entry.
- **Arch/Fedora**: Sway runs natively, no extra flag needed.
- **NixOS**: Sway is configured declaratively, no manual `.desktop` file.

### Session Registration

- **Ubuntu/Debian**: `/usr/share/wayland-sessions/`
- **Arch/Fedora**: same path, but you can also use `environment.d` instead.
- **NixOS**: register via `services.xserver.windowManager.sway.enable`.

### Nix Installation

- **Ubuntu**: single-user mode (default in `install.sh`).
- **NixOS**: Nix is pre-installed.
- **Arch/Fedora**: can use multi-user mode (`nix install --daemon`).

### Audio Stack

- **Ubuntu 22.04+**: PipeWire (`pactl`/`paplay` work via compatibility layer).
- **Fedora 34+**: PipeWire.
- **Arch**: PipeWire (new default) or PulseAudio.
- **Debian 11**: PulseAudio.

All audio scripts in this repo use `pactl`/`paplay`, which work on both PipeWire and PulseAudio.

### Brightness Control

`brightnessctl` works on most distros. Older systems may need `xbacklight` or `light` instead.
