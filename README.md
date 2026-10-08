<h1 align="center">dot-ccin</h1>
<p align="center">
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/Nix%202.35-5277C3?style=flat&logo=nixos&logoColor=white"></a>
  <a href="https://github.com/nix-community/home-manager"><img src="https://img.shields.io/badge/Home%20Manager%2025.11-4a6fa5?style=flat&logo=nixos&logoColor=white"></a>
  <a href="https://i3wm.org"><img src="https://img.shields.io/badge/i3%204.24-1793D1?style=flat&logo=i3&logoColor=white"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Catppuccin%20Mocha-cba6f7?style=flat"></a>
</p>

> A keyboard-driven i3 rice for plain Ubuntu (no NixOS), themed Catppuccin Mocha end to end. One Nix flake + Home Manager command rebuilds the whole desktop (Rofi menus, Kitty, Neovim, Yazi, Firefox, Vietnamese input), and dotfiles are symlinked so edits apply instantly.







https://github.com/user-attachments/assets/06cc8fbe-c099-4a4b-9646-09af651e6922







![Desktop screenshot](assets/fuzzyvim+yazi+btop.png)

## Screenshots

| Clean | Busy (fastfetch + nvim + btop) |
| --- | --- |
| ![Clean desktop](assets/desktop-clean.png) | ![Busy desktop](assets/desktop-busy.png) |
| **Rofi launcher** (`Mod+space`) | **Power menu** (`Mod+x`) |
| ![Rofi launcher](assets/rofi-launcher.png) | ![Power menu](assets/rofi-power.png) |

## What's installed

| Category | Tools |
| --- | --- |
| Window Manager | i3 (installed externally) + i3status-rust |
| Shell | Zsh + Starship |
| Terminal | Alacritty (Kitty also installed) |
| Launcher | Rofi (`Mod+space`: run / drun / ssh) |
| Quick menus | Rofi-driven power, clipboard, display, wallpaper, and pomodoro-task pickers (Wi-Fi/Bluetooth via nm-applet/blueman tray) |
| Notifications | dunst (custom sound + volume ducking on notify) |
| File Manager | Thunar (archive plugin + xarchiver), Yazi (smart-enter, full-border, jump-to-char, git, mount plugins) |
| Browser | Firefox (Catppuccin CSS, managed extensions, custom new-tab page) |
| Editor | Neovim + fuzzyvim (`Ctrl+F` fzf file picker with preview) |
| Screenshot | maim + Satty |
| Clipboard History | cliphist |
| Input Method | Fcitx5 + Unikey |
| Multiplexer | Tmux (Catppuccin, resurrect, continuum) |
| System Monitor | Btop |
| Media | VLC, kew |
| Theme | Catppuccin Mocha, applied everywhere |
| Housekeeping | Weekly `nix store gc` via systemd timer |

## Structure

```
.
├── flake.nix       # flake inputs, user, hostMain (stateVersion, machine-specific values)
├── home.nix        # minimal Home Manager entry point
├── modules/        # focused Home Manager modules
│   └── default.nix # imports all modules
├── dotfiles/       # app configs symlinked into ~/.config
├── Wallpapers/     # wallpaper assets
├── docs/           # architecture notes
├── install.sh      # one-shot bootstrap script
├── flake.lock      # locked dependency versions
└── README.md       # this file
```

## How to use

1. **Add a package** → edit `modules/packages.nix`
2. **Add an app config** → create `dotfiles/<app>/`, then add `"<app>"` to `configApps` in `modules/dotfiles.nix`
3. **Add Home Manager logic** → create a new file under `modules/`, import it from `modules/default.nix`
4. **Apply** → `home-manager switch --flake ".#$USER"`

Config files in `dotfiles/` are symlinked directly — edit and see changes immediately, no rebuild needed.

## Common commands

```bash
home-manager switch --flake ".#$(whoami)"     # apply config
nix flake check                               # validate before switching
nix fmt                                        # format Nix files
nix store gc                                   # clean /nix/store
```

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ledangquangdangquang/dot-ccin/main/install.sh)
```

The installer sets up Nix, installs i3, clones the repo to `~/dot-ccin`, applies Home Manager, and sets Zsh as the default shell.

## Notes

- i3 shortcuts: `Mod+i` (see `dotfiles/i3/keyshortcuts.txt`)
- Shell aliases: `modules/zsh.nix`
- Do not commit secrets, SSH keys, browser sessions, or generated logs
- Audio: PipeWire (PulseAudio-compatible, controlled via `pactl`/`wpctl`)
- Brightness: `brightnessctl` / `ddcutil`
