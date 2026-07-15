# Repository Guidelines

## Project Structure & Module Organization

This repository manages Ubuntu dotfiles with Nix flakes and Home Manager.

The active desktop session is Sway on Wayland. Treat `dotfiles/sway/` as the
primary compositor configuration and prefer Sway-compatible tools and examples.
Do not assume that Niri is in use merely because `dotfiles/niri/` exists.

- `flake.nix` defines inputs, the `quang` Home Manager configuration, and shared arguments.
- `home.nix` imports `./modules`, installs packages, and symlinks selected folders from `dotfiles/` into `~/.config`.
- `modules/` contains focused Home Manager modules: `zsh.nix`, `git.nix`, `gtk.nix`, `bash.nix`, and `firefox/`.
- `dotfiles/` stores application configuration directories, for example `sway/`, `kitty/`, `nvim/`, `fastfetch/`, and `yazi/`. Some folders, such as `niri/`, may contain inactive or experimental configurations.
- `Wallpapers/` contains desktop image assets.

Add new Home Manager logic under `modules/` and add new app config folders under `dotfiles/`. If a new dotfile folder should be linked, add its name to `configApps` in `home.nix`.

## Build, Test, and Development Commands

- `nix flake check` validates the flake outputs.
- `nix fmt` formats Nix files with the flake formatter.
- `nix run github:nix-community/home-manager -- switch --flake .#quang` applies the Home Manager configuration locally.
- `home-manager switch --flake .#quang` applies the same config when Home Manager is already installed.

Run validation before switching when editing `flake.nix`, `home.nix`, or `modules/*.nix`.

## Coding Style & Naming Conventions

Use two-space indentation in Nix files and keep attribute sets compact but readable. Prefer descriptive lower-case names for local variables, matching existing examples such as `dotfiles`, `configApps`, and `hostMain`. Keep modules focused: shell aliases belong in `modules/zsh.nix`, Git settings in `modules/git.nix`, and app-specific files in `dotfiles/<app>/`.

## Testing Guidelines

There is no dedicated test suite. Treat `nix flake check` and Home Manager evaluation as the main safety checks. For dotfile-only edits, verify the target application still parses the file, such as opening Kitty, Fastfetch, or Neovim after switching.

## Commit & Pull Request Guidelines

The Git history uses short, direct commit messages such as `eza and alias update`, `firefoxCss fix bookmark bar`, and `foot catpuccin mocha`. Follow that style: summarize the changed area and outcome in one concise line.

Pull requests should include a brief description, any commands run, and screenshots for visible UI changes such as themes, Firefox CSS, terminal styling, or wallpapers. Mention whether `home-manager switch --flake .#quang` was tested.

## Security & Configuration Tips

Do not commit private keys, tokens, machine-specific secrets, or browser session data. Review Firefox extension backups and generated config exports before adding them. Keep username- or host-specific assumptions centralized in `flake.nix` and `home.nix`.
