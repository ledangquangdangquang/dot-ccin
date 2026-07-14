# UbuntuConfig



![Ubuntu](https://img.shields.io/badge/ubuntu-26.04-orange?logo=ubuntu&logoColor=orange)
![Niri](https://img.shields.io/badge/niri-26.04-orange?logo=niri&logoColor=orange)
![Nix](https://img.shields.io/badge/nixpkgs-2.34.7-informational.svg?style=flat&logo=nixos&logoColor=CAD3F5&colorA=24273A&colorB=8aadf4)


Personal Ubuntu dotfiles managed with Nix flakes and Home Manager.

## Showcase 
![screenshot](./assets/screenshot.png) 
## Quick Install

Paste this into a terminal on Ubuntu:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ledangquangdangquang/UbuntuConfig/main/install.sh)
```

The script installs Nix if needed, enables flakes, clones this repo to `~/UbuntuConfig`, applies the Home Manager profile for the current Linux user, and sets zsh as the default shell.

## Overview

This repository is built for a non-NixOS Ubuntu setup. Nix and Home Manager install user packages, manage shell/browser/GTK settings, and symlink application configs from this repo into `~/.config`.

Main stack:

| Area | Tools |
| --- | --- |
| Shell | Zsh, Oh My Zsh, Starship |
| Window manager | Niri on Wayland |
| Terminal | Foot, Kitty, Tmux |
| Editor | Neovim |
| Launcher/UI | Vicinae, DankMaterialShell |
| File manager | Yazi |
| Browser | Firefox |
| Theme | Catppuccin, Bibata cursor, Nerd Fonts |

## Repository Layout

```text
.
├── flake.nix          # Flake inputs and Home Manager entry
├── home.nix           # Packages, config symlinks, shared Home Manager setup
├── modules/           # Focused Home Manager modules
├── dotfiles/          # App configs linked into ~/.config
├── Wallpapers/        # Wallpaper and avatar assets
├── AGENTS.md          # Contributor/agent guide
└── flake.lock         # Locked dependency versions
```

Important modules:

- `modules/zsh.nix`: Zsh setup, aliases, shell functions.
- `modules/git.nix`: Git identity, Git alias, SSH config for GitHub.
- `modules/gtk.nix`: GTK theme, fonts, cursor theme.
- `modules/tmux.nix`: Tmux prefix, session restore, sessionizer, clipboard, and theme.
- `modules/firefox/default.nix`: Firefox package, policies, profile config.

## Setup

Enable Nix flakes if needed:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Clone this repo to the expected path:

```bash
git clone git@github.com:ledangquangdangquang/UbuntuConfig.git ~/UbuntuConfig
cd ~/UbuntuConfig
```

Apply the Home Manager configuration for the current Linux user:

```bash
USER="$(id -un)" nix run github:nix-community/home-manager -- switch --impure --flake ".#$(id -un)"
```

After Home Manager is installed, you can use:

```bash
USER="$(id -un)" home-manager switch --impure --flake ".#$(id -un)"
```

## Common Commands

```bash
nix flake check --no-build
```

Validate flake outputs without building everything.

```bash
nix build .#homeConfigurations.quang.activationPackage
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
| `Alt-a` then `f` | Open `tmux-sessionizer` project picker with `fzf` |
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
2. Add `<app>` to `configApps` in `home.nix`.
3. Run `home-manager switch --flake .#quang`.

User-specific values live in `flake.nix` and `home.nix`, including `user`, `hostname`, `homeDirectory`, and `stateVersion`.

## Notes

- Keyboard shortcuts are mainly in `dotfiles/niri/config.kdl`, `dotfiles/kitty/kitty.conf`, and the Neovim config.
- Shell aliases are managed in `modules/zsh.nix`.
- Do not commit secrets, SSH private keys, browser sessions, or generated logs.

### Register Sway on Ubuntu

```sh
sudo tee /usr/share/wayland-sessions/sway-nix.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Sway (Nix)
Comment=Sway with Nix applications
Exec=/usr/bin/env PATH=/home/quang/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin XDG_DATA_DIRS=/home/quang/.nix-profile/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share /usr/bin/sway --unsupported-gpu
Type=Application
DesktopNames=sway
EOF
```
