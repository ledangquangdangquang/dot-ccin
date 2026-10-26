<h1 align="center">dot-ccin</h1>
<p align="center">
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/Nix%202.35-5277C3?style=flat&logo=nixos&logoColor=white"></a>
  <a href="https://github.com/nix-community/home-manager"><img src="https://img.shields.io/badge/Home%20Manager%2025.11-4a6fa5?style=flat&logo=nixos&logoColor=white"></a>
  <a href="https://i3wm.org"><img src="https://img.shields.io/badge/i3%204.25-1793D1?style=flat&logo=i3&logoColor=white"></a>
  <a href="https://github.com/catppuccin/catppuccin"><img src="https://img.shields.io/badge/Catppuccin%20Mocha-cba6f7?style=flat"></a>
</p>

> A keyboard-driven i3 rice for plain Ubuntu (no NixOS), themed Catppuccin Mocha end to end. One Nix flake + Home Manager command rebuilds the whole desktop (Rofi menus, Alacritty, Neovim, Yazi, Firefox, Vietnamese input), and dotfiles are symlinked so edits apply instantly.

![Desktop: btop, Neovim, fastfetch](assets/desktop-busy.png)

## Philosophy

- **Performance first.** i3 instead of a full desktop environment. picom renders on the GPU (`glx`) with blur off and 0.1 s animations, and fullscreen games/video bypass the compositor. No always-on tray applets: Wi-Fi and Bluetooth are TUIs opened on demand (the two GTK applets they replace used ~500 MB). Firefox ships with telemetry, studies, and background AI models off.
- **Simple to use.** Every action is a key (`Mod+i` lists them all). Daily tasks (power, clipboard, display, audio, wallpaper) are one Rofi menu away. One command rebuilds the whole desktop, and config edits apply without a rebuild.
- **No bloatware.** One small tool per job, terminal first. Nothing runs in the background unless it earns its place, and the Nix store is garbage-collected weekly.

## Screenshots

| Clean | fuzzyvim + Yazi |
| --- | --- |
| ![Clean desktop](assets/desktop-clean.png) | ![fuzzyvim and Yazi](assets/fuzzyvim-yazi.png) |
| **Rofi launcher** (`Mod+space`) | **Power menu** (`Mod+x`) |
| ![Rofi launcher](assets/rofi-launcher.png) | ![Power menu](assets/rofi-power.png) |

**Firefox start page**: a [tilde](https://github.com/xvvvyz/tilde)-style dial. Type a key to jump (`y` YouTube, `g` GitHub), `y lofi` to search a site, anything else to search the web. The background image, blur, and brightness can be changed from the top-right button.

![Firefox start page](assets/firefox-newtab.png)

## What's installed

| Category | Tools |
| --- | --- |
| Window Manager | i3 (installed externally) + i3status-rust |
| Shell | Zsh + Starship |
| Terminal | Alacritty (Kitty also installed) |
| Launcher | Rofi (`Mod+space`: run / drun / ssh) |
| Quick menus | Rofi-driven power, clipboard, display, audio, wallpaper, and pomodoro-task pickers |
| Wi-Fi / Bluetooth | wifitui (`Mod+w`) and bluetui (`Mod+Shift+w`) in floating terminals, no tray applets |
| Notifications | dunst (sound + volume ducking on notify, silent volume/brightness OSD, Caps Lock state), login/logout sounds, USB plug/unplug alerts |
| File Manager | Thunar (archive plugin + xarchiver: zip/7z/rar/tar), Yazi (smart-enter, full-border, jump-to-char, git, mount plugins) |
| Browser | Firefox (Catppuccin CSS, managed extensions, tilde-style start page) |
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
├── INSTALL.md      # step-by-step install guide
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

See [INSTALL.md](INSTALL.md) for step-by-step setup and troubleshooting.

## Notes

- i3 shortcuts: `Mod+i` (see `dotfiles/i3/keyshortcuts.txt`)
- Screenshots: `bash assets/capture.sh` retakes every README image on an empty workspace 9
- Shell aliases: `modules/zsh.nix`
- Do not commit secrets, SSH keys, browser sessions, or generated logs
- Audio: PipeWire (PulseAudio-compatible, controlled via `pactl`/`wpctl`)
- Brightness: `F6`/`F7` set 30% / 80%, media keys ±5%. Laptop panel via `brightnessctl`, external monitor via `ddcutil` (DDC/CI, needs the one-time i2c setup in [INSTALL.md](INSTALL.md#6-external-monitor-brightness-optional))
