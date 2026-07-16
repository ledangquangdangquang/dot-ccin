# Configuration Architecture

This repository is a Home Manager configuration for the `quang` user on a
non-NixOS Ubuntu system. Nix builds the packages and generated commands, while
Home Manager writes user-level configuration and links application dotfiles.
Sway is the active Wayland compositor; the Niri files are experimental.

## Evaluation Flow

```text
flake.nix
  └─ homeConfigurations.quang
       └─ home.nix
            ├─ Catppuccin Home Manager module
            └─ modules/default.nix
                 ├─ focused Home Manager modules
                 └─ modules/firefox/default.nix
```

`flake.nix` selects `x86_64-linux`, imports nixpkgs with unfree packages
enabled, and passes `inputs`, `hostMain`, and `user` to Home Manager.
`home.nix` deliberately contains only the shared imports and core account
settings. `modules/default.nix` is the index for all feature modules.

## Configuration Ownership

| Area | Source | Result |
| --- | --- | --- |
| Flake inputs and profile identity | `flake.nix` | `homeConfigurations.quang` |
| Account and Home Manager state | `home.nix` | `/home/quang`, state version, generic Linux support |
| Shared command-line packages | `modules/packages.nix` | Packages in the user profile |
| Application configuration | `dotfiles/<app>/` | Out-of-store links under `~/.config/<app>` |
| GTK, fonts, and cursor | `modules/gtk.nix` | GTK and pointer settings |
| Shells and terminal multiplexer | `modules/zsh.nix`, `modules/bash.nix`, `modules/tmux.nix` | Shell initialization, aliases, and tmux configuration |
| Firefox | `modules/firefox/` | Wrapped Firefox, policies, profile preferences, and CSS |
| Desktop helpers | Focused modules described below | Commands installed into the user profile |

`modules/dotfiles.nix` uses `mkOutOfStoreSymlink`, so linked application files
continue to point at the working tree instead of being copied into the Nix
store. The repository is therefore expected at `~/UbuntuConfig`; moving it
requires changing the `dotfiles` path in that module.

## Generated Desktop Commands

Several modules use `pkgs.writeShellApplication`. This packages each script
with its runtime dependencies and exposes the resulting command through
`home.packages`.

| Command | Module | Purpose |
| --- | --- | --- |
| `wifi-menu` | `modules/wifi.nix` | Toggle Wi-Fi, scan, disconnect, and connect through Fuzzel |
| `bluetooth-menu` | `modules/bluetooth.nix` | Toggle Bluetooth and pair, connect, or disconnect devices |
| `power-menu` | `modules/power.nix` | Suspend or confirm session and power actions |
| `clipboard-watcher` | `modules/clipboard.nix` | Store Wayland text and image clipboard history with Cliphist |
| `clipboard-menu` | `modules/clipboard.nix` | Select a clipboard entry with Fuzzel and copy it again |
| `clipboard-clear` | `modules/clipboard.nix` | Confirm and clear clipboard history |
| `screenshot` | `modules/screenshot.nix` | Capture a region or display, edit with Satty, or copy an image |
| `fuzzyvim` | `modules/fuzzyvim.nix` | Find a project file with ripgrep/Fzf and open it in Neovim |
| `notification-sound` | `modules/notifications.nix` | Duck active audio, play the notification sound, then restore volume |
| `system-control` | `modules/notifications.nix` | Control brightness, volume, Caps Lock indication, and night light |
| `nix-cleanup` | `modules/nix-cleanup.nix` | Remove old user-profile history and collect the Nix store |

Bindings and autostart behavior for these helpers belong in
`dotfiles/sway/config`. The weekly `nix-cleanup` invocation is instead managed
by a Home Manager systemd user timer.

## Extending the Configuration

### Add a Home Manager feature

1. Create a focused file such as `modules/example.nix`.
2. Keep feature-specific packages and generated scripts in that file.
3. Import it from `modules/default.nix`.
4. Run `nix fmt` and `nix flake check`.

### Add a linked application config

1. Add the application files under `dotfiles/<app>/`.
2. Add `<app>` to `configApps` in `modules/dotfiles.nix`.
3. Run `nix flake check` and apply the profile.

### Apply the profile

If Home Manager is already available:

```bash
home-manager switch --flake .#quang
```

Otherwise, run it through Nix:

```bash
nix run github:nix-community/home-manager -- switch --flake .#quang
```

Changing `home.stateVersion` can alter Home Manager defaults and should not be
done as part of a routine upgrade. Update flake inputs separately with
`nix flake update`, inspect the lock-file diff, and validate before switching.
