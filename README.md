# UbuntuConfig

> Personal Ubuntu dotfiles managed with Nix flakes and Home Manager.

## What's installed

| Category | Tools |
| --- | --- |
| Window Manager | i3 (installed externally, i3status-rust) |
| Shell | zsh + Starship |
| Terminal | Kitty, Alacritty |
| Application Launcher | Rofi, Fuzzel |
| Notification Daemon | dunst |
| File Manager | Yazi (with 5 plugins: smart-enter, full-border, jump-to-char, git, mount) |
| Browser | Firefox (custom CSS) |
| Editor | Neovim + fuzzyvim (Fzf) |
| Screenshot | Grim + Slurp + Satty |
| Power Menu | Fuzzel-based suspend/logout/reboot |
| Input Method | Fcitx5 + Unikey |
| Terminal Multiplexer | Tmux |
| System Monitor | Btop |
| File Viewer | Bat |
| File Explorer | Eza |
| Fuzzy Finder | Fzf |
| Theme | Catppuccin Mocha |
| Beyond | zsh aliases, GTK theme, Git config, Tmux, Picom |

## Structure

```
.
├── flake.nix       # flake inputs, hostname, user, stateVersion
├── home.nix        # minimal Home Manager entry point
├── modules/        # focused Home Manager modules
│   └── default.nix # imports all modules
├── dotfiles/       # app configs symlinked into ~/.config
├── Wallpapers/     # wallpaper and avatar assets
├── flake.lock      # locked dependency versions
└── README.md       # this file
```

## How to use

1. **Add a package** → edit `modules/packages.nix`
2. **Add an app config** → create `dotfiles/<app>/`, then add `"<app>"` to `configApps` in `modules/dotfiles.nix`
3. **Add Home Manager logic** → create a new file under `modules/`, import from `modules/default.nix`
4. **Apply** → `home-manager switch --flake ".#$USER"`

Config files in dotfiles are symlinked directly — edit and see changes immediately.

## Common commands

```bash
home-manager switch --flake ".#$(whoami)"     # apply config
nix flake check                               # validate before switching
nix fmt                                       # format Nix files
nix store gc                                  # clean /nix/store
```

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ledangquangdangquang/UbuntuConfig/main/install.sh)
```

The installer sets up Nix, clones the repo to `~/UbuntuConfig`, writes your username to `flake.nix`, applies Home Manager, sets zsh as default, and registers the Sway session with the display manager.

## Notes

- i3 shortcuts: `Mod+i` (see `dotfiles/i3/keyshortcuts.txt`)
- Shell aliases: `modules/zsh.nix`
- Do not commit secrets, SSH keys, browser sessions, or generated logs
- The system uses Catppuccin Mocha palette throughout
- Audio: PipeWire (works with PulseAudio compatibility)
- Brightness: `brightnessctl` on most distros