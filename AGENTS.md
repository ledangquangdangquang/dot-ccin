# Repository Guidelines

## Project Structure & Module Organization

This repository manages Ubuntu dotfiles with Nix flakes and Home Manager.

The active window manager is i3. Treat `dotfiles/i3/` as the window manager configuration. This project configures supporting tools (rofi, dunst, power menu, etc.); the window manager itself is installed externally.

**App configuration priority**: Add packages to `modules/packages.nix` first. For app configuration files, create `dotfiles/<app>/` and link it via `configApps` in `modules/dotfiles.nix`. Home Manager declarative modules (e.g., `programs.rofi`, `services.dunst`) should only be used when they offer deep integration that a simple config file cannot replicate (e.g., systemd services, generated configs).

- `flake.nix` defines inputs, the user-named Home Manager configuration, and shared arguments.
- `home.nix` is the minimal Home Manager entrypoint. It sets the user, home directory, state version, Catppuccin integration, and imports `./modules`.
- `modules/default.nix` is the module index. Register every new Home Manager module there.
- `modules/packages.nix` contains the shared package list. Feature-specific packages should remain in their owning module.
- `modules/dotfiles.nix` maps selected folders from `dotfiles/` into `~/.config`. Its `configApps` list is the place to register newly linked application folders.
- `modules/fcitx.nix` configures Fcitx5, Unikey, and input-method environment variables.
- `modules/wifi.nix` and `modules/bluetooth.nix` provide the Fuzzel-based network menus.
- `modules/notifications.nix` configures dunst notification daemon.
- `modules/screenshot.nix` provides the Grim, Slurp, and Satty screenshot workflow.
- `modules/fuzzyvim.nix` provides the Fzf-based project/file picker.
- `modules/tmux.nix`, `zsh.nix`, `git.nix`, `gtk.nix`, `bash.nix`, and `nix-cleanup.nix` contain their respective focused Home Manager configuration.
- `modules/firefox/` contains the Firefox Home Manager module, policies, profile settings, CSS, and related assets.
- `dotfiles/` stores application configuration directories, for example `i3/`, `rofi/`, `kitty/`, `nvim/`, `fastfetch/`, and `yazi/`.
- `Wallpapers/` contains desktop image assets.

Keep `home.nix` minimal. Add packages, generated scripts, session variables, and application logic to a focused file under `modules/`, then import it from `modules/default.nix`. Add application-owned configuration under `dotfiles/<app>/`; if the folder should be linked, add its name to `configApps` in `modules/dotfiles.nix`.

## Build, Test, and Development Commands

- `nix flake check` validates the flake outputs.
- `nix fmt` formats Nix files with the flake formatter.
- `nix run github:nix-community/home-manager -- switch --flake ".#$USER"` applies the Home Manager configuration locally.
- `home-manager switch --flake ".#$USER"` applies the same config when Home Manager is already installed.

Run validation before switching when editing `flake.nix`, `home.nix`, or `modules/*.nix`.

## Coding Style & Naming Conventions

Use two-space indentation in Nix files and keep attribute sets compact but readable. Prefer descriptive lower-case names for local variables, matching existing examples such as `dotfiles`, `configApps`, and `hostMain`. Keep modules focused: shell aliases belong in `modules/zsh.nix`, Git settings in `modules/git.nix`, and app-specific files in `dotfiles/<app>/`.

## Testing Guidelines

There is no dedicated test suite. Treat `nix flake check` and Home Manager evaluation as the main safety checks. For dotfile-only edits, verify the target application still parses the file, such as opening Kitty, Fastfetch, or Neovim after switching.

## Catppuccin Mocha Theming

This rice is centered around the Catppuccin Mocha palette. All themable apps (rofi, dunst, fastfetch, kitty, etc.) should use Catppuccin Mocha colors consistently:
- `background` (#1e1e2e / `base`)
- `foreground` (#cdd6f4 / `text`)
- `red` (#f38ba8), `blue` (#89b4fa), `green` (#a6e3a1), `yellow` (#f9e2af), `mauve` (#cba6f7), `peach` (#fab387), `teal` (#94e2d5), `sapphire` (#74c7ec)
- Surfaces: `surface0` (#313244), `surface1` (#45475a), `surface2` (#585b70)
- Subtext: `subtext1` (#bac2de), `subtext0` (#a6adc8)
- `overlay0` (#6c7086), `overlay1` (#7f849c), `overlay2` (#9399b2)

When adding app themes, ensure the colors are actual Catppuccin Mocha values (not Solarized or other palettes). Rasi theme files go in `dotfiles/<app>/` and are linked via `configApps`. Dunst config is declarative in `modules/notifications.nix` using `services.dunst`.

## Commit & Pull Request Guidelines

The Git history uses short, direct commit messages such as `eza and alias update`, `firefox css fix bookmark bar`, and `foot catppuccin mocha`. Follow that style: summarize the changed area and outcome in one concise line.

Pull requests should include a brief description, any commands run, and screenshots for visible UI changes such as themes, Firefox CSS, terminal styling, or wallpapers. Mention whether `home-manager switch --flake ".#$USER"` was tested.

## Security & Configuration Tips

Do not commit private keys, tokens, machine-specific secrets, or browser session data. Review Firefox extension backups and generated config exports before adding them. Keep username- or host-specific assumptions centralized in `flake.nix` and `home.nix`.

## Communication Style

- User has ADHD. Be extremely concise and direct.
- Skip preamble, summaries, and explanations unless explicitly asked.
- Just do the thing. One-line answers preferred.
